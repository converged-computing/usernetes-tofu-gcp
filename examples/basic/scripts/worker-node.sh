#!/bin/bash
set -euo pipefail

# This should not work if docker is not setup
docker run hello-world

# Install usernetes again
sudo chown -R $USER /opt

# Adding this in unecessary places...
sudo loginctl enable-linger $(whoami)

# And finally, install and enable kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x ./kubectl
sudo mv ./kubectl /usr/bin/kubectl

# git clone -b g2 https://github.com/AkihiroSuda/usernetes /opt/usernetes
git clone https://github.com/rootless-containers/usernetes /opt/usernetes

ls /opt/usernetes
cd /opt/usernetes

# Note that "join-command" is hard coded into the Makefile, and expected to be there
# This needs to be run first so it's in our user home
cp ~/join-command /opt/usernetes/join-command

# This didn't work the first time?
make -C /opt/usernetes up kubeadm-join || make -C /opt/usernetes up kubeadm-join
sudo loginctl enable-linger $(whoami)
