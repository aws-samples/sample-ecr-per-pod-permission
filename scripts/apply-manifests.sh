#!/usr/bin/env bash
set -euo pipefail

# Apply or delete K8s manifests with envsubst variable replacement
# Usage:
#   ./scripts/apply-manifests.sh          # apply all
#   ./scripts/apply-manifests.sh apply    # apply all
#   ./scripts/apply-manifests.sh delete   # delete all

ACTION="${1:-apply}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TF_DIR="${SCRIPT_DIR}/../infra-tf"
MANIFEST_DIR="${SCRIPT_DIR}/../manifest"

# Get values from Terraform outputs
export ACCOUNT_ID=$(terraform -chdir="$TF_DIR" output -raw aws_account_id)
export REGION=$(terraform -chdir="$TF_DIR" output -raw aws_region)
export CLUSTER_NAME=$(terraform -chdir="$TF_DIR" output -raw cluster_name)
export ECR_SHARED_REPO_URL=$(terraform -chdir="$TF_DIR" output -raw ecr_shared_repo_url)
export ECR_TEAM_A_REPO_URL=$(terraform -chdir="$TF_DIR" output -raw ecr_team_a_repo_url)
export ECR_TEAM_B_REPO_URL=$(terraform -chdir="$TF_DIR" output -raw ecr_team_b_repo_url)
export ECR_BASELINE_REPO_URL=$(terraform -chdir="$TF_DIR" output -raw ecr_baseline_repo_url)
export ECR_PULL_ROLE_ARN_TEAM_A=$(terraform -chdir="$TF_DIR" output -raw ecr_pull_role_arn_team_a)
export ECR_PULL_ROLE_ARN_TEAM_B=$(terraform -chdir="$TF_DIR" output -raw ecr_pull_role_arn_team_b)

ENVSUBST_VARS='${ACCOUNT_ID} ${REGION} ${CLUSTER_NAME} ${ECR_SHARED_REPO_URL} ${ECR_TEAM_A_REPO_URL} ${ECR_TEAM_B_REPO_URL} ${ECR_BASELINE_REPO_URL} ${ECR_PULL_ROLE_ARN_TEAM_A} ${ECR_PULL_ROLE_ARN_TEAM_B}'

echo "ACCOUNT_ID=$ACCOUNT_ID  REGION=$REGION  CLUSTER_NAME=$CLUSTER_NAME  ACTION=$ACTION"
echo "ECR_SHARED_REPO_URL=$ECR_SHARED_REPO_URL"
echo "ECR_TEAM_A_REPO_URL=$ECR_TEAM_A_REPO_URL"
echo "ECR_TEAM_B_REPO_URL=$ECR_TEAM_B_REPO_URL"
echo "ECR_BASELINE_REPO_URL=$ECR_BASELINE_REPO_URL"
echo "ECR_PULL_ROLE_ARN_TEAM_A=$ECR_PULL_ROLE_ARN_TEAM_A"
echo "ECR_PULL_ROLE_ARN_TEAM_B=$ECR_PULL_ROLE_ARN_TEAM_B"

# Apply namespaces first (on apply) or last (on delete)
if [ "$ACTION" = "apply" ]; then
  echo "==> $ACTION namespaces.yaml"
  envsubst "$ENVSUBST_VARS" < "$MANIFEST_DIR/namespaces.yaml" | kubectl "$ACTION" -f -

  for f in "$MANIFEST_DIR"/team-*.yaml "$MANIFEST_DIR"/node-role-*.yaml; do
    echo "==> $ACTION $(basename "$f")"
    envsubst "$ENVSUBST_VARS" < "$f" | kubectl "$ACTION" -f -
  done
else
  for f in "$MANIFEST_DIR"/team-*.yaml "$MANIFEST_DIR"/node-role-*.yaml; do
    echo "==> $ACTION $(basename "$f")"
    envsubst "$ENVSUBST_VARS" < "$f" | kubectl "$ACTION" -f - || true
  done

  echo "==> $ACTION namespaces.yaml"
  envsubst "$ENVSUBST_VARS" < "$MANIFEST_DIR/namespaces.yaml" | kubectl "$ACTION" -f - || true
fi
