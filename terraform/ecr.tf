# ecr.tf — Elastic Container Registry for the app image

resource "aws_ecr_repository" "app" {
  name                 = "cloud-modules-app"
  image_tag_mutability = "IMMUTABLE"
  force_delete         = true # allow `terraform destroy` even with images present

  image_scanning_configuration {
    scan_on_push = true
  }
}
