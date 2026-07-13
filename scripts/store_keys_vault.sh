#!/bin/bash
# ==============================================================================
# HashiCorp Vault Integration
# Description: Stores the generated Midnight validator keys into HashiCorp Vault
# ==============================================================================

set -euo pipefail

NETWORK=${1:-preprod}
VAULT_ADDR=${VAULT_ADDR:-"http://127.0.0.1:8200"}

echo "[*] Storing Midnight Validator Keys to HashiCorp Vault at $VAULT_ADDR..."

if ! command -v vault &> /dev/null; then
    echo "[!] HashiCorp Vault CLI not found. Please install it to proceed."
    exit 1
fi

for key in aura grandpa cross_chain; do
    if [ -f "$HOME/${key}.json" ]; then
        echo "[*] Uploading $key to Vault at secret/midnight/${NETWORK}/validator-keys/${key}..."
        # Using kv put format for KV V2
        vault kv put "secret/midnight/${NETWORK}/validator-keys/${key}" @$HOME/${key}.json > /dev/null
    else
        echo "[!] Key file $HOME/${key}.json not found. Skipping."
    fi
done

NETWORK_KEY="$HOME/data/chains/midnight_${NETWORK}/network/secret_ed25519"
if [ -f "$NETWORK_KEY" ]; then
    SECRET_PATH="secret/midnight/${NETWORK}/validator-keys/network"
    echo "[*] Uploading network key to Vault at $SECRET_PATH..."
    vault kv put "$SECRET_PATH" key=@$NETWORK_KEY > /dev/null
fi
echo "[+] Vault Keys storage complete."