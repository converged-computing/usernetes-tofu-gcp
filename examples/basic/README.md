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

Okay - so I think this is changing usernetes to use docker, and the next step is to work backwards and do rootless.
Actually, we likely want to clarify with Akihiro that this is not rootless, and then test this out fully and give him feedback.
We will want to run the delegate script (and maybe before the above):

```bash
for i in 1 2 3; do
  instance=usernetes-compute-00${i}
  gcloud compute ssh $instance --zone us-central1-a -- /bin/bash /home/sochat1_llnl_gov/scripts/delegate.sh
done
```

And then next steps for usernetes. Not done yet, but this is great!!

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
