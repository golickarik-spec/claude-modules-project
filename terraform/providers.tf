# providers.tf — Terraform + AWS provider configuration

terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Local backend (default). State stored on disk.
  backend "local" {}
}

provider "aws" {
  region = var.aws_region

  # Apply a consistent Project tag to every taggable resource.
  default_tags {
    tags = {
      Project = var.name_prefix
    }
  }
}
