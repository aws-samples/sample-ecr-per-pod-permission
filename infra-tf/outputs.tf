output "cluster_endpoint" {
  description = "EKS cluster API endpoint"
  value       = module.eks.cluster_endpoint
}

output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "ecr_shared_repo_url" {
  description = "ECR repository URL for shared/nginx"
  value       = aws_ecr_repository.shared_nginx.repository_url
}

output "ecr_team_a_repo_url" {
  description = "ECR repository URL for team-a/nginxa"
  value       = aws_ecr_repository.team_a_nginxa.repository_url
}

output "ecr_team_b_repo_url" {
  description = "ECR repository URL for team-b/nginxb"
  value       = aws_ecr_repository.team_b_nginxb.repository_url
}

output "irsa_role_arn_team_a" {
  description = "IRSA role ARN for team-a ECR access"
  value       = aws_iam_role.irsa_ecr_team_a.arn
}

output "irsa_role_arn_team_b" {
  description = "IRSA role ARN for team-b ECR access"
  value       = aws_iam_role.irsa_ecr_team_b.arn
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
