# -----------------------------------------------------------------------------
# IRSA Role — team-a: identity for team-a pods
# ECR pull permissions come from the repo policy on team-a/*, not this role.
# This role only needs ecr:GetAuthorizationToken (account-level, not repo-scoped).
# -----------------------------------------------------------------------------

resource "aws_iam_role" "irsa_ecr_team_a" {
  name = "${var.cluster_name}-irsa-ecr-team-a"
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

resource "aws_iam_policy" "irsa_ecr_team_a" {
  name = "${var.cluster_name}-irsa-ecr-team-a"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["ecr:GetAuthorizationToken"]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "irsa_ecr_team_a" {
  role       = aws_iam_role.irsa_ecr_team_a.name
  policy_arn = aws_iam_policy.irsa_ecr_team_a.arn
}

# -----------------------------------------------------------------------------
# IRSA Role — team-b: identity for team-b pods
# ECR pull permissions come from the repo policy on team-b/*, not this role.
# This role only needs ecr:GetAuthorizationToken (account-level, not repo-scoped).
# -----------------------------------------------------------------------------

resource "aws_iam_role" "irsa_ecr_team_b" {
  name = "${var.cluster_name}-irsa-ecr-team-b"
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

resource "aws_iam_policy" "irsa_ecr_team_b" {
  name = "${var.cluster_name}-irsa-ecr-team-b"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["ecr:GetAuthorizationToken"]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "irsa_ecr_team_b" {
  role       = aws_iam_role.irsa_ecr_team_b.name
  policy_arn = aws_iam_policy.irsa_ecr_team_b.arn
}