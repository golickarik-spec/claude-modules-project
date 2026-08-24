# outputs.tf — useful values for CI and operators

output "alb_dns_name" {
  description = "Public DNS name of the Application Load Balancer."
  value       = aws_lb.main.dns_name
}

output "ecr_repo_url" {
  description = "URL of the ECR repository."
  value       = aws_ecr_repository.app.repository_url
}

output "cluster_name" {
  description = "ECS cluster name."
  value       = aws_ecs_cluster.main.name
}

output "service_name" {
  description = "ECS service name."
  value       = aws_ecs_service.app.name
}

output "task_family" {
  description = "ECS task definition family."
  value       = aws_ecs_task_definition.app.family
}

output "oidc_role_arn" {
  description = "ARN of the GitHub Actions OIDC deploy role."
  value       = aws_iam_role.gha_deploy.arn
}

output "container_name" {
  description = "Container name inside the task definition."
  value       = "app"
}
