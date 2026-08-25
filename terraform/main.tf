# main.tf — wire the reusable modules together for one cluster.
#
# To add another cluster, copy the network/alb/ecr/ecs_service blocks below,
# give them a distinct name (e.g. module "network_b") and a distinct
# name_prefix + non-overlapping CIDRs/AZs. Reuse the SINGLE github_oidc module
# (its OIDC provider is account-global). See terraform/README.md.

module "network" {
  source               = "./modules/network"
  name_prefix          = var.name_prefix
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  azs                  = var.azs
}

module "ecr" {
  source      = "./modules/ecr"
  name_prefix = var.name_prefix
}

module "alb" {
  source            = "./modules/alb"
  name_prefix       = var.name_prefix
  vpc_id            = module.network.vpc_id
  public_subnet_ids = module.network.public_subnet_ids
}

module "ecs_service" {
  source             = "./modules/ecs-service"
  name_prefix        = var.name_prefix
  aws_region         = var.aws_region
  vpc_id             = module.network.vpc_id
  private_subnet_ids = module.network.private_subnet_ids
  alb_sg_id          = module.alb.alb_sg_id
  target_group_arn   = module.alb.target_group_arn
  ecr_repo_url       = module.ecr.repository_url
  image_tag          = var.image_tag

  # The ALB listener must exist before the service registers targets.
  depends_on = [module.alb]
}

module "github_oidc" {
  source                      = "./modules/github-oidc"
  name_prefix                 = var.name_prefix
  github_owner_repo           = var.github_owner_repo
  ecr_repository_arn          = module.ecr.repository_arn
  ecs_task_execution_role_arn = module.ecs_service.task_execution_role_arn
}
