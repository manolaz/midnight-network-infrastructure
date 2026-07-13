#!/bin/bash
# ==============================================================================
# Midnight Validator Node Configuration Script (Preprod)
# Description: Automates the setup of the environment variables and systemd 
#              service for a Midnight Validator Node.
# ==============================================================================

set -euo pipefail
trap 'echo "[!] Error occurred at line $LINENO. Exiting."; exit 1' ERR

NODE_USER=${SUDO_USER:-$USER}
USER_HOME=$(eval echo "~$NODE_USER")
NETWORK=${1:-preprod}
NODE_NAME=${2:-"midnight-validator-$(hostname)"}

echo "[*] Configuring Midnight Validator Node for user: $NODE_USER on network: $NETWORK"

echo "[*] Step 1: Prepare the environment configuration"

# Prompt for PostgreSQL password if not set
POSTGRES_PASSWORD=${POSTGRES_PASSWORD:-""}
if [ -z "$POSTGRES_PASSWORD" ]; then
    read -s -p "Enter PostgreSQL password for user 'midnight': " POSTGRES_PASSWORD
    echo ""
fi

# Create .env file
ENV_FILE="$USER_HOME/.env"
echo "[*] Creating $ENV_FILE..."

cat <<EOF > "$ENV_FILE"
# PostgreSQL connection
POSTGRES_HOST='localhost'
POSTGRES_DB='cexplorer'
POSTGRES_PORT=5432
POSTGRES_USER='midnight'
POSTGRES_PASSWORD='$POSTGRES_PASSWORD'
DB_SYNC_POSTGRES_CONNECTION_STRING=postgresql://midnight:$POSTGRES_PASSWORD@localhost:5432/cexplorer

# Cardano Preprod params
CARDANO_SECURITY_PARAMETER='432'
BLOCK_STABILITY_MARGIN=30

# Push to public telemetry
PROMETHEUS_PUSH_ENDPOINT='https://telemetry.shielded.tools/api/v1/receive'

# Midnight node settings
CFG_PRESET=$NETWORK
NODE_NAME='$NODE_NAME'

# Absolute path to network and keystore files
NODE_KEY_FILE='$USER_HOME/data/chains/midnight_${NETWORK}/network/secret_ed25519'
AURA_SEED_FILE='$USER_HOME/keystore/aura'
GRANDPA_SEED_FILE='$USER_HOME/keystore/grandpa'
CROSS_CHAIN_SEED_FILE='$USER_HOME/keystore/cross_chain'
EOF

chown $NODE_USER:$NODE_USER "$ENV_FILE"
chmod 600 "$ENV_FILE"

echo "[*] Verifying database connectivity..."
sudo -u postgres psql -h localhost -p 5432 -U midnight -d cexplorer -c "SELECT 'PostgreSQL Connection Verified' AS status;" || {
    echo "[!] Warning: PostgreSQL connection failed. Ensure PostgreSQL is running and credentials are correct."
}

echo "[*] Step 2: Deploy as a systemd service"
SERVICE_FILE="/etc/systemd/system/midnight-node.service"

sudo tee "$SERVICE_FILE" > /dev/null <<EOF
[Unit]
Description=Midnight Protocol Node (${NETWORK} FNO)
After=network.target postgresql.service
Wants=postgresql.service

[Service]
User=$NODE_USER
Group=$NODE_USER
Type=simple
WorkingDirectory=$USER_HOME
EnvironmentFile=$USER_HOME/.env

ExecStart=$USER_HOME/.local/bin/midnight-node \\
    --chain $USER_HOME/res/${NETWORK}/chain-spec-raw.json \\
    --base-path $USER_HOME/data \\
    --telemetry-url 'wss://telemetry.shielded.tools/submit 1' \\
    --validator \\
    --pool-limit 35 \\
    --name \${NODE_NAME} \\
    --rpc-port 9933

Restart=on-failure
RestartSec=10
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable midnight-node

echo "========================================================================"
echo "[+] Configuration completed!"
echo "[!] You can test the node interactively by running:"
echo "    source ~/.env && midnight-node --chain ~/res/${NETWORK}/chain-spec-raw.json --base-path ~/data --telemetry-url 'wss://telemetry.shielded.tools/submit 1' --validator --pool-limit 35 --name \$NODE_NAME --rpc-port 9933"
echo ""
echo "[!] Or start the service directly:"
echo "    sudo systemctl start midnight-node"
echo ""
echo "[*] To check logs and verify session keys are loaded, run:"
echo "    journalctl -u midnight-node -f"
echo "========================================================================"