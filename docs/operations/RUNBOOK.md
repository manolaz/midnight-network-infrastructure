# Production Runbook: Midnight Network Infrastructure

## 🌑 Executive Summary & Architecture Context

This runbook serves as the definitive reference for operating a **Full Node** or a **Federated Validator Node** on the Midnight Network (supporting **Preview**, **Preprod**, and **Mainnet** environments). It assumes you have a strong foundation in Linux systems administration, Ansible, systemd, and database tuning, but have not previously operated a node on the Midnight or Substrate-based protocols.

### Midnight as a Cardano Partner Chain
Unlike standalone networks, Midnight operates as a **Cardano Partner Chain**. This architecture imposes strict sequencing dependencies. The Midnight Substrate runtime relies directly on historical and real-time Cardano blockchain data to execute validation and cross-chain tracking logic. 

```mermaid
graph TD
    subgraph "FNO Server Boundary"
        subgraph "Cardano Stack"
            A[Mithril Client] -->|Mithril Snapshot Bootstrap| B[(Cardano Ledger DB)]
            C[Cardano Relay Node] -->|Pulls Live Blocks| B
            E[Cardano DB Sync] -->|Examines Ledger State| B
            E -->|Writes Structured Data| D[(PostgreSQL 17 Database)]
        end
        subgraph "Midnight Stack"
            F[Midnight Substrate Node] -->|Queries Cardano Blocks & Tx| D
            F -->|Syncs Blocks| G((Midnight Network P2P))
        end
    end
    C -->|Syncs Blocks| H((Cardano Network P2P))
```

### ⚠️ Critical Dependency Sequence Warning
> **CRITICAL FACT:** `cardano-db-sync` is a hard dependency of the Midnight node stack. The Midnight node queries the `cexplorer` PostgreSQL database continuously. 
> - **The Midnight service (`midnight-node.service`) will fail to start if the database is missing, unpopulated, or if schemas have not been migrated.**
> - Syncing Cardano DB Sync from scratch takes approximately **6 to 12 hours** on Preprod, even when bootstrapped using Mithril ledger snapshots.
> - **Operational Order of Operations:** You must provision Postgres -> Sync Cardano Node with Mithril -> Sync Cardano DB Sync completely -> Populate Postgres schemas -> ONLY THEN configure and start the Midnight node.

---

## 💻 Hardware, Systems & Networking Prerequisites

### Recommended Server Specifications
For both Cardano and Midnight nodes running on the same host machine (recommended for low-latency database access), use the following minimum and recommended specifications:

| Resource | Minimum Requirement | Recommended Specification | Notes |
| :--- | :--- | :--- | :--- |
| **CPU** | 4 vCPUs (x86-64 / AMD64) | 8 vCPUs | Substrate validation and DB Sync ingestion are highly CPU-intensive. |
| **Memory** | 16 GB RAM | 32 GB RAM | Cardano node and DB Sync are notorious memory consumers. |
| **Storage** | 500 GB NVMe / SSD | 1 TB NVMe / SSD | **SSD/NVMe is mandatory.** Standard HDDs will cause severe lag during disk writes. |
| **OS** | Ubuntu 22.04 LTS | Ubuntu 24.04 LTS | Scripts are optimized for official Canonical APT repositories. |

### Firewall & Port Configuration
Ensure your perimeter firewall (GCP VPC, AWS Security Groups, or local ufw) allows traffic across these explicit ports:

| Port | Protocol | Scope | Service Name | Purpose |
| :--- | :--- | :--- | :--- | :--- |
| **3001** | TCP | Public (0.0.0.0/0) | Cardano Node P2P | Inbound/Outbound peer block syncing for Cardano. |
| **30333** | TCP | Public (0.0.0.0/0) | Midnight Node P2P | Inbound/Outbound peer block syncing for Midnight. |
| **9944** | TCP | Private (Internal VPC / localhost) | Midnight WebSocket RPC | Safe RPC actions (or external if bound to proxy). |
| **5432** | TCP | Private (localhost Only) | PostgreSQL 17 | Database communication between DB Sync and Midnight. |
| **9615** | TCP | Internal Prometheus Scraper | Midnight Metrics | Substrate metrics exporter endpoint. |
| **12798**| TCP | Internal Prometheus Scraper | Cardano Metrics | Cardano Node EKG/Prometheus metrics endpoint. |

---

## 🚀 Deployment Orchestration

You can deploy the FNO node using two distinct approaches: **Ansible Automation (Recommended)** or **Manual Bare-Metal Compilation**.

### Option A: Complete Ansible Playbook Orchestration
This repository contains a full set of Ansible playbooks designed to execute on `localhost` or remote targets. They provision the entire dependency graph in an idempotent manner.

#### 1. Zero-Touch Onboarding Script (Wrapper)
We provide automated, cloud-init compatible wrappers that install Ansible, clone dependencies, and run the respective playbooks.
- **For a Full Node (Pruned Ledger, Low Storage):**
  ```bash
  sudo ./scripts/install_midnight_full_node.sh preprod
  ```
- **For an Archive Node (Unpruned, Complete Ledger History, RPC Exposed):**
  ```bash
  sudo ./scripts/install_midnight_archive_node.sh preprod
  ```

#### 2. Manual Playbook Invocations
If you prefer to bypass the wrappers and trigger Ansible directly, run:
```bash
# Verify Ansible is installed
sudo apt-get update && sudo apt-get install -y ansible

# Run the Full Node playbook
ansible-playbook -i localhost, -c local scripts/ansible/setup_full_node.yml --extra-vars "network=preprod"

# Run the Archive Node playbook
ansible-playbook -i localhost, -c local scripts/ansible/setup_node.yml --extra-vars "network=preprod"
```

---

### Option B: Manual Step-by-Step Bare-Metal Installation
For debugging, compliance, or when running on systems where Ansible is not authorized, execute the following actions sequentially.

#### Step 1: Install & Tune PostgreSQL 17
1. Add the PostgreSQL Apt repository and key:
   ```bash
   sudo apt-get install -y software-properties-common curl gnupg
   curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/postgresql.gpg
   echo "deb http://apt.postgresql.org/pub/repos/apt/ $(lsb_release -cs)-pgdg main" | sudo tee /etc/apt/sources.list.d/pgdg.list
   sudo apt-get update
   ```
2. Install Postgres 17 and Python dependencies:
   ```bash
   sudo apt-get install -y postgresql-17 postgresql-client-17 postgresql-contrib python3-psycopg2
   ```
3. Establish the database structures and user roles:
   ```bash
   sudo -u postgres psql -c "CREATE USER midnight WITH PASSWORD 'YOUR_POSTGRES_PASSWORD' SUPERUSER;"
   sudo -u postgres psql -c "CREATE DATABASE cexplorer OWNER midnight;"
   ```
4. **Tune PostgreSQL** inside `/etc/postgresql/17/main/postgresql.conf` to accommodate heavy DB Sync write operations:
   ```ini
   shared_buffers = 16GB
   maintenance_work_mem = 4GB
   max_parallel_maintenance_workers = 4
   effective_cache_size = 48GB
   ```
5. Restart the database and generate the `.pgpass` credential file in the runtime user's home directory (e.g., `/home/midnight/.pgpass`):
   ```bash
   sudo systemctl restart postgresql
   echo "*:5432:cexplorer:midnight:YOUR_POSTGRES_PASSWORD" > ~/.pgpass
   chmod 600 ~/.pgpass
   ```

#### Step 2: Cardano Relay Node & Mithril Snapshot Bootstrapping
To bypass waiting weeks for Cardano to sync blocks, we use Input Output Global's **Mithril** protocol to download an authenticated, cryptographic ledger snapshot.

1. Download the Mithril client and download the latest Preprod snapshot:
   ```bash
   mkdir -p ~/tmp/mithril && cd ~/tmp/mithril
   curl -L -O https://raw.githubusercontent.com/input-output-hk/mithril/refs/heads/main/mithril-install.sh
   chmod +x mithril-install.sh
   ./mithril-install.sh -c mithril-client -d unstable -p .
   
   # Retrieve Genesis Keys and fetch the snapshot
   export GENESIS_VERIFICATION_KEY=$(curl -s https://raw.githubusercontent.com/input-output-hk/mithril/main/mithril-infra/configuration/pre-release-preprod/genesis.vkey)
   export ANCILLARY_VERIFICATION_KEY=$(curl -s https://raw.githubusercontent.com/input-output-hk/mithril/main/mithril-infra/configuration/pre-release-preprod/ancillary.vkey)
   
   export CARDANO_NETWORK="preprod"
   export AGGREGATOR_ENDPOINT="https://aggregator.pre-release-preprod.api.mithril.network/aggregator"
   export SNAPSHOT_DIGEST="latest"
   
   ./mithril-client cardano-db download --include-ancillary latest
   
   # Deploy the db to the cardano data structure
   mkdir -p ~/cardano-data
   mv db ~/cardano-data/
   ```

2. Download and deploy the Cardano Node release binary:
   ```bash
   cd ~/tmp
   curl -L -O "https://github.com/IntersectMBO/cardano-node/releases/download/11.0.1/cardano-node-11.0.1-linux-amd64.tar.gz"
   tar -xvzf cardano-node-11.0.1-linux-amd64.tar.gz
   sudo cp bin/cardano-node /usr/local/bin/
   sudo cp bin/cardano-cli /usr/local/bin/
   ```

3. Create the Systemd service file `/etc/systemd/system/cardano-node.service`:
   ```ini
   [Unit]
   Description=Cardano Relay Node
   After=network.target

   [Service]
   User=midnight
   Type=simple
   ExecStart=/usr/local/bin/cardano-node run \
     --topology /home/midnight/.local/share/preprod/topology.json \
     --database-path /home/midnight/cardano-data/db \
     --socket-path /home/midnight/cardano-data/db/node.socket \
     --host-addr 0.0.0.0 \
     --port 3001 \
     --config /home/midnight/.local/share/preprod/config.json
   Restart=always
   RestartSec=10
   LimitNOFILE=32768

   [Install]
   WantedBy=multi-user.target
   ```
4. Start the Cardano node service:
   ```bash
   sudo systemctl daemon-reload
   sudo systemctl enable --now cardano-node
   ```

#### Step 3: Configure and Ingest Cardano DB Sync
1. Download and extract Cardano DB Sync:
   ```bash
   cd ~/tmp
   curl -L -O "https://github.com/IntersectMBO/cardano-db-sync/releases/download/13.6.0.4/cardano-db-sync-13.6.0.4-linux-x86_64.tar.gz"
   tar -xvzf cardano-db-sync-13.6.0.4-linux-x86_64.tar.gz
   sudo cp cardano-db-sync-13.6.0.4-linux-x86_64/cardano-db-sync /usr/local/bin/
   ```
2. Pull DB schema migration SQL scripts directly from Intersect's source repo:
   ```bash
   mkdir -p ~/cardano-data/schema ~/cardano-data/db-sync-state
   curl -L -O "https://github.com/IntersectMBO/cardano-db-sync/archive/refs/tags/13.6.0.4.tar.gz"
   tar -xvzf 13.6.0.4.tar.gz
   cp -r cardano-db-sync-13.6.0.4/schema/* ~/cardano-data/schema/
   ```
3. Get network configuration files and modify paths:
   ```bash
   curl -s -o ~/cardano-data/db-sync-config.json "https://book.world.dev.cardano.org/environments/preprod/db-sync-config.json"
   sed -i 's|"NodeConfigFile": ".*"|"NodeConfigFile": "/home/midnight/.local/share/preprod/config.json"|' ~/cardano-data/db-sync-config.json
   ```
4. Create the Systemd service file `/etc/systemd/system/cardano-db-sync.service`:
   ```ini
   [Unit]
   Description=Cardano DB Sync Daemon
   After=cardano-node.service postgresql.service
   Requires=cardano-node.service

   [Service]
   User=midnight
   Type=simple
   Environment="PGPASSFILE=/home/midnight/.pgpass"
   WorkingDirectory=/home/midnight/cardano-data
   ExecStart=/usr/local/bin/cardano-db-sync \
     --config /home/midnight/cardano-data/db-sync-config.json \
     --socket-path /home/midnight/cardano-data/db/node.socket \
     --schema-dir /home/midnight/cardano-data/schema \
     --state-dir /home/midnight/cardano-data/db-sync-state
   Restart=always
   RestartSec=10
   LimitNOFILE=32768

   [Install]
   WantedBy=multi-user.target
   ```
5. Trigger migration and watch ingestion:
   ```bash
   sudo systemctl daemon-reload
   sudo systemctl enable --now cardano-db-sync
   
   # Stream DB-Sync logs to trace database population
   journalctl -u cardano-db-sync -f --no-tail
   ```
   *🛑 HALT PROCESS:* Monitor the sync phase until DB Sync has entirely caught up with the Cardano network chain tip. You can execute this query to find current sync status:
   ```bash
   PGPASSFILE=~/.pgpass psql -h localhost -U midnight -d cexplorer -c "SELECT value FROM meta WHERE key='block_sync_progress';"
   ```
   Only proceed once progress reads `100` (or `99.99`%).

#### Step 4: Midnight Node Deployment
1. Download, extract, and establish the Midnight binaries:
   ```bash
   mkdir -p ~/data ~/res ~/.local/bin ~/tmp && cd ~/tmp
   curl -L -O https://github.com/midnightntwrk/midnight-node/releases/download/node-0.22.5/midnight-node-0.22.5-linux-amd64.tar.gz
   tar -xvzf midnight-node-0.22.5-linux-amd64.tar.gz
   mv midnight-node ~/.local/bin/
   mv res ~/res
   ```
2. Establish the environmental parameters in `~/.env`:
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
   chmod 600 ~/.env
   ```
3. Initialize the service and verify execution:
   ```bash
   source ~/.env
   ~/.local/bin/midnight-node \
     --chain ~/res/preprod/chain-spec-raw.json \
     --base-path ~/data \
     --name $NODE_NAME \
     --pool-limit 35 \
     --no-private-ip
   ```

---

## 🔑 Federated Validator Node Operations & Key Management

If you are running as a **Federated Validator Node Operator** rather than a passive observer, you must generate and secure specialized cryptographic keys, register them on the partner chain, and configure Systemd to load your key materials securely.

### Midnight Validator Key Layout
Midnight Validator Nodes require four distinct keys, each serving a unique Substrate consensus layer function:
1. **AURA Key (`sr25519`)**: Manages the Block Authoring engine.
2. **GRANDPA Key (`ed25519`)**: Manages Block Finalization voting.
3. **Cross-Chain Key (`ecdsa`)**: Signs transactions that interact across partner networks (BEEFY framework).
4. **Network P2P Key (`ed25519`)**: Establishes your node's stable cryptographic peer identity (`secret_ed25519`).

```mermaid
graph LR
    subgraph "Validator Keystore"
        A[AURA sr25519] -->|Consensus: Block Authoring| E(Substrate Runtime)
        B[GRANDPA ed25519] -->|Consensus: Block Finalization| E
        C[Cross-Chain ecdsa] -->|Consensus: BEEFY Bridges| E
        D[Network P2P ed25519] -->|Consensus: Secure Peer Identity| E
    end
```

### Validator Bootstrap & Key Generation Instructions

This process is automated via `scripts/install_midnight_validator.sh`. To run it manually:

1. **Step 1: Generate Session & Network Keys**
   Execute these commands inside your user home directory to output the JSON key templates:
   ```bash
   # Generate Session Keys
   ~/.local/bin/midnight-node key generate --scheme sr25519 --output-type json > aura.json
   ~/.local/bin/midnight-node key generate --scheme ed25519 --output-type json > grandpa.json
   ~/.local/bin/midnight-node key generate --scheme ecdsa --output-type json > cross_chain.json
   
   # Set secure permissions
   chmod 600 aura.json grandpa.json cross_chain.json

   # Generate stable network P2P identity key
   NETWORK_DIR="$HOME/data/chains/midnight_preprod/network"
   mkdir -p "$NETWORK_DIR" && chmod 700 "$NETWORK_DIR"
   ~/.local/bin/midnight-node key generate-node-key --file "$NETWORK_DIR/secret_ed25519"
   chmod 600 "$NETWORK_DIR/secret_ed25519"
   ```

2. **Step 2: Load Keys Into the Substrate Keystore**
   Substrate stores active keys in a binary-hashed keystore directory on disk. Inject your newly generated secrets using the node CLI:
   ```bash
   KEYSTORE_PATH="$HOME/data/chains/midnight_preprod/keystore"
   mkdir -p "$KEYSTORE_PATH"

   # Insert AURA Block Authoring key
   ~/.local/bin/midnight-node key insert \
     --keystore-path "$KEYSTORE_PATH" \
     --scheme sr25519 \
     --key-type aura \
     --suri "$(jq -r .secretPhrase aura.json)"

   # Insert GRANDPA Finalization key
   ~/.local/bin/midnight-node key insert \
     --keystore-path "$KEYSTORE_PATH" \
     --scheme ed25519 \
     --key-type gran \
     --suri "$(jq -r .secretPhrase grandpa.json)"

   # Insert Cross-Chain key
   ~/.local/bin/midnight-node key insert \
     --keystore-path "$KEYSTORE_PATH" \
     --scheme ecdsa \
     --key-type beef \
     --suri "$(jq -r .secretPhrase cross_chain.json)"
   ```

3. **Step 3: Generate the Partner-Chains Registration JSON**
   You must export your public keys to a standardized structure and share it with the Midnight Federation Coordinator for registration:
   ```bash
   cat <<EOF > "$HOME/partner-chains-public-keys.json"
   {
     "partner_chains_key": "$(jq -r .publicKey cross_chain.json)",
     "keys": {
       "aura": "$(jq -r .publicKey aura.json)",
       "crch": "$(jq -r .publicKey cross_chain.json)",
       "gran": "$(jq -r .publicKey grandpa.json)"
     }
   }
   EOF
   echo "[+] Registration file generated at ~/partner-chains-public-keys.json"
   ```

4. **Step 4: Deploy the Validator Systemd Service**
   Configure `/etc/systemd/system/midnight-node.service` specifically for block validation by appending the `--validator` argument:
   ```ini
   [Unit]
   Description=Midnight Protocol Validator Node
   After=network.target postgresql.service
   Wants=postgresql.service

   [Service]
   User=midnight
   Group=midnight
   Type=simple
   WorkingDirectory=/home/midnight
   EnvironmentFile=/home/midnight/.env
   ExecStart=/home/midnight/.local/bin/midnight-node \
       --chain /home/midnight/res/preprod/chain-spec-raw.json \
       --base-path /home/midnight/data \
       --telemetry-url 'wss://telemetry.shielded.tools/submit 1' \
       --validator \
       --pool-limit 35 \
       --name ${NODE_NAME} \
       --rpc-port 9933
   Restart=on-failure
   RestartSec=10
   LimitNOFILE=65535

   [Install]
   WantedBy=multi-user.target
   ```
5. Enable and start the service:
   ```bash
   sudo systemctl daemon-reload
   sudo systemctl enable --now midnight-node
   ```

---

## 🔒 Day-2 Secret Management & Cloud Key Vaulting

Once validator keys are generated on host memory, they must **never** remain unbacked or insecure. This repository contains custom shell integrations to seamlessly ship your validator key material directly to major secure storage providers.

### Option A: Secure Storage in AWS Secrets Manager
Use the script `scripts/store_keys_aws.sh` to package and upload the files to your AWS regional environment:
```bash
# Configure region and authenticate
export AWS_REGION="us-west-2"

# Runs AWS CLI in the background to create/update secret structures
./scripts/store_keys_aws.sh preprod
```
*Under the hood, this pushes keys under the prefix path: `midnight/preprod/validator-keys/{aura,grandpa,cross_chain,network}`.*

### Option B: Secure Storage in GCP Secret Manager
If running on GCP compute engines, use `scripts/store_keys_gcp.sh`:
```bash
export GOOGLE_CLOUD_PROJECT="my-midnight-production-project"

./scripts/store_keys_gcp.sh preprod
```
*Creates distinct secret objects: `midnight-preprod-validator-aura`, `midnight-preprod-validator-grandpa`, etc. mapped to Cloud IAM permissions.*

### Option C: Enterprise Storage via HashiCorp Vault
If running an on-premise Kubernetes cluster or a custom SRE architecture, use the KV Secret store integration via `scripts/store_keys_vault.sh`:
```bash
export VAULT_ADDR="https://vault.internal.net:8200"
export VAULT_TOKEN="hvs.xxxxxxxxxxxxxxxxxxxxxx"

./scripts/store_keys_vault.sh preprod
```

---

## 🤝 Day-2 Multi-Operator Coordination & Orchestration

Managing a network of independent node operators requires orchestration and operational governance. We include native tooling to handle public-key collection and downtime scheduling.

### 1. Public Key Collection Tracking (`scripts/key_collection.sh`)
This script implements a lightweight, idempotent **State Machine** designed to manage and audit key collection status across multiple FNOs. 

- **State File:** Saved to `scripts/data/key_collection_state.json`.
- **Logic:** Reads operator definitions from `scripts/data/operators.json`. It tracks whether an operator has successfully supplied their public key, automatically skipping already-completed profiles and raising warnings for missing profiles:
  ```bash
  # Execute tracking pass
  ./scripts/key_collection.sh
  ```

```mermaid
stateDiagram-v2
    [*] --> ReadOperators
    ReadOperators --> CheckState: Parse scripts/data/operators.json
    CheckState --> SkipOperator: Operator responded is true
    CheckState --> PollOperator: Operator responded is false or null
    PollOperator --> UpdateStateSuccess: Key Received
    PollOperator --> UpdateStatePending: No Response / Timed Out
    UpdateStateSuccess --> SaveState
    UpdateStatePending --> SaveState
    SaveState --> [*]
```

### 2. Automated Maintenance Windows & Acknowledgment Verification (`scripts/maintenance_notify.sh`)
When rolling out software patches, database indexes, or server upgrades, operators must coordinate to prevent concurrent downtime that could breach consensus thresholds.

The `maintenance_notify.sh` script:
1. Generates a structured JSON downtime notification with custom timestamps and impact descriptions.
2. Directs notifications to the operator group.
3. Polls and logs operator responses during a configurable timeout window.
4. **SRE Triage Rule:** If any operator fails to acknowledge within the timeframe, the script flags them for manual escalation:
   ```bash
   # Notify operator group and wait 10 seconds for ACKs before flagging
   ./scripts/maintenance_notify.sh 10
   ```

---

## 🩺 Automated Health Checks & Regression Monitoring

To continuously evaluate your node's operational stability, utilize `scripts/health_check.sh`. 

```bash
# Execute local RPC monitoring pass
./scripts/health_check.sh http://localhost:9944
```

### Operational Mechanics
1. **JSON-RPC Polling:** Sends a structured `system_health` JSON-RPC query to the Midnight Substrate engine.
2. **State Evaluation:** Evaluates status:
   - **`healthy`**: Active peers > 0 and node synchronization (`isSyncing`) is completed.
   - **`syncing`**: Actively downloading blocks from other peers.
   - **`degraded`**: Online, but reporting 0 peers.
   - **`offline`**: RPC failed to respond.
3. **Regression Diff Engine:** It archives the state to `node_health_report.json` and compares it against `node_health_report_prev.json`.
4. **Alerts Raised:** It triggers immediate terminal flags if:
   - Node health degraded from `healthy` -> `degraded`/`offline`.
   - Inbound peer count drops significantly below historical norms.

---

## 📊 Observability & Monitoring Architecture

Maintaining high availability requires continuous performance scraping. The `monitoring/` directory provides a pre-configured Prometheus and Grafana stack.

### Scraping Infrastructure Configuration
The monitoring architecture relies on a local Prometheus instance running inside Docker Compose, configured to scrape metrics directly from both the Midnight node (port `9615`) and Cardano node (port `12798`).

- **Docker Stack Bootstrapping:**
  ```bash
  cd monitoring/configs
  docker-compose up -d
  ```
- **Scraping Configuration (`prometheus.yml`):**
  ```yaml
  scrape_configs:
    - job_name: 'midnight_node'
      static_configs:
        - targets: ['host.docker.internal:9615']

    - job_name: 'cardano_node'
      static_configs:
        - targets: ['host.docker.internal:12798']
  ```

---

## 🚨 Alerting Matrix & SRE Triage Runbooks

The metrics compiled by Prometheus are continuously evaluated against alerting rules defined in `monitoring/alerts/node_alerts.yml`. If an alert triggers, use these step-by-step SRE playbooks to triage and mitigate the issue.

### 1. Alert: `BlockProductionStalled` (Severity: CRITICAL)
* **Description:** Node's best block height has not changed for more than 5 minutes.
* **Potential Root Cause:**
  1. Connection to the underlying PostgreSQL database was dropped.
  2. The local Cardano Relay Node has stopped syncing blocks.
  3. Network split or internet routing failure.
* **Triage Steps:**
  1. Verify if the database is responding:
     ```bash
     sudo -u postgres psql -h localhost -d cexplorer -c "SELECT NOW();"
     ```
  2. Inspect Midnight Node logs specifically for database or substrate errors:
     ```bash
     journalctl -u midnight-node -f -n 200
     ```
  3. Verify the Cardano node service is alive:
     ```bash
     sudo systemctl status cardano-node
     ```

### 2. Alert: `LowPeerCount` (Severity: WARNING)
* **Description:** Substrate peer-to-peer count has dropped below 5 active connections.
* **Potential Root Cause:**
  1. Port `30333` TCP is blocked by a local firewall change.
  2. The official bootnodes are offline or undergoing rolling maintenance.
  3. Network configuration issues (e.g. missing public IP mapping).
* **Triage Steps:**
  1. Check your public port status from an external server:
     ```bash
     nc -zv [YOUR_PUBLIC_IP] 30333
     ```
  2. Verify if the Substrate service is running with `--no-private-ip` to ensure it only establishes public internet connections.
  3. Restart the Midnight service to force peer re-discovery:
     ```bash
     sudo systemctl restart midnight-node
     ```

### 3. Alert: `HighCpuUsage` (Severity: WARNING)
* **Description:** Process CPU usage exceeds 85% for more than 5 minutes.
* **Potential Root Cause:**
  1. Node is undergoing initial ledger synchronization.
  2. Publicly exposed RPC port (`9944`) is being spammed with transaction submissions or complex state queries.
  3. Cardano DB Sync index rebuild is taxing the CPU core allotment.
* **Triage Steps:**
  1. Identify the consuming process:
     ```bash
     top -b -n 1 -o %CPU | head -n 20
     ```
  2. If the RPC port is public, check connection metrics or configure an Nginx reverse-proxy rate-limiter immediately.
  3. Check if the high usage is temporary due to sync activity:
     ```bash
     journalctl -u cardano-db-sync -n 50
     ```

### 4. Alert: `HighMemoryUsage` (Severity: WARNING)
* **Description:** The process resident memory exceeds 3.0 GB of RAM.
* **Potential Root Cause:**
  1. Severe database sync lag causing memory buffers to grow.
  2. Substrate runtime state-cache leaks.
* **Triage Steps:**
  1. Inspect the memory footprint of the services:
     ```bash
     ps aux --sort=-%mem | head -n 10
     ```
  2. Check DB sync status and verify Postgres hasn't entered recovery mode.
  3. If memory increases linearly without tapering off, restart the services during a scheduled maintenance window:
     ```bash
     sudo systemctl restart midnight-node
     ```

### 5. Alert: `NodeDown` (Severity: CRITICAL)
* **Description:** Prometheus is unable to scrape metrics from the Midnight exporter.
* **Potential Root Cause:**
  1. The `midnight-node` process has crashed (Out Of Memory, postgres panic, etc.).
  2. Local systemd service was manually stopped.
* **Triage Steps:**
  1. Check systemd service state:
     ```bash
     sudo systemctl status midnight-node
     ```
  2. If crashed, search the system logs for Out Of Memory (OOM) killer events:
     ```bash
     sudo dmesg -T | grep -i oom
     ```
  3. Inspect logs immediately prior to the crash:
     ```bash
     journalctl -u midnight-node --since "10 minutes ago"
     ```

### 6. Alert: `NodeRestarted` (Severity: WARNING)
* **Description:** Node uptime is less than 5 minutes (indicating a restart).
* **Potential Root Cause:**
  1. Auto-recovery systemd policies triggered on service crash.
  2. System reboot occurred.
* **Triage Steps:**
  1. Check system boot logs to identify if a full reboot occurred:
     ```bash
     uptime
     journalctl --list-boots
     ```
  2. Verify service stability. If it restarts repeatedly, stop the service to prevent database index corruption and troubleshoot the crash logs.

---

## 🛠 Honest DevOps Pitfalls, Gotchas & Mitigations

When maintaining a production Midnight node, you will likely hit these real-world issues. Use these pre-verified mitigations to resolve them quickly:

### 1. Failed Schema Extraction (GitHub API Rate Limits)
* **The Gotcha:** The Ansible DB-sync role attempts to download schemas by retrieving a tarball from GitHub (`https://github.com/IntersectMBO/cardano-db-sync/archive/refs/tags/13.6.0.4.tar.gz`). On cloud instances with shared public IP space (like GCP or AWS), GitHub will often reject these unauthenticated requests with an HTTP 403 Rate Limit block, causing the playbook deployment to fail.
* **The Mitigation:** If schema extraction fails, manually pre-fetch the SQL files using an alternative network route, or host the archive on a private local S3/GCS bucket and update the role source parameter (`setup_node.yml` variables).

### 2. Database Connection Failures (Retries & .pgpass Rights)
* **The Gotcha:** `cardano-db-sync` starts quickly and attempts to verify DB connection before Postgres completes its post-boot crash recovery routine, resulting in immediate startup failures. Alternatively, the `.pgpass` file is misconfigured or has loose file permissions (must be `0600`), blocking DB sync login.
* **The Mitigation:** Ensure the `.pgpass` file resides in the exact home directory of the systemd execution user (typically `/home/midnight`), is owned by that user, and has restricted access permissions (`chmod 600 ~/.pgpass`). Additionally, configure Systemd dependency chains (`After=postgresql.service`, `Wants=postgresql.service`) and set `Restart=always` with a `RestartSec=10` buffer.

### 3. Peer-ID Instability (Missing secret_ed25519 backups)
* **The Gotcha:** If the VM instance is destroyed and recreated via Terraform, a new P2P node-key file (`secret_ed25519`) will be generated. This changes your public Peer-ID, breaking your validator registry configuration on the network and preventing other peers from finding you, which stops block validation.
* **The Mitigation:** Always back up your `/home/midnight/data/chains/midnight_preprod/network/secret_ed25519` key file using `scripts/store_keys_gcp.sh` or `store_keys_aws.sh` during initialization. When redeploying, retrieve this file from your Secret Vault *before* booting the Midnight process.

### 4. Public RPC Exposure Security Vulnerabilities
* **The Gotcha:** Exposing the websocket port `9944` publicly allows external actors to spam your node with compute-heavy requests, causing memory panics or denial-of-service blockages.
* **The Mitigation:** Keep port `9944` strictly bound to `127.0.0.1` (localhost) or internal VPC CIDR ranges. If you must expose the RPC endpoint to support public apps or indexers, place it behind an Nginx or HAProxy reverse-proxy configured with rate-limiting, CORS protections, and strict SSL offloading. Ensure you pass the flag `--rpc-methods Safe` to disable admin endpoints.

