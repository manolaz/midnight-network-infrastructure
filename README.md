# 🌑 Midnight Network: Infrastructure Automation

[![Midnight Network](https://img.shields.io/badge/Network-Preview_%7C_Pre--Production_%7C_Mainnet-purple.svg)]()
[![Infrastructure](https://img.shields.io/badge/Infrastructure-GCP_Automated-blue.svg)]()
[![Observability](https://img.shields.io/badge/Observability-Prometheus_%7C_Grafana-orange.svg)]()

## 📑 Executive Summary

This repository encapsulates the deployment scripts, operational runbooks, observability stack, and Day-2 automation tooling required to securely operate a **Full Node Operator (FNO)** on the Midnight Networks (Preview, Pre-Production, and Mainnet). 

Designed with production-grade engineering principles, this setup explicitly handles Midnight's architecture as a Cardano Partner Chain. It systematically orchestrates the critical dependencies—Mithril snapshotting, Cardano Relay sync, and PostgreSQL database initialization via `cardano-db-sync`—before bootstrapping the Midnight Substrate runtime.

---

## 🏗 Architecture & Design Philosophy

1. **Dependency Sequencing:** The Midnight node possesses a hard dependency on a synchronized Cardano state. The automation explicitly manages this initialization phase to prevent premature Substrate startup failures.
2. **Data Availability (Archive Mode):** To support local indexers, block explorers, and rigorous testnet transaction tracking, the node defaults to `--pruning archive`. RPC WebSocket endpoints are explicitly exposed with strict CORS boundaries.
3. **Cloud-Native & Idempotent:** Shell scripts are engineered to be `cloud-init` compliant, allowing for zero-touch infrastructure provisioning on cloud providers like Google Cloud Platform (GCP).

---

## 📂 Repository Structure

```text
.
├── README.md                           # Documentation entrypoint (this file)
├── RUNBOOK.md                          # Step-by-step manual FNO onboarding & recovery procedures
├── SECURITY.md                         # Threat modeling, key management & incident response protocols
├── ansible/                            # Infrastructure as Code (Ansible Playbooks)
│   ├── inventory/
│   │   └── hosts.ini
│   ├── setup_node.yml                  # Main playbook
│   └── roles/
│       ├── common/                     # Base dependencies and user management
│       ├── postgres/                   # PostgreSQL 17 configuration & tuning
│       ├── cardano_node/               # Mithril snapshot and Cardano relay config
│       ├── cardano_db_sync/            # Cardano DB Sync daemon integration
│       └── midnight_node/              # Substrate node and archive mode setup
├── monitoring/
│   ├── configs/
│   │   ├── docker-compose.yml          # Containerized telemetry stack (Prometheus + Grafana)
│   │   └── prometheus.yml              # Target configurations for Substrate metric scraping
│   └── alerts/
│       └── node_alerts.yml             # Critical alerting thresholds (Block stalling, CPU, Peers)
└── scripts/
    ├── gcp_deploy.sh                   # GCP VM provisioning & firewall automation
    ├── install_midnight_archive_node.sh # Cloud-Init target: Zero-touch node setup
    ├── health_check.sh                 # Day-2: RPC-based health & regression monitoring (Option C)
    ├── key_collection.sh               # Day-2: Idempotent FNO public key collector (Option A)
    └── maintenance_notify.sh           # Day-2: Automated maintenance notification & ACK tracking (Option B)
```

---

## 🚀 Deployment Operations

### Option 1: Automated Cloud Provisioning (GCP)
For frictionless, reproducible infrastructure, a wrapper script is provided to provision an `e2-standard-4` (Ubuntu 22.04, 500GB SSD) instance on Google Cloud. 

```bash
# Authenticate with Google Cloud
gcloud auth login

# Deploy the FNO stack (Automatically sets up firewalls, VMs, and cloud-init scripts)
./scripts/gcp_deploy.sh [YOUR_PROJECT_ID] [COMPUTE_ZONE]
```
*The VM will boot and immediately execute `install_midnight_archive_node.sh` as `root`, safely configuring the `midnight` user environment and pulling the Mithril snapshots.*

### Option 2: Configuration Management (Ansible)
For on-premise environments, bare-metal clusters, or existing VMs, the entire node setup has been codified into modular Ansible playbooks. This ensures fine-grained idempotency.

```bash
# Run the setup playbook locally (or against remote hosts via inventory)
# Provide the target network via extra-vars: 'preview', 'preprod', or 'mainnet'
ansible-playbook -i ansible/inventory/hosts.ini ansible/setup_node.yml --extra-vars "network=preprod"
```
*The playbook cleanly separates roles (`common`, `postgres`, `cardano_node`, `midnight_node`) so you can run, test, or re-run specific components without state drift.*

### Option 3: Manual / On-Premise Setup
For a step-by-step educational guide on bootstrapping the Cardano dependencies and the Midnight node manually, refer to **[`RUNBOOK.md`](./RUNBOOK.md)**.

---

## 📊 Observability (Telemetry)

Robust visibility into the node's state is non-negotiable for an FNO. The `monitoring/` directory contains a lightweight, containerized telemetry stack.

### Alerting Rationale (`node_alerts.yml`)
Alerts are designed with a high signal-to-noise ratio to prevent alert fatigue:
1. **`BlockProductionStalled` (Critical):** Triggers if `substrate_block_height` remains static for 5 minutes. *Action: Investigate DB Sync connection or restart node service.*
2. **`LowPeerCount` (Warning):** Triggers if `libp2p_peers_count` falls below 5. Substrate consensus degrades rapidly without adequate peer propagation. *Action: Validate port 30333 reachability and bootnode health.*
3. **`HighCpuUsage` (Warning):** Triggers if CPU sustains >85% for 10 minutes. *Action: Check for RPC spam or prepare to vertically scale compute.*

---

## 🤝 Contributing

We welcome contributions from the open-source community! Whether it's adding support for AWS/Azure, improving monitoring dashboards, or fixing typos.

Please see our [CONTRIBUTING.md](CONTRIBUTING.md) for detailed guidelines on how to submit pull requests, run the linters, and utilize the included `Makefile`. We enforce a strict [Code of Conduct](CODE_OF_CONDUCT.md).

---

## 🛠 Day-2 Automation Tools

Operational scripts (located in `scripts/`) are built with idempotency and structured output (JSON) in mind, allowing them to be seamlessly integrated into CI/CD pipelines or cron jobs.

*   **`health_check.sh`**: Polls the local `system_health` RPC endpoint, evaluates peer counts/sync status, and diffs the output against previous runs to detect silent regressions.
*   **`key_collection.sh`**: Iterates through a mock directory of FNOs to request public keys, saving state efficiently so subsequent runs only target non-responsive operators.
*   **`maintenance_notify.sh`**: Simulates sending structured maintenance window alerts, tracks asynchronous acknowledgments, and flags operators who exceed the SLA timeout.

---

## 🔒 Security Posture

Operational security, specifically regarding the generation, storage, and rotation of Validator Session Keys, is detailed in **[`SECURITY.md`](./SECURITY.md)**. 
It covers cloud-native storage (KMS/Secrets Manager), HSM integration tradeoffs, and a strict 3-step Incident Response protocol for compromised credentials.

---

## 📌 Assumptions & Future Work

As a senior engineering implementation, it is important to document assumptions and areas slated for future iteration:

*   **Assumption - Ports:** We assume Prometheus exporter default ports (`9615` for Substrate) remain unmodified.
*   **Assumption - Env:** Designed for Debian/Ubuntu (apt-based) environments.
*   **Future Work - Full IaC:** Transition the bash-based `gcp_deploy.sh` to **Terraform** to manage state, VPCs, and IAM roles more robustly.
