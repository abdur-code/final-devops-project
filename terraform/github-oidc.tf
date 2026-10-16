locals {
  github_ci_enabled = var.github_repository != ""
}

resource "aws_iam_openid_connect_provider" "github" {
  count          = local.github_ci_enabled && var.create_github_oidc_provider ? 1 : 0
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
}

data "aws_iam_openid_connect_provider" "github" {
  count = local.github_ci_enabled && !var.create_github_oidc_provider ? 1 : 0
  url   = "https://token.actions.githubusercontent.com"
}

locals {
  github_oidc_arn = local.github_ci_enabled ? (
    var.create_github_oidc_provider ? aws_iam_openid_connect_provider.github[0].arn : data.aws_iam_openid_connect_provider.github[0].arn
  ) : ""
}

resource "aws_iam_role" "github_ci" {
  count = local.github_ci_enabled ? 1 : 0
  name  = "${local.name}-github-ci"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = local.github_oidc_arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = { "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com" }
        StringLike   = { "token.actions.githubusercontent.com:sub" = "repo:${var.github_repository}:*" }
      }
    }]
  })
}

resource "aws_iam_role_policy" "github_ci" {
  count = local.github_ci_enabled ? 1 : 0
  name  = "eks-describe"
  role  = aws_iam_role.github_ci[0].id
  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Action = ["eks:DescribeCluster"], Resource = module.eks.cluster_arn }]
  })
}
