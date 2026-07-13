# Contributing to Midnight Network Infrastructure

First off, thank you for considering contributing to the Midnight Network Infrastructure repository! It's people like you that make open-source communities thrive.

## Getting Started

1. **Fork the repository** on GitHub.
2. **Clone your fork** locally: `git clone https://github.com/manolaz/midnight-network-infrastructure.git`
3. **Create a branch** for your feature or bug fix: `git checkout -b feature/my-new-feature`

## Development Workflow

### Code Quality & Standards

We maintain high standards for infrastructure-as-code to ensure production readiness:

- **Bash Scripts:** Must be linted with `shellcheck`. Use strict modes (`set -euo pipefail`).
- **Ansible Playbooks:** Must be linted with `ansible-lint`. Keep roles modular and use idempotency.

### Testing Locally

We provide a `Makefile` to simplify local development and testing.

```bash
# Run linters locally before pushing
make lint

# Test the setup script locally (in a VM or isolated environment)
make deploy network=preview
```

## Pull Request Process

1. Ensure your branch is rebased against the latest `main` branch.
2. Ensure `make lint` passes without any errors.
3. Open a Pull Request using the provided PR template.
4. Describe your changes in detail, explaining *why* the change was made and *how* you tested it.
5. A maintainer will review your code. Please address any requested changes promptly.
6. Please note that all contributors must adhere to our [Code of Conduct](../../CODE_OF_CONDUCT.md).

## Reporting Issues

If you encounter a bug or have a feature request, please use the provided Issue Templates in the `.github/ISSUE_TEMPLATE` folder. Provide as much context as possible (OS version, network target, logs).
