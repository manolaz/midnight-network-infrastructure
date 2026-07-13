#!/bin/bash
# ==============================================================================
# Midnight Validator Node Automated Setup Script (Preprod)
# Description: Automates the setup of a Midnight validator node, key generation,
#              keystore configuration, and generates registration files.
# ==============================================================================

set -euo pipefail
trap 'echo "[!] Error occurred at line $LINENO. Exiting."; exit 1' ERR

NETWORK=${1:-preprod}
echo "[*] Setting up Midnight Validator Node for network: $NETWORK"

echo "[*] Step 1: Install the Midnight node"
mkdir -p ~/data ~/res ~/.local/bin ~/tmp
cd ~/tmp

VERSION="0.22.2"
echo "[*] Downloading midnight-node v${VERSION}..."
curl -L -O "https://github.com/midnightntwrk/midnight-node/releases/download/node-${VERSION}/midnight-node-${VERSION}-linux-amd64.tar.gz"
tar -xvzf "midnight-node-${VERSION}-linux-amd64.tar.gz"

mv ~/tmp/midnight-node ~/.local/bin/
if [ -d "$HOME/tmp/res" ]; then
    mv ~/tmp/res ~/res
fi

echo "[*] Step 2: Manage validator keys"
cd ~

echo "[*] Generating session keys..."
~/.local/bin/midnight-node key generate --scheme sr25519 --output-type json > aura.json
~/.local/bin/midnight-node key generate --scheme ed25519 --output-type json > grandpa.json
~/.local/bin/midnight-node key generate --scheme ecdsa --output-type json > cross_chain.json

# Restrict permissions for security
chmod 600 aura.json grandpa.json cross_chain.json

NETWORK_DIR="$HOME/data/chains/midnight_${NETWORK}/network"
mkdir -p "$NETWORK_DIR"
chmod 700 "$NETWORK_DIR"

echo "[*] Generating network key..."
~/.local/bin/midnight-node key generate-node-key --file "$NETWORK_DIR/secret_ed25519"
chmod 600 "$NETWORK_DIR/secret_ed25519"

echo "[*] Node PeerID:"
~/.local/bin/midnight-node key inspect-node-key --file "$NETWORK_DIR/secret_ed25519"

echo "[*] Step 3: Configure the keystore"
sudo apt-get update && sudo apt-get install jq -y

KEYSTORE_PATH="$HOME/data/chains/midnight_${NETWORK}/keystore"
mkdir -p "$KEYSTORE_PATH"

echo "[*] Inserting AURA key..."
~/.local/bin/midnight-node key insert \
  --keystore-path "$KEYSTORE_PATH" \
  --scheme sr25519 \
  --key-type aura \
  --suri "$(jq -r .secretPhrase aura.json)"

echo "[*] Inserting GRANDPA key..."
~/.local/bin/midnight-node key insert \
  --keystore-path "$KEYSTORE_PATH" \
  --scheme ed25519 \
  --key-type gran \
  --suri "$(jq -r .secretPhrase grandpa.json)"

echo "[*] Inserting Cross-Chain key..."
~/.local/bin/midnight-node key insert \
  --keystore-path "$KEYSTORE_PATH" \
  --scheme ecdsa \
  --key-type beef \
  --suri "$(jq -r .secretPhrase cross_chain.json)"

echo "[*] Step 4: Register as a Federated Node Operator"
OUTPUT_FILE="$HOME/partner-chains-public-keys.json"

cat <<EOF > "$OUTPUT_FILE"
{
  "partner_chains_key": "$(jq -r .publicKey cross_chain.json)",
  "keys": {
    "aura": "$(jq -r .publicKey aura.json)",
    "crch": "$(jq -r .publicKey cross_chain.json)",
    "gran": "$(jq -r .publicKey grandpa.json)"
  }
}
EOF

echo "[*] Validator Application file generated at $OUTPUT_FILE"
cat "$OUTPUT_FILE"
echo ""
echo "[+] Setup complete."
echo "[!] IMPORTANT: Backup your aura.json, grandpa.json, and cross_chain.json securely!"