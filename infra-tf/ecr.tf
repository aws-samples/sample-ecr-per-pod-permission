data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# -----------------------------------------------------------------------------
# ECR Repositories — three namespaces: shared, team-a, team-b
# -----------------------------------------------------------------------------

resource "aws_ecr_repository" "shared_nginx" {
  name                 = "shared/nginx"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  encryption_configuration {
    encryption_type = "KMS"
  }

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_repository" "team_a_nginxa" {
  name                 = "team-a/nginxa"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  encryption_configuration {
    encryption_type = "KMS"
  }

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_repository" "team_b_nginxb" {
  name                 = "team-b/nginxb"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  encryption_configuration {
    encryption_type = "KMS"
  }

  image_scanning_configuration {
    scan_on_push = true
  }
}

# -----------------------------------------------------------------------------
# ECR Repository Policies — team namespaces accessible only by their IRSA role
# -----------------------------------------------------------------------------

resource "aws_ecr_repository_policy" "team_a_nginxa" {
  repository = aws_ecr_repository.team_a_nginxa.name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowTeamAIRSARoleOnly"
        Effect    = "Allow"
        Principal = { AWS = aws_iam_role.irsa_ecr_team_a.arn }
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:BatchGetImage",
          "ecr:GetDownloadUrlForLayer"
        ]
      },
      {
        Sid       = "AllowPushAccess"
        Effect    = "Allow"
        Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/Admin" }
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:CompleteLayerUpload",
          "ecr:InitiateLayerUpload",
          "ecr:PutImage",
          "ecr:UploadLayerPart"
        ]
      },
      {
        Sid       = "DenyAllOthers"
        Effect    = "Deny"
        Principal = "*"
        Action    = "ecr:*"
        Condition = {
          StringNotEquals = {
            "aws:PrincipalArn" = [
              aws_iam_role.irsa_ecr_team_a.arn,
              "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/Admin"
            ]
          }
        }
      }
    ]
  })
}

resource "aws_ecr_repository_policy" "team_b_nginxb" {
  repository = aws_ecr_repository.team_b_nginxb.name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowTeamBIRSARoleOnly"
        Effect    = "Allow"
        Principal = { AWS = aws_iam_role.irsa_ecr_team_b.arn }
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:BatchGetImage",
          "ecr:GetDownloadUrlForLayer"
        ]
      },
      {
        Sid       = "AllowPushAccess"
        Effect    = "Allow"
        Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/Admin" }
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:CompleteLayerUpload",
          "ecr:InitiateLayerUpload",
          "ecr:PutImage",
          "ecr:UploadLayerPart"
        ]
      },
      {
        Sid       = "DenyAllOthers"
        Effect    = "Deny"
        Principal = "*"
        Action    = "ecr:*"
        Condition = {
          StringNotEquals = {
            "aws:PrincipalArn" = [
              aws_iam_role.irsa_ecr_team_b.arn,
              "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/Admin"
            ]
          }
        }
      }
    ]
  })
}
