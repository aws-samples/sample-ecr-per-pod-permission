#!/bin/bash
set -euo pipefail

CLUSTER_NAME="ecr-pod-permission-demo"
REGION="us-east-1"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

echo "=== Cleaning up resources for: $CLUSTER_NAME in $REGION (Account: $ACCOUNT_ID) ==="

# -------------------------------------------------------------
# 1. Delete EKS Addon (CoreDNS)
# -------------------------------------------------------------
echo "[1/9] Deleting CoreDNS addon..."
aws eks delete-addon \
  --cluster-name "$CLUSTER_NAME" \
  --addon-name coredns \
  --region "$REGION" 2>/dev/null || echo "  CoreDNS addon not found or already deleted"

# -------------------------------------------------------------
# 2. Delete Kubernetes RBAC resources
# -------------------------------------------------------------
echo "[2/9] Deleting RBAC resources..."
aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$REGION" 2>/dev/null && {
  kubectl delete clusterrolebinding kubelet-ecr-credential-provider-audience 2>/dev/null || true
  kubectl delete clusterrole ecr-credential-provider-audience 2>/dev/null || true
} || echo "  Could not connect to cluster (may already be deleted)"

# -------------------------------------------------------------
# 3. Delete EKS Managed Node Group
# -------------------------------------------------------------
echo "[3/9] Deleting node group 'default'..."
aws eks delete-nodegroup \
  --cluster-name "$CLUSTER_NAME" \
  --nodegroup-name default \
  --region "$REGION" 2>/dev/null || echo "  Node group not found or already deleted"

echo "  Waiting for node group deletion..."
aws eks wait nodegroup-deleted \
  --cluster-name "$CLUSTER_NAME" \
  --nodegroup-name default \
  --region "$REGION" 2>/dev/null || true

# -------------------------------------------------------------
# 4. Delete EKS Cluster
# -------------------------------------------------------------
echo "[4/9] Deleting EKS cluster..."
aws eks delete-cluster \
  --name "$CLUSTER_NAME" \
  --region "$REGION" 2>/dev/null || echo "  Cluster not found or already deleted"

echo "  Waiting for cluster deletion..."
aws eks wait cluster-deleted \
  --name "$CLUSTER_NAME" \
  --region "$REGION" 2>/dev/null || true

# -------------------------------------------------------------
# 5. Delete OIDC Provider
# -------------------------------------------------------------
echo "[5/9] Deleting OIDC provider..."
for OIDC_ARN in $(aws iam list-open-id-connect-providers --query "OpenIDConnectProviderList[].Arn" --output text); do
  if echo "$OIDC_ARN" | grep -q "oidc.eks.${REGION}"; then
    echo "  Deleting: $OIDC_ARN"
    aws iam delete-open-id-connect-provider --open-id-connect-provider-arn "$OIDC_ARN"
  fi
done

# -------------------------------------------------------------
# 6. Delete ECR pull IAM Roles & Policies
# -------------------------------------------------------------
echo "[6/9] Deleting ECR pull roles and policies..."
for TEAM in team-a team-b; do
  ROLE_NAME="${CLUSTER_NAME}-ecr-pull-${TEAM}"
  POLICY_ARN="arn:aws:iam::${ACCOUNT_ID}:policy/${CLUSTER_NAME}-ecr-pull-${TEAM}"

  aws iam detach-role-policy --role-name "$ROLE_NAME" --policy-arn "$POLICY_ARN" 2>/dev/null || true
  aws iam delete-policy --policy-arn "$POLICY_ARN" 2>/dev/null || true
  aws iam delete-role --role-name "$ROLE_NAME" 2>/dev/null || true
  echo "  Deleted: $ROLE_NAME"
done

# -------------------------------------------------------------
# 7. Delete EKS module IAM Roles (cluster + node group)
# -------------------------------------------------------------
echo "[7/9] Deleting EKS module IAM roles..."
for ROLE_PREFIX in "${CLUSTER_NAME}-cluster" "default-eks-node-group"; do
  for ROLE_NAME in $(aws iam list-roles --query "Roles[?starts_with(RoleName, '${ROLE_PREFIX}')].RoleName" --output text); do
    echo "  Cleaning up role: $ROLE_NAME"
    for POLICY_ARN in $(aws iam list-attached-role-policies --role-name "$ROLE_NAME" --query "AttachedPolicies[].PolicyArn" --output text); do
      aws iam detach-role-policy --role-name "$ROLE_NAME" --policy-arn "$POLICY_ARN"
    done
    for POLICY_NAME in $(aws iam list-role-policies --role-name "$ROLE_NAME" --query "PolicyNames[]" --output text); do
      aws iam delete-role-policy --role-name "$ROLE_NAME" --policy-name "$POLICY_NAME"
    done
    aws iam delete-role --role-name "$ROLE_NAME"
  done
done

# -------------------------------------------------------------
# 8. Delete ECR Repositories
# -------------------------------------------------------------
echo "[8/9] Deleting ECR repositories..."
aws ecr delete-repository --repository-name "shared/app" --force --region "$REGION" 2>/dev/null || true
aws ecr delete-repository --repository-name "team-a/app" --force --region "$REGION" 2>/dev/null || true
aws ecr delete-repository --repository-name "team-b/app" --force --region "$REGION" 2>/dev/null || true
aws ecr delete-repository --repository-name "baseline/app" --force --region "$REGION" 2>/dev/null || true
echo "  ECR repositories deleted"

# -------------------------------------------------------------
# 9. Delete VPC and all sub-resources
# -------------------------------------------------------------
echo "[9/9] Deleting VPC..."
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=${CLUSTER_NAME}-vpc" --query "Vpcs[0].VpcId" --output text --region "$REGION")

if [ "$VPC_ID" != "None" ] && [ -n "$VPC_ID" ]; then
  echo "  Found VPC: $VPC_ID"

  # Delete NAT Gateways
  for NAT_GW in $(aws ec2 describe-nat-gateways --filter "Name=vpc-id,Values=$VPC_ID" --query "NatGateways[?State!='deleted'].NatGatewayId" --output text --region "$REGION"); do
    echo "  Deleting NAT Gateway: $NAT_GW"
    aws ec2 delete-nat-gateway --nat-gateway-id "$NAT_GW" --region "$REGION"
  done

  echo "  Waiting for NAT Gateway(s) to delete..."
  sleep 60

  # Release Elastic IPs
  for ALLOC_ID in $(aws ec2 describe-addresses --filters "Name=tag:Name,Values=*${CLUSTER_NAME}*" --query "Addresses[].AllocationId" --output text --region "$REGION"); do
    echo "  Releasing EIP: $ALLOC_ID"
    aws ec2 release-address --allocation-id "$ALLOC_ID" --region "$REGION"
  done

  # Delete subnets
  for SUBNET_ID in $(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" --query "Subnets[].SubnetId" --output text --region "$REGION"); do
    echo "  Deleting subnet: $SUBNET_ID"
    aws ec2 delete-subnet --subnet-id "$SUBNET_ID" --region "$REGION"
  done

  # Detach and delete Internet Gateway
  for IGW_ID in $(aws ec2 describe-internet-gateways --filters "Name=attachment.vpc-id,Values=$VPC_ID" --query "InternetGateways[].InternetGatewayId" --output text --region "$REGION"); do
    echo "  Deleting Internet Gateway: $IGW_ID"
    aws ec2 detach-internet-gateway --internet-gateway-id "$IGW_ID" --vpc-id "$VPC_ID" --region "$REGION"
    aws ec2 delete-internet-gateway --internet-gateway-id "$IGW_ID" --region "$REGION"
  done

  # Delete route tables (non-main)
  for RT_ID in $(aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$VPC_ID" --query "RouteTables[?Associations[0].Main!=\`true\`].RouteTableId" --output text --region "$REGION"); do
    for ASSOC_ID in $(aws ec2 describe-route-tables --route-table-ids "$RT_ID" --query "RouteTables[0].Associations[?!Main].RouteTableAssociationId" --output text --region "$REGION"); do
      aws ec2 disassociate-route-table --association-id "$ASSOC_ID" --region "$REGION"
    done
    echo "  Deleting route table: $RT_ID"
    aws ec2 delete-route-table --route-table-id "$RT_ID" --region "$REGION"
  done

  # Delete security groups (non-default)
  for SG_ID in $(aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$VPC_ID" --query "SecurityGroups[?GroupName!='default'].GroupId" --output text --region "$REGION"); do
    echo "  Deleting security group: $SG_ID"
    aws ec2 delete-security-group --group-id "$SG_ID" --region "$REGION"
  done

  # Delete VPC
  echo "  Deleting VPC: $VPC_ID"
  aws ec2 delete-vpc --vpc-id "$VPC_ID" --region "$REGION"
else
  echo "  VPC not found (already deleted?)"
fi

echo ""
echo "=== Cleanup complete! ==="