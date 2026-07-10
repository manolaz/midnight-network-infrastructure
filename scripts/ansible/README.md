# Ansible Configuration Management

This directory contains the Ansible playbooks and roles designed to idempotently configure a Full Node Operator (FNO) for the Midnight Network.

## Architecture

The automation is split into distinct, modular roles to ensure clean separation of concerns and maintainability.

*   **`common`**: Prepares the base OS. Installs required system dependencies (like `curl`, `wget`, `jq`), configures system limits, and sets up the dedicated `midnight` service user.
*   **`postgres`**: Installs PostgreSQL 17, applies optimal database tuning configurations for heavy block-syncing workloads, and sets up the required user/database schemas.
*   **`cardano_node`**: Deploys the Cardano Relay node. Crucially, this role integrates the Mithril client to rapidly download the latest snapshot, saving weeks of sync time.
*   **`cardano_db_sync`**: Deploys the Cardano DB Sync process, establishing the connection between the synced Cardano node and PostgreSQL.
*   **`midnight_node`**: Finally, bootstraps the Midnight Substrate runtime, configures the environment variables, sets it to `--pruning archive`, and registers it as a `systemd` service.

## Prerequisites

- [Ansible](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html) (>= 2.14).
- Target hosts must be running a compatible Debian-based OS (Ubuntu 22.04 recommended).
- SSH access to the target hosts with `sudo` privileges.

## Configuration

### 1. Inventory

Update the `inventory/hosts.ini` file with the IP addresses or hostnames of your target servers.

```ini
[midnight_nodes]
192.168.1.100 ansible_user=ubuntu
```

### 2. Variables

The target network can be easily toggled. Supported networks are:
- `preview`
- `preprod` (Default)
- `mainnet`

The database password defaults to `YOUR_POSTGRES_PASSWORD` in `setup_node.yml`. It is highly recommended to override this securely (e.g., using Ansible Vault) for production environments.

## Usage

Run the main setup playbook, specifying the target environment via `extra-vars`:

```bash
# To provision a Pre-Production node:
ansible-playbook -i inventory/hosts.ini setup_node.yml --extra-vars "network=preprod"

# To provision a Preview node:
ansible-playbook -i inventory/hosts.ini setup_node.yml --extra-vars "network=preview"
```

## Systemd Services

Once the playbook completes, the following `systemd` services will be active on the host:
- `cardano-node.service`
- `cardano-db-sync.service`
- `midnight-node.service`

You can monitor their status on the target machine via:
```bash
journalctl -u midnight-node.service -f
```