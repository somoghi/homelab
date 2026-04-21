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

ephemeral "vault_kv_secret_v2" "proxmox_creds" {
  mount = "secret"
  name  = "proxmox/api_token"
}
resource "proxmox_virtual_environment_file" "qemu_user_data" {
  content_type = "snippets"
  datastore_id = "local" # Must have 'snippets' enabled in gui
  node_name    = "pve-mini"

  source_raw {
    data = <<EOF
#cloud-config
package_update: true
package_upgrade: true

# Install QEMU agent
packages:
  - qemu-guest-agent

runcmd:
  - systemctl enable --now qemu-guest-agent
EOF

    file_name = "qemu-cloud-config.yaml"
  }
}
provider "proxmox" {
  insecure = true

  endpoint  = "https://10.0.10.10:8006"
  api_token = ephemeral.vault_kv_secret_v2.proxmox_creds.data["token"]

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

# Provision the Control Node
resource "proxmox_virtual_environment_vm" "green_k3s-ctrl" {
  name        = "k3s-ctrl"
  description = "Debian 13 - k3s Control Node"
  tags        = ["compute", "k3s", "control"]

  node_name = "pve-mini"
  vm_id     = 700

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
    file_id      = "local:import/trixie-server-cloudimg-amd64.qcow2" # Image should already exist if Vault or Docker VMs are set up first.
    interface    = "scsi0"
    size         = 20
    discard      = "on"
  }

  network_device {
    bridge  = "vmbr0"
    vlan_id = 20
  }

  initialization {
    ip_config {
      ipv4 {
        address = "10.0.20.70/24"
        gateway = "10.0.20.1"
      }
    }

    user_account {
      username = "ansible"
      keys     = [var.ansible_ssh_public_key]
    }

    vendor_data_file_id = proxmox_virtual_environment_file.qemu_user_data.id
  }
}

# Provision Worker Node 1
resource "proxmox_virtual_environment_vm" "green_k3s-node-1" {
  name        = "k3s-node-1"
  description = "Debian 13 - k3s Worker Node 1"
  tags        = ["compute", "k3s", "node"]

  node_name = "pve-mini"
  vm_id     = 710

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
    file_id      = "local:import/trixie-server-cloudimg-amd64.qcow2"
    interface    = "scsi0"
    size         = 20
    discard      = "on"
  }

  network_device {
    bridge  = "vmbr0"
    vlan_id = 20
  }

  initialization {
    ip_config {
      ipv4 {
        address = "10.0.20.71/24"
        gateway = "10.0.20.1"
      }
    }

    user_account {
      username = "ansible"
      keys     = [var.ansible_ssh_public_key]
    }

    vendor_data_file_id = proxmox_virtual_environment_file.qemu_user_data.id
  }
}

# Privision Worker Node 2
resource "proxmox_virtual_environment_vm" "green_k3s-node-2" {
  name        = "k3s-node-2"
  description = "Debian 13 - k3s Worker Node 2"
  tags        = ["compute", "k3s", "node"]

  node_name = "pve-mini"
  vm_id     = 720

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
    file_id      = "local:import/trixie-server-cloudimg-amd64.qcow2"
    interface    = "scsi0"
    size         = 20
    discard      = "on"
  }

  network_device {
    bridge  = "vmbr0"
    vlan_id = 20
  }

  initialization {
    ip_config {
      ipv4 {
        address = "10.0.20.72/24"
        gateway = "10.0.20.1"
      }
    }

    user_account {
      username = "ansible"
      keys     = [var.ansible_ssh_public_key]
    }

    vendor_data_file_id = proxmox_virtual_environment_file.qemu_user_data.id
  }
}

output "green_k3s_ctrl_ip" {
  value = "10.0.20.70"
}

output "green_k3s_w1_ip" {
  value = "10.0.20.71"
}

output "green_k3s_w2_ip" {
  value = "10.0.20.72"
}
