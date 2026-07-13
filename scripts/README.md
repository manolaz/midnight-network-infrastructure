# Midnight Network FNO Setup Scripts

This directory contains automated scripts and Ansible playbooks to set up Cardano and Midnight nodes for Federated Node Operators (FNOs), focusing on the Preprod network.

## Scripts Overview

### Cardano & Dependencies

1. **`install_cardano_preprod.sh`**
   - **Purpose:** Automates the complete setup of the Cardano Preprod Availability node.
   - **Actions:**
     - Installs Mithril tooling and downloads the latest snapshot to accelerate syncing.
     - Downloads, extracts, and configures `cardano-node` and sets it up as a systemd service.
     - Installs PostgreSQL 17, initializes the `cexplorer` database, configures the `midnight` user role, and applies Postgres performance tuning for a Preprod node.
     - Installs `cardano-db-sync` and configures it to run as a systemd service connecting to the local `cardano-node`.
   - **Usage:** `./install_cardano_preprod.sh`

### Midnight Validator & Node Setup

2. **`install_midnight_archive_node.sh`**
   - **Purpose:** Automates the setup of an Archive Node for the Midnight networks.
   - **Actions:** Uses Ansible (`setup_node.yml`) to provision the entire stack, running the Midnight node with `--pruning archive` to keep historical states and exposing RPC.
   - **Usage:** `sudo ./install_midnight_archive_node.sh [NETWORK]`

3. **`install_midnight_full_node.sh`**
   - **Purpose:** Automates the setup of a Full Node for the Midnight networks.
   - **Actions:** Uses Ansible (`setup_full_node.yml`) to provision the entire stack, running the Midnight node efficiently without archive pruning (using `--pool-limit 35`) and without public RPC, suitable for validation and DApp development.
   - **Usage:** `sudo ./install_midnight_full_node.sh [NETWORK]`

4. **`install_midnight_validator.sh`**
   - **Purpose:** Automates the initial setup and key generation for a Midnight Validator Node.
   - **Actions:**
     - Downloads and installs the `midnight-node` binary (v0.22.2).
     - Generates the required session keys (`aura`, `grandpa`, `cross_chain`).
     - Generates the Node Identity Network Key (`secret_ed25519`).
     - Inserts the session keys into the local keystore.
     - Generates the `partner-chains-public-keys.json` file required for FNO registration.
   - **Usage:** `./install_midnight_validator.sh [NETWORK]` (Defaults to `preprod`)

5. **`configure_midnight_validator.sh`**
   - **Purpose:** Configures the environment and systemd service for running the Midnight node in Validator mode.
   - **Actions:**
     - Interactively prompts for the PostgreSQL password (or reads from `$POSTGRES_PASSWORD`).
     - Creates the `.env` file holding database credentials and keystore paths.
     - Validates PostgreSQL connectivity.
     - Creates and starts the `/etc/systemd/system/midnight-node.service` specifically tuned for validation (`--validator` flag).
   - **Usage:** `sudo ./configure_midnight_validator.sh [NETWORK] [NODE_NAME]`

### Key Management Integrations

These scripts safely backup your generated validator keys to enterprise secret managers.

6. **`store_keys_aws.sh`**
   - **Purpose:** Uploads the node's session and network keys to AWS Secrets Manager.
   - **Requires:** `aws-cli` configured. Uses `$AWS_REGION` (defaults to `us-east-1`).
   - **Usage:** `./store_keys_aws.sh [NETWORK]`

7. **`store_keys_gcp.sh`**
   - **Purpose:** Uploads keys to Google Cloud Secret Manager.
   - **Requires:** `$GOOGLE_CLOUD_PROJECT` environment variable and authenticated `gcloud` CLI.
   - **Usage:** `./store_keys_gcp.sh [NETWORK]`

8. **`store_keys_vault.sh`**
   - **Purpose:** Uploads keys to HashiCorp Vault.
   - **Requires:** `vault` CLI. Uses `$VAULT_ADDR` (defaults to local).
   - **Usage:** `./store_keys_vault.sh [NETWORK]`

### Secure Networking (WireGuard)

9. **`install_wireguard.sh`**
   - **Purpose:** Compiles WireGuard tools from source to meet Midnight's exact version requirements.
   - **Actions:** Installs `v1.0.20250521` and generates the Tunnel Identity Keypair (`privatekey`, `publickey`).
   - **Usage:** `./install_wireguard.sh`

10. **`configure_wireguard.sh`**
   - **Purpose:** Sets up the WireGuard tunnel interface once the foundation provides overlay assignments.
   - **Actions:** Prompts for assigned IP and peer variables, creates `/etc/wireguard/wg0.conf`, and enables the `wg-quick@wg0` service.
   - **Usage:** `sudo ./configure_wireguard.sh`

---

## Ansible Playbooks

In addition to the bash scripts, a declarative approach is provided using Ansible.

### `setup_validator_node.yml`
An Ansible playbook that achieves the same result as `configure_midnight_validator.sh`.
- **Role:** `midnight_validator`
- **Actions:** Downloads binaries, templates the `.env` file, and configures the systemd service.
- **Usage:** 
  ```bash
  ansible-playbook -i localhost, -c local ansible/setup_validator_node.yml --extra-vars "network=preprod postgres_password=your_password"
  ```