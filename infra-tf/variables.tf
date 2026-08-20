variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "us-east-2"
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "ecr-pod-permission-test"
}

variable "cluster_version" {
  description = "Kubernetes version for EKS (>= 1.35 required; ecr-credential-provider adds full KEP 4412 support in 1.35)"
  type        = string
  default     = "1.35"
}

variable "node_instance_type" {
  description = "EC2 instance type for EKS managed node groups"
  type        = string
  default     = "t3.medium"
}
