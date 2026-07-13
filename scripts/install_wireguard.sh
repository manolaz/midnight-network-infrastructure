#!/bin/bash
# ==============================================================================
# WireGuard Setup Script for Midnight Validator Node (Preprod)
# Description: Automates the installation of WireGuard from source, generation 
#              of keys, and prepares the configuration for the overlay network.
# ==============================================================================

set -euo pipefail
trap 'echo "[!] Error occurred at line $LINENO. Exiting."; exit 1' ERR

echo "[*] Step 1: Install WireGuard (Version v1.0.20250521)"
sudo apt-get update && sudo apt-get install -y \
    git \
    build-essential \
    pkg-config \
    libelf-dev \
    linux-headers-$(uname -r)

WIREGUARD_TOOLS_VERSION="v1.0.20250521"
WORKDIR="$(mktemp -d)"

echo "[*] Cloning and building wireguard-tools version $WIREGUARD_TOOLS_VERSION..."
git clone https://git.zx2c4.com/wireguard-tools "$WORKDIR/wireguard-tools"
cd "$WORKDIR/wireguard-tools"
git checkout "$WIREGUARD_TOOLS_VERSION"
make -C src && sudo make -C src install

echo "[*] Verifying installation:"
wg --version

echo "[*] Step 2: Generate Identity Keys"
WG_DIR="$HOME/wireguard-keys"
mkdir -p "$WG_DIR"
cd "$WG_DIR"

# Secure the directory
umask 077

echo "[*] Generating WireGuard Keypair (Tunnel Identity)..."
wg genkey | tee privatekey | wg pubkey > publickey

echo "[*] Keys generated at $WG_DIR:"
echo "    - privatekey (Keep this secure!)"
echo "    - publickey (Send this to Midnight Foundation)"

echo "========================================================================"
echo "[+] WireGuard installed and keys generated."
echo "[!] NEXT STEPS:"
echo "    1. View your public key: cat $WG_DIR/publickey"
echo "    2. Find your node Peer ID (if not already done):"
echo "       midnight-node key inspect-node-key --file ~/data/chains/midnight_preprod/network/secret_ed25519"
echo "    3. Send your Public Key, Public IP:Port, and Peer ID to Midnight Foundation."
echo "    4. Once you receive your assigned IP and peer details, run ./configure_wireguard.sh to set up wg0.conf."
echo "========================================================================"