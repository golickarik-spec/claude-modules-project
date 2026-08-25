# ecr module — input variables

variable "name_prefix" {
  description = "Prefix applied to resource names. Repository is named \"<name_prefix>-app\" unless repository_name is set."
  type        = string
}

variable "repository_name" {
  description = "Explicit ECR repository name. Defaults to \"<name_prefix>-app\" when null."
  type        = string
  default     = null
}

variable "image_tag_mutability" {
  description = "Image tag mutability for the repository."
  type        = string
  default     = "IMMUTABLE"
}

variable "force_delete" {
  description = "Allow `terraform destroy` even when the repository still contains images."
  type        = bool
  default     = true
}
