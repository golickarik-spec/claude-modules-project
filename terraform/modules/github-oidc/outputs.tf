# github-oidc module — outputs

output "oidc_role_arn" {
  description = "ARN of the GitHub Actions OIDC deploy role."
  value       = aws_iam_role.gha_deploy.arn
}

output "oidc_provider_arn" {
  description = "ARN of the GitHub Actions OIDC identity provider (account-global)."
  value       = aws_iam_openid_connect_provider.github.arn
}
