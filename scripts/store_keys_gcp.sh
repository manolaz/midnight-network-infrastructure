#!/bin/bash
# ==============================================================================
# Google Cloud Secret Manager Integration
# Description: Stores the generated Midnight validator keys into GCP Secret Manager
# ==============================================================================

set -euo pipefail

NETWORK=${1:-preprod}
PROJECT_ID=${GOOGLE_CLOUD_PROJECT:-""}

if [ -z "$PROJECT_ID" ]; then
    echo "[!] GOOGLE_CLOUD_PROJECT environment variable is not set. Please set it and try again."
    exit 1
fi

echo "[*] Storing Midnight Validator Keys to GCP Secret Manager (Project: $PROJECT_ID)..."

for key in aura grandpa cross_chain; do
    if [ -f "$HOME/${key}.json" ]; then
        SECRET_NAME="midnight-${NETWORK}-validator-${key}"
        # GCP Secret names can only contain letters, numbers, hyphens, and underscores.
        SECRET_NAME=$(echo "$SECRET_NAME" | tr '_' '-')
        
        echo "[*] Uploading $key to GCP Secret Manager as $SECRET_NAME..."
        if ! gcloud secrets describe "$SECRET_NAME" --project="$PROJECT_ID" >/dev/null 2>&1; then
            gcloud secrets create "$SECRET_NAME" --replication-policy="automatic" --project="$PROJECT_ID" > /dev/null
        fi
        gcloud secrets versions add "$SECRET_NAME" --data-file="$HOME/${key}.json" --project="$PROJECT_ID" > /dev/null
    else
        echo "[!] Key file $HOME/${key}.json not found. Skipping."
    fi
done

NETWORK_KEY="$HOME/data/chains/midnight_${NETWORK}/network/secret_ed25519"
if [ -f "$NETWORK_KEY" ]; then
    SECRET_NAME="midnight-${NETWORK}-validator-network"
    echo "[*] Uploading network key to GCP Secret Manager as $SECRET_NAME..."
    if ! gcloud secrets describe "$SECRET_NAME" --project="$PROJECT_ID" >/dev/null 2>&1; then
        gcloud secrets create "$SECRET_NAME" --replication-policy="automatic" --project="$PROJECT_ID" > /dev/null
    fi
    gcloud secrets versions add "$SECRET_NAME" --data-file="$NETWORK_KEY" --project="$PROJECT_ID" > /dev/null
fi
echo "[+] GCP Keys storage complete."