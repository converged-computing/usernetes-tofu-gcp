# Usernetes on Google Cloud

> This is intended to be a basic example.

We are using generation 2 of [usernetes](https://github.com/rootless-containers/usernetes).

# Usage

## Build images

Make note that the machine types should be compatible with those you chose in [build-images](../../build-images/)
First, edit variables in [basic.tfvars](basic.tfvars). This will determine number of instances, name, etc.

## Deploy

Initialize the deployment with the command:

```bash
$ terraform init
```

I find it's easiest to export my Google project in the environment for any terraform configs
that mysteriously need it.

```bash
export GOOGLE_PROJECT=$(gcloud config get-value core/project)
```

You'll want to inspect basic.tfvars and change for your use case (or keep as is for a small debugging cluster). Then:

```bash
$ make
```

And inspect the [Makefile](Makefile) to see the terraform commands we apply
to init, format, validate, and deploy. The deploy will setup networking and all the instances! Note that
you can change any of the `-var` values to be appropriate for your environment.
Verify that the cluster is up. You can shell into any compute node.

<details>

<summary>Extra Debugging Details</summary>

```bash
gcloud compute ssh usernetes-compute-001 --zone us-central1-a
```

You can check the startup scripts to make sure that everything finished.

```bash
sudo journalctl -u google-startup-scripts.service
```

</details>

I would give a few minutes for the boot script to run. next we are going to init the NFS mount
by running ssh as our user, and changing variables in `/etc/sub(u|g)id`. The reason these usernames
are off is because Google is using OS login.

```bash
for i in 1 2 3; do
  instance=usernetes-compute-00${i}
  login_user=$(gcloud compute ssh $instance --zone us-central1-a -- whoami)
done
echo "Found login user ${login_user}"
```

I usually give a minute or two for the startup script. Next we will:

1. Change the uid/gid this might vary for you - change the usernames based on the users you have)
2. Copy scripts to home
3. Setup rootless things (cgroups, eventually rootless docker)

<!--- 4. Add your user to the docker group (also might vary)-->

Note that the installation of rootless docker depends on the first step.

```bash
for i in 1 2 3; do
  instance=usernetes-compute-00${i}
  gcloud compute ssh $instance --zone us-central1-a -- sudo sed -i "s/sochat1_llnlgov/sochat1_llnl_gov/g" /etc/subuid
  gcloud compute ssh $instance --zone us-central1-a -- sudo sed -i "s/sochat1_llnlgov/sochat1_llnl_gov/g" /etc/subgid
  gcloud compute scp ./scripts --recurse ${instance}:/home/sochat1_llnl_gov --zone=us-central1-a
  gcloud compute ssh $instance --zone us-central1-a -- /bin/bash /home/sochat1_llnl_gov/scripts/rootless.sh
done
```

Note that sometimes I see:

```console
cat: /sys/fs/cgroup/user.slice/user-501043911.slice/user@501043911.service/cgroup.controllers: No such file or directory
Failed to connect to bus: No such file or directory
[INFO] systemd not detected, dockerd-rootless.sh needs to be started manually:
```

And I'm not sure why - it's like the setup is somehow wonky. The above could be a script, but a copy pasted loop is fine for now.
For the rest of this experiment we will work to setup each node. Since there are different steps per node,
we are going to clone usernetes to a non-shared location. 

### Control Plane

Let's treat instance 001 as the control plane.  We will run the script from
here. Here is a manual way:

```bash
gcloud compute ssh usernetes-compute-001 --zone us-central1-a
/bin/bash /home/sochat1_llnl_gov/scripts/001-control-plane.sh
source ~/.bashrc
# And then kubectl get nodes, etc. will work
```

And automated:

```bash
instance=usernetes-compute-001
gcloud compute ssh $instance --zone us-central1-a -- /bin/bash /home/sochat1_llnl_gov/scripts/001-control-plane.sh
```

We would want this to be even more automated, somehow. Exit (if you shelled in) and copy the kubeconfig to your host:

```bash
# Copy from control plane to local host
rm -rf ./join-command
control=usernetes-compute-001   
gcloud compute scp ${control}:/opt/usernetes/join-command ./join-command --zone=us-central1-a

# Copy from local host to other instances
for i in 2 3; do
  instance=usernetes-compute-00${i}   
  gcloud compute scp ./join-command ${instance}:/home/sochat1_llnl_gov/join-command --zone=us-central1-a
done
```

Note that I waited a few minutes here, just in case anything was pulling or otherwise getting setup.

### Worker Node

Now let's do the same setup for each worker node. Here is the manual way, for each node:

```bash
gcloud compute ssh usernetes-compute-002 --zone us-central1-a
/bin/bash /home/sochat1_llnl_gov/scripts/worker-node.sh
```

```bash
for i in 2 3; do
  instance=usernetes-compute-00${i}
  gcloud compute ssh $instance --zone us-central1-a -- /bin/bash /home/sochat1_llnl_gov/scripts/worker-node.sh
done
```

### Testing

Now let's go back to the control plane.

```bash
gcloud compute ssh usernetes-compute-001 --zone us-central1-a 
```

Ensure kubeconfig is set (and exists)

```bash
echo $KUBECONFIG
```
```console
/opt/usernetes/kubeconfig
```

And the moment of truth...

```bash
$ kubectl get nodes
```
```console
$ kubectl  get nodes
NAME                        STATUS   ROLES           AGE     VERSION
u7s-usernetes-compute-001   Ready    control-plane   2m22s   v1.28.0
u7s-usernetes-compute-002   Ready    <none>          53s     v1.28.0
u7s-usernetes-compute-003   Ready    <none>          13s     v1.28.0
```

Holy (#U$#$* why did that work this time?! 😍️

#### Test Application

Let's test running two nginx pods and having them communicate:

```bash
cd /opt/usernetes/hack
./test-smoke.sh
```

Here is the current issue:

```bash
$ kubectl exec -it dnstest-1 bash
kubectl exec [POD] [COMMAND] is DEPRECATED and will be removed in a future version. Use kubectl exec [POD] -- [COMMAND] instead.
Error from server: error dialing backend: dial tcp 10.10.0.5:10250: i/o timeout
```

The same timeout happens with `make shell`. Is it just memory maybe? oom score?

```
Sep 06 00:54:01 u7s-usernetes-compute-001 kubelet[877]: I0906 00:54:01.910936     877 pod_startup_latency_tracker.go:102] "Observed pod startup duration" pod="kube-system/coredns-5dd5756b68-6dljd" podStartSLOduration=19.910898197 podCreationTimestamp="2023-09-06 00:53:42 +0000 UTC" firstStartedPulling="0001-01-01 00:00:00 +0000 UTC" lastFinishedPulling="0001-01-01 00:00:00 +0000 UTC" observedRunningTime="2023-09-06 00:54:01.910498208 +0000 UTC m=+32.344325656" watchObservedRunningTime="2023-09-06 00:54:01.910898197 +0000 UTC m=+32.344725648"
Sep 06 00:58:30 u7s-usernetes-compute-001 kubelet[877]: E0906 00:58:30.319024     877 container_manager_linux.go:509] "Failed to ensure process in container with oom score" err="failed to apply oom score -999 to PID 877: write /proc/877/oom_score_adj: permission denied"
```

Maybe related? https://gitlab.freedesktop.org/dbus/dbus/-/issues/374

## TODO

These are the items we need to do to make this setup better.

 - Add back the nfs mount to `/home` it's largely useless now. The issue here is setting up docker, see link in main.tf for suggestion
 - More automation of setup - not ideal that we have to run so many things! These could be startup scripts I think.
 - The egress is a bit open and too permissive :)

We can work on debugging this. Here is how to interact or debug.

```bash
# Debug
make logs
make shell
make down-v
kubectl taint nodes --all node-role.kubernetes.io/control-plane-
```

## Cleanup

When you are done:

```bash
make destroy
```
