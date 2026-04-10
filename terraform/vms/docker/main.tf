terraform {
  required_version = ">= 1.5.0"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.100.0"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "~> 5.8.0"
    }
  }

}
variable "vault_role_id" {
  type        = string
  description = "RoleID for the Terraform AppRole"
}

variable "vault_secret_id" {
  type        = string
  description = "SecretID for the Terraform AppRole"
  sensitive   = true
}

provider "vault" {
  address         = "http://10.0.20.100:8200"
  skip_tls_verify = true

  skip_child_token = true # Not needed because of strict ttl rules
  auth_login {
    path = "auth/approle/login"
    parameters = {
      role_id   = var.vault_role_id
      secret_id = var.vault_secret_id
    }
  }
}

data "vault_kv_secret_v2" "proxmox_creds" {
  mount = "secret"
  name  = "proxmox/api_token"
}
resource "proxmox_virtual_environment_file" "docker_user_data" {
  content_type = "snippets"
  datastore_id = "local" # Must have 'snippets' enabled in gui
  node_name    = "pve-mini"

  source_raw {
    data = <<EOF
#cloud-config
package_update: true
package_upgrade: true

# Install QEMU agent, Docker, and Docker Compose immediately
packages:
  - qemu-guest-agent
  - docker.io
  - docker-compose-v2

runcmd:
  - systemctl enable --now qemu-guest-agent
  - systemctl enable --now docker
  # - usermod -aG docker ansible
  # This might not be necessary if 'become = true'
EOF

    file_name = "docker-cloud-config.yaml"
  }
}

# Provision the Debian VM
resource "proxmox_virtual_environment_vm" "docker_host" {
  name        = "docker-host-01"
  description = "Debian 13 - Main Docker Host"
  tags        = ["compute", "docker"]

  node_name = "pve"
  vm_id     = 500

  agent {
    enabled = true
  }

  cpu {
    cores = 4
    type  = "x86-64-v2-AES"
  }

  memory {
    dedicated = 4096
  }

  disk {
    datastore_id = "local-lvm"
    file_id      = proxmox_download_file.debian_cloud_image.id
    interface    = "scsi0"
    size         = 40
  }

  network_device {
    bridge  = "vmbr0"
    vlan_id = 20
  }

  initialization {
    ip_config {
      ipv4 {
        address = "10.0.20.60/24"
        gateway = "10.0.20.1"
      }
    }

    user_account {
      username = "ansible"
      keys     = [var.ansible_ssh_public_key]
    }

    user_data_file_id = proxmox_virtual_environment_file.docker_user_data.id
  }
}

output "docker_ip_address" {
  value = "10.0.20.60"
}

resource "proxmox_download_file" "debian_cloud_image" {
  content_type = "import"
  datastore_id = "local"
  node_name    = "pve-mini"
  url          = "https://cloud.debian.org/images/cloud/trixie/latest/debian-13-generic-amd64.qcow2"
  file_name    = "noble-server-cloudimg-amd64.qcow2"
}
