locals {
  bottlerocket_ecr_image_patterns = [
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
    "ecr-public.aws.com",
  ]

  bottlerocket_ecr_bootstrap_script = <<-BASH
    #!/usr/bin/env bash
    set -euo pipefail

    CPC=/.bottlerocket/rootfs/etc/kubernetes/kubelet/credential-provider-config.yaml
    mkdir -p "$(dirname "$CPC")"

    cat > "$CPC" <<'CONFIG'
    apiVersion: kubelet.config.k8s.io/v1
    kind: CredentialProviderConfig
    providers:
      - name: ecr-credential-provider
        matchImages: ${jsonencode(local.bottlerocket_ecr_image_patterns)}
        defaultCacheDuration: "12h0m0s"
        apiVersion: credentialprovider.kubelet.k8s.io/v1
        env:
          - name: HOME
            value: '/root'
        tokenAttributes:
          serviceAccountTokenAudience: sts.amazonaws.com
          cacheType: ServiceAccount
          requireServiceAccount: false
          optionalServiceAccountAnnotationKeys:
            - eks.amazonaws.com/ecr-role-arn
    CONFIG

    grep -q tokenAttributes "$CPC"
    echo "patched $CPC with tokenAttributes"
  BASH
}

module "eks_managed_node_group_bottlerocket" {
  count   = var.use_bottlerocket ? 1 : 0
  source  = "terraform-aws-modules/eks/aws//modules/eks-managed-node-group"
  version = "~> 21.0"

  name               = "bottlerocket"
  cluster_name       = module.eks.cluster_name
  kubernetes_version = var.cluster_version

  cluster_primary_security_group_id = module.eks.cluster_primary_security_group_id
  cluster_service_cidr              = module.eks.cluster_service_cidr
  vpc_security_group_ids            = [module.eks.node_security_group_id]
  subnet_ids                        = module.vpc.private_subnets

  ami_type       = "BOTTLEROCKET_x86_64"
  instance_types = [var.node_instance_type]
  min_size       = 0
  max_size       = 1
  desired_size   = 1

  # Fast node replacement for demo iterations
  update_config = {
    max_unavailable_percentage = 100
  }
  force_update_version = true

  # Same selector label as the AL2023 group so manifest/*.yaml schedules here
  # unchanged, plus a label to tell the two apart when reading `kubectl get pod -o wide`.
  labels = {
    "node.kubernetes.io/ecr-pod-permission" = "true"
    "ecr-pod-permission/ami-family"         = "bottlerocket"
  }

  # EKS injects the [settings.kubernetes] cluster bootstrap settings for
  # Bottlerocket managed node groups and merges them with the TOML below, so we
  # only supply our own settings.
  enable_bootstrap_user_data = false

  bootstrap_extra_args = <<-TOML
    # Ensures kubelet gets --image-credential-provider-config and
    # --image-credential-provider-bin-dir. image-patterns replaces (does not
    # merge with) Bottlerocket's default list.
    [settings.kubernetes.credential-providers.ecr-credential-provider]
    enabled = true
    cache-duration = "12h0m0s"
    image-patterns = ${jsonencode(local.bottlerocket_ecr_image_patterns)}

    # Adds tokenAttributes, which the settings API above cannot express.
    # mode = "always" is required: /etc is a tmpfs, so the file is re-rendered
    # from settings on every boot and must be re-patched every boot.
    # essential = true makes the node fail to come up rather than quietly fall
    # back to node-IAM-role image pulls.
    [settings.bootstrap-containers.ecr-token-attrs]
    mode = "always"
    essential = true
    user-data = "${base64encode(local.bottlerocket_ecr_bootstrap_script)}"
  TOML

  depends_on = [
    kubernetes_cluster_role_binding_v1.kubelet_ecr_credential_provider_audience
  ]
}
