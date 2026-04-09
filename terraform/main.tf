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

  skip_child_token = true # Not needed because of strict ttl rules in place already
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

provider "proxmox" {
  insecure = true

  endpoint  = "https://10.0.10.10:8006"
  api_token = data.vault_kv_secret_v2.proxmox_creds.data["token"]

  ssh {
    agent    = true
    username = "root"
  }
}
# actual pubkey read from ansible.tfvars
variable "ansible_ssh_public_key" {
  type        = string
  description = "The public SSH key for the Ansible control node"
}

resource "proxmox_virtual_environment_vm" "vault_server" {
  name        = "vault-server-01"
  description = "HashiCorp Vault - Secrets Management"
  tags        = ["infrastructure", "security", "vault"]

  node_name = "pve-mini"
  vm_id     = 800

  agent {
    enabled = true
  }

  cpu {
    cores = 2
    type  = "x86-64-v2-AES"
  }

  memory {
    dedicated = 2048
  }

  disk {
    datastore_id = "local-lvm"
    file_id      = proxmox_download_file.ubuntu_cloud_image.id
    interface    = "scsi0"
    size         = 20
  }

  network_device {
    bridge  = "vmbr0"
    vlan_id = 20
  }

  initialization {
    ip_config {
      ipv4 {
        address = "10.0.20.100/24"
        gateway = "10.0.20.1"
      }
    }
    user_account {
      username = "ansible"
      keys     = [var.ansible_ssh_public_key]
    }
  }
}
output "vault_ip_address" {
  value = "10.0.20.100"
}

resource "proxmox_download_file" "ubuntu_cloud_image" {
  content_type = "import"
  datastore_id = "local"
  node_name    = "pve-mini"
  url          = "https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
  file_name    = "noble-server-cloudimg-amd64.qcow2"
}
