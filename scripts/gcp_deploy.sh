#!/bin/bash
# ==============================================================================
# Midnight Node GCP Deployment Script
# Description: Provisions a Google Cloud Platform VM and configures the firewall 
#              to run the Midnight Archive Node automatically via startup-script.
# Usage: ./gcp_deploy.sh [PROJECT_ID] [ZONE]
# ==============================================================================

PROJECT_ID=${1:-$(gcloud config get-value project 2>/dev/null || echo "default-project")}
ZONE=${2:-"us-central1-a"}
INSTANCE_NAME="midnight-archive-node"
NETWORK="default"

echo "[*] Deploying to GCP Project: $PROJECT_ID, Zone: $ZONE"

# 1. Create Firewall Rules for Midnight & Cardano
echo "[*] Configuring GCP Firewall Rules..."
gcloud compute firewall-rules create midnight-node-fw \
    --project=$PROJECT_ID \
    --network=$NETWORK \
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
    --metadata-from-file startup-script=scripts/install_midnight_archive_node.sh

echo "========================================================================"
echo "[+] GCP Deployment Triggered!"
echo "    The VM is now booting and executing the install_midnight_archive_node.sh"
echo "    startup script. This process will take some time to download snapshots."
echo "    You can SSH into the machine using: gcloud compute ssh $INSTANCE_NAME --zone=$ZONE"
echo "    and tail the startup logs: sudo journalctl -u google-startup-scripts.service -f"
echo "========================================================================"
