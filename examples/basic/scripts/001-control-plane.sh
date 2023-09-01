#!/bin/bash
set -euo pipefail

# This should not work if docker is not setup
docker run hello-world

# Since we need to have usernetes built with different make commands, to be
# safe let's clone to a non-shared space.
sudo chown -R $USER /opt

# This is the generation 2 branch. This will fail if you run twice (and it should)
git clone -b g2 https://github.com/AkihiroSuda/usernetes /opt/usernetes
echo "Contents of /opt/usernetes"
ls /opt/usernetes
cd /opt/usernetes

# Now let's go there and try running the make command. This first example will
# bootstrap usernetes right here, and I think only need this one node.

# Bootstrap a cluster and install flannel, prepare kubeconfig
# Note the second command has a warning about socat, but I see it on the path
make up
make kubeadm-init
make install-flannel
make kubeconfig

# This is assumed to be in /opt/usernetes
export KUBECONFIG=$(pwd)/kubeconfig

# And finally, install and enable kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x ./kubectl
sudo mv ./kubectl /usr/bin/kubectl

# Note this is run from /opt/usernetes.
export KUBECONFIG=/opt/usernetes/kubeconfig
kubectl get pods -A

# Make the join command from the control plane
# This copies to the shared user home
make join-command
cp ./join-command ~/

# Ensure we keep the kubectl path
echo "export KUBECONFIG=/opt/usernetes/kubeconfig" >> ~/.bashrc

# Debug
# make logs
# make shell
# make down-v
# kubectl taint nodes --all node-role.kubernetes.io/control-plane-
