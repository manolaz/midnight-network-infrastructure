# Midnight Pre-Production FNO Node Setup

This repository contains the required setup and automation for operating a Midnight Full Node Operator (FNO) on the pre-production network. 

## Project Structure

```text
.
├── README.md              # Overview, setup instructions, design notes
├── RUNBOOK.md             # Section 1: FNO onboarding steps for Midnight (including DB Sync)
├── SECURITY.md            # Section 4: Key management answers & recommendations
├── monitoring/
│   ├── configs/
│   │   ├── docker-compose.yml  # Prometheus & Grafana stack
│   │   └── prometheus.yml      # Scrape config targeting Midnight node
│   └── alerts/
│       └── node_alerts.yml     # Alert definitions
└── scripts/
    ├── health_check.sh         # Section 3 (Option C): Node health checker automation script
    ├── install_midnight_archive_node.sh # Reproducible automated installation script
    ├── key_collection.sh       # Section 3 (Option A): Key collection script
    └── maintenance_notify.sh   # Section 3 (Option B): Maintenance notification script
```

## Section 1: FNO Onboarding
The full procedure to join the Midnight Pre-Production network as an FNO is documented in **`RUNBOOK.md`**.
*Note: A Midnight node heavily relies on the Cardano network as a partner chain. The runbook clearly outlines the Mithril snapshot and Cardano DB Sync requirements which are absolute prerequisites before spinning up the Midnight node binary.*

**Automated & Reproducible Setup:** To fulfill the requirement of tracking testnet transactions, an automated script is provided in `scripts/install_midnight_archive_node.sh`. This sets up the Substrate binary using `--pruning archive` and exposes the WebSocket RPC endpoints, allowing developers and indexers to trace all historical transactions.

## Section 2: Monitoring & Alerting (Telemetry)
The `monitoring` directory contains a basic `docker-compose` setup to spin up Prometheus and Grafana.

### Alert Design Choices
1. **BlockProductionStalled (Critical):** 
   - **Why:** If the node's block height does not increase for 5 minutes, it is no longer syncing with the network or participating in consensus. This is a critical failure.
   - **Operational Response:** Check if the node process is running, verify external network connectivity, check Cardano DB Sync logs, and restart the node service if necessary.
2. **LowPeerCount (Warning):**
   - **Why:** A healthy peer-to-peer network requires good connectivity. Falling below 5 peers increases the risk of being isolated from the network or missing consensus votes.
   - **Operational Response:** Check firewall rules (Port 30333), verify that bootnodes are reachable, and restart the service if connections appear stale.
3. **HighCpuUsage (Warning):**
   - **Why:** Extended high CPU usage (>85% for 10m) usually points to the node struggling with block processing, an expensive RPC query being spammed, or host exhaustion. 
   - **Operational Response:** Check the host's `htop`, investigate recent RPC requests, and evaluate if a vertical scale up (more cores) is required for the VM.

## Section 3: Automation & Scripting
We have implemented **all three options** to demonstrate comprehensive operational tooling capabilities.

### Option A: Key Collection Script (`scripts/key_collection.sh`)
This script iterates over a list of Mock FNO identifiers, constructs a structured public key request, and records who has responded. 
- **Features:** It is idempotent. Re-running the script will skip operators who have already supplied their keys, and gracefully handle operators who haven't. Results are written cleanly to `scripts/data/key_collection_state.json`.

### Option B: Maintenance Notification (`scripts/maintenance_notify.sh`)
This script constructs a structured JSON notification for a maintenance window and sends it to the FNO list. 
- **Features:** Simulates an acknowledgment system and waits for a configurable timeout (default 5s). Unacknowledged operators are automatically flagged for manual follow-up. 
- **Usage:** `./scripts/maintenance_notify.sh [timeout_in_seconds]`

### Option C: Health Checker (`scripts/health_check.sh`)
This script polls the node's RPC endpoint (`system_health`), parses the JSON response using `jq`, generates a structured health report to disk, and diffs it against the previous run to detect regressions (like peer count drops or sync status degradation).
- **Usage:** `./scripts/health_check.sh [optional_rpc_endpoint]`

## Section 4: Security & Key Management
Answers to the critical security, key rotation, and incident response questions are provided in **`SECURITY.md`**.

## Assumptions & Next Steps
- Assumed `jq`, `curl`, `tar`, and `docker-compose` are installed on the host.
- Assumed standard Substrate Prometheus exporter metrics port `9615` for scraping.
- Assumed that the operator uses a cloud-native environment (AWS/GCP/Azure) and has access to KMS/Secrets managers.
