output "cluster_endpoint" {
  description = "EKS cluster API endpoint"
  value       = module.eks.cluster_endpoint
}

output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "ecr_shared_repo_url" {
  description = "ECR repository URL for shared/app"
  value       = aws_ecr_repository.shared_repo.repository_url
}

output "ecr_team_a_repo_url" {
  description = "ECR repository URL for team-a/app"
  value       = aws_ecr_repository.team_a_repo.repository_url
}

output "ecr_team_b_repo_url" {
  description = "ECR repository URL for team-b/app"
  value       = aws_ecr_repository.team_b_repo.repository_url
}

output "ecr_baseline_repo_url" {
  description = "ECR repository URL for baseline/app (no repository policy)"
  value       = aws_ecr_repository.baseline_repo.repository_url
}

output "ecr_pull_role_arn_team_a" {
  description = "ECR pull role ARN for team-a ECR access"
  value       = aws_iam_role.ecr_pull_team_a.arn
}

output "ecr_pull_role_arn_team_b" {
  description = "ECR pull role ARN for team-b ECR access"
  value       = aws_iam_role.ecr_pull_team_b.arn
}

output "configure_kubectl" {
  description = "Command to configure kubectl for the EKS cluster"
  value       = "aws eks update-kubeconfig --name ${module.eks.cluster_name} --region ${var.aws_region}"
}

output "aws_account_id" {
  description = "AWS account ID (for ECR image URIs)"
  value       = data.aws_caller_identity.current.account_id
}

output "aws_region" {
  description = "AWS region"
  value       = var.aws_region
}
