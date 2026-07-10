## Describe your changes
<!-- Provide a clear and concise description of what this PR does. -->

## Related Issues
<!-- Link any related open issues (e.g., Fixes #123) -->

## How Has This Been Tested?
<!-- Describe the tests that you ran to verify your changes. Include details about the network target (Preview/Preprod) and OS. -->
- [ ] Local deployment via `make deploy network=preview`
- [ ] Deployed to GCP via `make deploy-gcp`
- [ ] Ansible syntax checks passed

## Checklist:
- [ ] I have read the `CONTRIBUTING.md` document.
- [ ] My code follows the strict bash mode (`set -euo pipefail`).
- [ ] `make lint` passes locally with no new warnings.
- [ ] I have updated the documentation accordingly (`README.md`, `RUNBOOK.md`).