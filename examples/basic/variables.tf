variable "compute_node_specs" {
  description = "A list of compute node specifications"
  type = list(object({
    name_prefix  = string
    machine_arch = string
    machine_type = string
    gpu_type     = string
    gpu_count    = number
    compact      = bool
    instances    = number
    properties   = set(string)
    boot_script  = string
  }))
  default = []
}

variable "compute_scopes" {
  description = "The set of access scopes for compute node instances"
  default     = ["cloud-platform"]
  type        = set(string)
}

variable "munge_key" {
  description = "A custom munge key"
  type        = string
  default     = ""
  nullable    = true
}

variable "network_name" {
  type = string
}

variable "nfs_prefix" {
  type    = string
  default = "nfs"
}

variable "nfs_size" {
  type    = number
  default = 512
}

variable "project_id" {
  description = "The GCP project ID"
  type        = string
}


variable "region" {
  description = "The GCP region where the cluster resides"
  type        = string
}

variable "ssh_source_ranges" {
  description = "List of CIDR ranges from which SSH connections are accepted"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "subnet_ip" {
  description = "CIDR for the network subnet"
  type        = string
  default     = "10.10.0.0/18"
}

variable "zone" {
  type = string
}

variable "compute_family" {
  description = "The source image x86 prefix to be used by the compute node(s)"
  type        = string
  default     = "flux-fw-compute-x86-64"
}
