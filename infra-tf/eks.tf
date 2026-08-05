# -----------------------------------------------------------------------------
# EKS Cluster — Managed Node Group with per-pod ECR credential provider
# Uses terraform-aws-modules/eks/aws v21.x
# The ecr-credential-provider uses IRSA (AssumeRoleWithWebIdentity) for
# per-pod image pull credentials — not EKS Pod Identity.
# -----------------------------------------------------------------------------

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name               = var.cluster_name
  kubernetes_version = var.cluster_version

  addons = {
    kube-proxy = {}
    vpc-cni    = { before_compute = true }
  }

  # Cluster access
  endpoint_public_access                   = true
  enable_cluster_creator_admin_permissions = true

  # Networking
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

}

# -----------------------------------------------------------------------------
# RBAC — Audience permission for kubelet SA token projection
# Must be applied BEFORE nodes join so the kubelet can request SA tokens
# with the "sts.amazonaws.com" audience for the credential provider.
# -----------------------------------------------------------------------------

resource "kubernetes_cluster_role" "ecr_credential_provider_audience" {
  metadata {
    name = "ecr-credential-provider-audience"
  }

  rule {
    verbs      = ["request-serviceaccounts-token-audience"]
    api_groups = [""]
    resources  = ["sts.amazonaws.com"]
  }
}

resource "kubernetes_cluster_role_binding" "kubelet_ecr_credential_provider_audience" {
  metadata {
    name = "kubelet-ecr-credential-provider-audience"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.ecr_credential_provider_audience.metadata[0].name
  }

  subject {
    kind      = "Group"
    name      = "system:nodes"
    api_group = "rbac.authorization.k8s.io"
  }
}

# -----------------------------------------------------------------------------
# Managed Node Group — created after RBAC audience permissions
# Uses the EKS module's cluster but managed as a separate resource to
# guarantee ordering: cluster → RBAC → node group.
# -----------------------------------------------------------------------------

module "eks_managed_node_group" {
  source  = "terraform-aws-modules/eks/aws//modules/eks-managed-node-group"
  version = "~> 21.0"

  name               = "default"
  cluster_name       = module.eks.cluster_name
  kubernetes_version = var.cluster_version

  cluster_primary_security_group_id = module.eks.cluster_primary_security_group_id
  cluster_service_cidr              = module.eks.cluster_service_cidr
  vpc_security_group_ids            = [module.eks.node_security_group_id]
  subnet_ids                        = module.vpc.private_subnets

  ami_type       = "AL2023_x86_64_STANDARD"
  instance_types = [var.node_instance_type]
  min_size       = 0
  max_size       = 1
  desired_size   = 1

  # Fast node replacement for demo iterations
  update_config = {
    max_unavailable_percentage = 100
  }
  force_update_version = true

  labels = {
    "node.kubernetes.io/ecr-pod-permission" = "true"
  }

  # Supply NodeConfig (endpoint, CA, CIDR) in user data so nodes
  # don't call DescribeCluster at boot — avoids API throttling.
  enable_bootstrap_user_data = true

  cloudinit_pre_nodeadm = [
    // {
    //   content_type = "application/node.eks.aws"
    //   content      = <<-EOT
    //     ---
    //     apiVersion: node.eks.aws/v1alpha1
    //     kind: NodeConfig
    //     spec:
    //       kubelet:
    //         flags:
    //           - --v=5
    //   EOT
    // },
    {
      content_type = "text/x-shellscript; charset=\"us-ascii\""
      content      = <<-EOT
        #!/bin/bash
        set -ex

        cat > /etc/eks/image-credential-provider/config.json <<'CONFIG'
        {
          "apiVersion": "kubelet.config.k8s.io/v1",
          "kind": "CredentialProviderConfig",
          "providers": [
            {
              "name": "ecr-credential-provider",
              "matchImages": [
                "*.dkr.ecr.*.amazonaws.com",
                "*.dkr-ecr.*.on.aws",
                "*.dkr.ecr.*.amazonaws.com.cn",
                "*.dkr-ecr.*.on.amazonwebservices.com.cn",
                "*.dkr.ecr-fips.*.amazonaws.com",
                "*.dkr-ecr-fips.*.on.aws",
                "*.dkr.ecr.*.c2s.ic.gov",
                "*.dkr.ecr.*.sc2s.sgov.gov",
                "*.dkr.ecr.*.cloud.adc-e.uk",
                "*.dkr.ecr.*.csp.hci.ic.gov",
                "*.dkr.ecr.*.amazonaws.eu",
                "public.ecr.aws",
                "ecr-public.aws.com"
              ],
              "defaultCacheDuration": "12h0m0s",
              "apiVersion": "credentialprovider.kubelet.k8s.io/v1",
              "tokenAttributes": {
                "serviceAccountTokenAudience": "sts.amazonaws.com",
                "cacheType": "ServiceAccount",
                "requireServiceAccount": false,
                "optionalServiceAccountAnnotationKeys": [
                  "eks.amazonaws.com/ecr-role-arn"
                ]
              }
            }
          ]
        }
        CONFIG
      EOT
    }
  ]

  depends_on = [
    kubernetes_cluster_role_binding.kubelet_ecr_credential_provider_audience
  ]
}

# -----------------------------------------------------------------------------
# CoreDNS Addon — deployed after the node group is available
# CoreDNS needs running nodes to schedule its pods. By depending on the node
# group module, we ensure nodes exist before CoreDNS attempts to schedule.
# -----------------------------------------------------------------------------

resource "aws_eks_addon" "coredns" {
  cluster_name = module.eks.cluster_name
  addon_name   = "coredns"

  depends_on = [
    module.eks_managed_node_group
  ]
}

