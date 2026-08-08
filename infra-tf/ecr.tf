data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# -----------------------------------------------------------------------------
# ECR Repositories — four namespaces: shared, team-a, team-b, baseline
# -----------------------------------------------------------------------------

resource "aws_ecr_repository" "shared_repo" {
  name                 = "shared/app"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  encryption_configuration {
    encryption_type = "KMS"
  }

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_repository" "team_a_repo" {
  name                 = "team-a/app"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  encryption_configuration {
    encryption_type = "KMS"
  }

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_repository" "team_b_repo" {
  name                 = "team-b/app"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  encryption_configuration {
    encryption_type = "KMS"
  }

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_repository" "baseline_repo" {
  name                 = "baseline/app"
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
# ECR Repository Policies
# -----------------------------------------------------------------------------

resource "aws_ecr_repository_policy" "team_a_repo" {
  repository = aws_ecr_repository.team_a_repo.name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyAllExceptTeamAAndAdmin"
        Effect    = "Deny"
        Principal = "*"
        Action    = "ecr:*"
        Condition = {
          StringNotEquals = {
            "aws:PrincipalArn" = [
              aws_iam_role.ecr_pull_team_a.arn,
              "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/Admin"
            ]
          }
        }
      }
    ]
  })
}

resource "aws_ecr_repository_policy" "team_b_repo" {
  repository = aws_ecr_repository.team_b_repo.name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyAllExceptTeamBAndAdmin"
        Effect    = "Deny"
        Principal = "*"
        Action    = "ecr:*"
        Condition = {
          StringNotEquals = {
            "aws:PrincipalArn" = [
              aws_iam_role.ecr_pull_team_b.arn,
              "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/Admin"
            ]
          }
        }
      }
    ]
  })
}


resource "aws_ecr_repository_policy" "shared_repo" {
  repository = aws_ecr_repository.shared_repo.name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyAllExceptTeamATeamBAndAdmin"
        Effect    = "Deny"
        Principal = "*"
        Action    = "ecr:*"
        Condition = {
          StringNotEquals = {
            "aws:PrincipalArn" = [
              aws_iam_role.ecr_pull_team_a.arn,
              aws_iam_role.ecr_pull_team_b.arn,
              "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/Admin"
            ]
          }
        }
      }
    ]
  })
}