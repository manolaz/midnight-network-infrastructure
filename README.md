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
    └── health_check.sh    # Section 3: Node health checker automation script
```

## Section 1: FNO Onboarding
The full procedure to join the Midnight Pre-Production network as an FNO is documented in **`RUNBOOK.md`**.
*Note: A Midnight node heavily relies on the Cardano network as a partner chain. The runbook clearly outlines the Mithril snapshot and Cardano DB Sync requirements which are absolute prerequisites before spinning up the Midnight node binary.*

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

## Section 3: Automation & Scripting (Health Checker)
We implemented **Option C** (Node Health Checker). 
The script polls the node's RPC endpoint (`system_health`), parses the JSON response using `jq`, generates a structured health report to disk, and diffs it against the previous run to detect regressions (like peer count drops or sync status degradation).

### Usage Instructions
Ensure you have `curl` and `jq` installed on your machine.
```bash
# Make it executable
chmod +x scripts/health_check.sh

# Run the script (defaults to http://localhost:9944)
./scripts/health_check.sh

# Run against a specific RPC endpoint
./scripts/health_check.sh http://my-node-ip:9944
```

## Section 4: Security & Key Management
Answers to the critical security, key rotation, and incident response questions are provided in **`SECURITY.md`**.

## Assumptions & Next Steps
- Assumed `jq`, `curl`, `tar`, and `docker-compose` are installed on the host.
- Assumed standard Substrate Prometheus exporter metrics port `9615` for scraping.
- Assumed that the operator uses a cloud-native environment (AWS/GCP/Azure) and has access to KMS/Secrets managers.
- **If I had more time:** I would write an Ansible playbook or Terraform modules to fully automate the provisioning of the host, Cardano DB Sync, and the Midnight node, rather than just providing a bash runbook.
