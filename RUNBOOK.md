# Runbook for Midnight Network Infrastructure

## Section 1: FNO (Full Node Operator) Onboarding Steps

### Prerequisites
- Access to a Linux-based server (x86-64/amd64 architecture, Ubuntu 22.04 LTS).
- Sufficient resources (CPU, memory, and storage) for both Cardano and Midnight nodes.
- SSH access with sudo privileges.
- Firewall configured to allow required ports:
  - 30333 (Midnight P2P)
  - 9944 (Midnight WebSocket RPC)
  - 3001 (Cardano Node P2P)
  - 5432 (PostgreSQL)

> **⚠️ CRITICAL PREREQUISITE:** Cardano DB Sync is a hard prerequisite for the Midnight node stack. The Midnight node requires a persistent connection to a PostgreSQL 17 database populated by Cardano-db-sync. Syncing takes a minimum of 6 hours against pre-prod. **Do not attempt to run the Midnight node until DB Sync is fully completed.**

> **🚀 AUTOMATED SETUP (Recommended):** A fully reproducible cloud-init compatible shell script is available at `scripts/install_midnight_archive_node.sh`. It automatically invokes Ansible to configure the entire stack for Preview, Preprod, or Mainnet.
> Usage: `sudo ./scripts/install_midnight_archive_node.sh [NETWORK]`

---

### Manual Setup (For Reference / Troubleshooting)

The underlying Ansible playbooks (`ansible/setup_node.yml`) orchestrate the following:

1. **PostgreSQL 17 Setup:** Installs PostgreSQL from the official APT repository, creates a `midnight` user, `cexplorer` database, tunes indexing params, and drops `.pgpass`.
2. **Cardano Relay Node & Mithril:** Downloads Mithril, syncs the latest environment snapshot, downloads the `cardano-node` release, and templates `cardano-node.service`.
3. **Cardano DB Sync:** Downloads the db-sync release, downloads the network-specific JSON configuration, extracts the SQL schemas, and templates `cardano-db-sync.service`.
4. **Midnight Node:** Downloads the Midnight binary, provisions network specs, templates `midnight-node.service` with conditional flags for RPC, Bootnode, and Archive pruning.

To invoke this manually without the wrapper script:
```bash
sudo apt-get install -y ansible
ansible-playbook -i localhost, -c local ansible/setup_node.yml --extra-vars "network=preprod"
```

2. **Start Cardano DB Sync:**
   Run `cardano-db-sync` connected to the `cardano-node` socket to populate the PostgreSQL database.
   
   *WAIT HERE:* Monitor the DB sync process. **It takes ~6 hours on pre-prod.** Ensure it is fully synced before proceeding.

---

### Step 3: Midnight Node Installation

1. **Download Midnight Node Binary:**
   ```bash
   mkdir -p ~/data ~/res ~/.local/bin ~/tmp && cd ~/tmp
   curl -L -O https://github.com/midnightntwrk/midnight-node/releases/download/node-0.22.5/midnight-node-0.22.5-linux-amd64.tar.gz
   tar -xvzf midnight-node-0.22.5-linux-amd64.tar.gz
   mv ~/tmp/midnight-node ~/.local/bin/
   mv ~/tmp/res ~/res
   ```

2. **Configure Environment:**
   Create `.env` file:
   ```bash
   cat << 'ENV' > ~/.env
   export POSTGRES_HOST="localhost"
   export POSTGRES_DB="cexplorer"
   export POSTGRES_PORT="5432"
   export POSTGRES_USER="midnight"
   export POSTGRES_PASSWORD="YOUR_POSTGRES_PASSWORD"
   export DB_SYNC_POSTGRES_CONNECTION_STRING="postgresql://midnight:YOUR_POSTGRES_PASSWORD@localhost:5432/cexplorer"
   export NODE_NAME="midnight-fno-1"
   ENV
   
   source ~/.env
   ```

3. **Start Midnight Node (Archive Mode):**
   To track all historical testnet transactions and enable querying by local indexers, run the node in `archive` mode and expose the RPC.
   ```bash
   midnight-node \
     --chain /home/$USER/res/preprod/chain-spec-raw.json \
     --base-path /home/$USER/data \
     --name $NODE_NAME \
     --pruning archive \
     --rpc-external \
     --rpc-cors all \
     --no-private-ip
   ```

### Step 4: Verification
- Check Midnight node logs for `Postgres connection established`.
- Verify P2P connections (peers > 0).
- Check that block height (`Best: #...`) is incrementing.
