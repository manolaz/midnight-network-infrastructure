#!/bin/bash
# ==============================================================================
# WireGuard Configuration Script
# Description: Generates the /etc/wireguard/wg0.conf file and starts the 
#              WireGuard interface.
# ==============================================================================

set -euo pipefail
trap 'echo "[!] Error occurred at line $LINENO. Exiting."; exit 1' ERR

if [ "$EUID" -ne 0 ]; then
  echo "[!] Please run as root (sudo ./configure_wireguard.sh)"
  exit 1
fi

# Detect user who ran sudo
SUDO_USER=${SUDO_USER:-$USER}
USER_HOME=$(eval echo "~$SUDO_USER")
WG_DIR="$USER_HOME/wireguard-keys"

if [ ! -f "$WG_DIR/privatekey" ]; then
    echo "[!] Could not find private key at $WG_DIR/privatekey. Did you run install_wireguard.sh?"
    exit 1
fi

PRIVATE_KEY=$(cat "$WG_DIR/privatekey")

echo "[*] WireGuard Configuration Wizard"
echo "Please enter the details provided by the Midnight Foundation."

read -p "Your assigned overlay IP (e.g., 10.0.0.5): " ASSIGNED_IP
if [[ -z "$ASSIGNED_IP" ]]; then echo "IP cannot be empty"; exit 1; fi

read -p "Validator Peer WireGuard Public Key: " PEER_PUBKEY
if [[ -z "$PEER_PUBKEY" ]]; then echo "Public key cannot be empty"; exit 1; fi

read -p "Validator Peer Endpoint (e.g., 198.51.100.10:51820): " PEER_ENDPOINT
if [[ -z "$PEER_ENDPOINT" ]]; then echo "Endpoint cannot be empty"; exit 1; fi

read -p "Validator Peer Overlay IP (e.g., 10.0.0.1): " PEER_OVERLAY_IP
if [[ -z "$PEER_OVERLAY_IP" ]]; then echo "Peer overlay IP cannot be empty"; exit 1; fi

echo "[*] Creating /etc/wireguard/wg0.conf..."
mkdir -p /etc/wireguard
chmod 700 /etc/wireguard

cat <<EOF > /etc/wireguard/wg0.conf
[Interface]
Address = $ASSIGNED_IP/32
PrivateKey = $PRIVATE_KEY
ListenPort = 51820
MTU = 1420

[Peer]
PublicKey = $PEER_PUBKEY
Endpoint = $PEER_ENDPOINT
AllowedIPs = $PEER_OVERLAY_IP/32
PersistentKeepalive = 25
EOF

chmod 600 /etc/wireguard/wg0.conf

echo "[*] Enabling and starting WireGuard (wg0)..."
systemctl enable --now wg-quick@wg0

echo "[*] Current WireGuard status:"
wg show

echo "========================================================================"
echo "[+] WireGuard overlay network configured!"
echo "[*] Connectivity Checklist:"
echo "    - Check 'wg show' for recent handshakes and data transfer."
echo "    - Try pinging the peer: ping $PEER_OVERLAY_IP"
echo "========================================================================"