#!/usr/bin/env bash
set -euo pipefail

# Push nginx images to all four ECR namespaces: shared, team-a, team-b, baseline
# Usage: ./scripts/build-push-images.sh
# Requires: aws cli + one of: docker, podman, finch

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TF_DIR="${SCRIPT_DIR}/../infra-tf"

# Get values from Terraform outputs
ACCOUNT_ID=$(terraform -chdir="$TF_DIR" output -raw aws_account_id)
REGION=$(terraform -chdir="$TF_DIR" output -raw aws_region)
ECR_REGISTRY="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"

# Detect container runtime
if command -v docker &>/dev/null; then
  RUNTIME=docker
elif command -v finch &>/dev/null; then
  RUNTIME=finch
elif command -v podman &>/dev/null; then
  RUNTIME=podman
else
  echo "ERROR: No container runtime found. Install docker, podman, or finch." >&2
  exit 1
fi
echo "Using container runtime: $RUNTIME"

# Authenticate to ECR
aws ecr get-login-password --region "$REGION" | \
  $RUNTIME login --username AWS --password-stdin "$ECR_REGISTRY"

# Pull nginx image (linux/amd64 for EKS nodes)
$RUNTIME pull --platform linux/amd64 public.ecr.aws/nginx/nginx:latest

# Tag and push to all four ECR repos
REPOS=("shared/app" "team-a/app" "team-b/app" "baseline/app")

for repo in "${REPOS[@]}"; do
  $RUNTIME tag public.ecr.aws/nginx/nginx:latest "${ECR_REGISTRY}/${repo}:latest"
  if [[ "$RUNTIME" == "docker" ]]; then
    $RUNTIME push "${ECR_REGISTRY}/${repo}:latest"
  else
    $RUNTIME push --platform linux/amd64 "${ECR_REGISTRY}/${repo}:latest"
  fi
done

echo "Done. Images pushed to all repos: shared/app, team-a/app, team-b/app, baseline/app."
