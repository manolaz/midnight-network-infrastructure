# Terraform Infrastructure Provisioning

This directory contains the Terraform configuration to provision a Google Cloud Platform (GCP) compute instance configured to run a Midnight Archive Node.

## Overview

The Terraform code will automatically:
1.  Configure the required GCP Provider.
2.  Set up a VPC and subnet for the node (if applicable).
3.  Configure Firewall rules to allow necessary ingress (P2P ports) and SSH access.
4.  Provision a dedicated Service Account.
5.  Launch an `e2-standard-4` (Ubuntu 24.04) Compute Engine instance.
6.  Inject the `install_midnight_archive_node.sh` as a `cloud-init` startup script to fully bootstrap the node automatically on boot.

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/downloads) (v1.5.0 or later recommended).
- [Google Cloud SDK (`gcloud`)](https://cloud.google.com/sdk/docs/install).
- A valid Google Cloud Project with the Compute Engine API enabled.

## Authentication

Ensure you have authenticated your local environment with GCP:

```bash
gcloud auth application-default login
```

## Variables

The following variables can be customized via the command line (`-var="key=value"`) or a `terraform.tfvars` file:

| Name | Description | Default | Required |
|------|-------------|---------|:--------:|
| `project_id` | The GCP Project ID where resources will be created. | *none* | **Yes** |
| `region` | The GCP Region. | `us-central1` | No |
| `zone` | The GCP Zone. | `us-central1-a` | No |
| `target_network` | The Midnight network to target (`preview`, `preprod`, `mainnet`). | `preprod` | No |
| `machine_type` | The Compute Engine machine type. | `e2-standard-4` | No |

## Usage

1. **Initialize the working directory:**
   ```bash
   terraform init
   ```

2. **Review the deployment plan:**
   ```bash
   terraform plan -var="project_id=YOUR_PROJECT_ID"
   ```

3. **Apply the configuration:**
   ```bash
   terraform apply -var="project_id=YOUR_PROJECT_ID" -var="target_network=preprod"
   ```

## Outputs

After a successful deployment, Terraform will output:
- `instance_public_ip`: The external IP address of the provisioned node.
- `ssh_command`: A pre-formatted `gcloud compute ssh` command to quickly access the instance.

*Note: The node will begin downloading the Mithril snapshots and syncing the database immediately after boot via the cloud-init script. This process can take several hours depending on the network.*