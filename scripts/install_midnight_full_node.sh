#!/bin/bash
# ==============================================================================
# Midnight Full Node Automated Setup Script
# Description: Automates the setup of a Full Node for the Midnight networks
#              (Preview/Preprod/Mainnet). A full node syncs with the blockchain, 
#              validates transactions, and provides real-time state queries.
# Usage: sudo ./install_midnight_full_node.sh [NETWORK]
# ==============================================================================

set -euo pipefail
trap 'echo "[!] Error occurred at line $LINENO. Exiting."; exit 1' ERR

TARGET_NETWORK=${1:-preprod}
echo "[*] Target Network: $TARGET_NETWORK"

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

if [ ! -f "scripts/ansible/setup_full_node.yml" ]; then
    echo "[!] Error: Cannot find scripts/ansible/setup_full_node.yml. Ensure you are running this from the repository root."
    exit 1
fi

ansible-playbook -i localhost, -c local scripts/ansible/setup_full_node.yml --extra-vars "network=$TARGET_NETWORK"

echo "========================================================================"
echo "    - sudo systemctl status postgresql"
echo "    - sudo systemctl status cardano-node"
echo "    - sudo systemctl status cardano-db-sync"
echo "    - sudo systemctl status midnight-node"

echo "========================================================================"
echo "[+] Setup automation completed."
echo "[!] IMPORTANT: You must configure PostgreSQL and run cardano-db-sync"
echo "    until fully synced (~6 hours) BEFORE starting midnight-node!"
echo "    Once ready, run: sudo systemctl start midnight-node"
echo "========================================================================"
