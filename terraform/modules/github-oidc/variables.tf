# github-oidc module — input variables

variable "name_prefix" {
  description = "Prefix applied to resource names."
  type        = string
}

variable "github_owner_repo" {
  description = "OWNER/NAME of the GitHub repo allowed to assume the deploy role."
  type        = string
}

variable "ecr_repository_arn" {
  description = "ARN of the ECR repository the deploy role may push/pull."
  type        = string
}

variable "ecs_task_execution_role_arn" {
  description = "ARN of the ECS task execution role the deploy role may pass to ECS."
  type        = string
}

variable "allowed_branch" {
  description = "Git branch (refs/heads/<branch>) permitted to assume the role."
  type        = string
  default     = "main"
}
