module "cluster" {
  source = "../../tf"
  # source     = "github.com/converged-computing/usernetes-tofu-gcp//tf"
  project_id = var.project_id
  region     = var.region

  service_account_emails = {
    manager = data.google_compute_default_service_account.default.email
    login   = data.google_compute_default_service_account.default.email
    compute = data.google_compute_default_service_account.default.email
  }

  subnetwork = module.network.subnets_self_links[0]
  # Modified from /home because rootless docker needs to be isolated using home 
  # See https://github.com/rootless-containers/usernetes/pull/287#issuecomment-1707454442 
  # for another idea. Also - this won't currently work, would need to update base image exports
  cluster_storage = {
    mountpoint = "/work"
    share      = "${module.nfs_server_instance.instances_details.0.network_interface.0.network_ip}:/var/nfs/home"
  }
  compute_node_specs = var.compute_node_specs
  compute_scopes     = var.compute_scopes
  family             = var.compute_family
}
