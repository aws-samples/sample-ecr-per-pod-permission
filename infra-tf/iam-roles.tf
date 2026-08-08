# -----------------------------------------------------------------------------
# ECR pull role — team-a: identity for team-a pods
# Uses AWS-managed AmazonEC2ContainerRegistryPullOnly policy.
# Per-repo scoping is enforced via ECR repository policies.
# -----------------------------------------------------------------------------

resource "aws_iam_role" "ecr_pull_team_a" {
  name = "${var.cluster_name}-ecr-pull-team-a"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = module.eks.oidc_provider_arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${module.eks.oidc_provider}:aud" = "sts.amazonaws.com"
        }
        StringLike = {
          "${module.eks.oidc_provider}:sub" = "system:serviceaccount:team-a:*"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecr_pull_team_a" {
  role       = aws_iam_role.ecr_pull_team_a.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPullOnly"
}

# -----------------------------------------------------------------------------
# ECR pull role — team-b: identity for team-b pods
# Uses AWS-managed AmazonEC2ContainerRegistryPullOnly policy.
# Per-repo scoping is enforced via ECR repository policies.
# -----------------------------------------------------------------------------

resource "aws_iam_role" "ecr_pull_team_b" {
  name = "${var.cluster_name}-ecr-pull-team-b"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = module.eks.oidc_provider_arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${module.eks.oidc_provider}:aud" = "sts.amazonaws.com"
        }
        StringLike = {
          "${module.eks.oidc_provider}:sub" = "system:serviceaccount:team-b:*"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecr_pull_team_b" {
  role       = aws_iam_role.ecr_pull_team_b.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPullOnly"
}