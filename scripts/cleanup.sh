#!/usr/bin/env bash
set -euo pipefail

# Destroy all infrastructure with Terraform
# Usage: ./scripts/cleanup.sh
# Requires confirmation (yes) before destroying

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TF_DIR="${SCRIPT_DIR}/../infra-tf"

echo "==> terraform destroy"
terraform -chdir="$TF_DIR" destroy -auto-approve
