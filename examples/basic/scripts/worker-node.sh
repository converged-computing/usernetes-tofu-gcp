#!/bin/bash
set -euo pipefail

# This should not work if docker is not setup
docker run hello-world

# Install usernetes again
sudo chown -R $USER /opt
git clone -b g2 https://github.com/AkihiroSuda/usernetes /opt/usernetes
ls /opt/usernetes
cd /opt/usernetes

# Note that "join-command" is hard coded into the Makefile, and expected to be there
# This needs to be run first so it's in our user home
cp ~/join-command /opt/usernetes/join-command

# This didn't work the first time?
make -C /opt/usernetes up kubeadm-join || make -C /opt/usernetes up kubeadm-join
