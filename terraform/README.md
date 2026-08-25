# Terraform layout

The infrastructure is split into reusable child modules under `modules/`, wired
together for one cluster in `main.tf`.

```
modules/
  network/       VPC, subnets, IGW, EIP, NAT, route tables
  alb/           ALB security group, load balancer, target group, HTTP listener
  ecr/           ECR repository
  ecs-service/   ECS cluster, task-exec role, log group, task def, task SG, service
  github-oidc/   GitHub Actions OIDC provider + deploy role  (account-global)
main.tf          instantiates the modules
variables.tf     top-level knobs
outputs.tf       re-exports module outputs (stable surface for CI)
providers.tf     terraform + aws provider, local backend, default tags
terraform.tfvars variable values
```

## Usage

```sh
terraform init
terraform validate
terraform plan
terraform apply
```

## Adding another cluster

Each cluster is one set of `network` + `alb` + `ecr` + `ecs_service` module
blocks. To add a second cluster, copy those four blocks in `main.tf`, rename them
(e.g. `module "network_b"`), and give the new cluster:

- a distinct `name_prefix` (all resource names derive from it), and
- non-overlapping `vpc_cidr` / subnet CIDRs (and AZs as needed).

Wire the new blocks the same way (`alb_b` reads `network_b.vpc_id`, etc.).

**Do not** create a second `github_oidc` module: its
`aws_iam_openid_connect_provider` is account-global — only one may exist per AWS
account for `token.actions.githubusercontent.com`. Grant an additional cluster's
ECR/exec-role access by extending the existing deploy role, or split the provider
resource out from the role if you need per-cluster roles.

Example:

```hcl
module "network_b" {
  source               = "./modules/network"
  name_prefix          = "cluster-b"
  vpc_cidr             = "10.1.0.0/16"
  public_subnet_cidrs  = ["10.1.0.0/24", "10.1.1.0/24"]
  private_subnet_cidrs = ["10.1.10.0/24", "10.1.11.0/24"]
  azs                  = ["us-east-1a", "us-east-1b"]
}
# ...alb_b, ecr_b, ecs_service_b follow the same pattern as the primary cluster.
```
