.PHONY: help deploy deploy-gcp lint setup-deps

help:
	@echo "🌑 Midnight Network Infrastructure Makefile"
	@echo ""
	@echo "Usage:"
	@echo "  make deploy network=<network>  - Deploy node locally (options: preview, preprod, mainnet)"
	@echo "  make deploy-gcp                - Deploy a fresh VM on GCP and bootstrap the node"
	@echo "  make lint                      - Run ShellCheck and Ansible Lint (requires local tooling)"
	@echo "  make setup-deps                - Install local development dependencies (Ubuntu/Debian)"

setup-deps:
	sudo apt-get update
	sudo apt-get install -y shellcheck python3-pip
	pip3 install ansible-lint

deploy:
	@if [ -z "$(network)" ]; then echo "Error: network parameter is required. (e.g. make deploy network=preprod)"; exit 1; fi
	./scripts/install_midnight_archive_node.sh $(network)

deploy-gcp:
	./scripts/gcp_deploy.sh

lint:
	@echo "[*] Running ShellCheck..."
	shellcheck scripts/*.sh
	@echo "[*] Running Ansible Lint..."
	ansible-lint ansible/setup_node.yml