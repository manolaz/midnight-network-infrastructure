#!/bin/bash
# ==============================================================================
# AWS Secrets Manager Integration
# Description: Stores the generated Midnight validator keys into AWS Secrets Manager
# ==============================================================================

set -euo pipefail

NETWORK=${1:-preprod}
REGION=${AWS_REGION:-us-east-1}

echo "[*] Storing Midnight Validator Keys to AWS Secrets Manager ($REGION)..."

for key in aura grandpa cross_chain; do
    if [ -f "$HOME/${key}.json" ]; then
        SECRET_NAME="midnight/${NETWORK}/validator-keys/${key}"
        echo "[*] Uploading $key to AWS Secrets Manager as $SECRET_NAME..."
        if aws secretsmanager describe-secret --secret-id "$SECRET_NAME" --region "$REGION" >/dev/null 2>&1; then
            aws secretsmanager put-secret-value --secret-id "$SECRET_NAME" --secret-string "file://$HOME/${key}.json" --region "$REGION" > /dev/null
        else
            aws secretsmanager create-secret --name "$SECRET_NAME" --secret-string "file://$HOME/${key}.json" --region "$REGION" > /dev/null
        fi
    else
        echo "[!] Key file $HOME/${key}.json not found. Skipping."
    fi
done

NETWORK_KEY="$HOME/data/chains/midnight_${NETWORK}/network/secret_ed25519"
if [ -f "$NETWORK_KEY" ]; then
    SECRET_NAME="midnight/${NETWORK}/validator-keys/network"
    echo "[*] Uploading network key to AWS Secrets Manager as $SECRET_NAME..."
    if aws secretsmanager describe-secret --secret-id "$SECRET_NAME" --region "$REGION" >/dev/null 2>&1; then
        aws secretsmanager put-secret-value --secret-id "$SECRET_NAME" --secret-string "file://$NETWORK_KEY" --region "$REGION" > /dev/null
    else
        aws secretsmanager create-secret --name "$SECRET_NAME" --secret-string "file://$NETWORK_KEY" --region "$REGION" > /dev/null
    fi
fi
echo "[+] AWS Keys storage complete."