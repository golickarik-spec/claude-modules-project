# ecr module — Elastic Container Registry for the app image

locals {
  repository_name = coalesce(var.repository_name, "${var.name_prefix}-app")
}

resource "aws_ecr_repository" "app" {
  name                 = local.repository_name
  image_tag_mutability = var.image_tag_mutability
  force_delete         = var.force_delete

  image_scanning_configuration {
    scan_on_push = true
  }
}
