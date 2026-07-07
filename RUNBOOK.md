# Runbook for Midnight Network Pre-Production Environment

## Section 1: FNO (Full Node Operator) Onboarding Steps

### Prerequisites
- Access to a Linux-based server (x86-64/amd64 architecture).
- Sufficient resources (CPU, memory, and storage) for both Cardano and Midnight nodes.
- SSH access with sudo privileges.
- Firewall configured to allow required ports:
  - 30333 (Midnight P2P)
  - 9944 (Midnight WebSocket RPC)
  - 3001 (Cardano Node P2P)
  - 5432 (PostgreSQL)

> **⚠️ CRITICAL PREREQUISITE:** Cardano DB Sync is a hard prerequisite for the Midnight node stack. The Midnight node requires a persistent connection to a PostgreSQL database populated by Cardano-db-sync. Syncing takes a minimum of 6 hours against pre-prod. **Do not attempt to run the Midnight node until DB Sync is fully completed.**

> **🚀 AUTOMATED SETUP:** A fully reproducible shell script is available at `scripts/install_midnight_archive_node.sh` to automate Steps 1 and 3 of this guide.

---

### Step 1: Cardano Relay Node & Mithril Setup
Midnight operates as a partner chain to Cardano. We use Mithril to download a verified snapshot to reduce sync time.

1. **Install Mithril Tooling:**
   ```bash
   mkdir -p $HOME/tmp/mithril && cd $HOME/tmp/mithril
   curl --proto '=https' --tlsv1.2 -sSf https://raw.githubusercontent.com/input-output-hk/mithril/refs/heads/main/mithril-install.sh | sh -s -- -c mithril-signer -d unstable -p $(pwd)
   curl --proto '=https' --tlsv1.2 -sSf https://raw.githubusercontent.com/input-output-hk/mithril/refs/heads/main/mithril-install.sh | sh -s -- -c mithril-client -d unstable -p $(pwd)
   curl --proto '=https' --tlsv1.2 -sSf https://raw.githubusercontent.com/input-output-hk/mithril/refs/heads/main/mithril-install.sh | sh -s -- -c mithril-aggregator -d unstable -p $(pwd)
   ```

2. **Configure Mithril for Preprod:**
   ```bash
   export CARDANO_NETWORK=preprod
   export AGGREGATOR_ENDPOINT=https://aggregator.pre-release-preprod.api.mithril.network/aggregator
   export GENESIS_VERIFICATION_KEY=$(wget -q -O - https://raw.githubusercontent.com/input-output-hk/mithril/main/mithril-infra/configuration/pre-release-preprod/genesis.vkey)
   export ANCILLARY_VERIFICATION_KEY=$(wget -q -O - https://raw.githubusercontent.com/input-output-hk/mithril/main/mithril-infra/configuration/pre-release-preprod/ancillary.vkey)
   export SNAPSHOT_DIGEST=latest
   ```

3. **Download Snapshot:**
   ```bash
   ./mithril-client cardano-db download --include-ancillary $SNAPSHOT_DIGEST
   ```

4. **Install Cardano Node:**
   ```bash
   VERSION="11.0.1"
   ARCH="linux-amd64"
   URL="https://github.com/IntersectMBO/cardano-node/releases/download/${VERSION}/cardano-node-${VERSION}-${ARCH}.tar.gz"
   
   mkdir -p ~/.local/bin ~/.local/share
   curl -L "$URL" | tar -xz -C ~/.local/bin --strip-components=2 ./bin
   curl -L "$URL" | tar -xz -C ~/.local/share --strip-components=1 ./share
   chmod +x ~/.local/bin/cardano-*
   ```

5. **Inject Mithril Snapshot and Start Cardano Node:**
   ```bash
   mkdir ~/cardano-data
   mv ~/tmp/mithril/db/ ~/cardano-data/
   
   # Set up systemd service to run cardano-node
   sudo tee /etc/systemd/system/cardano-node.service > /dev/null <<SERVICE
   [Unit]
   Description=Cardano Relay Node
   Wants=network-online.target
   After=network-online.target

   [Service]
   User=$USER
   Type=simple
   WorkingDirectory=$HOME/cardano-data
   ExecStart=$HOME/.local/bin/cardano-node run \
       --topology $HOME/.local/share/preprod/topology.json \
       --database-path $HOME/cardano-data/db \
       --socket-path $HOME/cardano-data/db/node.socket \
       --host-addr 0.0.0.0 \
       --port 3001 \
       --config $HOME/.local/share/preprod/config.json
   KillSignal=SIGINT
   Restart=always
   RestartSec=5
   LimitNOFILE=32768

   [Install]
   WantedBy=multi-user.target
   SERVICE
   
   sudo systemctl daemon-reload
   sudo systemctl enable --now cardano-node
   ```

---

### Step 2: Cardano DB Sync & PostgreSQL Setup
*(Assuming PostgreSQL 17 is installed and accessible)*

1. **Configure PostgreSQL:**
   Ensure PostgreSQL is running on port 5432 and the `midnight` user has access to a database (e.g., `cexplorer`).

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
