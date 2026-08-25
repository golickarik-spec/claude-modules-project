# claude-modules-project

A small containerized web app deployed to **AWS ECS Fargate** behind an
**Application Load Balancer**, with all infrastructure defined as reusable
**Terraform modules** and shipped through a keyless **GitHub Actions → OIDC**
CI/CD pipeline.

Built for the *Cloud-Modules DevOps Practitioner Challenge*.

## Architecture

```
                       Internet
                          │  HTTP :80
                          ▼
        ┌───────────────────────────────────┐
        │  Application Load Balancer (public)│
        └───────────────────────────────────┘
                          │  forward :5000
                          ▼
        ┌───────────────────────────────────┐
        │  ECS Fargate service (private subnets)
        │  └─ task: nginx container :5000    │
        └───────────────────────────────────┘
                          │ pull image        │ egress
                          ▼                    ▼
                   ECR repository         NAT Gateway ──► Internet

  GitHub Actions ──(OIDC, no static keys)──► IAM deploy role
       └─ build image ─► push to ECR ─► register task def ─► roll ECS service
```

- **VPC** with public + private subnets across two AZs; a single NAT Gateway
  gives the private Fargate tasks outbound access.
- The **ALB** (public subnets) is the only internet-facing component; tasks run
  in **private subnets** and accept traffic only from the ALB security group.
- **CI/CD** authenticates to AWS via **GitHub OIDC federation** — no long-lived
  AWS access keys are stored anywhere.

## Repository layout

```
app/                     the container image
  Dockerfile             nginx:alpine serving a static site on :5000
  index.html             the page
  nginx.conf             nginx listening on :5000
terraform/               infrastructure as code (see terraform/README.md)
  modules/               reusable modules: network, alb, ecr, ecs-service, github-oidc
  main.tf                wires the modules for one cluster
  variables.tf           top-level inputs
  outputs.tf             ALB DNS, ECR URL, cluster/service names, deploy role ARN
  providers.tf           AWS provider + local backend
.github/workflows/
  deploy.yml             build → push → deploy on every push to main
```

## The app

A static site served by nginx (`nginx:alpine`) listening on port **5000**
(matching the ECS task and ALB target group). Build and run it locally with
Docker:

```sh
docker build -t claude-modules-app ./app
docker run --rm -p 5000:5000 claude-modules-app
# open http://localhost:5000  ->  "hello cloud-modules"
```

## Infrastructure (Terraform)

The stack is split into fine-grained, reusable modules so a new cluster is just
another set of module blocks with a different `name_prefix` and CIDRs. See
[`terraform/README.md`](terraform/README.md) for the module contracts and the
"adding another cluster" guide.

```sh
cd terraform
terraform init
terraform plan
terraform apply
```

Useful outputs after apply:

```sh
terraform output alb_dns_name   # public URL of the app
terraform output ecr_repo_url   # where CI pushes images
terraform output oidc_role_arn  # the GitHub Actions deploy role
```

> **Note:** the `github-oidc` module contains an account-global OIDC provider —
> instantiate it only once per AWS account.

### Backend

State uses the **local backend** (`terraform.tfstate` on disk). State files and
`*.tfvars` are gitignored and must never be committed.

## CI/CD pipeline

`.github/workflows/deploy.yml` runs on every push to `main` (and via
`workflow_dispatch`):

1. Assume the `cloud-modules-gha-deploy` IAM role via **GitHub OIDC** (no secrets).
2. `docker build` the app image and **push to ECR**, tagged with the commit SHA.
3. Download the live ECS task definition, render the new image into it, and
   **register a new revision**.
4. **Update the ECS service** and wait for it to stabilize.

Because CI registers task-def revisions and updates the service out-of-band, the
Terraform `ecs-service` module intentionally ignores drift on the task
definition and the service's `task_definition` — so `terraform plan` stays clean
after deploys.

## Prerequisites

- **Terraform** ≥ 1.5 and the **AWS CLI**, with credentials for the target
  account (`aws sts get-caller-identity` should succeed).
- **Docker** (for building the image locally).
- The GitHub repo configured to use OIDC against the account — no AWS secrets
  needed in GitHub.

## Deploying from scratch

1. `cd terraform && terraform apply` — provisions the VPC, ALB, ECR, ECS
   cluster/service, and the OIDC deploy role.
2. Push to `main` (or run the **deploy** workflow) — builds and ships the image;
   the ECS service rolls to the new task revision.
3. Visit `terraform output alb_dns_name` to see the running app.
