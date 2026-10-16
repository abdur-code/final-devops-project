output "region" {
  value = var.aws_region
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "configure_kubectl" {
  description = "Command that configures kubectl for the new cluster"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}

output "github_ci_role_arn" {
  description = "IAM role assumed by the deploy-helm workflow (repository variable AWS_DEPLOY_ROLE_ARN)"
  value       = local.github_ci_enabled ? aws_iam_role.github_ci[0].arn : null
}
