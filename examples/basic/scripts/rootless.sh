#!/bin/bash

# sudo systemctl enable docker
# sudo systemctl start docker

# Sometimes it tells me things aren't installed, not sure why
sudo apt-get update && sudo apt-get install -y uidmap systemd

# This didn't seem to be enabled
# cat /sys/fs/cgroup/user.slice/user-$(id -u).slice/user@$(id -u).service/cgroup.controllers
sudo mkdir -p /etc/systemd/system/user@.service.d
cat <<EOF | sudo tee /etc/systemd/system/user@.service.d/delegate.conf
[Service]
Delegate=cpu cpuset io memory pids
EOF
sudo systemctl daemon-reload
cat /sys/fs/cgroup/user.slice/user-$(id -u).slice/user@$(id -u).service/cgroup.controllers
# cpuset cpu io memory pids

# Install rootless docker (initial steps done in base image)
sudo loginctl enable-linger $(whoami)
dockerd-rootless-setuptool.sh install

# TODO we need to install rootless docker, I found I could do on one node and
# the others would have issues, so I'm sticking with regular docker for now :)
# WARNING: systemd not found. You have to remove XDG_RUNTIME_DIR manually on every logout.
# echo "export XDG_RUNTIME_DIR=/home/sochat1_llnl_gov/.docker/run" >> ~/.bashrc
echo "export PATH=/usr/bin:$PATH" >> ~/.bashrc
echo "export DOCKER_HOST=unix://${XDG_RUNTIME_DIR}/docker.sock" >> ~/.bashrc

# echo "export DOCKER_HOST=unix:///home/sochat1_llnl_gov/.docker/run/docker.sock" >> ~/.bashrc
# kernel modules
sudo modprobe vxlan
sudo systemctl daemon-reload
docker run hello-world
sudo loginctl enable-linger $(whoami)
