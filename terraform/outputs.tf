# outputs.tf — useful values for CI and operators (re-exported from modules)

output "alb_dns_name" {
  description = "Public DNS name of the Application Load Balancer."
  value       = module.alb.alb_dns_name
}

output "ecr_repo_url" {
  description = "URL of the ECR repository."
  value       = module.ecr.repository_url
}

output "cluster_name" {
  description = "ECS cluster name."
  value       = module.ecs_service.cluster_name
}

output "service_name" {
  description = "ECS service name."
  value       = module.ecs_service.service_name
}

output "task_family" {
  description = "ECS task definition family."
  value       = module.ecs_service.task_family
}

output "oidc_role_arn" {
  description = "ARN of the GitHub Actions OIDC deploy role."
  value       = module.github_oidc.oidc_role_arn
}

output "container_name" {
  description = "Container name inside the task definition."
  value       = module.ecs_service.container_name
}
