# Usernetes on Google Cloud

> This is intended to be a basic exampel.

but we are going to test out [generation 2 here](https://github.com/rootless-containers/usernetes/pull/287).

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

Next we will:

1. Change the uid/gid this might vary for you - change the usernames based on the users you have)
2. Add your user to the docker group (also might vary)

```bash
for i in 1 2 3; do
  instance=usernetes-compute-00${i}
  gcloud compute ssh $instance --zone us-central1-a -- sudo sed -i "s/sochat1_llnlgov/sochat1_llnl_gov/g" /etc/subuid
  gcloud compute ssh $instance --zone us-central1-a -- sudo sed -i "s/sochat1_llnlgov/sochat1_llnl_gov/g" /etc/subgid
  gcloud compute ssh $instance --zone us-central1-a -- /bin/bash /home/sochat1_llnl_gov/scripts/delegate.sh
  gcloud compute ssh $instance --zone us-central1-a -- sudo usermod -aG docker sochat1_llnl_gov
done
```

The above could be a script, but a copy pasted loop is fine for now.
One sanity check:

```bash
gcloud compute ssh $instance --zone us-central1-a -- cat /etc/subgid
```

And we only need to copy scripts once (the $HOME is an NFS share). Also take note of the username.

```bash
gcloud compute scp ./scripts --recurse usernetes-compute-001:/home/sochat1_llnl_gov --zone=us-central1-a
```

For the rest of this experiment we will work to setup each node. Since there are different steps per node,
we are going to clone usernetes to a non-shared location. 

### Control Plane

Let's treat instance 001 as the control plane.  We will run the script from
here.

```bash
instance=usernetes-compute-001
gcloud compute ssh $instance --zone us-central1-a -- /bin/bash /home/sochat1_llnl_gov/scripts/001-control-plane.sh
```

The full output is below:

<details>

<summary>Output for control plane</summary>

```console
External IP address was not found; defaulting to using IAP tunneling.
WARNING: 

To increase the performance of the tunnel, consider installing NumPy. For instructions,
please see https://cloud.google.com/iap/docs/using-tcp-forwarding#increasing_the_tcp_upload_bandwidth

Unable to find image 'hello-world:latest' locally
latest: Pulling from library/hello-world
719385e32844: Pull complete 
Digest: sha256:dcba6daec718f547568c562956fa47e1b03673dd010fe6ee58ca806767031d1c
Status: Downloaded newer image for hello-world:latest

Hello from Docker!
This message shows that your installation appears to be working correctly.

To generate this message, Docker took the following steps:
 1. The Docker client contacted the Docker daemon.
 2. The Docker daemon pulled the "hello-world" image from the Docker Hub.
    (amd64)
 3. The Docker daemon created a new container from that image which runs the
    executable that produces the output you are currently reading.
 4. The Docker daemon streamed that output to the Docker client, which sent it
    to your terminal.

To try something more ambitious, you can run an Ubuntu container with:
 $ docker run -it ubuntu bash

Share images, automate workflows, and more with a free Docker ID:
 https://hub.docker.com/

For more examples and ideas, visit:
 https://docs.docker.com/get-started/

Cloning into '/opt/usernetes'...
remote: Enumerating objects: 2134, done.
remote: Counting objects: 100% (440/440), done.
remote: Compressing objects: 100% (187/187), done.
remote: Total 2134 (delta 227), reused 423 (delta 219), pack-reused 1694
Receiving objects: 100% (2134/2134), 840.16 KiB | 7.31 MiB/s, done.
Resolving deltas: 100% (1247/1247), done.
Contents of /opt/usernetes
Dockerfile  LICENSE  Makefile  README.md  docker-compose.yml  hack  kubeadm-config.yaml
docker compose up --build -d
[+] Building 21.1s (9/9) FINISHED                                                                                   
 => [node internal] load .dockerignore                                                                         0.0s
 => => transferring context: 66B                                                                               0.0s
 => [node internal] load build definition from Dockerfile                                                      0.0s
 => => transferring dockerfile: 752B                                                                           0.0s
 => [node internal] load metadata for docker.io/kindest/node:v1.27.3                                           0.6s
 => [node] https://github.com/containernetworking/plugins/releases/download/v1.3.0/cni-plugins-linux-amd64-v1  0.5s
 => [node stage-3 1/3] FROM docker.io/kindest/node:v1.27.3@sha256:3966ac761ae0136263ffdb6cfd4db23ef8a83cba8a4  7.5s
 => => resolve docker.io/kindest/node:v1.27.3@sha256:3966ac761ae0136263ffdb6cfd4db23ef8a83cba8a463690e98317ad  0.0s
 => => sha256:89e7dc9f91313684c3e3a6db1557d12067cf9619e8c6cc0a442820a7964dc2d6 1.94kB / 1.94kB                 0.0s
 => => sha256:f86a56ded609290d97bd193f9c72e4f270c9e852bddae68e772b37828e76a3e5 123.82MB / 123.82MB             1.7s
 => => sha256:4a5fe1bb00cb4026658c6579761b79fb71fcfb09c9d8c045f165f462cfd18720 304.49MB / 304.49MB             4.6s
 => => sha256:3966ac761ae0136263ffdb6cfd4db23ef8a83cba8a463690e98317add2c9ba72 741B / 741B                     0.0s
 => => sha256:9dd3392d79af1b084671b05bcf65b21de476256ad1dcc853d9f3b10b4ac52dde 743B / 743B                     0.0s
 => => extracting sha256:f86a56ded609290d97bd193f9c72e4f270c9e852bddae68e772b37828e76a3e5                      2.2s
 => => extracting sha256:4a5fe1bb00cb4026658c6579761b79fb71fcfb09c9d8c045f165f462cfd18720                      2.8s
 => [node cni-plugins-amd64 1/1] ADD https://github.com/containernetworking/plugins/releases/download/v1.3.0/  0.1s
 => [node stage-3 2/3] RUN --mount=type=bind,from=cni-plugins,dst=/mnt/tmp   tar Cxzvf /opt/cni/bin /mnt/tmp/  9.8s
 => [node stage-3 3/3] RUN apt-get update &&   apt-get install -y --no-install-recommends gettext-base         2.9s
 => [node] exporting to image                                                                                  0.3s 
 => => exporting layers                                                                                        0.3s 
 => => writing image sha256:d5a7599c88765579f63d969ad7ac0517c4a6038aec9a56950e22101ace5c534e                   0.0s 
 => => naming to docker.io/library/usernetes-node                                                              0.0s 
[+] Running 3/3
 ✔ Network usernetes_default    Created                                                                        0.1s 
 ✔ Volume "usernetes_node-var"  Created                                                                        0.0s 
 ✔ Container usernetes-node-1   Started                                                                        4.9s 
docker compose exec -e U7S_HOST_IP=10.10.0.3 node sh -euc "envsubst </usernetes/kubeadm-config.yaml >/tmp/kubeadm-config.yaml"
docker compose exec -e U7S_HOST_IP=10.10.0.3 node kubeadm init --config /tmp/kubeadm-config.yaml
I0901 02:52:17.210357     112 version.go:256] remote version is much newer: v1.28.1; falling back to: stable-1.27
[init] Using Kubernetes version: v1.27.5
[preflight] Running pre-flight checks
	[WARNING FileExisting-socat]: socat not found in system path
[preflight] Pulling images required for setting up a Kubernetes cluster
[preflight] This might take a minute or two, depending on the speed of your internet connection
[preflight] You can also perform this action in beforehand using 'kubeadm config images pull'
W0901 02:52:21.904965     112 checks.go:835] detected that the sandbox image "registry.k8s.io/pause:3.7" of the container runtime is inconsistent with that used by kubeadm. It is recommended that using "registry.k8s.io/pause:3.9" as the CRI sandbox image.
[certs] Using certificateDir folder "/etc/kubernetes/pki"
[certs] Generating "ca" certificate and key
[certs] Generating "apiserver" certificate and key
[certs] apiserver serving cert is signed for DNS names [kubernetes kubernetes.default kubernetes.default.svc kubernetes.default.svc.cluster.local u7s-usernetes-compute-001] and IPs [10.96.0.1 172.18.0.2 10.10.0.3]
[certs] Generating "apiserver-kubelet-client" certificate and key
[certs] Generating "front-proxy-ca" certificate and key
[certs] Generating "front-proxy-client" certificate and key
[certs] Generating "etcd/ca" certificate and key
[certs] Generating "etcd/server" certificate and key
[certs] etcd/server serving cert is signed for DNS names [localhost u7s-usernetes-compute-001] and IPs [172.18.0.2 127.0.0.1 ::1]
[certs] Generating "etcd/peer" certificate and key
[certs] etcd/peer serving cert is signed for DNS names [localhost u7s-usernetes-compute-001] and IPs [172.18.0.2 127.0.0.1 ::1]
[certs] Generating "etcd/healthcheck-client" certificate and key
[certs] Generating "apiserver-etcd-client" certificate and key
[certs] Generating "sa" key and public key
[kubeconfig] Using kubeconfig folder "/etc/kubernetes"
[kubeconfig] Writing "admin.conf" kubeconfig file
[kubeconfig] Writing "kubelet.conf" kubeconfig file
[kubeconfig] Writing "controller-manager.conf" kubeconfig file
[kubeconfig] Writing "scheduler.conf" kubeconfig file
[kubelet-start] Writing kubelet environment file with flags to file "/var/lib/kubelet/kubeadm-flags.env"
[kubelet-start] Writing kubelet configuration to file "/var/lib/kubelet/config.yaml"
[kubelet-start] Starting the kubelet
[control-plane] Using manifest folder "/etc/kubernetes/manifests"
[control-plane] Creating static Pod manifest for "kube-apiserver"
[control-plane] Creating static Pod manifest for "kube-controller-manager"
[control-plane] Creating static Pod manifest for "kube-scheduler"
[etcd] Creating static Pod manifest for local etcd in "/etc/kubernetes/manifests"
[wait-control-plane] Waiting for the kubelet to boot up the control plane as static Pods from directory "/etc/kubernetes/manifests". This can take up to 4m0s
[apiclient] All control plane components are healthy after 7.056705 seconds
[upload-config] Storing the configuration used in ConfigMap "kubeadm-config" in the "kube-system" Namespace
[kubelet] Creating a ConfigMap "kubelet-config" in namespace kube-system with the configuration for the kubelets in the cluster
[upload-certs] Skipping phase. Please see --upload-certs
[mark-control-plane] Marking the node u7s-usernetes-compute-001 as control-plane by adding the labels: [node-role.kubernetes.io/control-plane node.kubernetes.io/exclude-from-external-load-balancers]
[mark-control-plane] Marking the node u7s-usernetes-compute-001 as control-plane by adding the taints [node-role.kubernetes.io/control-plane:NoSchedule]
[bootstrap-token] Using token: j4f4jy.a3u1h0je5jf69xrh
[bootstrap-token] Configuring bootstrap tokens, cluster-info ConfigMap, RBAC Roles
[bootstrap-token] Configured RBAC rules to allow Node Bootstrap tokens to get nodes
[bootstrap-token] Configured RBAC rules to allow Node Bootstrap tokens to post CSRs in order for nodes to get long term certificate credentials
[bootstrap-token] Configured RBAC rules to allow the csrapprover controller automatically approve CSRs from a Node Bootstrap Token
[bootstrap-token] Configured RBAC rules to allow certificate rotation for all node client certificates in the cluster
[bootstrap-token] Creating the "cluster-info" ConfigMap in the "kube-public" namespace
[kubelet-finalize] Updating "/etc/kubernetes/kubelet.conf" to point to a rotatable kubelet client certificate and key
[addons] Applied essential addon: CoreDNS
[addons] Applied essential addon: kube-proxy

Your Kubernetes control-plane has initialized successfully!

To start using your cluster, you need to run the following as a regular user:

  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config

Alternatively, if you are the root user, you can run:

  export KUBECONFIG=/etc/kubernetes/admin.conf

You should now deploy a pod network to the cluster.
Run "kubectl apply -f [podnetwork].yaml" with one of the options listed at:
  https://kubernetes.io/docs/concepts/cluster-administration/addons/

You can now join any number of control-plane nodes by copying certificate authorities
and service account keys on each node and then running the following as root:

  kubeadm join 10.10.0.3:6443 --token j4f4jy.a3u1h0je5jf69xrh \
	--discovery-token-ca-cert-hash sha256:e01683f674c14b796add97b8c5511abb0236de6ad59b45b7f71560d2ffb80f17 \
	--control-plane 

Then you can join any number of worker nodes by running the following on each as root:

kubeadm join 10.10.0.3:6443 --token j4f4jy.a3u1h0je5jf69xrh \
	--discovery-token-ca-cert-hash sha256:e01683f674c14b796add97b8c5511abb0236de6ad59b45b7f71560d2ffb80f17 
docker compose exec -e U7S_HOST_IP=10.10.0.3 node kubectl apply -f https://github.com/flannel-io/flannel/releases/download/v0.22.2/kube-flannel.yml
namespace/kube-flannel created
serviceaccount/flannel created
clusterrole.rbac.authorization.k8s.io/flannel created
clusterrolebinding.rbac.authorization.k8s.io/flannel created
configmap/kube-flannel-cfg created
daemonset.apps/kube-flannel-ds created
docker compose cp node:/etc/kubernetes/admin.conf ./kubeconfig
[+] Copying 1/0
 ✔ usernetes-node-1 copy usernetes-node-1:/etc/kubernetes/admin.conf to ./kubeconfig Copied                    0.1s 
# Run the following command by yourself:
export KUBECONFIG=/opt/usernetes/kubeconfig
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100   138  100   138    0     0   2107      0 --:--:-- --:--:-- --:--:--  2090
100 47.5M  100 47.5M    0     0  45.2M      0  0:00:01  0:00:01 --:--:-- 45.2M
NAMESPACE     NAME                                                READY   STATUS    RESTARTS   AGE
kube-system   etcd-u7s-usernetes-compute-001                      0/1     Running   0          3s
kube-system   kube-apiserver-u7s-usernetes-compute-001            0/1     Running   0          3s
kube-system   kube-controller-manager-u7s-usernetes-compute-001   0/1     Running   0          3s
kube-system   kube-scheduler-u7s-usernetes-compute-001            0/1     Running   0          3s
docker compose exec -e U7S_HOST_IP=10.10.0.3 node kubeadm token create --print-join-command >join-command
# Copy the 'join-command' file to another host, and run 'make kubeadm-join' on that host (not on this host)
Connection to compute.7396139119419387511 closed.
```

</details>

Note that the second command seems to run, but there is a warning I was worried about:

```console
[init] Using Kubernetes version: v1.27.5
[preflight] Running pre-flight checks
	[WARNING FileExisting-socat]: socat not found in system path
```

The executable `socat` is there:

```bash
$ which socat
/usr/bin/socat
```

A sochat knows a socat :)
Also note that we export the `KUBECONFIG` in the user bash profile so it should be there
when we log in again.

### Worker Node

Now let's do the same for each worker node:

```bash
for i in 2 3; do
  instance=usernetes-compute-00${i}
  gcloud compute ssh $instance --zone us-central1-a -- /bin/bash /home/sochat1_llnl_gov/scripts/worker-node.sh
done
```

Here is example output. Note that the last command sometimes fails the first time? Maybe we need a sleep or something somewhere - it does seem like something isn't ready.

<details>

<summary>Worker node output</summary>

```console
External IP address was not found; defaulting to using IAP tunneling.
WARNING: 

To increase the performance of the tunnel, consider installing NumPy. For instructions,
please see https://cloud.google.com/iap/docs/using-tcp-forwarding#increasing_the_tcp_upload_bandwidth

Unable to find image 'hello-world:latest' locally
latest: Pulling from library/hello-world
719385e32844: Pull complete 
Digest: sha256:dcba6daec718f547568c562956fa47e1b03673dd010fe6ee58ca806767031d1c
Status: Downloaded newer image for hello-world:latest

Hello from Docker!
This message shows that your installation appears to be working correctly.

To generate this message, Docker took the following steps:
 1. The Docker client contacted the Docker daemon.
 2. The Docker daemon pulled the "hello-world" image from the Docker Hub.
    (amd64)
 3. The Docker daemon created a new container from that image which runs the
    executable that produces the output you are currently reading.
 4. The Docker daemon streamed that output to the Docker client, which sent it
    to your terminal.

To try something more ambitious, you can run an Ubuntu container with:
 $ docker run -it ubuntu bash

Share images, automate workflows, and more with a free Docker ID:
 https://hub.docker.com/

For more examples and ideas, visit:
 https://docs.docker.com/get-started/

Cloning into '/opt/usernetes'...
remote: Enumerating objects: 2134, done.
remote: Counting objects: 100% (440/440), done.
remote: Compressing objects: 100% (187/187), done.
remote: Total 2134 (delta 227), reused 423 (delta 219), pack-reused 1694
Receiving objects: 100% (2134/2134), 840.59 KiB | 7.00 MiB/s, done.
Resolving deltas: 100% (1247/1247), done.
Dockerfile  LICENSE  Makefile  README.md  docker-compose.yml  hack  kubeadm-config.yaml
make: Entering directory '/opt/usernetes'
docker compose up --build -d
[+] Building 23.0s (9/9) FINISHED                                                                                   
 => [node internal] load .dockerignore                                                                         0.0s
 => => transferring context: 66B                                                                               0.0s
 => [node internal] load build definition from Dockerfile                                                      0.0s
 => => transferring dockerfile: 752B                                                                           0.0s
 => [node internal] load metadata for docker.io/kindest/node:v1.27.3                                           0.6s
 => [node] https://github.com/containernetworking/plugins/releases/download/v1.3.0/cni-plugins-linux-amd64-v1  0.5s
 => [node stage-3 1/3] FROM docker.io/kindest/node:v1.27.3@sha256:3966ac761ae0136263ffdb6cfd4db23ef8a83cba8a4  8.1s
 => => resolve docker.io/kindest/node:v1.27.3@sha256:3966ac761ae0136263ffdb6cfd4db23ef8a83cba8a463690e98317ad  0.0s
 => => sha256:3966ac761ae0136263ffdb6cfd4db23ef8a83cba8a463690e98317add2c9ba72 741B / 741B                     0.0s
 => => sha256:9dd3392d79af1b084671b05bcf65b21de476256ad1dcc853d9f3b10b4ac52dde 743B / 743B                     0.0s
 => => sha256:89e7dc9f91313684c3e3a6db1557d12067cf9619e8c6cc0a442820a7964dc2d6 1.94kB / 1.94kB                 0.0s
 => => sha256:f86a56ded609290d97bd193f9c72e4f270c9e852bddae68e772b37828e76a3e5 123.82MB / 123.82MB             1.8s
 => => sha256:4a5fe1bb00cb4026658c6579761b79fb71fcfb09c9d8c045f165f462cfd18720 304.49MB / 304.49MB             5.2s
 => => extracting sha256:f86a56ded609290d97bd193f9c72e4f270c9e852bddae68e772b37828e76a3e5                      2.3s
 => => extracting sha256:4a5fe1bb00cb4026658c6579761b79fb71fcfb09c9d8c045f165f462cfd18720                      2.8s
 => [node cni-plugins-amd64 1/1] ADD https://github.com/containernetworking/plugins/releases/download/v1.3.0/  0.1s
 => [node stage-3 2/3] RUN --mount=type=bind,from=cni-plugins,dst=/mnt/tmp   tar Cxzvf /opt/cni/bin /mnt/tmp/  9.8s
 => [node stage-3 3/3] RUN apt-get update &&   apt-get install -y --no-install-recommends gettext-base         4.0s
 => [node] exporting to image                                                                                  0.3s 
 => => exporting layers                                                                                        0.3s 
 => => writing image sha256:f089b682c80e352c923d488a71692814971ced5d6c960006a15aee2223aa919d                   0.0s 
 => => naming to docker.io/library/usernetes-node                                                              0.0s 
[+] Running 3/3
 ✔ Network usernetes_default    Created                                                                        0.1s 
 ✔ Volume "usernetes_node-var"  Created                                                                        0.0s 
 ✔ Container usernetes-node-1   Started                                                                        4.7s 
docker compose exec -e U7S_HOST_IP=10.10.0.5 node kubeadm join 10.10.0.3:6443 --token t55f82.jc9ii8yfteg875k7 --discovery-token-ca-cert-hash sha256:e01683f674c14b796add97b8c5511abb0236de6ad59b45b7f71560d2ffb80f17 
[preflight] Running pre-flight checks
	[WARNING FileExisting-socat]: socat not found in system path
error execution phase preflight: [preflight] Some fatal errors occurred:
	[ERROR CRI]: container runtime is not running: output: time="2023-09-01T02:58:53Z" level=fatal msg="validate service connection: validate CRI v1 runtime API for endpoint \"unix:///var/run/containerd/containerd.sock\": rpc error: code = Unavailable desc = connection error: desc = \"transport: Error while dialing dial unix /var/run/containerd/containerd.sock: connect: no such file or directory\""
, error: exit status 1
[preflight] If you know what you are doing, you can make a check non-fatal with `--ignore-preflight-errors=...`
To see the stack trace of this error execute with --v=5 or higher
make: *** [Makefile:75: kubeadm-join] Error 1
make: Leaving directory '/opt/usernetes'
make: Entering directory '/opt/usernetes'
docker compose up --build -d
[+] Building 0.2s (9/9) FINISHED                                                                                    
 => [node internal] load build definition from Dockerfile                                                      0.0s
 => => transferring dockerfile: 752B                                                                           0.0s
 => [node internal] load .dockerignore                                                                         0.0s
 => => transferring context: 66B                                                                               0.0s
 => [node internal] load metadata for docker.io/kindest/node:v1.27.3                                           0.1s
 => [node] https://github.com/containernetworking/plugins/releases/download/v1.3.0/cni-plugins-linux-amd64-v1  0.1s
 => [node stage-3 1/3] FROM docker.io/kindest/node:v1.27.3@sha256:3966ac761ae0136263ffdb6cfd4db23ef8a83cba8a4  0.0s
 => CACHED [node cni-plugins-amd64 1/1] ADD https://github.com/containernetworking/plugins/releases/download/  0.0s
 => CACHED [node stage-3 2/3] RUN --mount=type=bind,from=cni-plugins,dst=/mnt/tmp   tar Cxzvf /opt/cni/bin /m  0.0s
 => CACHED [node stage-3 3/3] RUN apt-get update &&   apt-get install -y --no-install-recommends gettext-base  0.0s
 => [node] exporting to image                                                                                  0.0s
 => => exporting layers                                                                                        0.0s
 => => writing image sha256:f089b682c80e352c923d488a71692814971ced5d6c960006a15aee2223aa919d                   0.0s
 => => naming to docker.io/library/usernetes-node                                                              0.0s
[+] Running 1/0
 ✔ Container usernetes-node-1  Running                                                                         0.0s 
docker compose exec -e U7S_HOST_IP=10.10.0.5 node kubeadm join 10.10.0.3:6443 --token t55f82.jc9ii8yfteg875k7 --discovery-token-ca-cert-hash sha256:e01683f674c14b796add97b8c5511abb0236de6ad59b45b7f71560d2ffb80f17 
[preflight] Running pre-flight checks
	[WARNING FileExisting-socat]: socat not found in system path
[preflight] Reading configuration from the cluster...
[preflight] FYI: You can look at this config file with 'kubectl -n kube-system get cm kubeadm-config -o yaml'
[kubelet-start] Writing kubelet configuration to file "/var/lib/kubelet/config.yaml"
[kubelet-start] Writing kubelet environment file with flags to file "/var/lib/kubelet/kubeadm-flags.env"
[kubelet-start] Starting the kubelet
[kubelet-start] Waiting for the kubelet to perform the TLS Bootstrap...

This node has joined the cluster:
* Certificate signing request was sent to apiserver and a response was received.
* The Kubelet was informed of the new secure connection details.

Run 'kubectl get nodes' on the control-plane to see this node join the cluster.

make: Leaving directory '/opt/usernetes'
Connection to compute.7014825304335904374 closed.
```

</details>

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
u7s-usernetes-compute-001   Ready    control-plane   8m13s   v1.27.3
u7s-usernetes-compute-002   Ready    <none>          107s    v1.27.3
u7s-usernetes-compute-003   Ready    <none>          4m8s    v1.27.3
```

Holy (#U$#$* why did that work this time?! 😍️

## Test Application

Let's test running two nginx pods and having them communicate:

```bash
cd /opt/usernetes/hack
./test-smoke.sh
```

Debugging output is included below - looks like an issue with flannel.

<details>

<summary>Debugging application `kubectl describe pods`</summary>

```bash
$ kubectl describe pods
```
```console
Name:             dnstest-0
Namespace:        default
Priority:         0
Service Account:  default
Node:             u7s-usernetes-compute-002/172.18.0.2
Start Time:       Fri, 01 Sep 2023 23:37:33 +0000
Labels:           controller-revision-hash=dnstest-6b77ddb6f9
                  run=dnstest
                  statefulset.kubernetes.io/pod-name=dnstest-0
Annotations:      <none>
Status:           Pending
IP:               
IPs:              <none>
Controlled By:    StatefulSet/dnstest
Containers:
  dnstest:
    Container ID:   
    Image:          nginx:alpine
    Image ID:       
    Port:           80/TCP
    Host Port:      0/TCP
    State:          Waiting
      Reason:       ContainerCreating
    Ready:          False
    Restart Count:  0
    Environment:    <none>
    Mounts:
      /var/run/secrets/kubernetes.io/serviceaccount from kube-api-access-hnhkk (ro)
Conditions:
  Type              Status
  Initialized       True 
  Ready             False 
  ContainersReady   False 
  PodScheduled      True 
Volumes:
  kube-api-access-hnhkk:
    Type:                    Projected (a volume that contains injected data from multiple sources)
    TokenExpirationSeconds:  3607
    ConfigMapName:           kube-root-ca.crt
    ConfigMapOptional:       <nil>
    DownwardAPI:             true
QoS Class:                   BestEffort
Node-Selectors:              <none>
Tolerations:                 node.kubernetes.io/not-ready:NoExecute op=Exists for 300s
                             node.kubernetes.io/unreachable:NoExecute op=Exists for 300s
Events:
  Type     Reason                  Age               From               Message
  ----     ------                  ----              ----               -------
  Normal   Scheduled               3m3s              default-scheduler  Successfully assigned default/dnstest-0 to u7s-usernetes-compute-002
  Warning  FailedCreatePodSandBox  3m2s              kubelet            Failed to create pod sandbox: rpc error: code = Unknown desc = failed to setup network for sandbox "adbef643614c95eecce8119c994afecb5222460dac2d476caaaaaedbc67535a0": plugin type="flannel" failed (add): loadFlannelSubnetEnv failed: open /run/flannel/subnet.env: no such file or directory
...
  Warning  FailedCreatePodSandBox  74s               kubelet            Failed to create pod sandbox: rpc error: code = Unknown desc = failed to setup network for sandbox "7fcfabd2e8733659bcd2c90b664f8cb8c5cabc085f43a90cfcdcb4922b58cd81": plugin type="flannel" failed (add): loadFlannelSubnetEnv failed: open /run/flannel/subnet.env: no such file or directory
  Warning  FailedCreatePodSandBox  6s (x5 over 59s)  kubelet            (combined from similar events): Failed to create pod sandbox: rpc error: code = Unknown desc = failed to setup network for sandbox "06028b69c7c0bc429d98fa50dee6eb1ea5f90208f53562073358cb4d459d9f87": plugin type="flannel" failed (add): loadFlannelSubnetEnv failed: open /run/flannel/subnet.env: no such file or directory
```

And then the service:

```bash
$ kubectl describe svc
```
```console
Name:              dnstest
Namespace:         default
Labels:            run=dnstest
Annotations:       <none>
Selector:          run=dnstest
Type:              ClusterIP
IP Family Policy:  SingleStack
IP Families:       IPv4
IP:                None
IPs:               None
Port:              http  80/TCP
TargetPort:        80/TCP
Endpoints:         <none>
Session Affinity:  None
Events:            <none>


Name:              kubernetes
Namespace:         default
Labels:            component=apiserver
                   provider=kubernetes
Annotations:       <none>
Selector:          <none>
Type:              ClusterIP
IP Family Policy:  SingleStack
IP Families:       IPv4
IP:                10.96.0.1
IPs:               10.96.0.1
Port:              https  443/TCP
TargetPort:        6443/TCP
Endpoints:         172.18.0.2:6443
Session Affinity:  None
Events:            <none>
```

</details>

And complete output of logs

<details>

<summary>Output of `make logs`</summary>

```bash
docker compose exec -e U7S_HOST_IP=10.10.0.5 node journalctl --follow --since="1 day ago"
-- Journal begins at Fri 2023-09-01 23:34:50 UTC. --
Sep 01 23:34:50 u7s-usernetes-compute-001 systemd-journald[96]: Journal started
Sep 01 23:34:50 u7s-usernetes-compute-001 systemd-journald[96]: Runtime Journal (/run/log/journal/5e1e2799dd1c4cce8e4e7d28ac265148) is 8.0M, max 1.5G, 1.5G free.
Sep 01 23:34:50 u7s-usernetes-compute-001 systemd-sysusers[101]: Creating group systemd-timesync with gid 999.
Sep 01 23:34:50 u7s-usernetes-compute-001 systemd-sysusers[101]: Creating user systemd-timesync (systemd Time Synchronization) with uid 999 and gid 999.
Sep 01 23:34:50 u7s-usernetes-compute-001 systemd-sysusers[101]: Creating group systemd-coredump with gid 998.
Sep 01 23:34:50 u7s-usernetes-compute-001 systemd-sysusers[101]: Creating user systemd-coredump (systemd Core Dumper) with uid 998 and gid 998.
Sep 01 23:34:50 u7s-usernetes-compute-001 systemd[1]: Starting Flush Journal to Persistent Storage...
Sep 01 23:34:50 u7s-usernetes-compute-001 systemd[1]: Finished Create System Users.
Sep 01 23:34:50 u7s-usernetes-compute-001 systemd[1]: Starting Create Static Device Nodes in /dev...
Sep 01 23:34:50 u7s-usernetes-compute-001 systemd-journald[96]: Runtime Journal (/run/log/journal/5e1e2799dd1c4cce8e4e7d28ac265148) is 8.0M, max 1.5G, 1.5G free.
Sep 01 23:34:50 u7s-usernetes-compute-001 systemd[1]: Finished Flush Journal to Persistent Storage.
Sep 01 23:34:50 u7s-usernetes-compute-001 systemd[1]: Finished Create Static Device Nodes in /dev.
Sep 01 23:34:50 u7s-usernetes-compute-001 systemd[1]: Reached target Local File Systems (Pre).
Sep 01 23:34:50 u7s-usernetes-compute-001 systemd[1]: Reached target Local File Systems.
Sep 01 23:34:50 u7s-usernetes-compute-001 systemd[1]: Condition check resulted in Store a System Token in an EFI Variable being skipped.
Sep 01 23:34:50 u7s-usernetes-compute-001 systemd[1]: Condition check resulted in Commit a transient machine-id on disk being skipped.
Sep 01 23:34:50 u7s-usernetes-compute-001 systemd[1]: Condition check resulted in Rule-based Manager for Device Events and Files being skipped.
Sep 01 23:34:50 u7s-usernetes-compute-001 systemd-modules-load[97]: Inserted module 'iscsi_tcp'
Sep 01 23:34:51 u7s-usernetes-compute-001 systemd-modules-load[97]: Inserted module 'ib_iser'
Sep 01 23:34:51 u7s-usernetes-compute-001 systemd[1]: Finished Load Kernel Modules.
Sep 01 23:34:51 u7s-usernetes-compute-001 systemd[1]: Starting Apply Kernel Variables...
Sep 01 23:34:51 u7s-usernetes-compute-001 systemd[1]: Finished Apply Kernel Variables.
Sep 01 23:34:51 u7s-usernetes-compute-001 systemd[1]: Reached target System Initialization.
Sep 01 23:34:51 u7s-usernetes-compute-001 systemd[1]: Started Daily Cleanup of Temporary Directories.
Sep 01 23:34:51 u7s-usernetes-compute-001 systemd[1]: Reached target Basic System.
Sep 01 23:34:51 u7s-usernetes-compute-001 systemd[1]: Reached target Timers.
Sep 01 23:34:51 u7s-usernetes-compute-001 systemd[1]: Starting Undo KIND mount hacks...
Sep 01 23:34:51 u7s-usernetes-compute-001 systemd[1]: undo-mount-hacks.service: Succeeded.
Sep 01 23:34:51 u7s-usernetes-compute-001 systemd[1]: Finished Undo KIND mount hacks.
Sep 01 23:34:51 u7s-usernetes-compute-001 systemd[1]: Starting containerd container runtime...
Sep 01 23:34:51 u7s-usernetes-compute-001 systemd[1]: Condition check resulted in kubelet: The Kubernetes Node Agent being skipped.
Sep 01 23:34:51 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:51.049596576Z" level=info msg="starting containerd" revision=1677a17964311325ed1c31e2c0a3589ce6d5c30d version=v1.7.1
Sep 01 23:34:51 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:51.063768100Z" level=info msg="loading plugin \"io.containerd.content.v1.content\"..." type=io.containerd.content.v1
Sep 01 23:34:51 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:51.063804553Z" level=info msg="loading plugin \"io.containerd.snapshotter.v1.native\"..." type=io.containerd.snapshotter.v1
Sep 01 23:34:51 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:51.063821880Z" level=info msg="loading plugin \"io.containerd.snapshotter.v1.overlayfs\"..." type=io.containerd.snapshotter.v1
Sep 01 23:34:51 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:51.063913370Z" level=info msg="loading plugin \"io.containerd.snapshotter.v1.fuse-overlayfs\"..." type=io.containerd.snapshotter.v1
Sep 01 23:34:51 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:51.064131872Z" level=info msg="loading plugin \"io.containerd.metadata.v1.bolt\"..." type=io.containerd.metadata.v1
Sep 01 23:34:51 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:51.064150935Z" level=info msg="metadata content store policy set" policy=shared
Sep 01 23:34:51 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:51.064416322Z" level=info msg="loading plugin \"io.containerd.differ.v1.walking\"..." type=io.containerd.differ.v1
Sep 01 23:34:51 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:51.064436988Z" level=info msg="loading plugin \"io.containerd.event.v1.exchange\"..." type=io.containerd.event.v1
Sep 01 23:34:51 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:51.064447628Z" level=info msg="loading plugin \"io.containerd.gc.v1.scheduler\"..." type=io.containerd.gc.v1
Sep 01 23:34:51 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:51.064472574Z" level=info msg="loading plugin \"io.containerd.lease.v1.manager\"..." type=io.containerd.lease.v1
Sep 01 23:34:51 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:51.064485487Z" level=info msg="loading plugin \"io.containerd.nri.v1.nri\"..." type=io.containerd.nri.v1
Sep 01 23:34:51 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:51.064496576Z" level=info msg="NRI interface is disabled by configuration."
Sep 01 23:34:51 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:51.064506266Z" level=info msg="loading plugin \"io.containerd.runtime.v2.task\"..." type=io.containerd.runtime.v2
Sep 01 23:34:51 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:51.064562330Z" level=info msg="loading plugin \"io.containerd.runtime.v2.shim\"..." type=io.containerd.runtime.v2
Sep 01 23:34:51 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:51.064633634Z" level=info msg="loading plugin \"io.containerd.sandbox.store.v1.local\"..." type=io.containerd.sandbox.store.v1
Sep 01 23:34:51 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:51.064648641Z" level=info msg="loading plugin \"io.containerd.sandbox.controller.v1.local\"..." type=io.containerd.sandbox.controller.v1
Sep 01 23:34:51 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:51.064659128Z" level=info msg="loading plugin \"io.containerd.streaming.v1.manager\"..." type=io.containerd.streaming.v1
Sep 01 23:34:51 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:51.064669143Z" level=info msg="loading plugin \"io.containerd.service.v1.introspection-service\"..." type=io.containerd.service.v1
Sep 01 23:34:51 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:51.064684504Z" level=info msg="loading plugin \"io.containerd.service.v1.containers-service\"..." type=io.containerd.service.v1
Sep 01 23:34:51 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:51.064695991Z" level=info msg="loading plugin \"io.containerd.service.v1.content-service\"..." type=io.containerd.service.v1
Sep 01 23:34:51 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:51.064704988Z" level=info msg="loading plugin \"io.containerd.service.v1.diff-service\"..." type=io.containerd.service.v1
Sep 01 23:34:51 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:51.064714310Z" level=info msg="loading plugin \"io.containerd.service.v1.images-service\"..." type=io.containerd.service.v1
Sep 01 23:34:51 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:51.064730761Z" level=info msg="loading plugin \"io.containerd.service.v1.namespaces-service\"..." type=io.containerd.service.v1
Sep 01 23:34:51 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:51.064744726Z" level=info msg="loading plugin \"io.containerd.service.v1.snapshots-service\"..." type=io.containerd.service.v1
Sep 01 23:34:51 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:51.064755469Z" level=info msg="loading plugin \"io.containerd.runtime.v1.linux\"..." type=io.containerd.runtime.v1
Sep 01 23:34:51 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:51.064792145Z" level=info msg="loading plugin \"io.containerd.monitor.v1.cgroups\"..." type=io.containerd.monitor.v1
Sep 01 23:34:51 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:51.064958941Z" level=info msg="loading plugin \"io.containerd.service.v1.tasks-service\"..." type=io.containerd.service.v1
Sep 01 23:34:51 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:51.064982026Z" level=info msg="loading plugin \"io.containerd.grpc.v1.introspection\"..." type=io.containerd.grpc.v1
Sep 01 23:34:51 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:51.065052290Z" level=info msg="loading plugin \"io.containerd.transfer.v1.local\"..." type=io.containerd.transfer.v1
Sep 01 23:34:51 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:51.065084322Z" level=info msg="loading plugin \"io.containerd.internal.v1.restart\"..." type=io.containerd.internal.v1
Sep 01 23:34:51 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:51.065145697Z" level=info msg="loading plugin \"io.containerd.grpc.v1.containers\"..." type=io.containerd.grpc.v1
Sep 01 23:34:51 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:51.065158858Z" level=info msg="loading plugin \"io.containerd.grpc.v1.content\"..." type=io.containerd.grpc.v1
Sep 01 23:34:51 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:51.065169747Z" level=info msg="loading plugin \"io.containerd.grpc.v1.diff\"..." type=io.containerd.grpc.v1
Sep 01 23:34:51 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:51.065178773Z" level=info msg="loading plugin \"io.containerd.grpc.v1.events\"..." type=io.containerd.grpc.v1
Sep 01 23:34:51 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:51.065192562Z" level=info msg="loading plugin \"io.containerd.grpc.v1.healthcheck\"..." type=io.containerd.grpc.v1
Sep 01 23:34:51 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:51.065202664Z" level=info msg="loading plugin \"io.containerd.grpc.v1.images\"..." type=io.containerd.grpc.v1
Sep 01 23:34:51 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:51.065210856Z" level=info msg="loading plugin \"io.containerd.grpc.v1.leases\"..." type=io.containerd.grpc.v1
Sep 01 23:34:51 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:51.065221112Z" level=info msg="loading plugin \"io.containerd.grpc.v1.namespaces\"..." type=io.containerd.grpc.v1
Sep 01 23:34:51 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:51.065231467Z" level=info msg="loading plugin \"io.containerd.internal.v1.opt\"..." type=io.containerd.internal.v1
Sep 01 23:34:51 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:51.065299322Z" level=info msg="loading plugin \"io.containerd.grpc.v1.sandbox-controllers\"..." type=io.containerd.grpc.v1
Sep 01 23:34:51 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:51.065314322Z" level=info msg="loading plugin \"io.containerd.grpc.v1.sandboxes\"..." type=io.containerd.grpc.v1
Sep 01 23:34:51 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:51.065324043Z" level=info msg="loading plugin \"io.containerd.grpc.v1.snapshots\"..." type=io.containerd.grpc.v1
Sep 01 23:34:51 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:51.065332421Z" level=info msg="loading plugin \"io.containerd.grpc.v1.streaming\"..." type=io.containerd.grpc.v1
Sep 01 23:34:51 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:51.065341072Z" level=info msg="loading plugin \"io.containerd.grpc.v1.tasks\"..." type=io.containerd.grpc.v1
Sep 01 23:34:51 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:51.065358083Z" level=info msg="loading plugin \"io.containerd.grpc.v1.transfer\"..." type=io.containerd.grpc.v1
Sep 01 23:34:51 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:51.065368336Z" level=info msg="loading plugin \"io.containerd.grpc.v1.version\"..." type=io.containerd.grpc.v1
Sep 01 23:34:51 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:51.065375790Z" level=info msg="loading plugin \"io.containerd.grpc.v1.cri\"..." type=io.containerd.grpc.v1
Sep 01 23:34:51 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:51.065558915Z" level=info msg="Start cri plugin with config {PluginConfig:{ContainerdConfig:{Snapshotter:overlayfs DefaultRuntimeName:runc DefaultRuntime:{Type: Path: Engine: PodAnnotations:[] ContainerAnnotations:[] Root: Options:map[] PrivilegedWithoutHostDevices:false PrivilegedWithoutHostDevicesAllDevicesAllowed:false BaseRuntimeSpec: NetworkPluginConfDir: NetworkPluginMaxConfNum:0 Snapshotter: SandboxMode:} UntrustedWorkloadRuntime:{Type: Path: Engine: PodAnnotations:[] ContainerAnnotations:[] Root: Options:map[] PrivilegedWithoutHostDevices:false PrivilegedWithoutHostDevicesAllDevicesAllowed:false BaseRuntimeSpec: NetworkPluginConfDir: NetworkPluginMaxConfNum:0 Snapshotter: SandboxMode:} Runtimes:map[runc:{Type:io.containerd.runc.v2 Path: Engine: PodAnnotations:[] ContainerAnnotations:[] Root: Options:map[SystemdCgroup:true] PrivilegedWithoutHostDevices:false PrivilegedWithoutHostDevicesAllDevicesAllowed:false BaseRuntimeSpec:/etc/containerd/cri-base.json NetworkPluginConfDir: NetworkPluginMaxConfNum:0 Snapshotter: SandboxMode:podsandbox} test-handler:{Type:io.containerd.runc.v2 Path: Engine: PodAnnotations:[] ContainerAnnotations:[] Root: Options:map[SystemdCgroup:true] PrivilegedWithoutHostDevices:false PrivilegedWithoutHostDevicesAllDevicesAllowed:false BaseRuntimeSpec:/etc/containerd/cri-base.json NetworkPluginConfDir: NetworkPluginMaxConfNum:0 Snapshotter: SandboxMode:podsandbox}] NoPivot:false DisableSnapshotAnnotations:true DiscardUnpackedLayers:true IgnoreBlockIONotEnabledErrors:false IgnoreRdtNotEnabledErrors:false} CniConfig:{NetworkPluginBinDir:/opt/cni/bin NetworkPluginConfDir:/etc/cni/net.d NetworkPluginMaxConfNum:1 NetworkPluginSetupSerially:false NetworkPluginConfTemplate: IPPreference:} Registry:{ConfigPath: Mirrors:map[] Configs:map[] Auths:map[] Headers:map[]} ImageDecryption:{KeyModel:node} DisableTCPService:true StreamServerAddress:127.0.0.1 StreamServerPort:0 StreamIdleTimeout:4h0m0s EnableSelinux:false SelinuxCategoryRange:1024 SandboxImage:registry.k8s.io/pause:3.7 StatsCollectPeriod:10 SystemdCgroup:false EnableTLSStreaming:false X509KeyPairStreaming:{TLSCertFile: TLSKeyFile:} MaxContainerLogLineSize:16384 DisableCgroup:false DisableApparmor:false RestrictOOMScoreAdj:false MaxConcurrentDownloads:3 DisableProcMount:false UnsetSeccompProfile: TolerateMissingHugetlbController:true DisableHugetlbController:true DeviceOwnershipFromSecurityContext:false IgnoreImageDefinedVolumes:false NetNSMountsUnderStateDir:false EnableUnprivilegedPorts:false EnableUnprivilegedICMP:false EnableCDI:false CDISpecDirs:[/etc/cdi /var/run/cdi] ImagePullProgressTimeout:1m0s DrainExecSyncIOTimeout:0s} ContainerdRootDir:/var/lib/containerd ContainerdEndpoint:/run/containerd/containerd.sock RootDir:/var/lib/containerd/io.containerd.grpc.v1.cri StateDir:/run/containerd/io.containerd.grpc.v1.cri}"
Sep 01 23:34:51 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:51.065612514Z" level=info msg="Connect containerd service"
Sep 01 23:34:51 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:51.065634098Z" level=info msg="using legacy CRI server"
Sep 01 23:34:51 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:51.065639356Z" level=info msg="using experimental NRI integration - disable nri plugin to prevent this"
Sep 01 23:34:51 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:51.065662504Z" level=info msg="Get image filesystem path \"/var/lib/containerd/io.containerd.snapshotter.v1.overlayfs\""
Sep 01 23:34:51 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:51.066152862Z" level=error msg="failed to load cni during init, please check CRI plugin status before setting up network for pods" error="cni config load failed: no network config found in /etc/cni/net.d: cni plugin not initialized: failed to load cni config"
Sep 01 23:34:51 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:51.067018515Z" level=info msg="loading plugin \"io.containerd.tracing.processor.v1.otlp\"..." type=io.containerd.tracing.processor.v1
Sep 01 23:34:51 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:51.067046635Z" level=info msg="skip loading plugin \"io.containerd.tracing.processor.v1.otlp\"..." error="no OpenTelemetry endpoint: skip plugin" type=io.containerd.tracing.processor.v1
Sep 01 23:34:51 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:51.067060378Z" level=info msg="loading plugin \"io.containerd.internal.v1.tracing\"..." type=io.containerd.internal.v1
Sep 01 23:34:51 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:51.067072910Z" level=info msg="skipping tracing processor initialization (no tracing plugin)" error="no OpenTelemetry endpoint: skip plugin"
Sep 01 23:34:51 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:51.067076190Z" level=info msg="Start subscribing containerd event"
Sep 01 23:34:51 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:51.067120446Z" level=info msg="Start recovering state"
Sep 01 23:34:51 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:51.067408043Z" level=info msg=serving... address=/run/containerd/containerd.sock.ttrpc
Sep 01 23:34:51 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:51.067530138Z" level=info msg=serving... address=/run/containerd/containerd.sock
Sep 01 23:34:51 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:51.067643715Z" level=info msg="containerd successfully booted in 0.018566s"
Sep 01 23:34:51 u7s-usernetes-compute-001 systemd[1]: Started containerd container runtime.
Sep 01 23:34:51 u7s-usernetes-compute-001 systemd[1]: Reached target Multi-User System.
Sep 01 23:34:51 u7s-usernetes-compute-001 systemd[1]: Reached target Graphical Interface.
Sep 01 23:34:51 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:51.068100710Z" level=warning msg="The image sha256:221177c6082a88ea4f6240ab2450d540955ac6f4d5454f0e15751b653ebda165 is not unpacked."
Sep 01 23:34:51 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:51.068180264Z" level=warning msg="The image sha256:9d5429f6d7697ae3186f049e142875ba5854f674dfee916fa6c53da276808a23 is not unpacked."
Sep 01 23:34:51 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:51.068212261Z" level=warning msg="The image docker.io/kindest/kindnetd:v20230511-dc714da8 is not unpacked."
Sep 01 23:34:51 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:51.068871961Z" level=warning msg="The image sha256:b0b1fa0f58c6e932b7f20bf208b2841317a1e8c88cc51b18358310bbd8ec95da is not unpacked."
Sep 01 23:34:51 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:51.069050773Z" level=warning msg="The image import-2023-06-15@sha256:0202953c0b15043ca535e81d97f7062240ae66ea044b24378370d6e577782762 is not unpacked."
Sep 01 23:34:51 u7s-usernetes-compute-001 systemd[1]: Starting Update UTMP about System Runlevel Changes...
Sep 01 23:34:51 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:51.069983336Z" level=warning msg="The image registry.k8s.io/kube-proxy:v1.27.3 is not unpacked."
Sep 01 23:34:51 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:51.070031020Z" level=warning msg="The image sha256:be300acfc86223548b4949398f964389b7309dfcfdcfc89125286359abb86956 is not unpacked."
Sep 01 23:34:51 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:51.070086475Z" level=warning msg="The image sha256:c604ff157f0cff86bfa45c67c76c949deaf48d8d68560fc4c456a319af5fd8fa is not unpacked."
Sep 01 23:34:51 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:51.070092720Z" level=warning msg="The image registry.k8s.io/kube-scheduler:v1.27.3 is not unpacked."
Sep 01 23:34:51 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:51.070097909Z" level=warning msg="The image sha256:9f8f3a9f3e8a9706694dd6d7a62abd1590034454974c31cd0e21c85cf2d3a1d5 is not unpacked."
Sep 01 23:34:51 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:51.070057016Z" level=warning msg="The image sha256:205a4d549b94d37cc0e39e08cbf8871ffe2d7e7cbb6832e26713cd69ea1e2c4f is not unpacked."
Sep 01 23:34:51 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:51.070362280Z" level=warning msg="The image import-2023-06-15@sha256:ce2145a147b3f1fc440ba15eaa91b879ba9cbf929c8dd8f3190868f4373f2183 is not unpacked."
Sep 01 23:34:51 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:51.070480818Z" level=warning msg="The image sha256:ead0a4a53df89fd173874b46093b6e62d8c72967bbf606d672c9e8c9b601a4fc is not unpacked."
Sep 01 23:34:51 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:51.070602454Z" level=warning msg="The image sha256:86b6af7dd652c1b38118be1c338e9354b33469e69a218f7e290a0ca5304ad681 is not unpacked."
Sep 01 23:34:51 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:51.070695874Z" level=warning msg="The image registry.k8s.io/coredns/coredns:v1.10.1 is not unpacked."
Sep 01 23:34:51 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:51.070722424Z" level=warning msg="The image registry.k8s.io/kube-controller-manager:v1.27.3 is not unpacked."
Sep 01 23:34:51 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:51.070712916Z" level=warning msg="The image registry.k8s.io/kube-apiserver:v1.27.3 is not unpacked."
Sep 01 23:34:51 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:51.071599126Z" level=warning msg="The image registry.k8s.io/pause:3.7 is not unpacked."
Sep 01 23:34:51 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:51.071604606Z" level=warning msg="The image import-2023-06-15@sha256:9d6f903c0d4bf3b145c7bbc68727251ca1abf98aed7f8d2acb9f6a10ac81e8c2 is not unpacked."
Sep 01 23:34:51 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:51.072019445Z" level=warning msg="The image import-2023-06-15@sha256:bdbeb95d8a0820cbc385e44f75ed25799ac8961e952ded26aa2a09b3377dfee7 is not unpacked."
Sep 01 23:34:51 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:51.072019952Z" level=warning msg="The image registry.k8s.io/etcd:3.5.7-0 is not unpacked."
Sep 01 23:34:51 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:51.072153106Z" level=warning msg="The image docker.io/kindest/local-path-provisioner:v20230511-dc714da8 is not unpacked."
Sep 01 23:34:51 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:51.072280307Z" level=warning msg="The image sha256:ce18e076e9d4b4283a79ef706170486225475fc4d64253710d94780fb6ec7627 is not unpacked."
Sep 01 23:34:51 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:51.072463433Z" level=warning msg="The image docker.io/kindest/local-path-helper:v20230510-486859a6 is not unpacked."
Sep 01 23:34:51 u7s-usernetes-compute-001 systemd[1]: systemd-update-utmp-runlevel.service: Succeeded.
Sep 01 23:34:51 u7s-usernetes-compute-001 systemd[1]: Finished Update UTMP about System Runlevel Changes.
Sep 01 23:34:51 u7s-usernetes-compute-001 systemd[1]: Startup finished in 440ms.
Sep 01 23:34:51 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:51.084635668Z" level=info msg="Start event monitor"
Sep 01 23:34:51 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:51.084657492Z" level=info msg="Start snapshots syncer"
Sep 01 23:34:51 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:51.084666900Z" level=info msg="Start cni network conf syncer for default"
Sep 01 23:34:51 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:51.084672758Z" level=info msg="Start streaming server"
Sep 01 23:34:51 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:51.441261954Z" level=info msg="PullImage \"registry.k8s.io/kube-apiserver:v1.27.5\""
Sep 01 23:34:51 u7s-usernetes-compute-001 systemd[1]: var-lib-containerd-tmpmounts-containerd\x2dmount3208157555.mount: Succeeded.
Sep 01 23:34:52 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:52.772688239Z" level=info msg="ImageCreate event name:\"registry.k8s.io/kube-apiserver:v1.27.5\" labels:{key:\"io.cri-containerd.image\" value:\"managed\"}"
Sep 01 23:34:52 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:52.773439019Z" level=info msg="stop pulling image registry.k8s.io/kube-apiserver:v1.27.5: active requests=0, bytes read=32416613"
Sep 01 23:34:52 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:52.774432781Z" level=info msg="ImageCreate event name:\"sha256:b58f4bc39345002ec3201b4a944a723612a8b58b5c4c15c9e37543e256335c25\" labels:{key:\"io.cri-containerd.image\" value:\"managed\"}"
Sep 01 23:34:52 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:52.775930905Z" level=info msg="ImageUpdate event name:\"registry.k8s.io/kube-apiserver:v1.27.5\" labels:{key:\"io.cri-containerd.image\" value:\"managed\"}"
Sep 01 23:34:52 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:52.777549606Z" level=info msg="ImageCreate event name:\"registry.k8s.io/kube-apiserver@sha256:d1929adf470fcc623ff6abf114ea8edd72bccacced84795bcd1a0084b40babe3\" labels:{key:\"io.cri-containerd.image\" value:\"managed\"}"
Sep 01 23:34:52 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:52.778268260Z" level=info msg="Pulled image \"registry.k8s.io/kube-apiserver:v1.27.5\" with image id \"sha256:b58f4bc39345002ec3201b4a944a723612a8b58b5c4c15c9e37543e256335c25\", repo tag \"registry.k8s.io/kube-apiserver:v1.27.5\", repo digest \"registry.k8s.io/kube-apiserver@sha256:d1929adf470fcc623ff6abf114ea8edd72bccacced84795bcd1a0084b40babe3\", size \"33386504\" in 1.336958292s"
Sep 01 23:34:52 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:52.778299372Z" level=info msg="PullImage \"registry.k8s.io/kube-apiserver:v1.27.5\" returns image reference \"sha256:b58f4bc39345002ec3201b4a944a723612a8b58b5c4c15c9e37543e256335c25\""
Sep 01 23:34:52 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:52.811225440Z" level=info msg="PullImage \"registry.k8s.io/kube-controller-manager:v1.27.5\""
Sep 01 23:34:53 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:53.963564842Z" level=info msg="ImageCreate event name:\"registry.k8s.io/kube-controller-manager:v1.27.5\" labels:{key:\"io.cri-containerd.image\" value:\"managed\"}"
Sep 01 23:34:53 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:53.964305493Z" level=info msg="stop pulling image registry.k8s.io/kube-controller-manager:v1.27.5: active requests=0, bytes read=29283143"
Sep 01 23:34:53 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:53.965426942Z" level=info msg="ImageCreate event name:\"sha256:ae819fd2a0d75d119af03d7b933ab72df32a42360ef607ba36106575fae38e18\" labels:{key:\"io.cri-containerd.image\" value:\"managed\"}"
Sep 01 23:34:53 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:53.967011839Z" level=info msg="ImageUpdate event name:\"registry.k8s.io/kube-controller-manager:v1.27.5\" labels:{key:\"io.cri-containerd.image\" value:\"managed\"}"
Sep 01 23:34:53 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:53.968587656Z" level=info msg="ImageCreate event name:\"registry.k8s.io/kube-controller-manager@sha256:2f3d44a2ef081468a43e3d3481c78c798bb97cd819ca181d34f6b05f33017a5c\" labels:{key:\"io.cri-containerd.image\" value:\"managed\"}"
Sep 01 23:34:53 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:53.969260529Z" level=info msg="Pulled image \"registry.k8s.io/kube-controller-manager:v1.27.5\" with image id \"sha256:ae819fd2a0d75d119af03d7b933ab72df32a42360ef607ba36106575fae38e18\", repo tag \"registry.k8s.io/kube-controller-manager:v1.27.5\", repo digest \"registry.k8s.io/kube-controller-manager@sha256:2f3d44a2ef081468a43e3d3481c78c798bb97cd819ca181d34f6b05f33017a5c\", size \"30978722\" in 1.158004429s"
Sep 01 23:34:53 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:53.969292722Z" level=info msg="PullImage \"registry.k8s.io/kube-controller-manager:v1.27.5\" returns image reference \"sha256:ae819fd2a0d75d119af03d7b933ab72df32a42360ef607ba36106575fae38e18\""
Sep 01 23:34:54 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:54.002079603Z" level=info msg="PullImage \"registry.k8s.io/kube-scheduler:v1.27.5\""
Sep 01 23:34:54 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:54.819181151Z" level=info msg="ImageCreate event name:\"registry.k8s.io/kube-scheduler:v1.27.5\" labels:{key:\"io.cri-containerd.image\" value:\"managed\"}"
Sep 01 23:34:54 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:54.819823362Z" level=info msg="stop pulling image registry.k8s.io/kube-scheduler:v1.27.5: active requests=0, bytes read=16536703"
Sep 01 23:34:54 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:54.820986846Z" level=info msg="ImageCreate event name:\"sha256:96c06904875e1192cbf4eb7f45d3c79f99e65d3cb1d19ac5a35204dd75f1bc2d\" labels:{key:\"io.cri-containerd.image\" value:\"managed\"}"
Sep 01 23:34:54 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:54.822726580Z" level=info msg="ImageUpdate event name:\"registry.k8s.io/kube-scheduler:v1.27.5\" labels:{key:\"io.cri-containerd.image\" value:\"managed\"}"
Sep 01 23:34:54 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:54.824251217Z" level=info msg="ImageCreate event name:\"registry.k8s.io/kube-scheduler@sha256:be4cc611269fce9c54491bc1529c89ea08b183ae9f4e90095e51a7a23e0f1655\" labels:{key:\"io.cri-containerd.image\" value:\"managed\"}"
Sep 01 23:34:54 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:54.824987571Z" level=info msg="Pulled image \"registry.k8s.io/kube-scheduler:v1.27.5\" with image id \"sha256:96c06904875e1192cbf4eb7f45d3c79f99e65d3cb1d19ac5a35204dd75f1bc2d\", repo tag \"registry.k8s.io/kube-scheduler:v1.27.5\", repo digest \"registry.k8s.io/kube-scheduler@sha256:be4cc611269fce9c54491bc1529c89ea08b183ae9f4e90095e51a7a23e0f1655\", size \"18232318\" in 822.874373ms"
Sep 01 23:34:54 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:54.825022749Z" level=info msg="PullImage \"registry.k8s.io/kube-scheduler:v1.27.5\" returns image reference \"sha256:96c06904875e1192cbf4eb7f45d3c79f99e65d3cb1d19ac5a35204dd75f1bc2d\""
Sep 01 23:34:54 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:54.858494348Z" level=info msg="PullImage \"registry.k8s.io/kube-proxy:v1.27.5\""
Sep 01 23:34:55 u7s-usernetes-compute-001 systemd[1]: var-lib-containerd-tmpmounts-containerd\x2dmount19855878.mount: Succeeded.
Sep 01 23:34:55 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:55.658176845Z" level=info msg="ImageCreate event name:\"registry.k8s.io/kube-proxy:v1.27.5\" labels:{key:\"io.cri-containerd.image\" value:\"managed\"}"
Sep 01 23:34:55 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:55.658981732Z" level=info msg="stop pulling image registry.k8s.io/kube-proxy:v1.27.5: active requests=0, bytes read=16168358"
Sep 01 23:34:55 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:55.660030266Z" level=info msg="ImageCreate event name:\"sha256:f249729a2355525533403e8580570bb19df59c41a7510d70f0373bf0880cf7d5\" labels:{key:\"io.cri-containerd.image\" value:\"managed\"}"
Sep 01 23:34:55 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:55.661415527Z" level=info msg="ImageUpdate event name:\"registry.k8s.io/kube-proxy:v1.27.5\" labels:{key:\"io.cri-containerd.image\" value:\"managed\"}"
Sep 01 23:34:55 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:55.662689969Z" level=info msg="ImageCreate event name:\"registry.k8s.io/kube-proxy@sha256:ad9fac60432dc7d4717db4703f7b62d12f34825dff61f6462f65bd66914d7534\" labels:{key:\"io.cri-containerd.image\" value:\"managed\"}"
Sep 01 23:34:55 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:55.664372021Z" level=info msg="Pulled image \"registry.k8s.io/kube-proxy:v1.27.5\" with image id \"sha256:f249729a2355525533403e8580570bb19df59c41a7510d70f0373bf0880cf7d5\", repo tag \"registry.k8s.io/kube-proxy:v1.27.5\", repo digest \"registry.k8s.io/kube-proxy@sha256:ad9fac60432dc7d4717db4703f7b62d12f34825dff61f6462f65bd66914d7534\", size \"23898800\" in 805.840112ms"
Sep 01 23:34:55 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:55.664682128Z" level=info msg="PullImage \"registry.k8s.io/kube-proxy:v1.27.5\" returns image reference \"sha256:f249729a2355525533403e8580570bb19df59c41a7510d70f0373bf0880cf7d5\""
Sep 01 23:34:55 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:55.712523878Z" level=info msg="PullImage \"registry.k8s.io/pause:3.9\""
Sep 01 23:34:56 u7s-usernetes-compute-001 systemd[1]: var-lib-containerd-tmpmounts-containerd\x2dmount1367853172.mount: Succeeded.
Sep 01 23:34:56 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:56.066783068Z" level=info msg="ImageCreate event name:\"registry.k8s.io/pause:3.9\" labels:{key:\"io.cri-containerd.image\" value:\"managed\"}"
Sep 01 23:34:56 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:56.067429208Z" level=info msg="stop pulling image registry.k8s.io/pause:3.9: active requests=0, bytes read=323924"
Sep 01 23:34:56 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:56.068596150Z" level=info msg="ImageCreate event name:\"sha256:e6f1816883972d4be47bd48879a08919b96afcd344132622e4d444987919323c\" labels:{key:\"io.cri-containerd.image\" value:\"managed\"}"
Sep 01 23:34:56 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:56.070055905Z" level=info msg="ImageUpdate event name:\"registry.k8s.io/pause:3.9\" labels:{key:\"io.cri-containerd.image\" value:\"managed\"}"
Sep 01 23:34:56 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:56.071458962Z" level=info msg="ImageCreate event name:\"registry.k8s.io/pause@sha256:7031c1b283388d2c2e09b57badb803c05ebed362dc88d84b480cc47f72a21097\" labels:{key:\"io.cri-containerd.image\" value:\"managed\"}"
Sep 01 23:34:56 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:56.072068856Z" level=info msg="Pulled image \"registry.k8s.io/pause:3.9\" with image id \"sha256:e6f1816883972d4be47bd48879a08919b96afcd344132622e4d444987919323c\", repo tag \"registry.k8s.io/pause:3.9\", repo digest \"registry.k8s.io/pause@sha256:7031c1b283388d2c2e09b57badb803c05ebed362dc88d84b480cc47f72a21097\", size \"321520\" in 359.513241ms"
Sep 01 23:34:56 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:56.072102784Z" level=info msg="PullImage \"registry.k8s.io/pause:3.9\" returns image reference \"sha256:e6f1816883972d4be47bd48879a08919b96afcd344132622e4d444987919323c\""
Sep 01 23:34:57 u7s-usernetes-compute-001 systemd[1]: Reloading.
Sep 01 23:34:57 u7s-usernetes-compute-001 systemd[1]: Starting kubelet: The Kubernetes Node Agent...
Sep 01 23:34:57 u7s-usernetes-compute-001 systemd[1]: Started kubelet: The Kubernetes Node Agent.
Sep 01 23:34:57 u7s-usernetes-compute-001 kubelet[391]: Flag --container-runtime-endpoint has been deprecated, This parameter should be set via the config file specified by the Kubelet's --config flag. See https://kubernetes.io/docs/tasks/administer-cluster/kubelet-config-file/ for more information.
Sep 01 23:34:57 u7s-usernetes-compute-001 kubelet[391]: Flag --pod-infra-container-image has been deprecated, will be removed in a future release. Image garbage collector will get sandbox image information from CRI.
Sep 01 23:34:57 u7s-usernetes-compute-001 kubelet[391]: I0901 23:34:57.991776     391 server.go:199] "--pod-infra-container-image will not be pruned by the image garbage collector in kubelet and should also be set in the remote runtime"
Sep 01 23:34:58 u7s-usernetes-compute-001 kubelet[391]: I0901 23:34:58.231448     391 server.go:415] "Kubelet version" kubeletVersion="v1.27.3"
Sep 01 23:34:58 u7s-usernetes-compute-001 kubelet[391]: I0901 23:34:58.231470     391 server.go:417] "Golang settings" GOGC="" GOMAXPROCS="" GOTRACEBACK=""
Sep 01 23:34:58 u7s-usernetes-compute-001 kubelet[391]: I0901 23:34:58.231685     391 server.go:837] "Client rotation is on, will bootstrap in background"
Sep 01 23:34:58 u7s-usernetes-compute-001 kubelet[391]: I0901 23:34:58.235054     391 dynamic_cafile_content.go:157] "Starting controller" name="client-ca-bundle::/etc/kubernetes/pki/ca.crt"
Sep 01 23:34:58 u7s-usernetes-compute-001 kubelet[391]: E0901 23:34:58.236094     391 certificate_manager.go:562] kubernetes.io/kube-apiserver-client-kubelet: Failed while requesting a signed certificate from the control plane: cannot create certificate signing request: Post "https://10.10.0.5:6443/apis/certificates.k8s.io/v1/certificatesigningrequests": read tcp 172.18.0.2:34136->10.10.0.5:6443: read: connection reset by peer
Sep 01 23:34:58 u7s-usernetes-compute-001 kubelet[391]: I0901 23:34:58.238632     391 server.go:662] "--cgroups-per-qos enabled, but --cgroup-root was not specified.  defaulting to /"
Sep 01 23:34:58 u7s-usernetes-compute-001 kubelet[391]: I0901 23:34:58.238800     391 container_manager_linux.go:266] "Container manager verified user specified cgroup-root exists" cgroupRoot=[]
Sep 01 23:34:58 u7s-usernetes-compute-001 kubelet[391]: I0901 23:34:58.238855     391 container_manager_linux.go:271] "Creating Container Manager object based on Node Config" nodeConfig={RuntimeCgroupsName:/system.slice/containerd.service SystemCgroupsName: KubeletCgroupsName: KubeletOOMScoreAdj:-999 ContainerRuntime: CgroupsPerQOS:true CgroupRoot:/ CgroupDriver:systemd KubeletRootDir:/var/lib/kubelet ProtectKernelDefaults:false NodeAllocatableConfig:{KubeReservedCgroupName: SystemReservedCgroupName: ReservedSystemCPUs: EnforceNodeAllocatable:map[pods:{}] KubeReserved:map[] SystemReserved:map[] HardEvictionThresholds:[{Signal:nodefs.available Operator:LessThan Value:{Quantity:<nil> Percentage:0.1} GracePeriod:0s MinReclaim:<nil>} {Signal:nodefs.inodesFree Operator:LessThan Value:{Quantity:<nil> Percentage:0.05} GracePeriod:0s MinReclaim:<nil>} {Signal:imagefs.available Operator:LessThan Value:{Quantity:<nil> Percentage:0.15} GracePeriod:0s MinReclaim:<nil>} {Signal:memory.available Operator:LessThan Value:{Quantity:100Mi Percentage:0} GracePeriod:0s MinReclaim:<nil>}]} QOSReserved:map[] CPUManagerPolicy:none CPUManagerPolicyOptions:map[] TopologyManagerScope:container CPUManagerReconcilePeriod:10s ExperimentalMemoryManagerPolicy:None ExperimentalMemoryManagerReservedMemory:[] PodPidsLimit:-1 EnforceCPULimits:true CPUCFSQuotaPeriod:100ms TopologyManagerPolicy:none ExperimentalTopologyManagerPolicyOptions:map[]}
Sep 01 23:34:58 u7s-usernetes-compute-001 kubelet[391]: I0901 23:34:58.238875     391 topology_manager.go:136] "Creating topology manager with policy per scope" topologyPolicyName="none" topologyScopeName="container"
Sep 01 23:34:58 u7s-usernetes-compute-001 kubelet[391]: I0901 23:34:58.238884     391 container_manager_linux.go:302] "Creating device plugin manager"
Sep 01 23:34:58 u7s-usernetes-compute-001 kubelet[391]: I0901 23:34:58.238952     391 state_mem.go:36] "Initialized new in-memory state store"
Sep 01 23:34:58 u7s-usernetes-compute-001 kubelet[391]: I0901 23:34:58.240873     391 kubelet.go:405] "Attempting to sync node with API server"
Sep 01 23:34:58 u7s-usernetes-compute-001 kubelet[391]: I0901 23:34:58.240892     391 kubelet.go:298] "Adding static pod path" path="/etc/kubernetes/manifests"
Sep 01 23:34:58 u7s-usernetes-compute-001 kubelet[391]: I0901 23:34:58.240930     391 kubelet.go:309] "Adding apiserver pod source"
Sep 01 23:34:58 u7s-usernetes-compute-001 kubelet[391]: I0901 23:34:58.240946     391 apiserver.go:42] "Waiting for node sync before watching apiserver pods"
Sep 01 23:34:58 u7s-usernetes-compute-001 kubelet[391]: I0901 23:34:58.241359     391 kuberuntime_manager.go:257] "Container runtime initialized" containerRuntime="containerd" version="v1.7.1" apiVersion="v1"
Sep 01 23:34:58 u7s-usernetes-compute-001 kubelet[391]: W0901 23:34:58.241636     391 probe.go:268] Flexvolume plugin directory at /usr/libexec/kubernetes/kubelet-plugins/volume/exec/ does not exist. Recreating.
Sep 01 23:34:58 u7s-usernetes-compute-001 kubelet[391]: I0901 23:34:58.242095     391 server.go:1168] "Started kubelet"
Sep 01 23:34:58 u7s-usernetes-compute-001 kubelet[391]: I0901 23:34:58.242228     391 ratelimit.go:65] "Setting rate limiting for podresources endpoint" qps=100 burstTokens=10
Sep 01 23:34:58 u7s-usernetes-compute-001 kubelet[391]: E0901 23:34:58.242881     391 cri_stats_provider.go:455] "Failed to get the info of the filesystem with mountpoint" err="unable to find data in memory cache" mountpoint="/var/lib/containerd/io.containerd.snapshotter.v1.overlayfs"
Sep 01 23:34:58 u7s-usernetes-compute-001 kubelet[391]: E0901 23:34:58.242921     391 kubelet.go:1400] "Image garbage collection failed once. Stats initialization may not have completed yet" err="invalid capacity 0 on image filesystem"
Sep 01 23:34:58 u7s-usernetes-compute-001 kubelet[391]: I0901 23:34:58.242955     391 server.go:162] "Starting to listen" address="0.0.0.0" port=10250
Sep 01 23:34:58 u7s-usernetes-compute-001 kubelet[391]: E0901 23:34:58.243002     391 event.go:289] Unable to write event: '&v1.Event{TypeMeta:v1.TypeMeta{Kind:"", APIVersion:""}, ObjectMeta:v1.ObjectMeta{Name:"u7s-usernetes-compute-001.1780ea80ab4e929b", GenerateName:"", Namespace:"default", SelfLink:"", UID:"", ResourceVersion:"", Generation:0, CreationTimestamp:time.Date(1, time.January, 1, 0, 0, 0, 0, time.UTC), DeletionTimestamp:<nil>, DeletionGracePeriodSeconds:(*int64)(nil), Labels:map[string]string(nil), Annotations:map[string]string(nil), OwnerReferences:[]v1.OwnerReference(nil), Finalizers:[]string(nil), ManagedFields:[]v1.ManagedFieldsEntry(nil)}, InvolvedObject:v1.ObjectReference{Kind:"Node", Namespace:"", Name:"u7s-usernetes-compute-001", UID:"u7s-usernetes-compute-001", APIVersion:"", ResourceVersion:"", FieldPath:""}, Reason:"Starting", Message:"Starting kubelet.", Source:v1.EventSource{Component:"kubelet", Host:"u7s-usernetes-compute-001"}, FirstTimestamp:time.Date(2023, time.September, 1, 23, 34, 58, 242073243, time.Local), LastTimestamp:time.Date(2023, time.September, 1, 23, 34, 58, 242073243, time.Local), Count:1, Type:"Normal", EventTime:time.Date(1, time.January, 1, 0, 0, 0, 0, time.UTC), Series:(*v1.EventSeries)(nil), Action:"", Related:(*v1.ObjectReference)(nil), ReportingController:"", ReportingInstance:""}': 'Post "https://10.10.0.5:6443/api/v1/namespaces/default/events": EOF'(may retry after sleeping)
Sep 01 23:34:58 u7s-usernetes-compute-001 kubelet[391]: I0901 23:34:58.244745     391 server.go:461] "Adding debug handlers to kubelet server"
Sep 01 23:34:58 u7s-usernetes-compute-001 kubelet[391]: I0901 23:34:58.244929     391 fs_resource_analyzer.go:67] "Starting FS ResourceAnalyzer"
Sep 01 23:34:58 u7s-usernetes-compute-001 kubelet[391]: I0901 23:34:58.245002     391 volume_manager.go:284] "Starting Kubelet Volume Manager"
Sep 01 23:34:58 u7s-usernetes-compute-001 kubelet[391]: E0901 23:34:58.245011     391 kubelet_node_status.go:458] "Error getting the current node from lister" err="node \"u7s-usernetes-compute-001\" not found"
Sep 01 23:34:58 u7s-usernetes-compute-001 kubelet[391]: I0901 23:34:58.245191     391 desired_state_of_world_populator.go:145] "Desired state populator starts to run"
Sep 01 23:34:58 u7s-usernetes-compute-001 kubelet[391]: I0901 23:34:58.256008     391 cpu_manager.go:214] "Starting CPU manager" policy="none"
Sep 01 23:34:58 u7s-usernetes-compute-001 kubelet[391]: I0901 23:34:58.256023     391 cpu_manager.go:215] "Reconciling" reconcilePeriod="10s"
Sep 01 23:34:58 u7s-usernetes-compute-001 kubelet[391]: I0901 23:34:58.256036     391 state_mem.go:36] "Initialized new in-memory state store"
Sep 01 23:34:58 u7s-usernetes-compute-001 kubelet[391]: I0901 23:34:58.258378     391 policy_none.go:49] "None policy: Start"
Sep 01 23:34:58 u7s-usernetes-compute-001 kubelet[391]: I0901 23:34:58.258829     391 memory_manager.go:169] "Starting memorymanager" policy="None"
Sep 01 23:34:58 u7s-usernetes-compute-001 kubelet[391]: I0901 23:34:58.258849     391 state_mem.go:35] "Initializing new in-memory state store"
Sep 01 23:34:58 u7s-usernetes-compute-001 kubelet[391]: I0901 23:34:58.262628     391 kubelet_network_linux.go:63] "Initialized iptables rules." protocol=IPv4
Sep 01 23:34:58 u7s-usernetes-compute-001 kubelet[391]: I0901 23:34:58.263556     391 kubelet_network_linux.go:63] "Initialized iptables rules." protocol=IPv6
Sep 01 23:34:58 u7s-usernetes-compute-001 kubelet[391]: I0901 23:34:58.263579     391 status_manager.go:207] "Starting to sync pod status with apiserver"
Sep 01 23:34:58 u7s-usernetes-compute-001 kubelet[391]: I0901 23:34:58.263600     391 kubelet.go:2257] "Starting kubelet main sync loop"
Sep 01 23:34:58 u7s-usernetes-compute-001 kubelet[391]: E0901 23:34:58.263647     391 kubelet.go:2281] "Skipping pod synchronization" err="[container runtime status check may not have completed yet, PLEG is not healthy: pleg has yet to be successful]"
Sep 01 23:34:58 u7s-usernetes-compute-001 systemd[1]: Created slice libcontainer container kubepods.slice.
Sep 01 23:34:58 u7s-usernetes-compute-001 systemd[1]: Created slice libcontainer container kubepods-burstable.slice.
Sep 01 23:34:58 u7s-usernetes-compute-001 systemd[1]: Created slice libcontainer container kubepods-besteffort.slice.
Sep 01 23:34:58 u7s-usernetes-compute-001 kubelet[391]: I0901 23:34:58.328923     391 manager.go:455] "Failed to read data from checkpoint" checkpoint="kubelet_internal_checkpoint" err="checkpoint is not found"
Sep 01 23:34:58 u7s-usernetes-compute-001 kubelet[391]: I0901 23:34:58.329080     391 plugin_manager.go:118] "Starting Kubelet Plugin Manager"
Sep 01 23:34:58 u7s-usernetes-compute-001 kubelet[391]: E0901 23:34:58.329393     391 eviction_manager.go:262] "Eviction manager: failed to get summary stats" err="failed to get node info: node \"u7s-usernetes-compute-001\" not found"
Sep 01 23:34:58 u7s-usernetes-compute-001 kubelet[391]: I0901 23:34:58.346620     391 kubelet_node_status.go:70] "Attempting to register node" node="u7s-usernetes-compute-001"
Sep 01 23:34:58 u7s-usernetes-compute-001 kubelet[391]: E0901 23:34:58.347078     391 kubelet_node_status.go:92] "Unable to register node with API server" err="Post \"https://10.10.0.5:6443/api/v1/nodes\": read tcp 172.18.0.2:34188->10.10.0.5:6443: read: connection reset by peer" node="u7s-usernetes-compute-001"
Sep 01 23:34:58 u7s-usernetes-compute-001 kubelet[391]: I0901 23:34:58.364257     391 topology_manager.go:212] "Topology Admit Handler"
Sep 01 23:34:58 u7s-usernetes-compute-001 kubelet[391]: I0901 23:34:58.364749     391 topology_manager.go:212] "Topology Admit Handler"
Sep 01 23:34:58 u7s-usernetes-compute-001 kubelet[391]: I0901 23:34:58.365161     391 topology_manager.go:212] "Topology Admit Handler"
Sep 01 23:34:58 u7s-usernetes-compute-001 kubelet[391]: I0901 23:34:58.365589     391 topology_manager.go:212] "Topology Admit Handler"
Sep 01 23:34:58 u7s-usernetes-compute-001 systemd[1]: Created slice libcontainer container kubepods-burstable-pod65293b5fb246ed9728c144ff6ed5f365.slice.
Sep 01 23:34:58 u7s-usernetes-compute-001 systemd[1]: Created slice libcontainer container kubepods-burstable-podfc29d9d860df7d1516151a6ead9f9f64.slice.
Sep 01 23:34:58 u7s-usernetes-compute-001 systemd[1]: Created slice libcontainer container kubepods-burstable-pod5717a8580af9c26b0530fb2dc202e84b.slice.
Sep 01 23:34:58 u7s-usernetes-compute-001 kubelet[391]: I0901 23:34:58.446287     391 reconciler_common.go:258] "operationExecutor.VerifyControllerAttachedVolume started for volume \"etc-ca-certificates\" (UniqueName: \"kubernetes.io/host-path/fc29d9d860df7d1516151a6ead9f9f64-etc-ca-certificates\") pod \"kube-apiserver-u7s-usernetes-compute-001\" (UID: \"fc29d9d860df7d1516151a6ead9f9f64\") " pod="kube-system/kube-apiserver-u7s-usernetes-compute-001"
Sep 01 23:34:58 u7s-usernetes-compute-001 kubelet[391]: I0901 23:34:58.446313     391 reconciler_common.go:258] "operationExecutor.VerifyControllerAttachedVolume started for volume \"k8s-certs\" (UniqueName: \"kubernetes.io/host-path/fc29d9d860df7d1516151a6ead9f9f64-k8s-certs\") pod \"kube-apiserver-u7s-usernetes-compute-001\" (UID: \"fc29d9d860df7d1516151a6ead9f9f64\") " pod="kube-system/kube-apiserver-u7s-usernetes-compute-001"
Sep 01 23:34:58 u7s-usernetes-compute-001 kubelet[391]: I0901 23:34:58.446331     391 reconciler_common.go:258] "operationExecutor.VerifyControllerAttachedVolume started for volume \"usr-local-share-ca-certificates\" (UniqueName: \"kubernetes.io/host-path/fc29d9d860df7d1516151a6ead9f9f64-usr-local-share-ca-certificates\") pod \"kube-apiserver-u7s-usernetes-compute-001\" (UID: \"fc29d9d860df7d1516151a6ead9f9f64\") " pod="kube-system/kube-apiserver-u7s-usernetes-compute-001"
Sep 01 23:34:58 u7s-usernetes-compute-001 kubelet[391]: I0901 23:34:58.446352     391 reconciler_common.go:258] "operationExecutor.VerifyControllerAttachedVolume started for volume \"kubeconfig\" (UniqueName: \"kubernetes.io/host-path/86b04793958bc8604bae256476aad501-kubeconfig\") pod \"kube-scheduler-u7s-usernetes-compute-001\" (UID: \"86b04793958bc8604bae256476aad501\") " pod="kube-system/kube-scheduler-u7s-usernetes-compute-001"
Sep 01 23:34:58 u7s-usernetes-compute-001 kubelet[391]: I0901 23:34:58.446388     391 reconciler_common.go:258] "operationExecutor.VerifyControllerAttachedVolume started for volume \"etcd-certs\" (UniqueName: \"kubernetes.io/host-path/65293b5fb246ed9728c144ff6ed5f365-etcd-certs\") pod \"etcd-u7s-usernetes-compute-001\" (UID: \"65293b5fb246ed9728c144ff6ed5f365\") " pod="kube-system/etcd-u7s-usernetes-compute-001"
Sep 01 23:34:58 u7s-usernetes-compute-001 kubelet[391]: I0901 23:34:58.446422     391 reconciler_common.go:258] "operationExecutor.VerifyControllerAttachedVolume started for volume \"k8s-certs\" (UniqueName: \"kubernetes.io/host-path/5717a8580af9c26b0530fb2dc202e84b-k8s-certs\") pod \"kube-controller-manager-u7s-usernetes-compute-001\" (UID: \"5717a8580af9c26b0530fb2dc202e84b\") " pod="kube-system/kube-controller-manager-u7s-usernetes-compute-001"
Sep 01 23:34:58 u7s-usernetes-compute-001 kubelet[391]: I0901 23:34:58.446452     391 reconciler_common.go:258] "operationExecutor.VerifyControllerAttachedVolume started for volume \"usr-share-ca-certificates\" (UniqueName: \"kubernetes.io/host-path/5717a8580af9c26b0530fb2dc202e84b-usr-share-ca-certificates\") pod \"kube-controller-manager-u7s-usernetes-compute-001\" (UID: \"5717a8580af9c26b0530fb2dc202e84b\") " pod="kube-system/kube-controller-manager-u7s-usernetes-compute-001"
Sep 01 23:34:58 u7s-usernetes-compute-001 kubelet[391]: I0901 23:34:58.446509     391 reconciler_common.go:258] "operationExecutor.VerifyControllerAttachedVolume started for volume \"ca-certs\" (UniqueName: \"kubernetes.io/host-path/fc29d9d860df7d1516151a6ead9f9f64-ca-certs\") pod \"kube-apiserver-u7s-usernetes-compute-001\" (UID: \"fc29d9d860df7d1516151a6ead9f9f64\") " pod="kube-system/kube-apiserver-u7s-usernetes-compute-001"
Sep 01 23:34:58 u7s-usernetes-compute-001 kubelet[391]: I0901 23:34:58.446551     391 reconciler_common.go:258] "operationExecutor.VerifyControllerAttachedVolume started for volume \"ca-certs\" (UniqueName: \"kubernetes.io/host-path/5717a8580af9c26b0530fb2dc202e84b-ca-certs\") pod \"kube-controller-manager-u7s-usernetes-compute-001\" (UID: \"5717a8580af9c26b0530fb2dc202e84b\") " pod="kube-system/kube-controller-manager-u7s-usernetes-compute-001"
Sep 01 23:34:58 u7s-usernetes-compute-001 kubelet[391]: I0901 23:34:58.446581     391 reconciler_common.go:258] "operationExecutor.VerifyControllerAttachedVolume started for volume \"etc-ca-certificates\" (UniqueName: \"kubernetes.io/host-path/5717a8580af9c26b0530fb2dc202e84b-etc-ca-certificates\") pod \"kube-controller-manager-u7s-usernetes-compute-001\" (UID: \"5717a8580af9c26b0530fb2dc202e84b\") " pod="kube-system/kube-controller-manager-u7s-usernetes-compute-001"
Sep 01 23:34:58 u7s-usernetes-compute-001 kubelet[391]: I0901 23:34:58.446612     391 reconciler_common.go:258] "operationExecutor.VerifyControllerAttachedVolume started for volume \"usr-local-share-ca-certificates\" (UniqueName: \"kubernetes.io/host-path/5717a8580af9c26b0530fb2dc202e84b-usr-local-share-ca-certificates\") pod \"kube-controller-manager-u7s-usernetes-compute-001\" (UID: \"5717a8580af9c26b0530fb2dc202e84b\") " pod="kube-system/kube-controller-manager-u7s-usernetes-compute-001"
Sep 01 23:34:58 u7s-usernetes-compute-001 kubelet[391]: I0901 23:34:58.446641     391 reconciler_common.go:258] "operationExecutor.VerifyControllerAttachedVolume started for volume \"usr-share-ca-certificates\" (UniqueName: \"kubernetes.io/host-path/fc29d9d860df7d1516151a6ead9f9f64-usr-share-ca-certificates\") pod \"kube-apiserver-u7s-usernetes-compute-001\" (UID: \"fc29d9d860df7d1516151a6ead9f9f64\") " pod="kube-system/kube-apiserver-u7s-usernetes-compute-001"
Sep 01 23:34:58 u7s-usernetes-compute-001 kubelet[391]: I0901 23:34:58.446681     391 reconciler_common.go:258] "operationExecutor.VerifyControllerAttachedVolume started for volume \"flexvolume-dir\" (UniqueName: \"kubernetes.io/host-path/5717a8580af9c26b0530fb2dc202e84b-flexvolume-dir\") pod \"kube-controller-manager-u7s-usernetes-compute-001\" (UID: \"5717a8580af9c26b0530fb2dc202e84b\") " pod="kube-system/kube-controller-manager-u7s-usernetes-compute-001"
Sep 01 23:34:58 u7s-usernetes-compute-001 kubelet[391]: I0901 23:34:58.446714     391 reconciler_common.go:258] "operationExecutor.VerifyControllerAttachedVolume started for volume \"kubeconfig\" (UniqueName: \"kubernetes.io/host-path/5717a8580af9c26b0530fb2dc202e84b-kubeconfig\") pod \"kube-controller-manager-u7s-usernetes-compute-001\" (UID: \"5717a8580af9c26b0530fb2dc202e84b\") " pod="kube-system/kube-controller-manager-u7s-usernetes-compute-001"
Sep 01 23:34:58 u7s-usernetes-compute-001 kubelet[391]: I0901 23:34:58.446741     391 reconciler_common.go:258] "operationExecutor.VerifyControllerAttachedVolume started for volume \"etcd-data\" (UniqueName: \"kubernetes.io/host-path/65293b5fb246ed9728c144ff6ed5f365-etcd-data\") pod \"etcd-u7s-usernetes-compute-001\" (UID: \"65293b5fb246ed9728c144ff6ed5f365\") " pod="kube-system/etcd-u7s-usernetes-compute-001"
Sep 01 23:34:58 u7s-usernetes-compute-001 systemd[1]: Created slice libcontainer container kubepods-burstable-pod86b04793958bc8604bae256476aad501.slice.
Sep 01 23:34:58 u7s-usernetes-compute-001 kubelet[391]: I0901 23:34:58.547624     391 kubelet_node_status.go:70] "Attempting to register node" node="u7s-usernetes-compute-001"
Sep 01 23:34:58 u7s-usernetes-compute-001 kubelet[391]: E0901 23:34:58.548155     391 kubelet_node_status.go:92] "Unable to register node with API server" err="Post \"https://10.10.0.5:6443/api/v1/nodes\": read tcp 172.18.0.2:34194->10.10.0.5:6443: read: connection reset by peer" node="u7s-usernetes-compute-001"
Sep 01 23:34:58 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:58.722270404Z" level=info msg="RunPodSandbox for &PodSandboxMetadata{Name:etcd-u7s-usernetes-compute-001,Uid:65293b5fb246ed9728c144ff6ed5f365,Namespace:kube-system,Attempt:0,}"
Sep 01 23:34:58 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:58.723614742Z" level=info msg="RunPodSandbox for &PodSandboxMetadata{Name:kube-apiserver-u7s-usernetes-compute-001,Uid:fc29d9d860df7d1516151a6ead9f9f64,Namespace:kube-system,Attempt:0,}"
Sep 01 23:34:58 u7s-usernetes-compute-001 systemd[1]: var-lib-containerd-tmpmounts-containerd\x2dmount2543123850.mount: Succeeded.
Sep 01 23:34:58 u7s-usernetes-compute-001 systemd[1]: var-lib-containerd-tmpmounts-containerd\x2dmount3304000394.mount: Succeeded.
Sep 01 23:34:58 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:58.753645443Z" level=info msg="RunPodSandbox for &PodSandboxMetadata{Name:kube-controller-manager-u7s-usernetes-compute-001,Uid:5717a8580af9c26b0530fb2dc202e84b,Namespace:kube-system,Attempt:0,}"
Sep 01 23:34:58 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:58.756346772Z" level=info msg="RunPodSandbox for &PodSandboxMetadata{Name:kube-scheduler-u7s-usernetes-compute-001,Uid:86b04793958bc8604bae256476aad501,Namespace:kube-system,Attempt:0,}"
Sep 01 23:34:58 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:58.759235830Z" level=info msg="loading plugin \"io.containerd.internal.v1.shutdown\"..." runtime=io.containerd.runc.v2 type=io.containerd.internal.v1
Sep 01 23:34:58 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:58.759721793Z" level=info msg="loading plugin \"io.containerd.ttrpc.v1.pause\"..." runtime=io.containerd.runc.v2 type=io.containerd.ttrpc.v1
Sep 01 23:34:58 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:58.759691801Z" level=info msg="loading plugin \"io.containerd.internal.v1.shutdown\"..." runtime=io.containerd.runc.v2 type=io.containerd.internal.v1
Sep 01 23:34:58 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:58.759740822Z" level=info msg="loading plugin \"io.containerd.event.v1.publisher\"..." runtime=io.containerd.runc.v2 type=io.containerd.event.v1
Sep 01 23:34:58 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:58.759758140Z" level=info msg="loading plugin \"io.containerd.ttrpc.v1.task\"..." runtime=io.containerd.runc.v2 type=io.containerd.ttrpc.v1
Sep 01 23:34:58 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:58.759752748Z" level=info msg="loading plugin \"io.containerd.ttrpc.v1.pause\"..." runtime=io.containerd.runc.v2 type=io.containerd.ttrpc.v1
Sep 01 23:34:58 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:58.759771216Z" level=info msg="loading plugin \"io.containerd.event.v1.publisher\"..." runtime=io.containerd.runc.v2 type=io.containerd.event.v1
Sep 01 23:34:58 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:58.759786766Z" level=info msg="loading plugin \"io.containerd.ttrpc.v1.task\"..." runtime=io.containerd.runc.v2 type=io.containerd.ttrpc.v1
Sep 01 23:34:58 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:58.776056726Z" level=info msg="loading plugin \"io.containerd.internal.v1.shutdown\"..." runtime=io.containerd.runc.v2 type=io.containerd.internal.v1
Sep 01 23:34:58 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:58.776103148Z" level=info msg="loading plugin \"io.containerd.ttrpc.v1.pause\"..." runtime=io.containerd.runc.v2 type=io.containerd.ttrpc.v1
Sep 01 23:34:58 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:58.776116401Z" level=info msg="loading plugin \"io.containerd.event.v1.publisher\"..." runtime=io.containerd.runc.v2 type=io.containerd.event.v1
Sep 01 23:34:58 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:58.776127076Z" level=info msg="loading plugin \"io.containerd.ttrpc.v1.task\"..." runtime=io.containerd.runc.v2 type=io.containerd.ttrpc.v1
Sep 01 23:34:58 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:58.777357541Z" level=info msg="loading plugin \"io.containerd.internal.v1.shutdown\"..." runtime=io.containerd.runc.v2 type=io.containerd.internal.v1
Sep 01 23:34:58 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:58.777709291Z" level=info msg="loading plugin \"io.containerd.ttrpc.v1.pause\"..." runtime=io.containerd.runc.v2 type=io.containerd.ttrpc.v1
Sep 01 23:34:58 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:58.777733859Z" level=info msg="loading plugin \"io.containerd.event.v1.publisher\"..." runtime=io.containerd.runc.v2 type=io.containerd.event.v1
Sep 01 23:34:58 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:58.777747872Z" level=info msg="loading plugin \"io.containerd.ttrpc.v1.task\"..." runtime=io.containerd.runc.v2 type=io.containerd.ttrpc.v1
Sep 01 23:34:58 u7s-usernetes-compute-001 systemd[1]: Started libcontainer container 3ced231d88a130225c9f4e4f4d69d9b659577fb811ac4c100f27c9ba731aea88.
Sep 01 23:34:58 u7s-usernetes-compute-001 systemd[1]: Started libcontainer container 5049ad78f700b4f80dbd2f816a3815a61eb27591a19b9b5c47d7fc5446054364.
Sep 01 23:34:58 u7s-usernetes-compute-001 systemd[1]: Started libcontainer container d9a70873b587820fd168b2dbed298d0dfab68931c716325663e79b0bc79f252f.
Sep 01 23:34:58 u7s-usernetes-compute-001 systemd[1]: Started libcontainer container d9a8b4bf071ccd001ce61bb8b8031f2ddf3f513ff3a1c1c542e964ce92523f59.
Sep 01 23:34:58 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:58.854405242Z" level=info msg="RunPodSandbox for &PodSandboxMetadata{Name:etcd-u7s-usernetes-compute-001,Uid:65293b5fb246ed9728c144ff6ed5f365,Namespace:kube-system,Attempt:0,} returns sandbox id \"3ced231d88a130225c9f4e4f4d69d9b659577fb811ac4c100f27c9ba731aea88\""
Sep 01 23:34:58 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:58.854716500Z" level=info msg="RunPodSandbox for &PodSandboxMetadata{Name:kube-apiserver-u7s-usernetes-compute-001,Uid:fc29d9d860df7d1516151a6ead9f9f64,Namespace:kube-system,Attempt:0,} returns sandbox id \"5049ad78f700b4f80dbd2f816a3815a61eb27591a19b9b5c47d7fc5446054364\""
Sep 01 23:34:58 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:58.858010178Z" level=info msg="CreateContainer within sandbox \"5049ad78f700b4f80dbd2f816a3815a61eb27591a19b9b5c47d7fc5446054364\" for container &ContainerMetadata{Name:kube-apiserver,Attempt:0,}"
Sep 01 23:34:58 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:58.858301829Z" level=info msg="CreateContainer within sandbox \"3ced231d88a130225c9f4e4f4d69d9b659577fb811ac4c100f27c9ba731aea88\" for container &ContainerMetadata{Name:etcd,Attempt:0,}"
Sep 01 23:34:58 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:58.864731685Z" level=info msg="RunPodSandbox for &PodSandboxMetadata{Name:kube-scheduler-u7s-usernetes-compute-001,Uid:86b04793958bc8604bae256476aad501,Namespace:kube-system,Attempt:0,} returns sandbox id \"d9a8b4bf071ccd001ce61bb8b8031f2ddf3f513ff3a1c1c542e964ce92523f59\""
Sep 01 23:34:58 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:58.865658230Z" level=info msg="RunPodSandbox for &PodSandboxMetadata{Name:kube-controller-manager-u7s-usernetes-compute-001,Uid:5717a8580af9c26b0530fb2dc202e84b,Namespace:kube-system,Attempt:0,} returns sandbox id \"d9a70873b587820fd168b2dbed298d0dfab68931c716325663e79b0bc79f252f\""
Sep 01 23:34:58 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:58.866551265Z" level=info msg="CreateContainer within sandbox \"d9a8b4bf071ccd001ce61bb8b8031f2ddf3f513ff3a1c1c542e964ce92523f59\" for container &ContainerMetadata{Name:kube-scheduler,Attempt:0,}"
Sep 01 23:34:58 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:58.870230705Z" level=info msg="CreateContainer within sandbox \"d9a70873b587820fd168b2dbed298d0dfab68931c716325663e79b0bc79f252f\" for container &ContainerMetadata{Name:kube-controller-manager,Attempt:0,}"
Sep 01 23:34:58 u7s-usernetes-compute-001 systemd[1]: var-lib-containerd-tmpmounts-containerd\x2dmount1320364290.mount: Succeeded.
Sep 01 23:34:58 u7s-usernetes-compute-001 systemd[1]: var-lib-containerd-tmpmounts-containerd\x2dmount116143605.mount: Succeeded.
Sep 01 23:34:58 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:58.899910541Z" level=info msg="CreateContainer within sandbox \"5049ad78f700b4f80dbd2f816a3815a61eb27591a19b9b5c47d7fc5446054364\" for &ContainerMetadata{Name:kube-apiserver,Attempt:0,} returns container id \"5119ae1f3e7f461d49fac0f127fdec1e256b1564d1d1612c53f9b8584d30cc21\""
Sep 01 23:34:58 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:58.900400404Z" level=info msg="StartContainer for \"5119ae1f3e7f461d49fac0f127fdec1e256b1564d1d1612c53f9b8584d30cc21\""
Sep 01 23:34:58 u7s-usernetes-compute-001 systemd[1]: var-lib-containerd-tmpmounts-containerd\x2dmount2580233943.mount: Succeeded.
Sep 01 23:34:58 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:58.905702239Z" level=info msg="CreateContainer within sandbox \"d9a8b4bf071ccd001ce61bb8b8031f2ddf3f513ff3a1c1c542e964ce92523f59\" for &ContainerMetadata{Name:kube-scheduler,Attempt:0,} returns container id \"dc9d72ce9a43789a1b7bb2f6f218f4e21e88c21a23d6ef8787977ef4f943433e\""
Sep 01 23:34:58 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:58.906065566Z" level=info msg="StartContainer for \"dc9d72ce9a43789a1b7bb2f6f218f4e21e88c21a23d6ef8787977ef4f943433e\""
Sep 01 23:34:58 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:58.908083319Z" level=info msg="CreateContainer within sandbox \"d9a70873b587820fd168b2dbed298d0dfab68931c716325663e79b0bc79f252f\" for &ContainerMetadata{Name:kube-controller-manager,Attempt:0,} returns container id \"305625a5a8c013ea2d5e4926feb5111643d46bd9c22218f77fce3e3a5880cecc\""
Sep 01 23:34:58 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:58.908437329Z" level=info msg="StartContainer for \"305625a5a8c013ea2d5e4926feb5111643d46bd9c22218f77fce3e3a5880cecc\""
Sep 01 23:34:58 u7s-usernetes-compute-001 systemd[1]: Started libcontainer container 5119ae1f3e7f461d49fac0f127fdec1e256b1564d1d1612c53f9b8584d30cc21.
Sep 01 23:34:58 u7s-usernetes-compute-001 kubelet[391]: I0901 23:34:58.949544     391 kubelet_node_status.go:70] "Attempting to register node" node="u7s-usernetes-compute-001"
Sep 01 23:34:58 u7s-usernetes-compute-001 kubelet[391]: E0901 23:34:58.950490     391 kubelet_node_status.go:92] "Unable to register node with API server" err="Post \"https://10.10.0.5:6443/api/v1/nodes\": EOF" node="u7s-usernetes-compute-001"
Sep 01 23:34:58 u7s-usernetes-compute-001 systemd[1]: Started libcontainer container dc9d72ce9a43789a1b7bb2f6f218f4e21e88c21a23d6ef8787977ef4f943433e.
Sep 01 23:34:58 u7s-usernetes-compute-001 systemd[1]: Started libcontainer container 305625a5a8c013ea2d5e4926feb5111643d46bd9c22218f77fce3e3a5880cecc.
Sep 01 23:34:59 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:59.025396204Z" level=info msg="StartContainer for \"5119ae1f3e7f461d49fac0f127fdec1e256b1564d1d1612c53f9b8584d30cc21\" returns successfully"
Sep 01 23:34:59 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:59.034383644Z" level=info msg="StartContainer for \"dc9d72ce9a43789a1b7bb2f6f218f4e21e88c21a23d6ef8787977ef4f943433e\" returns successfully"
Sep 01 23:34:59 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:34:59.034478684Z" level=info msg="StartContainer for \"305625a5a8c013ea2d5e4926feb5111643d46bd9c22218f77fce3e3a5880cecc\" returns successfully"
Sep 01 23:34:59 u7s-usernetes-compute-001 systemd[1]: var-lib-containerd-tmpmounts-containerd\x2dmount2665006176.mount: Succeeded.
Sep 01 23:34:59 u7s-usernetes-compute-001 kubelet[391]: I0901 23:34:59.752068     391 kubelet_node_status.go:70] "Attempting to register node" node="u7s-usernetes-compute-001"
Sep 01 23:35:00 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:35:00.499250505Z" level=info msg="CreateContainer within sandbox \"3ced231d88a130225c9f4e4f4d69d9b659577fb811ac4c100f27c9ba731aea88\" for &ContainerMetadata{Name:etcd,Attempt:0,} returns container id \"e283e1deecb5a4cae9bdeaeadbbfc7b4072804e6c0c1798c1093e8bfe3d59298\""
Sep 01 23:35:00 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:35:00.499696996Z" level=info msg="StartContainer for \"e283e1deecb5a4cae9bdeaeadbbfc7b4072804e6c0c1798c1093e8bfe3d59298\""
Sep 01 23:35:00 u7s-usernetes-compute-001 systemd[1]: Started libcontainer container e283e1deecb5a4cae9bdeaeadbbfc7b4072804e6c0c1798c1093e8bfe3d59298.
Sep 01 23:35:00 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:35:00.611896449Z" level=info msg="StartContainer for \"e283e1deecb5a4cae9bdeaeadbbfc7b4072804e6c0c1798c1093e8bfe3d59298\" returns successfully"
Sep 01 23:35:03 u7s-usernetes-compute-001 kubelet[391]: E0901 23:35:03.170871     391 nodelease.go:49] "Failed to get node when trying to set owner ref to the node lease" err="nodes \"u7s-usernetes-compute-001\" not found" node="u7s-usernetes-compute-001"
Sep 01 23:35:03 u7s-usernetes-compute-001 kubelet[391]: I0901 23:35:03.243705     391 apiserver.go:52] "Watching apiserver"
Sep 01 23:35:03 u7s-usernetes-compute-001 kubelet[391]: I0901 23:35:03.246006     391 desired_state_of_world_populator.go:153] "Finished populating initial desired state of world"
Sep 01 23:35:03 u7s-usernetes-compute-001 kubelet[391]: I0901 23:35:03.267417     391 kubelet_node_status.go:73] "Successfully registered node" node="u7s-usernetes-compute-001"
Sep 01 23:35:03 u7s-usernetes-compute-001 kubelet[391]: I0901 23:35:03.267496     391 reconciler.go:41] "Reconciler: start to sync state"
Sep 01 23:35:05 u7s-usernetes-compute-001 systemd[1]: Reloading.
Sep 01 23:35:05 u7s-usernetes-compute-001 kubelet[391]: I0901 23:35:05.921797     391 dynamic_cafile_content.go:171] "Shutting down controller" name="client-ca-bundle::/etc/kubernetes/pki/ca.crt"
Sep 01 23:35:05 u7s-usernetes-compute-001 systemd[1]: Stopping kubelet: The Kubernetes Node Agent...
Sep 01 23:35:05 u7s-usernetes-compute-001 systemd[1]: kubelet.service: Succeeded.
Sep 01 23:35:05 u7s-usernetes-compute-001 systemd[1]: Stopped kubelet: The Kubernetes Node Agent.
Sep 01 23:35:06 u7s-usernetes-compute-001 systemd[1]: Starting kubelet: The Kubernetes Node Agent...
Sep 01 23:35:06 u7s-usernetes-compute-001 systemd[1]: Started kubelet: The Kubernetes Node Agent.
Sep 01 23:35:06 u7s-usernetes-compute-001 kubelet[849]: Flag --container-runtime-endpoint has been deprecated, This parameter should be set via the config file specified by the Kubelet's --config flag. See https://kubernetes.io/docs/tasks/administer-cluster/kubelet-config-file/ for more information.
Sep 01 23:35:06 u7s-usernetes-compute-001 kubelet[849]: Flag --pod-infra-container-image has been deprecated, will be removed in a future release. Image garbage collector will get sandbox image information from CRI.
Sep 01 23:35:06 u7s-usernetes-compute-001 kubelet[849]: I0901 23:35:06.068687     849 server.go:199] "--pod-infra-container-image will not be pruned by the image garbage collector in kubelet and should also be set in the remote runtime"
Sep 01 23:35:06 u7s-usernetes-compute-001 kubelet[849]: I0901 23:35:06.072279     849 server.go:415] "Kubelet version" kubeletVersion="v1.27.3"
Sep 01 23:35:06 u7s-usernetes-compute-001 kubelet[849]: I0901 23:35:06.072312     849 server.go:417] "Golang settings" GOGC="" GOMAXPROCS="" GOTRACEBACK=""
Sep 01 23:35:06 u7s-usernetes-compute-001 kubelet[849]: I0901 23:35:06.072629     849 server.go:837] "Client rotation is on, will bootstrap in background"
Sep 01 23:35:06 u7s-usernetes-compute-001 kubelet[849]: I0901 23:35:06.074997     849 certificate_store.go:130] Loading cert/key pair from "/var/lib/kubelet/pki/kubelet-client-current.pem".
Sep 01 23:35:06 u7s-usernetes-compute-001 kubelet[849]: I0901 23:35:06.075776     849 dynamic_cafile_content.go:157] "Starting controller" name="client-ca-bundle::/etc/kubernetes/pki/ca.crt"
Sep 01 23:35:06 u7s-usernetes-compute-001 kubelet[849]: I0901 23:35:06.079466     849 server.go:662] "--cgroups-per-qos enabled, but --cgroup-root was not specified.  defaulting to /"
Sep 01 23:35:06 u7s-usernetes-compute-001 kubelet[849]: I0901 23:35:06.079672     849 container_manager_linux.go:266] "Container manager verified user specified cgroup-root exists" cgroupRoot=[]
Sep 01 23:35:06 u7s-usernetes-compute-001 kubelet[849]: I0901 23:35:06.079729     849 container_manager_linux.go:271] "Creating Container Manager object based on Node Config" nodeConfig={RuntimeCgroupsName:/system.slice/containerd.service SystemCgroupsName: KubeletCgroupsName: KubeletOOMScoreAdj:-999 ContainerRuntime: CgroupsPerQOS:true CgroupRoot:/ CgroupDriver:systemd KubeletRootDir:/var/lib/kubelet ProtectKernelDefaults:false NodeAllocatableConfig:{KubeReservedCgroupName: SystemReservedCgroupName: ReservedSystemCPUs: EnforceNodeAllocatable:map[pods:{}] KubeReserved:map[] SystemReserved:map[] HardEvictionThresholds:[{Signal:memory.available Operator:LessThan Value:{Quantity:100Mi Percentage:0} GracePeriod:0s MinReclaim:<nil>} {Signal:nodefs.available Operator:LessThan Value:{Quantity:<nil> Percentage:0.1} GracePeriod:0s MinReclaim:<nil>} {Signal:nodefs.inodesFree Operator:LessThan Value:{Quantity:<nil> Percentage:0.05} GracePeriod:0s MinReclaim:<nil>} {Signal:imagefs.available Operator:LessThan Value:{Quantity:<nil> Percentage:0.15} GracePeriod:0s MinReclaim:<nil>}]} QOSReserved:map[] CPUManagerPolicy:none CPUManagerPolicyOptions:map[] TopologyManagerScope:container CPUManagerReconcilePeriod:10s ExperimentalMemoryManagerPolicy:None ExperimentalMemoryManagerReservedMemory:[] PodPidsLimit:-1 EnforceCPULimits:true CPUCFSQuotaPeriod:100ms TopologyManagerPolicy:none ExperimentalTopologyManagerPolicyOptions:map[]}
Sep 01 23:35:06 u7s-usernetes-compute-001 kubelet[849]: I0901 23:35:06.079750     849 topology_manager.go:136] "Creating topology manager with policy per scope" topologyPolicyName="none" topologyScopeName="container"
Sep 01 23:35:06 u7s-usernetes-compute-001 kubelet[849]: I0901 23:35:06.079758     849 container_manager_linux.go:302] "Creating device plugin manager"
Sep 01 23:35:06 u7s-usernetes-compute-001 kubelet[849]: I0901 23:35:06.079782     849 state_mem.go:36] "Initialized new in-memory state store"
Sep 01 23:35:06 u7s-usernetes-compute-001 kubelet[849]: I0901 23:35:06.082146     849 kubelet.go:405] "Attempting to sync node with API server"
Sep 01 23:35:06 u7s-usernetes-compute-001 kubelet[849]: I0901 23:35:06.082171     849 kubelet.go:298] "Adding static pod path" path="/etc/kubernetes/manifests"
Sep 01 23:35:06 u7s-usernetes-compute-001 kubelet[849]: I0901 23:35:06.082189     849 kubelet.go:309] "Adding apiserver pod source"
Sep 01 23:35:06 u7s-usernetes-compute-001 kubelet[849]: I0901 23:35:06.082231     849 apiserver.go:42] "Waiting for node sync before watching apiserver pods"
Sep 01 23:35:06 u7s-usernetes-compute-001 kubelet[849]: I0901 23:35:06.082858     849 kuberuntime_manager.go:257] "Container runtime initialized" containerRuntime="containerd" version="v1.7.1" apiVersion="v1"
Sep 01 23:35:06 u7s-usernetes-compute-001 kubelet[849]: I0901 23:35:06.083417     849 server.go:1168] "Started kubelet"
Sep 01 23:35:06 u7s-usernetes-compute-001 kubelet[849]: I0901 23:35:06.083762     849 ratelimit.go:65] "Setting rate limiting for podresources endpoint" qps=100 burstTokens=10
Sep 01 23:35:06 u7s-usernetes-compute-001 kubelet[849]: E0901 23:35:06.083856     849 cri_stats_provider.go:455] "Failed to get the info of the filesystem with mountpoint" err="unable to find data in memory cache" mountpoint="/var/lib/containerd/io.containerd.snapshotter.v1.overlayfs"
Sep 01 23:35:06 u7s-usernetes-compute-001 kubelet[849]: E0901 23:35:06.083895     849 kubelet.go:1400] "Image garbage collection failed once. Stats initialization may not have completed yet" err="invalid capacity 0 on image filesystem"
Sep 01 23:35:06 u7s-usernetes-compute-001 kubelet[849]: I0901 23:35:06.084362     849 server.go:162] "Starting to listen" address="0.0.0.0" port=10250
Sep 01 23:35:06 u7s-usernetes-compute-001 kubelet[849]: I0901 23:35:06.085889     849 server.go:461] "Adding debug handlers to kubelet server"
Sep 01 23:35:06 u7s-usernetes-compute-001 kubelet[849]: I0901 23:35:06.086011     849 fs_resource_analyzer.go:67] "Starting FS ResourceAnalyzer"
Sep 01 23:35:06 u7s-usernetes-compute-001 kubelet[849]: I0901 23:35:06.086907     849 volume_manager.go:284] "Starting Kubelet Volume Manager"
Sep 01 23:35:06 u7s-usernetes-compute-001 kubelet[849]: I0901 23:35:06.087810     849 desired_state_of_world_populator.go:145] "Desired state populator starts to run"
Sep 01 23:35:06 u7s-usernetes-compute-001 kubelet[849]: I0901 23:35:06.098764     849 kubelet_network_linux.go:63] "Initialized iptables rules." protocol=IPv4
Sep 01 23:35:06 u7s-usernetes-compute-001 kubelet[849]: I0901 23:35:06.100106     849 kubelet_network_linux.go:63] "Initialized iptables rules." protocol=IPv6
Sep 01 23:35:06 u7s-usernetes-compute-001 kubelet[849]: I0901 23:35:06.100212     849 status_manager.go:207] "Starting to sync pod status with apiserver"
Sep 01 23:35:06 u7s-usernetes-compute-001 kubelet[849]: I0901 23:35:06.100277     849 kubelet.go:2257] "Starting kubelet main sync loop"
Sep 01 23:35:06 u7s-usernetes-compute-001 kubelet[849]: E0901 23:35:06.100380     849 kubelet.go:2281] "Skipping pod synchronization" err="[container runtime status check may not have completed yet, PLEG is not healthy: pleg has yet to be successful]"
Sep 01 23:35:06 u7s-usernetes-compute-001 kubelet[849]: I0901 23:35:06.129947     849 cpu_manager.go:214] "Starting CPU manager" policy="none"
Sep 01 23:35:06 u7s-usernetes-compute-001 kubelet[849]: I0901 23:35:06.129966     849 cpu_manager.go:215] "Reconciling" reconcilePeriod="10s"
Sep 01 23:35:06 u7s-usernetes-compute-001 kubelet[849]: I0901 23:35:06.129980     849 state_mem.go:36] "Initialized new in-memory state store"
Sep 01 23:35:06 u7s-usernetes-compute-001 kubelet[849]: I0901 23:35:06.130101     849 state_mem.go:88] "Updated default CPUSet" cpuSet=""
Sep 01 23:35:06 u7s-usernetes-compute-001 kubelet[849]: I0901 23:35:06.130112     849 state_mem.go:96] "Updated CPUSet assignments" assignments=map[]
Sep 01 23:35:06 u7s-usernetes-compute-001 kubelet[849]: I0901 23:35:06.130117     849 policy_none.go:49] "None policy: Start"
Sep 01 23:35:06 u7s-usernetes-compute-001 kubelet[849]: I0901 23:35:06.130539     849 memory_manager.go:169] "Starting memorymanager" policy="None"
Sep 01 23:35:06 u7s-usernetes-compute-001 kubelet[849]: I0901 23:35:06.130570     849 state_mem.go:35] "Initializing new in-memory state store"
Sep 01 23:35:06 u7s-usernetes-compute-001 kubelet[849]: I0901 23:35:06.130679     849 state_mem.go:75] "Updated machine memory state"
Sep 01 23:35:06 u7s-usernetes-compute-001 kubelet[849]: I0901 23:35:06.161029     849 manager.go:455] "Failed to read data from checkpoint" checkpoint="kubelet_internal_checkpoint" err="checkpoint is not found"
Sep 01 23:35:06 u7s-usernetes-compute-001 kubelet[849]: I0901 23:35:06.161333     849 plugin_manager.go:118] "Starting Kubelet Plugin Manager"
Sep 01 23:35:06 u7s-usernetes-compute-001 kubelet[849]: I0901 23:35:06.188765     849 kubelet_node_status.go:70] "Attempting to register node" node="u7s-usernetes-compute-001"
Sep 01 23:35:06 u7s-usernetes-compute-001 kubelet[849]: I0901 23:35:06.198483     849 kubelet_node_status.go:108] "Node was previously registered" node="u7s-usernetes-compute-001"
Sep 01 23:35:06 u7s-usernetes-compute-001 kubelet[849]: I0901 23:35:06.198572     849 kubelet_node_status.go:73] "Successfully registered node" node="u7s-usernetes-compute-001"
Sep 01 23:35:06 u7s-usernetes-compute-001 kubelet[849]: I0901 23:35:06.200736     849 topology_manager.go:212] "Topology Admit Handler"
Sep 01 23:35:06 u7s-usernetes-compute-001 kubelet[849]: I0901 23:35:06.200826     849 topology_manager.go:212] "Topology Admit Handler"
Sep 01 23:35:06 u7s-usernetes-compute-001 kubelet[849]: I0901 23:35:06.200860     849 topology_manager.go:212] "Topology Admit Handler"
Sep 01 23:35:06 u7s-usernetes-compute-001 kubelet[849]: I0901 23:35:06.200889     849 topology_manager.go:212] "Topology Admit Handler"
Sep 01 23:35:06 u7s-usernetes-compute-001 kubelet[849]: I0901 23:35:06.388847     849 reconciler_common.go:258] "operationExecutor.VerifyControllerAttachedVolume started for volume \"flexvolume-dir\" (UniqueName: \"kubernetes.io/host-path/5717a8580af9c26b0530fb2dc202e84b-flexvolume-dir\") pod \"kube-controller-manager-u7s-usernetes-compute-001\" (UID: \"5717a8580af9c26b0530fb2dc202e84b\") " pod="kube-system/kube-controller-manager-u7s-usernetes-compute-001"
Sep 01 23:35:06 u7s-usernetes-compute-001 kubelet[849]: I0901 23:35:06.388890     849 reconciler_common.go:258] "operationExecutor.VerifyControllerAttachedVolume started for volume \"etc-ca-certificates\" (UniqueName: \"kubernetes.io/host-path/fc29d9d860df7d1516151a6ead9f9f64-etc-ca-certificates\") pod \"kube-apiserver-u7s-usernetes-compute-001\" (UID: \"fc29d9d860df7d1516151a6ead9f9f64\") " pod="kube-system/kube-apiserver-u7s-usernetes-compute-001"
Sep 01 23:35:06 u7s-usernetes-compute-001 kubelet[849]: I0901 23:35:06.388926     849 reconciler_common.go:258] "operationExecutor.VerifyControllerAttachedVolume started for volume \"etc-ca-certificates\" (UniqueName: \"kubernetes.io/host-path/5717a8580af9c26b0530fb2dc202e84b-etc-ca-certificates\") pod \"kube-controller-manager-u7s-usernetes-compute-001\" (UID: \"5717a8580af9c26b0530fb2dc202e84b\") " pod="kube-system/kube-controller-manager-u7s-usernetes-compute-001"
Sep 01 23:35:06 u7s-usernetes-compute-001 kubelet[849]: I0901 23:35:06.388961     849 reconciler_common.go:258] "operationExecutor.VerifyControllerAttachedVolume started for volume \"k8s-certs\" (UniqueName: \"kubernetes.io/host-path/5717a8580af9c26b0530fb2dc202e84b-k8s-certs\") pod \"kube-controller-manager-u7s-usernetes-compute-001\" (UID: \"5717a8580af9c26b0530fb2dc202e84b\") " pod="kube-system/kube-controller-manager-u7s-usernetes-compute-001"
Sep 01 23:35:06 u7s-usernetes-compute-001 kubelet[849]: I0901 23:35:06.388989     849 reconciler_common.go:258] "operationExecutor.VerifyControllerAttachedVolume started for volume \"ca-certs\" (UniqueName: \"kubernetes.io/host-path/fc29d9d860df7d1516151a6ead9f9f64-ca-certs\") pod \"kube-apiserver-u7s-usernetes-compute-001\" (UID: \"fc29d9d860df7d1516151a6ead9f9f64\") " pod="kube-system/kube-apiserver-u7s-usernetes-compute-001"
Sep 01 23:35:06 u7s-usernetes-compute-001 kubelet[849]: I0901 23:35:06.389022     849 reconciler_common.go:258] "operationExecutor.VerifyControllerAttachedVolume started for volume \"ca-certs\" (UniqueName: \"kubernetes.io/host-path/5717a8580af9c26b0530fb2dc202e84b-ca-certs\") pod \"kube-controller-manager-u7s-usernetes-compute-001\" (UID: \"5717a8580af9c26b0530fb2dc202e84b\") " pod="kube-system/kube-controller-manager-u7s-usernetes-compute-001"
Sep 01 23:35:06 u7s-usernetes-compute-001 kubelet[849]: I0901 23:35:06.389054     849 reconciler_common.go:258] "operationExecutor.VerifyControllerAttachedVolume started for volume \"kubeconfig\" (UniqueName: \"kubernetes.io/host-path/5717a8580af9c26b0530fb2dc202e84b-kubeconfig\") pod \"kube-controller-manager-u7s-usernetes-compute-001\" (UID: \"5717a8580af9c26b0530fb2dc202e84b\") " pod="kube-system/kube-controller-manager-u7s-usernetes-compute-001"
Sep 01 23:35:06 u7s-usernetes-compute-001 kubelet[849]: I0901 23:35:06.389081     849 reconciler_common.go:258] "operationExecutor.VerifyControllerAttachedVolume started for volume \"usr-local-share-ca-certificates\" (UniqueName: \"kubernetes.io/host-path/5717a8580af9c26b0530fb2dc202e84b-usr-local-share-ca-certificates\") pod \"kube-controller-manager-u7s-usernetes-compute-001\" (UID: \"5717a8580af9c26b0530fb2dc202e84b\") " pod="kube-system/kube-controller-manager-u7s-usernetes-compute-001"
Sep 01 23:35:06 u7s-usernetes-compute-001 kubelet[849]: I0901 23:35:06.389108     849 reconciler_common.go:258] "operationExecutor.VerifyControllerAttachedVolume started for volume \"usr-share-ca-certificates\" (UniqueName: \"kubernetes.io/host-path/5717a8580af9c26b0530fb2dc202e84b-usr-share-ca-certificates\") pod \"kube-controller-manager-u7s-usernetes-compute-001\" (UID: \"5717a8580af9c26b0530fb2dc202e84b\") " pod="kube-system/kube-controller-manager-u7s-usernetes-compute-001"
Sep 01 23:35:06 u7s-usernetes-compute-001 kubelet[849]: I0901 23:35:06.389145     849 reconciler_common.go:258] "operationExecutor.VerifyControllerAttachedVolume started for volume \"kubeconfig\" (UniqueName: \"kubernetes.io/host-path/86b04793958bc8604bae256476aad501-kubeconfig\") pod \"kube-scheduler-u7s-usernetes-compute-001\" (UID: \"86b04793958bc8604bae256476aad501\") " pod="kube-system/kube-scheduler-u7s-usernetes-compute-001"
Sep 01 23:35:06 u7s-usernetes-compute-001 kubelet[849]: I0901 23:35:06.389172     849 reconciler_common.go:258] "operationExecutor.VerifyControllerAttachedVolume started for volume \"etcd-certs\" (UniqueName: \"kubernetes.io/host-path/65293b5fb246ed9728c144ff6ed5f365-etcd-certs\") pod \"etcd-u7s-usernetes-compute-001\" (UID: \"65293b5fb246ed9728c144ff6ed5f365\") " pod="kube-system/etcd-u7s-usernetes-compute-001"
Sep 01 23:35:06 u7s-usernetes-compute-001 kubelet[849]: I0901 23:35:06.389209     849 reconciler_common.go:258] "operationExecutor.VerifyControllerAttachedVolume started for volume \"usr-share-ca-certificates\" (UniqueName: \"kubernetes.io/host-path/fc29d9d860df7d1516151a6ead9f9f64-usr-share-ca-certificates\") pod \"kube-apiserver-u7s-usernetes-compute-001\" (UID: \"fc29d9d860df7d1516151a6ead9f9f64\") " pod="kube-system/kube-apiserver-u7s-usernetes-compute-001"
Sep 01 23:35:06 u7s-usernetes-compute-001 kubelet[849]: I0901 23:35:06.389234     849 reconciler_common.go:258] "operationExecutor.VerifyControllerAttachedVolume started for volume \"usr-local-share-ca-certificates\" (UniqueName: \"kubernetes.io/host-path/fc29d9d860df7d1516151a6ead9f9f64-usr-local-share-ca-certificates\") pod \"kube-apiserver-u7s-usernetes-compute-001\" (UID: \"fc29d9d860df7d1516151a6ead9f9f64\") " pod="kube-system/kube-apiserver-u7s-usernetes-compute-001"
Sep 01 23:35:06 u7s-usernetes-compute-001 kubelet[849]: I0901 23:35:06.389261     849 reconciler_common.go:258] "operationExecutor.VerifyControllerAttachedVolume started for volume \"etcd-data\" (UniqueName: \"kubernetes.io/host-path/65293b5fb246ed9728c144ff6ed5f365-etcd-data\") pod \"etcd-u7s-usernetes-compute-001\" (UID: \"65293b5fb246ed9728c144ff6ed5f365\") " pod="kube-system/etcd-u7s-usernetes-compute-001"
Sep 01 23:35:06 u7s-usernetes-compute-001 kubelet[849]: I0901 23:35:06.389311     849 reconciler_common.go:258] "operationExecutor.VerifyControllerAttachedVolume started for volume \"k8s-certs\" (UniqueName: \"kubernetes.io/host-path/fc29d9d860df7d1516151a6ead9f9f64-k8s-certs\") pod \"kube-apiserver-u7s-usernetes-compute-001\" (UID: \"fc29d9d860df7d1516151a6ead9f9f64\") " pod="kube-system/kube-apiserver-u7s-usernetes-compute-001"
Sep 01 23:35:07 u7s-usernetes-compute-001 kubelet[849]: I0901 23:35:07.083201     849 apiserver.go:52] "Watching apiserver"
Sep 01 23:35:07 u7s-usernetes-compute-001 kubelet[849]: I0901 23:35:07.088034     849 desired_state_of_world_populator.go:153] "Finished populating initial desired state of world"
Sep 01 23:35:07 u7s-usernetes-compute-001 kubelet[849]: I0901 23:35:07.093021     849 reconciler.go:41] "Reconciler: start to sync state"
Sep 01 23:35:07 u7s-usernetes-compute-001 kubelet[849]: I0901 23:35:07.122171     849 pod_startup_latency_tracker.go:102] "Observed pod startup duration" pod="kube-system/etcd-u7s-usernetes-compute-001" podStartSLOduration=1.122101053 podCreationTimestamp="2023-09-01 23:35:06 +0000 UTC" firstStartedPulling="0001-01-01 00:00:00 +0000 UTC" lastFinishedPulling="0001-01-01 00:00:00 +0000 UTC" observedRunningTime="2023-09-01 23:35:07.111932381 +0000 UTC m=+1.074083811" watchObservedRunningTime="2023-09-01 23:35:07.122101053 +0000 UTC m=+1.084252474"
Sep 01 23:35:07 u7s-usernetes-compute-001 kubelet[849]: E0901 23:35:07.122259     849 kubelet.go:1856] "Failed creating a mirror pod for" err="pods \"etcd-u7s-usernetes-compute-001\" already exists" pod="kube-system/etcd-u7s-usernetes-compute-001"
Sep 01 23:35:07 u7s-usernetes-compute-001 kubelet[849]: E0901 23:35:07.122273     849 kubelet.go:1856] "Failed creating a mirror pod for" err="pods \"kube-apiserver-u7s-usernetes-compute-001\" already exists" pod="kube-system/kube-apiserver-u7s-usernetes-compute-001"
Sep 01 23:35:07 u7s-usernetes-compute-001 kubelet[849]: I0901 23:35:07.129535     849 pod_startup_latency_tracker.go:102] "Observed pod startup duration" pod="kube-system/kube-apiserver-u7s-usernetes-compute-001" podStartSLOduration=1.129507651 podCreationTimestamp="2023-09-01 23:35:06 +0000 UTC" firstStartedPulling="0001-01-01 00:00:00 +0000 UTC" lastFinishedPulling="0001-01-01 00:00:00 +0000 UTC" observedRunningTime="2023-09-01 23:35:07.122285526 +0000 UTC m=+1.084436952" watchObservedRunningTime="2023-09-01 23:35:07.129507651 +0000 UTC m=+1.091659078"
Sep 01 23:35:07 u7s-usernetes-compute-001 kubelet[849]: I0901 23:35:07.129635     849 pod_startup_latency_tracker.go:102] "Observed pod startup duration" pod="kube-system/kube-controller-manager-u7s-usernetes-compute-001" podStartSLOduration=1.129610661 podCreationTimestamp="2023-09-01 23:35:06 +0000 UTC" firstStartedPulling="0001-01-01 00:00:00 +0000 UTC" lastFinishedPulling="0001-01-01 00:00:00 +0000 UTC" observedRunningTime="2023-09-01 23:35:07.129425678 +0000 UTC m=+1.091577104" watchObservedRunningTime="2023-09-01 23:35:07.129610661 +0000 UTC m=+1.091762090"
Sep 01 23:35:07 u7s-usernetes-compute-001 kubelet[849]: I0901 23:35:07.136189     849 pod_startup_latency_tracker.go:102] "Observed pod startup duration" pod="kube-system/kube-scheduler-u7s-usernetes-compute-001" podStartSLOduration=1.136162415 podCreationTimestamp="2023-09-01 23:35:06 +0000 UTC" firstStartedPulling="0001-01-01 00:00:00 +0000 UTC" lastFinishedPulling="0001-01-01 00:00:00 +0000 UTC" observedRunningTime="2023-09-01 23:35:07.13610021 +0000 UTC m=+1.098251652" watchObservedRunningTime="2023-09-01 23:35:07.136162415 +0000 UTC m=+1.098313838"
Sep 01 23:35:20 u7s-usernetes-compute-001 kubelet[849]: I0901 23:35:20.499953     849 kuberuntime_manager.go:1460] "Updating runtime config through cri with podcidr" CIDR="10.244.0.0/24"
Sep 01 23:35:20 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:35:20.500230544Z" level=info msg="No cni config template is specified, wait for other system components to drop the config."
Sep 01 23:35:20 u7s-usernetes-compute-001 kubelet[849]: I0901 23:35:20.500414     849 kubelet_network.go:61] "Updating Pod CIDR" originalPodCIDR="" newPodCIDR="10.244.0.0/24"
Sep 01 23:35:21 u7s-usernetes-compute-001 kubelet[849]: I0901 23:35:21.226109     849 topology_manager.go:212] "Topology Admit Handler"
Sep 01 23:35:21 u7s-usernetes-compute-001 kubelet[849]: I0901 23:35:21.229228     849 topology_manager.go:212] "Topology Admit Handler"
Sep 01 23:35:21 u7s-usernetes-compute-001 systemd[1]: Created slice libcontainer container kubepods-besteffort-podffbc4508_6d28_427d_a7e5_4b4a36c5c5af.slice.
Sep 01 23:35:21 u7s-usernetes-compute-001 kubelet[849]: I0901 23:35:21.248994     849 reconciler_common.go:258] "operationExecutor.VerifyControllerAttachedVolume started for volume \"run\" (UniqueName: \"kubernetes.io/host-path/05f55160-0783-4476-a1a9-0b08e251ab49-run\") pod \"kube-flannel-ds-4dckq\" (UID: \"05f55160-0783-4476-a1a9-0b08e251ab49\") " pod="kube-flannel/kube-flannel-ds-4dckq"
Sep 01 23:35:21 u7s-usernetes-compute-001 kubelet[849]: I0901 23:35:21.249034     849 reconciler_common.go:258] "operationExecutor.VerifyControllerAttachedVolume started for volume \"cni\" (UniqueName: \"kubernetes.io/host-path/05f55160-0783-4476-a1a9-0b08e251ab49-cni\") pod \"kube-flannel-ds-4dckq\" (UID: \"05f55160-0783-4476-a1a9-0b08e251ab49\") " pod="kube-flannel/kube-flannel-ds-4dckq"
Sep 01 23:35:21 u7s-usernetes-compute-001 kubelet[849]: I0901 23:35:21.249054     849 reconciler_common.go:258] "operationExecutor.VerifyControllerAttachedVolume started for volume \"flannel-cfg\" (UniqueName: \"kubernetes.io/configmap/05f55160-0783-4476-a1a9-0b08e251ab49-flannel-cfg\") pod \"kube-flannel-ds-4dckq\" (UID: \"05f55160-0783-4476-a1a9-0b08e251ab49\") " pod="kube-flannel/kube-flannel-ds-4dckq"
Sep 01 23:35:21 u7s-usernetes-compute-001 kubelet[849]: I0901 23:35:21.249149     849 reconciler_common.go:258] "operationExecutor.VerifyControllerAttachedVolume started for volume \"xtables-lock\" (UniqueName: \"kubernetes.io/host-path/ffbc4508-6d28-427d-a7e5-4b4a36c5c5af-xtables-lock\") pod \"kube-proxy-tjgbq\" (UID: \"ffbc4508-6d28-427d-a7e5-4b4a36c5c5af\") " pod="kube-system/kube-proxy-tjgbq"
Sep 01 23:35:21 u7s-usernetes-compute-001 kubelet[849]: I0901 23:35:21.249198     849 reconciler_common.go:258] "operationExecutor.VerifyControllerAttachedVolume started for volume \"kube-api-access-rkd4t\" (UniqueName: \"kubernetes.io/projected/05f55160-0783-4476-a1a9-0b08e251ab49-kube-api-access-rkd4t\") pod \"kube-flannel-ds-4dckq\" (UID: \"05f55160-0783-4476-a1a9-0b08e251ab49\") " pod="kube-flannel/kube-flannel-ds-4dckq"
Sep 01 23:35:21 u7s-usernetes-compute-001 kubelet[849]: I0901 23:35:21.249310     849 reconciler_common.go:258] "operationExecutor.VerifyControllerAttachedVolume started for volume \"lib-modules\" (UniqueName: \"kubernetes.io/host-path/ffbc4508-6d28-427d-a7e5-4b4a36c5c5af-lib-modules\") pod \"kube-proxy-tjgbq\" (UID: \"ffbc4508-6d28-427d-a7e5-4b4a36c5c5af\") " pod="kube-system/kube-proxy-tjgbq"
Sep 01 23:35:21 u7s-usernetes-compute-001 kubelet[849]: I0901 23:35:21.249353     849 reconciler_common.go:258] "operationExecutor.VerifyControllerAttachedVolume started for volume \"cni-plugin\" (UniqueName: \"kubernetes.io/host-path/05f55160-0783-4476-a1a9-0b08e251ab49-cni-plugin\") pod \"kube-flannel-ds-4dckq\" (UID: \"05f55160-0783-4476-a1a9-0b08e251ab49\") " pod="kube-flannel/kube-flannel-ds-4dckq"
Sep 01 23:35:21 u7s-usernetes-compute-001 kubelet[849]: I0901 23:35:21.249378     849 reconciler_common.go:258] "operationExecutor.VerifyControllerAttachedVolume started for volume \"xtables-lock\" (UniqueName: \"kubernetes.io/host-path/05f55160-0783-4476-a1a9-0b08e251ab49-xtables-lock\") pod \"kube-flannel-ds-4dckq\" (UID: \"05f55160-0783-4476-a1a9-0b08e251ab49\") " pod="kube-flannel/kube-flannel-ds-4dckq"
Sep 01 23:35:21 u7s-usernetes-compute-001 kubelet[849]: I0901 23:35:21.249416     849 reconciler_common.go:258] "operationExecutor.VerifyControllerAttachedVolume started for volume \"kube-proxy\" (UniqueName: \"kubernetes.io/configmap/ffbc4508-6d28-427d-a7e5-4b4a36c5c5af-kube-proxy\") pod \"kube-proxy-tjgbq\" (UID: \"ffbc4508-6d28-427d-a7e5-4b4a36c5c5af\") " pod="kube-system/kube-proxy-tjgbq"
Sep 01 23:35:21 u7s-usernetes-compute-001 kubelet[849]: I0901 23:35:21.249446     849 reconciler_common.go:258] "operationExecutor.VerifyControllerAttachedVolume started for volume \"kube-api-access-9slfj\" (UniqueName: \"kubernetes.io/projected/ffbc4508-6d28-427d-a7e5-4b4a36c5c5af-kube-api-access-9slfj\") pod \"kube-proxy-tjgbq\" (UID: \"ffbc4508-6d28-427d-a7e5-4b4a36c5c5af\") " pod="kube-system/kube-proxy-tjgbq"
Sep 01 23:35:21 u7s-usernetes-compute-001 systemd[1]: Created slice libcontainer container kubepods-burstable-pod05f55160_0783_4476_a1a9_0b08e251ab49.slice.
Sep 01 23:35:21 u7s-usernetes-compute-001 kubelet[849]: E0901 23:35:21.354086     849 projected.go:292] Couldn't get configMap kube-flannel/kube-root-ca.crt: configmap "kube-root-ca.crt" not found
Sep 01 23:35:21 u7s-usernetes-compute-001 kubelet[849]: E0901 23:35:21.354113     849 projected.go:198] Error preparing data for projected volume kube-api-access-rkd4t for pod kube-flannel/kube-flannel-ds-4dckq: configmap "kube-root-ca.crt" not found
Sep 01 23:35:21 u7s-usernetes-compute-001 kubelet[849]: E0901 23:35:21.354169     849 nestedpendingoperations.go:348] Operation for "{volumeName:kubernetes.io/projected/05f55160-0783-4476-a1a9-0b08e251ab49-kube-api-access-rkd4t podName:05f55160-0783-4476-a1a9-0b08e251ab49 nodeName:}" failed. No retries permitted until 2023-09-01 23:35:21.854149947 +0000 UTC m=+15.816301368 (durationBeforeRetry 500ms). Error: MountVolume.SetUp failed for volume "kube-api-access-rkd4t" (UniqueName: "kubernetes.io/projected/05f55160-0783-4476-a1a9-0b08e251ab49-kube-api-access-rkd4t") pod "kube-flannel-ds-4dckq" (UID: "05f55160-0783-4476-a1a9-0b08e251ab49") : configmap "kube-root-ca.crt" not found
Sep 01 23:35:21 u7s-usernetes-compute-001 kubelet[849]: E0901 23:35:21.354086     849 projected.go:292] Couldn't get configMap kube-system/kube-root-ca.crt: configmap "kube-root-ca.crt" not found
Sep 01 23:35:21 u7s-usernetes-compute-001 kubelet[849]: E0901 23:35:21.354351     849 projected.go:198] Error preparing data for projected volume kube-api-access-9slfj for pod kube-system/kube-proxy-tjgbq: configmap "kube-root-ca.crt" not found
Sep 01 23:35:21 u7s-usernetes-compute-001 kubelet[849]: E0901 23:35:21.354401     849 nestedpendingoperations.go:348] Operation for "{volumeName:kubernetes.io/projected/ffbc4508-6d28-427d-a7e5-4b4a36c5c5af-kube-api-access-9slfj podName:ffbc4508-6d28-427d-a7e5-4b4a36c5c5af nodeName:}" failed. No retries permitted until 2023-09-01 23:35:21.854386875 +0000 UTC m=+15.816538300 (durationBeforeRetry 500ms). Error: MountVolume.SetUp failed for volume "kube-api-access-9slfj" (UniqueName: "kubernetes.io/projected/ffbc4508-6d28-427d-a7e5-4b4a36c5c5af-kube-api-access-9slfj") pod "kube-proxy-tjgbq" (UID: "ffbc4508-6d28-427d-a7e5-4b4a36c5c5af") : configmap "kube-root-ca.crt" not found
Sep 01 23:35:22 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:35:22.162461924Z" level=info msg="RunPodSandbox for &PodSandboxMetadata{Name:kube-proxy-tjgbq,Uid:ffbc4508-6d28-427d-a7e5-4b4a36c5c5af,Namespace:kube-system,Attempt:0,}"
Sep 01 23:35:22 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:35:22.163842034Z" level=info msg="RunPodSandbox for &PodSandboxMetadata{Name:kube-flannel-ds-4dckq,Uid:05f55160-0783-4476-a1a9-0b08e251ab49,Namespace:kube-flannel,Attempt:0,}"
Sep 01 23:35:22 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:35:22.185342460Z" level=info msg="loading plugin \"io.containerd.internal.v1.shutdown\"..." runtime=io.containerd.runc.v2 type=io.containerd.internal.v1
Sep 01 23:35:22 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:35:22.185407382Z" level=info msg="loading plugin \"io.containerd.ttrpc.v1.pause\"..." runtime=io.containerd.runc.v2 type=io.containerd.ttrpc.v1
Sep 01 23:35:22 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:35:22.185425360Z" level=info msg="loading plugin \"io.containerd.event.v1.publisher\"..." runtime=io.containerd.runc.v2 type=io.containerd.event.v1
Sep 01 23:35:22 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:35:22.185440944Z" level=info msg="loading plugin \"io.containerd.ttrpc.v1.task\"..." runtime=io.containerd.runc.v2 type=io.containerd.ttrpc.v1
Sep 01 23:35:22 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:35:22.185852338Z" level=info msg="loading plugin \"io.containerd.internal.v1.shutdown\"..." runtime=io.containerd.runc.v2 type=io.containerd.internal.v1
Sep 01 23:35:22 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:35:22.185911447Z" level=info msg="loading plugin \"io.containerd.ttrpc.v1.pause\"..." runtime=io.containerd.runc.v2 type=io.containerd.ttrpc.v1
Sep 01 23:35:22 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:35:22.185924660Z" level=info msg="loading plugin \"io.containerd.event.v1.publisher\"..." runtime=io.containerd.runc.v2 type=io.containerd.event.v1
Sep 01 23:35:22 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:35:22.185937222Z" level=info msg="loading plugin \"io.containerd.ttrpc.v1.task\"..." runtime=io.containerd.runc.v2 type=io.containerd.ttrpc.v1
Sep 01 23:35:22 u7s-usernetes-compute-001 systemd[1]: run-containerd-runc-k8s.io-3c49bc8817885edf9b580bf92076a2ec413f2029838b38beefd42f42502134f3-runc.2pVrAe.mount: Succeeded.
Sep 01 23:35:22 u7s-usernetes-compute-001 systemd[1]: Started libcontainer container 04b07abe018e7b944356f7d8b8225b358cc9fc94716255fe1c239bcc2c848710.
Sep 01 23:35:22 u7s-usernetes-compute-001 systemd[1]: Started libcontainer container 3c49bc8817885edf9b580bf92076a2ec413f2029838b38beefd42f42502134f3.
Sep 01 23:35:22 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:35:22.251890381Z" level=info msg="RunPodSandbox for &PodSandboxMetadata{Name:kube-proxy-tjgbq,Uid:ffbc4508-6d28-427d-a7e5-4b4a36c5c5af,Namespace:kube-system,Attempt:0,} returns sandbox id \"04b07abe018e7b944356f7d8b8225b358cc9fc94716255fe1c239bcc2c848710\""
Sep 01 23:35:22 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:35:22.254034405Z" level=info msg="CreateContainer within sandbox \"04b07abe018e7b944356f7d8b8225b358cc9fc94716255fe1c239bcc2c848710\" for container &ContainerMetadata{Name:kube-proxy,Attempt:0,}"
Sep 01 23:35:22 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:35:22.266648888Z" level=info msg="RunPodSandbox for &PodSandboxMetadata{Name:kube-flannel-ds-4dckq,Uid:05f55160-0783-4476-a1a9-0b08e251ab49,Namespace:kube-flannel,Attempt:0,} returns sandbox id \"3c49bc8817885edf9b580bf92076a2ec413f2029838b38beefd42f42502134f3\""
Sep 01 23:35:22 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:35:22.267909638Z" level=info msg="PullImage \"docker.io/flannel/flannel-cni-plugin:v1.2.0\""
Sep 01 23:35:22 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:35:22.268006882Z" level=info msg="CreateContainer within sandbox \"04b07abe018e7b944356f7d8b8225b358cc9fc94716255fe1c239bcc2c848710\" for &ContainerMetadata{Name:kube-proxy,Attempt:0,} returns container id \"e96aae3bcf8bb300c742a5e072c23f5bbdc1aaca5b21c378de35c7c1a8d6ad56\""
Sep 01 23:35:22 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:35:22.268364141Z" level=info msg="StartContainer for \"e96aae3bcf8bb300c742a5e072c23f5bbdc1aaca5b21c378de35c7c1a8d6ad56\""
Sep 01 23:35:22 u7s-usernetes-compute-001 systemd[1]: Started libcontainer container e96aae3bcf8bb300c742a5e072c23f5bbdc1aaca5b21c378de35c7c1a8d6ad56.
Sep 01 23:35:22 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:35:22.369959110Z" level=info msg="StartContainer for \"e96aae3bcf8bb300c742a5e072c23f5bbdc1aaca5b21c378de35c7c1a8d6ad56\" returns successfully"
Sep 01 23:35:23 u7s-usernetes-compute-001 kubelet[849]: I0901 23:35:23.444705     849 pod_startup_latency_tracker.go:102] "Observed pod startup duration" pod="kube-system/kube-proxy-tjgbq" podStartSLOduration=2.444661251 podCreationTimestamp="2023-09-01 23:35:21 +0000 UTC" firstStartedPulling="0001-01-01 00:00:00 +0000 UTC" lastFinishedPulling="0001-01-01 00:00:00 +0000 UTC" observedRunningTime="2023-09-01 23:35:23.444353287 +0000 UTC m=+17.406504712" watchObservedRunningTime="2023-09-01 23:35:23.444661251 +0000 UTC m=+17.406812681"
Sep 01 23:35:27 u7s-usernetes-compute-001 systemd[1]: var-lib-containerd-tmpmounts-containerd\x2dmount1297764747.mount: Succeeded.
Sep 01 23:35:27 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:35:27.594205684Z" level=info msg="ImageCreate event name:\"docker.io/flannel/flannel-cni-plugin:v1.2.0\" labels:{key:\"io.cri-containerd.image\" value:\"managed\"}"
Sep 01 23:35:27 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:35:27.595076539Z" level=info msg="stop pulling image docker.io/flannel/flannel-cni-plugin:v1.2.0: active requests=0, bytes read=3887949"
Sep 01 23:35:27 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:35:27.596171252Z" level=info msg="ImageCreate event name:\"sha256:a55d1bad692b776e7c632739dfbeffab2984ef399e1fa633e0751b1662ea8bb4\" labels:{key:\"io.cri-containerd.image\" value:\"managed\"}"
Sep 01 23:35:27 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:35:27.597705227Z" level=info msg="ImageUpdate event name:\"docker.io/flannel/flannel-cni-plugin:v1.2.0\" labels:{key:\"io.cri-containerd.image\" value:\"managed\"}"
Sep 01 23:35:27 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:35:27.599148842Z" level=info msg="ImageCreate event name:\"docker.io/flannel/flannel-cni-plugin@sha256:ca6779c6ad63b77af8a00151cefc08578241197b9a6fe144b0e55484bc52b852\" labels:{key:\"io.cri-containerd.image\" value:\"managed\"}"
Sep 01 23:35:27 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:35:27.600751393Z" level=info msg="Pulled image \"docker.io/flannel/flannel-cni-plugin:v1.2.0\" with image id \"sha256:a55d1bad692b776e7c632739dfbeffab2984ef399e1fa633e0751b1662ea8bb4\", repo tag \"docker.io/flannel/flannel-cni-plugin:v1.2.0\", repo digest \"docker.io/flannel/flannel-cni-plugin@sha256:ca6779c6ad63b77af8a00151cefc08578241197b9a6fe144b0e55484bc52b852\", size \"3879095\" in 5.332801633s"
Sep 01 23:35:27 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:35:27.600810668Z" level=info msg="PullImage \"docker.io/flannel/flannel-cni-plugin:v1.2.0\" returns image reference \"sha256:a55d1bad692b776e7c632739dfbeffab2984ef399e1fa633e0751b1662ea8bb4\""
Sep 01 23:35:27 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:35:27.602304574Z" level=info msg="CreateContainer within sandbox \"3c49bc8817885edf9b580bf92076a2ec413f2029838b38beefd42f42502134f3\" for container &ContainerMetadata{Name:install-cni-plugin,Attempt:0,}"
Sep 01 23:35:27 u7s-usernetes-compute-001 systemd[1]: var-lib-containerd-tmpmounts-containerd\x2dmount3205703827.mount: Succeeded.
Sep 01 23:35:27 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:35:27.612325535Z" level=info msg="CreateContainer within sandbox \"3c49bc8817885edf9b580bf92076a2ec413f2029838b38beefd42f42502134f3\" for &ContainerMetadata{Name:install-cni-plugin,Attempt:0,} returns container id \"d9d4f789168619cf0eb245e0740d41b59c641a776afb9fd07b83e2d726b2bab8\""
Sep 01 23:35:27 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:35:27.612663395Z" level=info msg="StartContainer for \"d9d4f789168619cf0eb245e0740d41b59c641a776afb9fd07b83e2d726b2bab8\""
Sep 01 23:35:27 u7s-usernetes-compute-001 systemd[1]: Started libcontainer container d9d4f789168619cf0eb245e0740d41b59c641a776afb9fd07b83e2d726b2bab8.
Sep 01 23:35:27 u7s-usernetes-compute-001 systemd[1]: cri-containerd-d9d4f789168619cf0eb245e0740d41b59c641a776afb9fd07b83e2d726b2bab8.scope: Succeeded.
Sep 01 23:35:27 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:35:27.703029967Z" level=info msg="StartContainer for \"d9d4f789168619cf0eb245e0740d41b59c641a776afb9fd07b83e2d726b2bab8\" returns successfully"
Sep 01 23:35:27 u7s-usernetes-compute-001 systemd[1]: run-containerd-io.containerd.runtime.v2.task-k8s.io-d9d4f789168619cf0eb245e0740d41b59c641a776afb9fd07b83e2d726b2bab8-rootfs.mount: Succeeded.
Sep 01 23:35:27 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:35:27.746393290Z" level=info msg="shim disconnected" id=d9d4f789168619cf0eb245e0740d41b59c641a776afb9fd07b83e2d726b2bab8 namespace=k8s.io
Sep 01 23:35:27 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:35:27.746447786Z" level=warning msg="cleaning up after shim disconnected" id=d9d4f789168619cf0eb245e0740d41b59c641a776afb9fd07b83e2d726b2bab8 namespace=k8s.io
Sep 01 23:35:27 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:35:27.746456661Z" level=info msg="cleaning up dead shim" namespace=k8s.io
Sep 01 23:35:28 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:35:28.145667266Z" level=info msg="PullImage \"docker.io/flannel/flannel:v0.22.2\""
Sep 01 23:35:29 u7s-usernetes-compute-001 systemd[1]: var-lib-containerd-tmpmounts-containerd\x2dmount3674995815.mount: Succeeded.
Sep 01 23:35:29 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:35:29.738064679Z" level=info msg="ImageCreate event name:\"docker.io/flannel/flannel:v0.22.2\" labels:{key:\"io.cri-containerd.image\" value:\"managed\"}"
Sep 01 23:35:29 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:35:29.738783203Z" level=info msg="stop pulling image docker.io/flannel/flannel:v0.22.2: active requests=0, bytes read=27012974"
Sep 01 23:35:29 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:35:29.739856086Z" level=info msg="ImageCreate event name:\"sha256:d73868a08083b8b0a6c8351a7270e915852301881ac0194440b67c85c7957fa4\" labels:{key:\"io.cri-containerd.image\" value:\"managed\"}"
Sep 01 23:35:29 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:35:29.741466255Z" level=info msg="ImageUpdate event name:\"docker.io/flannel/flannel:v0.22.2\" labels:{key:\"io.cri-containerd.image\" value:\"managed\"}"
Sep 01 23:35:29 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:35:29.743113454Z" level=info msg="ImageCreate event name:\"docker.io/flannel/flannel@sha256:c7214e3ce66191e45b8c2808c703a2a5674751e90f0f65aef0b404db0a22400c\" labels:{key:\"io.cri-containerd.image\" value:\"managed\"}"
Sep 01 23:35:29 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:35:29.743874077Z" level=info msg="Pulled image \"docker.io/flannel/flannel:v0.22.2\" with image id \"sha256:d73868a08083b8b0a6c8351a7270e915852301881ac0194440b67c85c7957fa4\", repo tag \"docker.io/flannel/flannel:v0.22.2\", repo digest \"docker.io/flannel/flannel@sha256:c7214e3ce66191e45b8c2808c703a2a5674751e90f0f65aef0b404db0a22400c\", size \"27004177\" in 1.598165144s"
Sep 01 23:35:29 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:35:29.743919248Z" level=info msg="PullImage \"docker.io/flannel/flannel:v0.22.2\" returns image reference \"sha256:d73868a08083b8b0a6c8351a7270e915852301881ac0194440b67c85c7957fa4\""
Sep 01 23:35:29 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:35:29.745235823Z" level=info msg="CreateContainer within sandbox \"3c49bc8817885edf9b580bf92076a2ec413f2029838b38beefd42f42502134f3\" for container &ContainerMetadata{Name:install-cni,Attempt:0,}"
Sep 01 23:35:29 u7s-usernetes-compute-001 systemd[1]: var-lib-containerd-tmpmounts-containerd\x2dmount807514564.mount: Succeeded.
Sep 01 23:35:29 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:35:29.758259414Z" level=info msg="CreateContainer within sandbox \"3c49bc8817885edf9b580bf92076a2ec413f2029838b38beefd42f42502134f3\" for &ContainerMetadata{Name:install-cni,Attempt:0,} returns container id \"2818b6773cfddb6becfcc1df8a2c3aa1895cf00a1725c60b7b4679bb8c5b2803\""
Sep 01 23:35:29 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:35:29.758583081Z" level=info msg="StartContainer for \"2818b6773cfddb6becfcc1df8a2c3aa1895cf00a1725c60b7b4679bb8c5b2803\""
Sep 01 23:35:29 u7s-usernetes-compute-001 systemd[1]: Started libcontainer container 2818b6773cfddb6becfcc1df8a2c3aa1895cf00a1725c60b7b4679bb8c5b2803.
Sep 01 23:35:29 u7s-usernetes-compute-001 systemd[1]: cri-containerd-2818b6773cfddb6becfcc1df8a2c3aa1895cf00a1725c60b7b4679bb8c5b2803.scope: Succeeded.
Sep 01 23:35:29 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:35:29.851696801Z" level=info msg="StartContainer for \"2818b6773cfddb6becfcc1df8a2c3aa1895cf00a1725c60b7b4679bb8c5b2803\" returns successfully"
Sep 01 23:35:29 u7s-usernetes-compute-001 systemd[1]: run-containerd-io.containerd.runtime.v2.task-k8s.io-2818b6773cfddb6becfcc1df8a2c3aa1895cf00a1725c60b7b4679bb8c5b2803-rootfs.mount: Succeeded.
Sep 01 23:35:29 u7s-usernetes-compute-001 kubelet[849]: I0901 23:35:29.938988     849 kubelet_node_status.go:493] "Fast updating node status as it just became ready"
Sep 01 23:35:30 u7s-usernetes-compute-001 kubelet[849]: I0901 23:35:30.322469     849 topology_manager.go:212] "Topology Admit Handler"
Sep 01 23:35:30 u7s-usernetes-compute-001 kubelet[849]: I0901 23:35:30.324183     849 topology_manager.go:212] "Topology Admit Handler"
Sep 01 23:35:30 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:35:30.349205061Z" level=info msg="shim disconnected" id=2818b6773cfddb6becfcc1df8a2c3aa1895cf00a1725c60b7b4679bb8c5b2803 namespace=k8s.io
Sep 01 23:35:30 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:35:30.349257527Z" level=warning msg="cleaning up after shim disconnected" id=2818b6773cfddb6becfcc1df8a2c3aa1895cf00a1725c60b7b4679bb8c5b2803 namespace=k8s.io
Sep 01 23:35:30 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:35:30.349266526Z" level=info msg="cleaning up dead shim" namespace=k8s.io
Sep 01 23:35:30 u7s-usernetes-compute-001 systemd[1]: Created slice libcontainer container kubepods-burstable-pod51c51727_e945_40cc_a869_c87abe4cffea.slice.
Sep 01 23:35:30 u7s-usernetes-compute-001 systemd[1]: Created slice libcontainer container kubepods-burstable-pod680d08a6_7bc2_441d_9a77_7c02e3e72ab6.slice.
Sep 01 23:35:30 u7s-usernetes-compute-001 kubelet[849]: I0901 23:35:30.392997     849 reconciler_common.go:258] "operationExecutor.VerifyControllerAttachedVolume started for volume \"config-volume\" (UniqueName: \"kubernetes.io/configmap/680d08a6-7bc2-441d-9a77-7c02e3e72ab6-config-volume\") pod \"coredns-5d78c9869d-v77lb\" (UID: \"680d08a6-7bc2-441d-9a77-7c02e3e72ab6\") " pod="kube-system/coredns-5d78c9869d-v77lb"
Sep 01 23:35:30 u7s-usernetes-compute-001 kubelet[849]: I0901 23:35:30.393060     849 reconciler_common.go:258] "operationExecutor.VerifyControllerAttachedVolume started for volume \"kube-api-access-7msrq\" (UniqueName: \"kubernetes.io/projected/51c51727-e945-40cc-a869-c87abe4cffea-kube-api-access-7msrq\") pod \"coredns-5d78c9869d-9b8f2\" (UID: \"51c51727-e945-40cc-a869-c87abe4cffea\") " pod="kube-system/coredns-5d78c9869d-9b8f2"
Sep 01 23:35:30 u7s-usernetes-compute-001 kubelet[849]: I0901 23:35:30.393132     849 reconciler_common.go:258] "operationExecutor.VerifyControllerAttachedVolume started for volume \"config-volume\" (UniqueName: \"kubernetes.io/configmap/51c51727-e945-40cc-a869-c87abe4cffea-config-volume\") pod \"coredns-5d78c9869d-9b8f2\" (UID: \"51c51727-e945-40cc-a869-c87abe4cffea\") " pod="kube-system/coredns-5d78c9869d-9b8f2"
Sep 01 23:35:30 u7s-usernetes-compute-001 kubelet[849]: I0901 23:35:30.393167     849 reconciler_common.go:258] "operationExecutor.VerifyControllerAttachedVolume started for volume \"kube-api-access-mq589\" (UniqueName: \"kubernetes.io/projected/680d08a6-7bc2-441d-9a77-7c02e3e72ab6-kube-api-access-mq589\") pod \"coredns-5d78c9869d-v77lb\" (UID: \"680d08a6-7bc2-441d-9a77-7c02e3e72ab6\") " pod="kube-system/coredns-5d78c9869d-v77lb"
Sep 01 23:35:30 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:35:30.652932408Z" level=info msg="RunPodSandbox for &PodSandboxMetadata{Name:coredns-5d78c9869d-9b8f2,Uid:51c51727-e945-40cc-a869-c87abe4cffea,Namespace:kube-system,Attempt:0,}"
Sep 01 23:35:30 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:35:30.654430581Z" level=info msg="RunPodSandbox for &PodSandboxMetadata{Name:coredns-5d78c9869d-v77lb,Uid:680d08a6-7bc2-441d-9a77-7c02e3e72ab6,Namespace:kube-system,Attempt:0,}"
Sep 01 23:35:30 u7s-usernetes-compute-001 systemd[1]: run-netns-cni\x2d7984e835\x2dfebd\x2d87fa\x2d49bb\x2de4752f2c1c13.mount: Succeeded.
Sep 01 23:35:30 u7s-usernetes-compute-001 systemd[1]: run-containerd-io.containerd.grpc.v1.cri-sandboxes-d2171ac4b11f7c0ed1c9b5b0b04760615beefe3953e90422cfa0fca83574b7ea-shm.mount: Succeeded.
Sep 01 23:35:30 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:35:30.674342908Z" level=error msg="RunPodSandbox for &PodSandboxMetadata{Name:coredns-5d78c9869d-9b8f2,Uid:51c51727-e945-40cc-a869-c87abe4cffea,Namespace:kube-system,Attempt:0,} failed, error" error="failed to setup network for sandbox \"d2171ac4b11f7c0ed1c9b5b0b04760615beefe3953e90422cfa0fca83574b7ea\": plugin type=\"flannel\" failed (add): loadFlannelSubnetEnv failed: open /run/flannel/subnet.env: no such file or directory"
Sep 01 23:35:30 u7s-usernetes-compute-001 kubelet[849]: E0901 23:35:30.674582     849 remote_runtime.go:176] "RunPodSandbox from runtime service failed" err="rpc error: code = Unknown desc = failed to setup network for sandbox \"d2171ac4b11f7c0ed1c9b5b0b04760615beefe3953e90422cfa0fca83574b7ea\": plugin type=\"flannel\" failed (add): loadFlannelSubnetEnv failed: open /run/flannel/subnet.env: no such file or directory"
Sep 01 23:35:30 u7s-usernetes-compute-001 kubelet[849]: E0901 23:35:30.674636     849 kuberuntime_sandbox.go:72] "Failed to create sandbox for pod" err="rpc error: code = Unknown desc = failed to setup network for sandbox \"d2171ac4b11f7c0ed1c9b5b0b04760615beefe3953e90422cfa0fca83574b7ea\": plugin type=\"flannel\" failed (add): loadFlannelSubnetEnv failed: open /run/flannel/subnet.env: no such file or directory" pod="kube-system/coredns-5d78c9869d-9b8f2"
Sep 01 23:35:30 u7s-usernetes-compute-001 kubelet[849]: E0901 23:35:30.674653     849 kuberuntime_manager.go:1122] "CreatePodSandbox for pod failed" err="rpc error: code = Unknown desc = failed to setup network for sandbox \"d2171ac4b11f7c0ed1c9b5b0b04760615beefe3953e90422cfa0fca83574b7ea\": plugin type=\"flannel\" failed (add): loadFlannelSubnetEnv failed: open /run/flannel/subnet.env: no such file or directory" pod="kube-system/coredns-5d78c9869d-9b8f2"
Sep 01 23:35:30 u7s-usernetes-compute-001 kubelet[849]: E0901 23:35:30.674698     849 pod_workers.go:1294] "Error syncing pod, skipping" err="failed to \"CreatePodSandbox\" for \"coredns-5d78c9869d-9b8f2_kube-system(51c51727-e945-40cc-a869-c87abe4cffea)\" with CreatePodSandboxError: \"Failed to create sandbox for pod \\\"coredns-5d78c9869d-9b8f2_kube-system(51c51727-e945-40cc-a869-c87abe4cffea)\\\": rpc error: code = Unknown desc = failed to setup network for sandbox \\\"d2171ac4b11f7c0ed1c9b5b0b04760615beefe3953e90422cfa0fca83574b7ea\\\": plugin type=\\\"flannel\\\" failed (add): loadFlannelSubnetEnv failed: open /run/flannel/subnet.env: no such file or directory\"" pod="kube-system/coredns-5d78c9869d-9b8f2" podUID=51c51727-e945-40cc-a869-c87abe4cffea
Sep 01 23:35:30 u7s-usernetes-compute-001 systemd[1]: run-netns-cni\x2d8773943f\x2d9244\x2dd50d\x2df414\x2da006b702b091.mount: Succeeded.
Sep 01 23:35:30 u7s-usernetes-compute-001 systemd[1]: run-containerd-io.containerd.grpc.v1.cri-sandboxes-7733d34d60cd2b48e2628ecc2646c2c9cece512921767ca8ac8fddc6e17e8ca9-shm.mount: Succeeded.
Sep 01 23:35:30 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:35:30.677930979Z" level=error msg="RunPodSandbox for &PodSandboxMetadata{Name:coredns-5d78c9869d-v77lb,Uid:680d08a6-7bc2-441d-9a77-7c02e3e72ab6,Namespace:kube-system,Attempt:0,} failed, error" error="failed to setup network for sandbox \"7733d34d60cd2b48e2628ecc2646c2c9cece512921767ca8ac8fddc6e17e8ca9\": plugin type=\"flannel\" failed (add): loadFlannelSubnetEnv failed: open /run/flannel/subnet.env: no such file or directory"
Sep 01 23:35:30 u7s-usernetes-compute-001 kubelet[849]: E0901 23:35:30.678123     849 remote_runtime.go:176] "RunPodSandbox from runtime service failed" err="rpc error: code = Unknown desc = failed to setup network for sandbox \"7733d34d60cd2b48e2628ecc2646c2c9cece512921767ca8ac8fddc6e17e8ca9\": plugin type=\"flannel\" failed (add): loadFlannelSubnetEnv failed: open /run/flannel/subnet.env: no such file or directory"
Sep 01 23:35:30 u7s-usernetes-compute-001 kubelet[849]: E0901 23:35:30.678161     849 kuberuntime_sandbox.go:72] "Failed to create sandbox for pod" err="rpc error: code = Unknown desc = failed to setup network for sandbox \"7733d34d60cd2b48e2628ecc2646c2c9cece512921767ca8ac8fddc6e17e8ca9\": plugin type=\"flannel\" failed (add): loadFlannelSubnetEnv failed: open /run/flannel/subnet.env: no such file or directory" pod="kube-system/coredns-5d78c9869d-v77lb"
Sep 01 23:35:30 u7s-usernetes-compute-001 kubelet[849]: E0901 23:35:30.678180     849 kuberuntime_manager.go:1122] "CreatePodSandbox for pod failed" err="rpc error: code = Unknown desc = failed to setup network for sandbox \"7733d34d60cd2b48e2628ecc2646c2c9cece512921767ca8ac8fddc6e17e8ca9\": plugin type=\"flannel\" failed (add): loadFlannelSubnetEnv failed: open /run/flannel/subnet.env: no such file or directory" pod="kube-system/coredns-5d78c9869d-v77lb"
Sep 01 23:35:30 u7s-usernetes-compute-001 kubelet[849]: E0901 23:35:30.678223     849 pod_workers.go:1294] "Error syncing pod, skipping" err="failed to \"CreatePodSandbox\" for \"coredns-5d78c9869d-v77lb_kube-system(680d08a6-7bc2-441d-9a77-7c02e3e72ab6)\" with CreatePodSandboxError: \"Failed to create sandbox for pod \\\"coredns-5d78c9869d-v77lb_kube-system(680d08a6-7bc2-441d-9a77-7c02e3e72ab6)\\\": rpc error: code = Unknown desc = failed to setup network for sandbox \\\"7733d34d60cd2b48e2628ecc2646c2c9cece512921767ca8ac8fddc6e17e8ca9\\\": plugin type=\\\"flannel\\\" failed (add): loadFlannelSubnetEnv failed: open /run/flannel/subnet.env: no such file or directory\"" pod="kube-system/coredns-5d78c9869d-v77lb" podUID=680d08a6-7bc2-441d-9a77-7c02e3e72ab6
Sep 01 23:35:31 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:35:31.154179866Z" level=info msg="CreateContainer within sandbox \"3c49bc8817885edf9b580bf92076a2ec413f2029838b38beefd42f42502134f3\" for container &ContainerMetadata{Name:kube-flannel,Attempt:0,}"
Sep 01 23:35:31 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:35:31.164795411Z" level=info msg="CreateContainer within sandbox \"3c49bc8817885edf9b580bf92076a2ec413f2029838b38beefd42f42502134f3\" for &ContainerMetadata{Name:kube-flannel,Attempt:0,} returns container id \"191f2cf170c5dbbf8916a6e183a96a28fd12f7b54f2228b84f12bf0d433e6978\""
Sep 01 23:35:31 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:35:31.165157731Z" level=info msg="StartContainer for \"191f2cf170c5dbbf8916a6e183a96a28fd12f7b54f2228b84f12bf0d433e6978\""
Sep 01 23:35:31 u7s-usernetes-compute-001 systemd[1]: Started libcontainer container 191f2cf170c5dbbf8916a6e183a96a28fd12f7b54f2228b84f12bf0d433e6978.
Sep 01 23:35:31 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:35:31.259785459Z" level=info msg="StartContainer for \"191f2cf170c5dbbf8916a6e183a96a28fd12f7b54f2228b84f12bf0d433e6978\" returns successfully"
Sep 01 23:35:32 u7s-usernetes-compute-001 kubelet[849]: I0901 23:35:32.164718     849 pod_startup_latency_tracker.go:102] "Observed pod startup duration" pod="kube-flannel/kube-flannel-ds-4dckq" podStartSLOduration=3.688063283 podCreationTimestamp="2023-09-01 23:35:21 +0000 UTC" firstStartedPulling="2023-09-01 23:35:22.267486813 +0000 UTC m=+16.229638231" lastFinishedPulling="2023-09-01 23:35:29.744100043 +0000 UTC m=+23.706251461" observedRunningTime="2023-09-01 23:35:32.164427302 +0000 UTC m=+26.126578727" watchObservedRunningTime="2023-09-01 23:35:32.164676513 +0000 UTC m=+26.126827939"
Sep 01 23:35:42 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:35:42.101622130Z" level=info msg="RunPodSandbox for &PodSandboxMetadata{Name:coredns-5d78c9869d-v77lb,Uid:680d08a6-7bc2-441d-9a77-7c02e3e72ab6,Namespace:kube-system,Attempt:0,}"
Sep 01 23:35:42 u7s-usernetes-compute-001 containerd[130]: map[string]interface {}{"cniVersion":"0.3.1", "hairpinMode":true, "ipMasq":false, "ipam":map[string]interface {}{"ranges":[][]map[string]interface {}{[]map[string]interface {}{map[string]interface {}{"subnet":"10.244.0.0/24"}}}, "routes":[]types.Route{types.Route{Dst:net.IPNet{IP:net.IP{0xa, 0xf4, 0x0, 0x0}, Mask:net.IPMask{0xff, 0xff, 0x0, 0x0}}, GW:net.IP(nil)}}, "type":"host-local"}, "isDefaultGateway":true, "isGateway":true, "mtu":(*uint)(0xc0000ae728), "name":"cbr0", "type":"bridge"}
Sep 01 23:35:42 u7s-usernetes-compute-001 containerd[130]: delegateAdd: netconf sent to delegate plugin:
Sep 01 23:35:42 u7s-usernetes-compute-001 containerd[130]: {"cniVersion":"0.3.1","hairpinMode":true,"ipMasq":false,"ipam":{"ranges":[[{"subnet":"10.244.0.0/24"}]],"routes":[{"dst":"10.244.0.0/16"}],"type":"host-local"},"isDefaultGateway":true,"isGateway":true,"mtu":1450,"name":"cbr0","type":"bridge"}time="2023-09-01T23:35:42.132876824Z" level=info msg="loading plugin \"io.containerd.internal.v1.shutdown\"..." runtime=io.containerd.runc.v2 type=io.containerd.internal.v1
Sep 01 23:35:42 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:35:42.132934805Z" level=info msg="loading plugin \"io.containerd.ttrpc.v1.pause\"..." runtime=io.containerd.runc.v2 type=io.containerd.ttrpc.v1
Sep 01 23:35:42 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:35:42.132946423Z" level=info msg="loading plugin \"io.containerd.event.v1.publisher\"..." runtime=io.containerd.runc.v2 type=io.containerd.event.v1
Sep 01 23:35:42 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:35:42.132953918Z" level=info msg="loading plugin \"io.containerd.ttrpc.v1.task\"..." runtime=io.containerd.runc.v2 type=io.containerd.ttrpc.v1
Sep 01 23:35:42 u7s-usernetes-compute-001 systemd[1]: Started libcontainer container e55c5213d4ade290c1e82e2f2a0dde17f85e84c092bb9882aa6e08cab7d99e33.
Sep 01 23:35:42 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:35:42.190404756Z" level=info msg="RunPodSandbox for &PodSandboxMetadata{Name:coredns-5d78c9869d-v77lb,Uid:680d08a6-7bc2-441d-9a77-7c02e3e72ab6,Namespace:kube-system,Attempt:0,} returns sandbox id \"e55c5213d4ade290c1e82e2f2a0dde17f85e84c092bb9882aa6e08cab7d99e33\""
Sep 01 23:35:42 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:35:42.192303649Z" level=info msg="CreateContainer within sandbox \"e55c5213d4ade290c1e82e2f2a0dde17f85e84c092bb9882aa6e08cab7d99e33\" for container &ContainerMetadata{Name:coredns,Attempt:0,}"
Sep 01 23:35:42 u7s-usernetes-compute-001 systemd[1]: var-lib-containerd-tmpmounts-containerd\x2dmount2629683163.mount: Succeeded.
Sep 01 23:35:42 u7s-usernetes-compute-001 systemd[1]: var-lib-containerd-tmpmounts-containerd\x2dmount894178282.mount: Succeeded.
Sep 01 23:35:42 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:35:42.455336099Z" level=info msg="CreateContainer within sandbox \"e55c5213d4ade290c1e82e2f2a0dde17f85e84c092bb9882aa6e08cab7d99e33\" for &ContainerMetadata{Name:coredns,Attempt:0,} returns container id \"493e66db675e4e46cf8af01e0dc70624781bb021d46a04d859720a32ba572d6e\""
Sep 01 23:35:42 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:35:42.455737526Z" level=info msg="StartContainer for \"493e66db675e4e46cf8af01e0dc70624781bb021d46a04d859720a32ba572d6e\""
Sep 01 23:35:42 u7s-usernetes-compute-001 systemd[1]: Started libcontainer container 493e66db675e4e46cf8af01e0dc70624781bb021d46a04d859720a32ba572d6e.
Sep 01 23:35:42 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:35:42.543430597Z" level=info msg="StartContainer for \"493e66db675e4e46cf8af01e0dc70624781bb021d46a04d859720a32ba572d6e\" returns successfully"
Sep 01 23:35:43 u7s-usernetes-compute-001 kubelet[849]: I0901 23:35:43.180993     849 pod_startup_latency_tracker.go:102] "Observed pod startup duration" pod="kube-system/coredns-5d78c9869d-v77lb" podStartSLOduration=22.180964165 podCreationTimestamp="2023-09-01 23:35:21 +0000 UTC" firstStartedPulling="0001-01-01 00:00:00 +0000 UTC" lastFinishedPulling="0001-01-01 00:00:00 +0000 UTC" observedRunningTime="2023-09-01 23:35:43.18051898 +0000 UTC m=+37.142670406" watchObservedRunningTime="2023-09-01 23:35:43.180964165 +0000 UTC m=+37.143115590"
Sep 01 23:35:44 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:35:44.101983257Z" level=info msg="RunPodSandbox for &PodSandboxMetadata{Name:coredns-5d78c9869d-9b8f2,Uid:51c51727-e945-40cc-a869-c87abe4cffea,Namespace:kube-system,Attempt:0,}"
Sep 01 23:35:44 u7s-usernetes-compute-001 containerd[130]: map[string]interface {}{"cniVersion":"0.3.1", "hairpinMode":true, "ipMasq":false, "ipam":map[string]interface {}{"ranges":[][]map[string]interface {}{[]map[string]interface {}{map[string]interface {}{"subnet":"10.244.0.0/24"}}}, "routes":[]types.Route{types.Route{Dst:net.IPNet{IP:net.IP{0xa, 0xf4, 0x0, 0x0}, Mask:net.IPMask{0xff, 0xff, 0x0, 0x0}}, GW:net.IP(nil)}}, "type":"host-local"}, "isDefaultGateway":true, "isGateway":true, "mtu":(*uint)(0xc0000187a8), "name":"cbr0", "type":"bridge"}
Sep 01 23:35:44 u7s-usernetes-compute-001 containerd[130]: delegateAdd: netconf sent to delegate plugin:
Sep 01 23:35:44 u7s-usernetes-compute-001 containerd[130]: {"cniVersion":"0.3.1","hairpinMode":true,"ipMasq":false,"ipam":{"ranges":[[{"subnet":"10.244.0.0/24"}]],"routes":[{"dst":"10.244.0.0/16"}],"type":"host-local"},"isDefaultGateway":true,"isGateway":true,"mtu":1450,"name":"cbr0","type":"bridge"}time="2023-09-01T23:35:44.136633077Z" level=info msg="loading plugin \"io.containerd.internal.v1.shutdown\"..." runtime=io.containerd.runc.v2 type=io.containerd.internal.v1
Sep 01 23:35:44 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:35:44.136692526Z" level=info msg="loading plugin \"io.containerd.ttrpc.v1.pause\"..." runtime=io.containerd.runc.v2 type=io.containerd.ttrpc.v1
Sep 01 23:35:44 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:35:44.136704826Z" level=info msg="loading plugin \"io.containerd.event.v1.publisher\"..." runtime=io.containerd.runc.v2 type=io.containerd.event.v1
Sep 01 23:35:44 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:35:44.136712310Z" level=info msg="loading plugin \"io.containerd.ttrpc.v1.task\"..." runtime=io.containerd.runc.v2 type=io.containerd.ttrpc.v1
Sep 01 23:35:44 u7s-usernetes-compute-001 systemd[1]: Started libcontainer container dfc5e54a3caa7998eff63b025901fbc5b9a270fdd2c65ab38ba2e50b7f36b27f.
Sep 01 23:35:44 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:35:44.202154076Z" level=info msg="RunPodSandbox for &PodSandboxMetadata{Name:coredns-5d78c9869d-9b8f2,Uid:51c51727-e945-40cc-a869-c87abe4cffea,Namespace:kube-system,Attempt:0,} returns sandbox id \"dfc5e54a3caa7998eff63b025901fbc5b9a270fdd2c65ab38ba2e50b7f36b27f\""
Sep 01 23:35:44 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:35:44.204127507Z" level=info msg="CreateContainer within sandbox \"dfc5e54a3caa7998eff63b025901fbc5b9a270fdd2c65ab38ba2e50b7f36b27f\" for container &ContainerMetadata{Name:coredns,Attempt:0,}"
Sep 01 23:35:44 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:35:44.215548980Z" level=info msg="CreateContainer within sandbox \"dfc5e54a3caa7998eff63b025901fbc5b9a270fdd2c65ab38ba2e50b7f36b27f\" for &ContainerMetadata{Name:coredns,Attempt:0,} returns container id \"7a56de15a8196fc9402cb486275a977ce389608cfc0b69b66fa791f5ec95f4fb\""
Sep 01 23:35:44 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:35:44.215911112Z" level=info msg="StartContainer for \"7a56de15a8196fc9402cb486275a977ce389608cfc0b69b66fa791f5ec95f4fb\""
Sep 01 23:35:44 u7s-usernetes-compute-001 systemd[1]: Started libcontainer container 7a56de15a8196fc9402cb486275a977ce389608cfc0b69b66fa791f5ec95f4fb.
Sep 01 23:35:44 u7s-usernetes-compute-001 containerd[130]: time="2023-09-01T23:35:44.311576674Z" level=info msg="StartContainer for \"7a56de15a8196fc9402cb486275a977ce389608cfc0b69b66fa791f5ec95f4fb\" returns successfully"
Sep 01 23:35:50 u7s-usernetes-compute-001 kubelet[849]: I0901 23:35:50.662086     849 pod_startup_latency_tracker.go:102] "Observed pod startup duration" pod="kube-system/coredns-5d78c9869d-9b8f2" podStartSLOduration=29.662056856 podCreationTimestamp="2023-09-01 23:35:21 +0000 UTC" firstStartedPulling="0001-01-01 00:00:00 +0000 UTC" lastFinishedPulling="0001-01-01 00:00:00 +0000 UTC" observedRunningTime="2023-09-01 23:35:45.184138963 +0000 UTC m=+39.146290389" watchObservedRunningTime="2023-09-01 23:35:50.662056856 +0000 UTC m=+44.624208280"
```

</details>

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
