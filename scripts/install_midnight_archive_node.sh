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

# 1. Update and install Ansible
echo "[*] Step 1: Installing Ansible..."
sudo apt-get update
sudo apt-get install -y software-properties-common
sudo add-apt-repository --yes --update ppa:ansible/ansible
sudo apt-get install -y ansible git curl

# 2. Setup local inventory and run playbook
echo "[*] Step 2: Running Ansible Playbook for Full Node Provisioning..."

# Ensure we are in the correct directory. If running as a GCP startup script, 
# we might need to pull the repo first, but assuming the repo is copied or we are in it:
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_DIR"

if [ ! -f "ansible/setup_node.yml" ]; then
    echo "[!] Error: Cannot find ansible/setup_node.yml. Ensure you are running this from the repository root."
    exit 1
fi

ansible-playbook -i localhost, -c local ansible/setup_node.yml

echo "[*] Node setup complete. Check the status of the following services:"
echo "    - sudo systemctl status postgresql"
echo "    - sudo systemctl status cardano-node"
echo "    - sudo systemctl status cardano-db-sync"
echo "    - sudo systemctl status midnight-node"

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
