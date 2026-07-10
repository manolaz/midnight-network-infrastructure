# AWS Terraform Infrastructure Provisioning

This directory contains the Terraform configuration to provision an Amazon Web Services (AWS) EC2 instance configured to run a Midnight Archive Node.

## Overview

The Terraform code will automatically:
1.  Configure the required AWS Provider.
2.  Set up a Security Group in the default VPC (or a specified VPC) to allow necessary ingress (P2P ports 30333/3001) and SSH access.
3.  Provision an IAM Role with SSM access.
4.  Launch a `t3.xlarge` (Ubuntu 22.04) EC2 instance with a 500GB gp3 EBS volume.
5.  Inject the `install_midnight_archive_node.sh` as an EC2 `user_data` script to fully bootstrap the node automatically on boot.

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/downloads) (v1.5.0 or later recommended).
- [AWS CLI](https://aws.amazon.com/cli/).
- AWS credentials configured locally (e.g., via `aws configure`).
- An existing AWS Key Pair in the target region for SSH access.

## Authentication

Ensure you have authenticated your local environment with AWS:

```bash
aws configure
```

## Variables

The following variables can be customized via the command line (`-var="key=value"`) or a `terraform.tfvars` file:

| Name | Description | Default | Required |
|------|-------------|---------|:--------:|
| `aws_region` | The AWS Region where resources will be created. | `us-east-1` | No |
| `key_name` | Name of an existing AWS Key Pair to allow SSH access. | *none* | **Yes** |
| `target_network` | The Midnight network to target (`preview`, `preprod`, `mainnet`). | `preprod` | No |
| `instance_type` | The EC2 instance type. | `t3.xlarge` | No |
| `vpc_id` | ID of the VPC to deploy into. Leave blank to use Default VPC. | `""` | No |

## Usage

1. **Initialize the working directory:**
   ```bash
   terraform init
   ```

2. **Review the deployment plan:**
   ```bash
   terraform plan -var="key_name=YOUR_KEY_PAIR_NAME"
   ```

3. **Apply the configuration:**
   ```bash
   terraform apply -var="key_name=YOUR_KEY_PAIR_NAME" -var="target_network=preprod"
   ```

## Outputs

After a successful deployment, Terraform will output:
- `instance_public_ip`: The external IP address of the provisioned node.
- `ssh_command`: A pre-formatted `ssh` command to quickly access the instance.

*Note: The node will begin downloading the Mithril snapshots and syncing the database immediately after boot via the user_data script. This process can take several hours depending on the network.*