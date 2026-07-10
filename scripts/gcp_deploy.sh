#!/bin/bash
# ==============================================================================
# Midnight Node GCP Deployment Script (DEPRECATED)
# Description: This script has been deprecated in favor of Terraform.
#              Please see the terraform/ directory for infrastructure deployment.
# ==============================================================================

echo "========================================================================"
echo "[!] DEPRECATION WARNING: gcp_deploy.sh is no longer supported."
echo "    Please use Terraform to provision your infrastructure."
echo "    "
echo "    Migration steps:"
echo "    1. cd terraform/"
echo "    2. terraform init"
echo "    3. terraform plan -var=\"project_id=YOUR_PROJECT\""
echo "    4. terraform apply -var=\"project_id=YOUR_PROJECT\""
echo "========================================================================"
exit 1

set -euo pipefail
trap 'echo "[!] Error occurred at line $LINENO. Exiting."; exit 1' ERR

show_help() {
    echo "Usage: ./gcp_deploy.sh [PROJECT_ID] [ZONE] [NETWORK]"
    echo "  PROJECT_ID : GCP Project ID (Defaults to active gcloud config)"
    echo "  ZONE       : GCP Compute Zone (Default: us-central1-a)"
    echo "  NETWORK    : Midnight network to target: preview, preprod, mainnet (Default: preprod)"
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    show_help
    exit 0
fi

PROJECT_ID=${1:-$(gcloud config get-value project 2>/dev/null || echo "default-project")}
ZONE=${2:-"us-central1-a"}
TARGET_NETWORK=${3:-"preprod"}
INSTANCE_NAME="midnight-archive-node"
NETWORK="default"

echo "[*] Deploying to GCP Project: $PROJECT_ID, Zone: $ZONE, Network: $TARGET_NETWORK"

# 1. Create Firewall Rules for Midnight & Cardano
echo "[*] Configuring GCP Firewall Rules..."
gcloud compute firewall-rules create midnight-node-fw \
    --project="$PROJECT_ID" \
    --network="$NETWORK" \
    --allow tcp:30333,tcp:9944,tcp:3001,tcp:5432,tcp:9090,tcp:3000 \
    --description="Allow Midnight P2P, RPC, Cardano P2P, PostgreSQL, Prometheus, Grafana" \
    --target-tags="midnight-node" || echo "[!] Firewall rule already exists or error occurred."

# 2. Launch the VM Instance with Startup Script
echo "[*] Provisioning VM instance ($INSTANCE_NAME)..."
gcloud compute instances create $INSTANCE_NAME \
    --project=$PROJECT_ID \
    --zone=$ZONE \
    --machine-type=e2-standard-4 \
    --boot-disk-size=500GB \
    --boot-disk-type=pd-ssd \
    --image-family=ubuntu-2204-lts \
    --image-project=ubuntu-os-cloud \
    --tags="midnight-node" \
    --metadata startup-script="#!/bin/bash
      cd /root
      git clone https://github.com/tristan-midnight-network/midnight-network-infrastructure.git
      cd midnight-network-infrastructure
      bash scripts/install_midnight_archive_node.sh $TARGET_NETWORK"

echo "========================================================================"
echo "[+] GCP Deployment Triggered!"
echo "    The VM is now booting and executing the install script for $TARGET_NETWORK."
echo "    startup script. This process will take some time to download snapshots."
echo "    You can SSH into the machine using: gcloud compute ssh $INSTANCE_NAME --zone=$ZONE"
echo "    and tail the startup logs: sudo journalctl -u google-startup-scripts.service -f"
echo "========================================================================"
