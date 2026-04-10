# Terraform initial config

The initial configuration for setting up a security-first IaC infrastructure.
The directory structure is as follows:

- `foundation/`

> Contains configuration for the HashiCorp Vault VM so far.
> This should offer better isolation for credential storage across the entire homelab.

- `vms/` contains the configuration for all other VMs that operate inside the hoemlab.

>At the moment, it will contain the main Docker host, HomeAssistant,
and Traefik which will server as ingress.

- (*NOT IN VERSION CONTROL*) `.terraform.d/` contains the plugin cache.

## Auxiliary files

- `.terraformrc`

> Contains the configuration for the CLI.
> Currently specifies which directory to use for the plugin cache.
