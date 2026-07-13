#!/bin/bash
# ==============================================================================
# Cardano Node & DB Sync Preprod Automated Setup Script
# Description: Automates the setup of a Cardano relay node and synchronized 
#              PostgreSQL database using cardano-db-sync for the Preprod network 
#              with Mithril snapshot.
# ==============================================================================

set -euo pipefail
trap 'echo "[!] Error occurred at line $LINENO. Exiting."; exit 1' ERR

echo "[*] Step 1: Install Mithril tooling and download snapshot"
mkdir -p "$HOME/tmp/mithril" && cd "$HOME/tmp/mithril"

curl --proto '=https' --tlsv1.2 -sSf https://raw.githubusercontent.com/input-output-hk/mithril/refs/heads/main/mithril-install.sh | sh -s -- -c mithril-signer -d unstable -p "$(pwd)"
curl --proto '=https' --tlsv1.2 -sSf https://raw.githubusercontent.com/input-output-hk/mithril/refs/heads/main/mithril-install.sh | sh -s -- -c mithril-client -d unstable -p "$(pwd)"
curl --proto '=https' --tlsv1.2 -sSf https://raw.githubusercontent.com/input-output-hk/mithril/refs/heads/main/mithril-install.sh | sh -s -- -c mithril-aggregator -d unstable -p "$(pwd)"

export CARDANO_NETWORK=preprod
export AGGREGATOR_ENDPOINT=https://aggregator.release-preprod.api.mithril.network/aggregator
export GENESIS_VERIFICATION_KEY=$(wget -q -O - https://raw.githubusercontent.com/input-output-hk/mithril/main/mithril-infra/configuration/release-preprod/genesis.vkey)
export ANCILLARY_VERIFICATION_KEY=$(wget -q -O - https://raw.githubusercontent.com/input-output-hk/mithril/main/mithril-infra/configuration/release-preprod/ancillary.vkey)
export SNAPSHOT_DIGEST=latest

./mithril-client cardano-db download --include-ancillary "$SNAPSHOT_DIGEST"

echo "[*] Step 2: Set up the Cardano relay node"
mkdir -p ~/.local/bin ~/.local/share

VERSION="10.6.2"
ARCH="linux-amd64"
URL="https://github.com/IntersectMBO/cardano-node/releases/download/${VERSION}/cardano-node-${VERSION}-${ARCH}.tar.gz"

curl -L "$URL" | tar -xz -C ~/.local/bin --strip-components=2 ./bin
curl -L "$URL" | tar -xz -C ~/.local/share --strip-components=1 ./share
chmod +x ~/.local/bin/cardano-*

mkdir -p ~/cardano-data
# Move the snapshot db if it was created
if [ -d "$HOME/tmp/mithril/db/" ]; then
    mv "$HOME/tmp/mithril/db/" ~/cardano-data/
fi

echo "[*] Creating Cardano Node systemd service..."
sudo tee /etc/systemd/system/cardano-node.service > /dev/null <<SERVICE
[Unit]
Description=Cardano Relay Node (Preprod)
Wants=network-online.target
After=network-online.target

[Service]
User=$USER
Type=simple
WorkingDirectory=$HOME/cardano-data
ExecStart=$HOME/.local/bin/cardano-node run \\
    --topology $HOME/.local/share/preprod/topology.json \\
    --database-path $HOME/cardano-data/db \\
    --socket-path $HOME/cardano-data/db/node.socket \\
    --host-addr 0.0.0.0 \\
    --port 3001 \\
    --config $HOME/.local/share/preprod/config.json
KillSignal=SIGINT
Restart=always
RestartSec=5
LimitNOFILE=32768

[Install]
WantedBy=multi-user.target
SERVICE

sudo systemctl daemon-reload
sudo systemctl enable cardano-node
sudo systemctl start cardano-node

echo "[*] Step 3: Configure PostgreSQL 17"
sudo apt-get update
sudo apt-get install curl ca-certificates -y
sudo install -d /usr/share/postgresql-common/pgdg
sudo curl -s -o /usr/share/postgresql-common/pgdg/apt.postgresql.org.asc --fail https://www.postgresql.org/media/keys/ACCC4CF8.asc
sudo sh -c 'echo "deb [signed-by=/usr/share/postgresql-common/pgdg/apt.postgresql.org.asc] https://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
sudo apt-get update && sudo apt-get -y install postgresql-17 postgresql-server-dev-17

# Prompt or use default password for PostgreSQL
POSTGRES_PASSWORD=${POSTGRES_PASSWORD:-"your_secure_password"}

# Configure roles and database
sudo -u postgres psql -c "CREATE USER midnight WITH PASSWORD '${POSTGRES_PASSWORD}';" || echo "User midnight already exists"
sudo -u postgres psql -c "ALTER ROLE midnight WITH SUPERUSER CREATEDB;"
sudo -u postgres psql -c "CREATE DATABASE cexplorer;" || echo "Database cexplorer already exists"

export PGPASSFILE="${HOME}/.pgpass"
echo "/var/run/postgresql:5432:cexplorer:midnight:${POSTGRES_PASSWORD}" > "$PGPASSFILE"
chmod 0600 "$PGPASSFILE"

# PostgreSQL Performance tuning
PG_CONF="/etc/postgresql/17/main/postgresql.conf"
if [ -f "$PG_CONF" ]; then
    sudo sed -i -E "s/^[#\s]*shared_buffers\s*=\s*.*$/shared_buffers = 4GB/" "$PG_CONF"
    sudo sed -i -E "s/^[#\s]*maintenance_work_mem\s*=\s*.*$/maintenance_work_mem = 1GB/" "$PG_CONF"
    sudo sed -i -E "s/^[#\s]*max_parallel_maintenance_workers\s*=\s*.*$/max_parallel_maintenance_workers = 2/" "$PG_CONF"
    sudo sed -i -E "s/^[#\s]*effective_cache_size\s*=\s*.*$/effective_cache_size = 12GB/" "$PG_CONF"
    sudo sed -i -E "s/^[#\s]*join_collapse_limit\s*=\s*.*$/join_collapse_limit = 1/" "$PG_CONF"
    sudo systemctl restart postgresql
fi

echo "[*] Step 4: Set up cardano-db-sync"
NETWORK="preprod"
mkdir -p "$HOME/tmp" && cd "$HOME/tmp"
curl -L -O https://github.com/IntersectMBO/cardano-db-sync/releases/download/13.6.0.5/cardano-db-sync-13.6.0.7-linux.tar.gz
tar -xzf cardano-db-sync-13.6.0.7-linux.tar.gz

cp bin/* ~/.local/bin/
mkdir -p ~/cardano-data/
if [ -d "$HOME/tmp/schema" ]; then
    sudo mv "$HOME/tmp/schema" ~/cardano-data/ || true
fi

cd ~/cardano-data
curl -O https://book.world.dev.cardano.org/environments/$NETWORK/db-sync-config.json
sed -i "s|\"NodeConfigFile\": \"config.json\"|\"NodeConfigFile\": \"$HOME/.local/share/$NETWORK/config.json\"|" ~/cardano-data/db-sync-config.json

mkdir -p ~/cardano-data/db-sync-state

echo "[*] Creating cardano-db-sync systemd service..."
sudo tee /etc/systemd/system/cardano-db-sync.service > /dev/null <<SERVICE
[Unit]
Description=Cardano DB Sync (Preprod)
After=cardano-node.service
Requires=cardano-node.service

[Service]
User=$USER
Type=simple
Environment="PGPASSFILE=$HOME/.pgpass"
WorkingDirectory=$HOME/cardano-data
ExecStart=$HOME/.local/bin/cardano-db-sync \\
    --config $HOME/cardano-data/db-sync-config.json \\
    --socket-path $HOME/cardano-data/db/node.socket \\
    --schema-dir $HOME/cardano-data/schema \\
    --state-dir $HOME/cardano-data/db-sync-state
KillSignal=SIGINT
Restart=always
RestartSec=10
LimitNOFILE=32768

[Install]
WantedBy=multi-user.target
SERVICE

sudo systemctl daemon-reload
sudo systemctl enable cardano-db-sync
sudo systemctl start cardano-db-sync

echo "========================================================================"
echo "[+] Cardano Preprod Node & DB Sync setup completed."
echo "[*] To check DB synchronization status:"
echo "    psql -h /var/run/postgresql -U midnight -d cexplorer -c \"SELECT block_no, slot_no, time FROM block ORDER BY id DESC LIMIT 1;\""
echo "========================================================================"
