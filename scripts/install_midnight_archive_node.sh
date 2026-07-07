#!/bin/bash
# ==============================================================================
# Midnight Pre-prod Archive Node Automated Setup Script
# Description: Automates the setup of an Archive Node for the Midnight Preprod
#              network. Enables keeping all historical states to track testnet
#              transactions and enables RPC options for local indexers/explorers.
#              This complements the instructions in RUNBOOK.md.
# Usage: sudo ./install_midnight_archive_node.sh
# ==============================================================================

set -e

if [ "$EUID" -eq 0 ]; then
  echo "[*] Running as root (e.g., GCP Startup Script). Setting up 'midnight' user..."
  id -u midnight &>/dev/null || useradd -m -s /bin/bash midnight
  NODE_USER="midnight"
  USER_HOME="/home/midnight"
else
  NODE_USER="$USER"
  USER_HOME="$HOME"
fi

echo "[*] Using user: $NODE_USER, home directory: $USER_HOME"

# 1. Update and install dependencies
echo "[*] Step 1: Installing dependencies..."
sudo apt-get update
sudo apt-get install -y curl jq tar wget tmux htop build-essential postgresql

# 2. Setup Mithril and Cardano Node Snapshot
echo "[*] Step 2: Setting up Mithril & downloading snapshot..."
mkdir -p "$USER_HOME/tmp/mithril"
cd "$USER_HOME/tmp/mithril"
curl --proto '=https' --tlsv1.2 -sSf https://raw.githubusercontent.com/input-output-hk/mithril/refs/heads/main/mithril-install.sh | sh -s -- -c mithril-client -d unstable -p $(pwd)

export CARDANO_NETWORK=preprod
export AGGREGATOR_ENDPOINT=https://aggregator.pre-release-preprod.api.mithril.network/aggregator
export GENESIS_VERIFICATION_KEY=$(wget -q -O - https://raw.githubusercontent.com/input-output-hk/mithril/main/mithril-infra/configuration/pre-release-preprod/genesis.vkey)
export ANCILLARY_VERIFICATION_KEY=$(wget -q -O - https://raw.githubusercontent.com/input-output-hk/mithril/main/mithril-infra/configuration/pre-release-preprod/ancillary.vkey)
export SNAPSHOT_DIGEST=latest

./mithril-client cardano-db download --include-ancillary $SNAPSHOT_DIGEST

# 3. Install Cardano Node
echo "[*] Step 3: Installing Cardano Node..."
VERSION="11.0.1"
ARCH="linux-amd64"
URL="https://github.com/IntersectMBO/cardano-node/releases/download/${VERSION}/cardano-node-${VERSION}-${ARCH}.tar.gz"

mkdir -p "$USER_HOME/.local/bin" "$USER_HOME/.local/share"
curl -L "$URL" | tar -xz -C "$USER_HOME/.local/bin" --strip-components=2 ./bin
curl -L "$URL" | tar -xz -C "$USER_HOME/.local/share" --strip-components=1 ./share
chmod +x $USER_HOME/.local/bin/cardano-*

mkdir -p "$USER_HOME/cardano-data"
mv "$USER_HOME/tmp/mithril/db/" "$USER_HOME/cardano-data/"

# Note: systemd setup for cardano-node is in RUNBOOK.md
# We will create a unit file here as well.
echo "[*] Step 4: Creating Cardano Node systemd service..."
sudo tee /etc/systemd/system/cardano-node.service > /dev/null <<SERVICE
[Unit]
Description=Cardano Relay Node
Wants=network-online.target
After=network-online.target

[Service]
User=$NODE_USER
Type=simple
WorkingDirectory=$USER_HOME/cardano-data
ExecStart=$USER_HOME/.local/bin/cardano-node run \
    --topology $USER_HOME/.local/share/preprod/topology.json \
    --database-path $USER_HOME/cardano-data/db \
    --socket-path $USER_HOME/cardano-data/db/node.socket \
    --host-addr 0.0.0.0 \
    --port 3001 \
    --config $USER_HOME/.local/share/preprod/config.json
KillSignal=SIGINT
Restart=always
RestartSec=5
LimitNOFILE=32768

[Install]
WantedBy=multi-user.target
SERVICE

sudo systemctl daemon-reload

# 4. Install Midnight Node
echo "[*] Step 5: Installing Midnight Node..."
mkdir -p "$USER_HOME/data" "$USER_HOME/res" "$USER_HOME/.local/bin" "$USER_HOME/tmp"
cd "$USER_HOME/tmp"
curl -L -O https://github.com/midnightntwrk/midnight-node/releases/download/node-0.22.5/midnight-node-0.22.5-linux-amd64.tar.gz
tar -xvzf midnight-node-0.22.5-linux-amd64.tar.gz
mv "$USER_HOME/tmp/midnight-node" "$USER_HOME/.local/bin/"
mv "$USER_HOME/tmp/res" "$USER_HOME/"

# Create Environment file
cat << 'ENV' > "$USER_HOME/.env"
export POSTGRES_HOST="localhost"
export POSTGRES_DB="cexplorer"
export POSTGRES_PORT="5432"
export POSTGRES_USER="midnight"
export POSTGRES_PASSWORD="YOUR_POSTGRES_PASSWORD"
export DB_SYNC_POSTGRES_CONNECTION_STRING="postgresql://midnight:YOUR_POSTGRES_PASSWORD@localhost:5432/cexplorer"
export NODE_NAME="midnight-archive-node"
ENV

echo "[*] Step 6: Creating Midnight Node systemd service (ARCHIVE MODE)..."
sudo tee /etc/systemd/system/midnight-node.service > /dev/null <<SERVICE
[Unit]
Description=Midnight Archive Node
Wants=network-online.target
After=network-online.target cardano-node.service

[Service]
User=$NODE_USER
Type=simple
EnvironmentFile=$USER_HOME/.env
WorkingDirectory=$USER_HOME/data
# Run in Archive mode to track all testnet transactions
ExecStart=$USER_HOME/.local/bin/midnight-node \
    --chain $USER_HOME/res/preprod/chain-spec-raw.json \
    --base-path $USER_HOME/data \
    --name \${NODE_NAME} \
    --pruning archive \
    --rpc-external \
    --rpc-cors all \
    --no-private-ip
KillSignal=SIGINT
Restart=always
RestartSec=10
LimitNOFILE=32768

[Install]
WantedBy=multi-user.target
SERVICE

sudo systemctl daemon-reload

# Fix permissions if script was run as root
if [ "$EUID" -eq 0 ]; then
  echo "[*] Fixing permissions for $USER_HOME..."
  chown -R $NODE_USER:$NODE_USER $USER_HOME
fi

echo "========================================================================"
echo "[+] Setup automation completed."
echo "[!] IMPORTANT: You must configure PostgreSQL and run cardano-db-sync"
echo "    until fully synced (~6 hours) BEFORE starting midnight-node!"
echo "    Once ready, run: sudo systemctl start midnight-node"
echo "========================================================================"
