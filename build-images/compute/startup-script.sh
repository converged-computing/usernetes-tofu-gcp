#!/bin/bash

# Note that I'm erring on installing too many things, a lot of these are flux deps
# and I figure we might eventually want or need. This could be cleaned up further.
export DEBIAN_FRONTEND=noninteractive

# This first section from src/test/docker/bionic/Dockerfile in flux-core
# https://github.com/flux-framework/flux-core/blob/master/src/test/docker/bionic/Dockerfile
apt-get update && \
    apt-get -qq install -y --no-install-recommends \
    apt-utils nfs-kernel-server nfs-common firewalld && \
    rm -rf /var/lib/apt/lists/*

# Debian free firmware
# echo "deb http://deb.debian.org/debian bookworm main contrib non-free non-free-firmware" >> /etc/apt/sources.list
# echo "deb-src http://deb.debian.org/debian bookworm main contrib non-free non-free-firmware" >> /etc/apt/sources.list
# echo "deb http://deb.debian.org/debian-security bookworm-security main contrib non-free non-free-firmware" >> /etc/apt/sources.list
# echo "deb-src http://deb.debian.org/debian-security bookworm-security main contrib non-free non-free-firmware" >> /etc/apt/sources.list
# echo "deb http://deb.debian.org/debian bookworm-updates main contrib non-free non-free-firmware" >> /etc/apt/sources.list
# echo "deb-src http://deb.debian.org/debian bookworm-updates main contrib non-free non-free-firmware" >> /etc/apt/sources.list

# apt-get update
# apt-get install -y firmware-iwlwifi firmware-amd-graphics firmware-misc-nonfree

# Update grub
cat /etc/default/grub | grep GRUB_CMDLINE_LINUX=
GRUB_CMDLINE_LINUX=""
sed -i -e 's/^GRUB_CMDLINE_LINUX=""/GRUB_CMDLINE_LINUX="systemd.unified_cgroup_hierarchy=1"/' /etc/default/grub
update-grub

# Install fuse
apt-get update && apt-get install -y fuse

export GCSFUSE_REPO=gcsfuse-`lsb_release -c -s`
echo "deb https://packages.cloud.google.com/apt $GCSFUSE_REPO main" | tee /etc/apt/sources.list.d/gcsfuse.list
curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
apt-get update
apt-get install gcsfuse

# Utilities
apt-get update && \
    apt-get -qq install -y --no-install-recommends \
        locales \
        ca-certificates \
        socat \
        wget \
        man \
        git \
        flex \
        ssh \
        sudo \
        vim \
        lcov \
        ccache \
        lua5.2 \
        jq && \
    rm -rf /var/lib/apt/lists/*

# Compilers, autotools
apt-get update && \
    apt-get -qq install -y --no-install-recommends \
        build-essential \
        pkg-config \
        autotools-dev \
        libtool \
        autoconf \
        automake \
        make \
        cmake \
        clang \
        clang-tidy \
        gcc g++ && \
    rm -rf /var/lib/apt/lists/*

# Python
# NOTE: sudo pip install is necessary to get differentiated installations of
# python binary components for multiple python3 variants, --ignore-installed
# makes it ignore local versions of the packages if your home directory is
# mapped into the container and contains the same libraries
apt-get update && \
    apt-get -qq install -y --no-install-recommends \
	libffi-dev \
        python3-dev \
        python3-pip \
        python3-setuptools \
        python3-wheel \
        python3-markupsafe \
        python3-coverage \
        python3-cffi \
        python3-ply \
        python3-six \
        python3-jsonschema \
        python3-sphinx \
        python3-yaml && \
    rm -rf /var/lib/apt/lists/*

# Other deps
apt-get update && \
    apt-get -qq install -y --no-install-recommends \
        libsodium-dev \
        libzmq3-dev \
        libczmq-dev \
        libjansson-dev \
        libmunge-dev \
        libncursesw5-dev \
        liblua5.2-dev \
        liblz4-dev \
        libsqlite3-dev \
        uuid-dev \
        libhwloc-dev \
        libmpich-dev \
        libs3-dev \
        libevent-dev \
        libarchive-dev \
        libpam-dev && \
    rm -rf /var/lib/apt/lists/*

# install docker
apt-get update && apt-get install ca-certificates curl gnupg
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

echo \
   "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
   "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
   tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update
apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
docker run hello-world

locale-gen en_US.UTF-8
systemctl enable nfs-server
