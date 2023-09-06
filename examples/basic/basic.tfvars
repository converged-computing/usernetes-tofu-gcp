# project_id, network_name, and region / zone are provided in Makefile

# Note that the name_prefix + instances determines the size of the cluster
# E.g., below would deploy usernetes-compute-[001-003]

# This builds from the ../../build-images directory
compute_family = "usernetes-ubuntu-jammy-x86-64"
compute_node_specs = [
  {
    name_prefix  = "usernetes-compute"
    machine_arch = "x86-64"
    machine_type = "c2-standard-16"
    gpu_type     = null
    gpu_count    = 0
    compact      = false
    instances    = 3
    properties   = []
    boot_script  = <<BOOT_SCRIPT
#!/bin/bash

# Setup nfs home
mkdir -p /var/nfs/home
chown nobody:nobody /var/nfs/home

ip_addr=$(hostname -I)

echo "/var/nfs/home *(rw,no_subtree_check,no_root_squash)" >> /etc/exports

firewall-cmd --add-service={nfs,nfs3,mountd,rpc-bind} --permanent
firewall-cmd --reload

systemctl enable --now nfs-server rpcbind

# This enables NFS
nfsmounts=$(curl "http://metadata.google.internal/computeMetadata/v1/instance/attributes/nfs-mounts" -H "Metadata-Flavor: Google")

if [[ "X$nfsmounts" != "X" ]]; then
    echo "Enabling NFS mounts"
    share=$(echo $nfsmounts | jq -r '.share')
    mountpoint=$(echo $nfsmounts | jq -r '.mountpoint')
    bash -c "sudo echo $share $mountpoint nfs defaults,hard,intr,_netdev 0 0 >> /etc/fstab"
    mount -a
fi
BOOT_SCRIPT
  },
]
compute_scopes = ["cloud-platform"]
