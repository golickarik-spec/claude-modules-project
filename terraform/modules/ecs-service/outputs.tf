# ecs-service module — outputs

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

output "task_execution_role_arn" {
  description = "ARN of the task execution role (for iam:PassRole in the deploy policy)."
  value       = aws_iam_role.ecs_task_execution.arn
}

output "container_name" {
  description = "Container name inside the task definition."
  value       = "app"
}
