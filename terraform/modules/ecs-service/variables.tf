# ecs-service module — input variables

variable "name_prefix" {
  description = "Prefix applied to resource names."
  type        = string
}

variable "aws_region" {
  description = "AWS region (used for the awslogs log driver configuration)."
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC the task security group is created in."
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs the Fargate tasks run in."
  type        = list(string)
}

variable "alb_sg_id" {
  description = "Security group ID of the ALB — the only allowed source for the app port."
  type        = string
}

variable "target_group_arn" {
  description = "ARN of the ALB target group the service registers with."
  type        = string
}

variable "ecr_repo_url" {
  description = "URL of the ECR repository holding the app image."
  type        = string
}

variable "image_tag" {
  description = "Container image tag to deploy."
  type        = string
  default     = "bootstrap"
}

variable "container_port" {
  description = "Port the app container listens on."
  type        = number
  default     = 5000
}

variable "cpu" {
  description = "Fargate task CPU units."
  type        = number
  default     = 256
}

variable "memory" {
  description = "Fargate task memory (MiB)."
  type        = number
  default     = 512
}

variable "desired_count" {
  description = "Number of task copies the service keeps running."
  type        = number
  default     = 1
}

variable "log_retention_in_days" {
  description = "CloudWatch log group retention."
  type        = number
  default     = 7
}
