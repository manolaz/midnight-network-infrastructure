.PHONY: help deploy deploy-gcp lint setup-deps pre-commit tf-init tf-plan tf-apply

help:
	@echo "🌑 Midnight Network Infrastructure Makefile"
	@echo ""
	@echo "Usage:"
	@echo "  make deploy network=<network>  - Deploy node locally (options: preview, preprod, mainnet)"
	@echo "  make deploy-gcp                - Deploy a fresh VM on GCP and bootstrap the node"
	@echo "  make lint                      - Run ShellCheck and Ansible Lint (requires local tooling)"
	@echo "  make setup-deps                - Install local development dependencies (Ubuntu/Debian)"
	@echo "  make pre-commit                - Run pre-commit hooks on all files"
	@echo "  make tf-init                   - Initialize Terraform"
	@echo "  make tf-plan                   - Plan Terraform deployment"
	@echo "  make tf-apply                  - Apply Terraform deployment"

setup-deps:
	sudo apt-get update
	sudo apt-get install -y shellcheck python3-pip
	pip3 install ansible-lint pre-commit
	pre-commit install

deploy:
	@if [ -z "$(network)" ]; then echo "Error: network parameter is required. (e.g. make deploy network=preprod)"; exit 1; fi
	./scripts/install_midnight_archive_node.sh $(network)

deploy-gcp:
	./scripts/gcp_deploy.sh

lint:
	@echo "[*] Running ShellCheck..."
	shellcheck scripts/*.sh
	@echo "[*] Running Ansible Lint..."
	ansible-lint scripts/ansible/setup_node.yml
	@echo "[*] Checking Ansible syntax..."
	ansible-playbook --syntax-check -i scripts/ansible/inventory/hosts.ini scripts/ansible/setup_node.yml

pre-commit:
	pre-commit run --all-files

tf-init:
	cd scripts/terraform && terraform init

tf-plan:
	cd scripts/terraform && terraform plan

tf-apply:
	cd scripts/terraform && terraform apply
