# alb module — input variables

variable "name_prefix" {
  description = "Prefix applied to resource names."
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC to create the ALB and target group in."
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnet IDs to place the internet-facing ALB in."
  type        = list(string)
}

variable "container_port" {
  description = "Port the app container listens on (target group + health check port)."
  type        = number
  default     = 5000
}

variable "health_check_path" {
  description = "HTTP path used by the target group health check."
  type        = string
  default     = "/"
}
