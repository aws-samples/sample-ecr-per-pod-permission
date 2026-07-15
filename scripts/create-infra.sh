#!/usr/bin/env bash
set -euo pipefail

# Provision all infrastructure with Terraform
# Usage: ./scripts/create-infra.sh
# Requires confirmation (yes) before applying

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TF_DIR="${SCRIPT_DIR}/../infra-tf"

echo "==> terraform init"
terraform -chdir="$TF_DIR" init

echo ""
echo "==> terraform apply"
terraform -chdir="$TF_DIR" apply -auto-approve
