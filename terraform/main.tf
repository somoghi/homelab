terraform {
  required_version = ">= 1.5.0"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.100.0"
    }
  }
}

provider "proxmox" {
  insecure = true 
  # Get secrets from terminal
  # export PROXMOX_VE_ENDPOINT=...
  # export PROXMOX_VE_API_TOKEN=...

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
    file_id      = proxmox_virtual_environment_download_file.ubuntu_cloud_image.id
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
    output "vault_ip_address" {
        value       = "192.168.1.50"
    }
  }
}
resource "proxmox_virtual_environment_download_file" "ubuntu_cloud_image" {
    content_type = "import"
    datastore_id = "local"
    node_name    = "pve"
    url          = "https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
    file_name = "noble-server-cloudimg-amd64.qcow2"
}
