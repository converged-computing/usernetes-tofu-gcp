# Generate a packer build for an AMI (Amazon Image)

packer {
  required_plugins {
    googlecompute = {
      version = ">= 1.1.1"
      source  = "github.com/hashicorp/googlecompute"
    }
  }
}

variable "enable_secure_boot" {
  type    = bool
  default = true
}

variable "machine_architecture" {
  type    = string
  default = "x86-64"
}

variable "machine_type" {
  type    = string
  default = "c2-standard-16"
}

variable "project_id" {
  type    = string
  default = "llnl-flux"
}

# $ gcloud compute images list --project=debian-cloud --no-standard-images
variable "source_image" {
  type    = string
  default = "ubuntu-2204-jammy-v20230727"
}

variable "source_image_project_id" {
  type    = string
  default = "ubuntu-os-cloud"
}

variable "subnetwork" {
  type    = string
  default = "default"
}

variable "zone" {
  type    = string
  default = "us-central1-a"
}

# "timestamp" template function replacement for image naming
# This is so us of the future can remember when images were built
locals { timestamp = regex_replace(timestamp(), "[- TZ:]", "") }

source "googlecompute" "usernetes-ubuntu" {
  project_id              = var.project_id
  source_image            = var.source_image
  source_image_project_id = [var.source_image_project_id]
  zone                    = var.zone
  image_name              = "usernetes-ubuntu-jammy-${var.machine_architecture}-v{{timestamp}}"
  image_family            = "usernetes-ubuntu-jammy-${var.machine_architecture}"
  image_description       = "usernetes-ubuntu-jammy"
  machine_type            = var.machine_type
  disk_size               = 256
  subnetwork              = var.subnetwork
  tags                    = ["packer", "usernetes", "ubuntu", "${var.machine_architecture}"]
  startup_script_file     = "startup-script.sh"
  ssh_username            = "user"
  enable_secure_boot      = var.enable_secure_boot
}

build {
  sources = ["sources.googlecompute.usernetes-ubuntu"]
}
