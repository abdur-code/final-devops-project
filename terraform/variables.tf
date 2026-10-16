variable "project" {
  description = "Name prefix for all resources"
  type        = string
  default     = "stockpilot"
}

variable "environment" {
  description = "Environment name (dev, prod, ...)"
  type        = string
  default     = "dev"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-south-1"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.30.0.0/16"
}

variable "kubernetes_version" {
  description = "EKS Kubernetes version (a version in EKS standard support; extended support costs extra)"
  type        = string
  default     = "1.34"
}

variable "node_instance_types" {
  description = "EC2 instance types for the managed node group"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_min_size" {
  type    = number
  default = 2
}

variable "node_desired_size" {
  type    = number
  default = 2
}

variable "node_max_size" {
  type    = number
  default = 4
}

variable "endpoint_public_access_cidrs" {
  description = "CIDR blocks allowed to reach the public Kubernetes API endpoint"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "github_repository" {
  description = "GitHub repo (owner/name) allowed to deploy through OIDC. Empty string disables the CI role."
  type        = string
  default     = "abdur-code/final-devops-project"
}

variable "create_github_oidc_provider" {
  description = "Create the GitHub OIDC provider (false when the account already has one)"
  type        = bool
  default     = true
}
