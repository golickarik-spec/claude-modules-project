# Execution Plan — Cloud-Modules DevOps Practitioner Challenge

## Context

Deploy a containerized web app to **AWS ECS** using **Terraform** and **GitHub Actions**.
The container serves an HTML page printing `hello cloud-modules`, listens on **port 5000**, and
is reached by users through an **Application Load Balancer on port 80**. CI must authenticate to
AWS **without access/secret keys** (→ GitHub OIDC). Greenfield build — the repo starts empty.

**Outcome:** a live deployment we verify returns `hello cloud-modules`, all code + evidence
artifacts captured, then torn down to stop charges. Results emailed to `devops@cloud-modules.com`.

## Locked decisions

| Area | Decision |
|------|----------|
| AWS account | Real deploy, **region us-east-1**, AZs `us-east-1a`/`us-east-1b` |
| Launch type | **Fargate** (serverless, `awsvpc` networking) |
| Task placement | Tasks in **2 private subnets**; ALB in **2 public subnets** |
| Egress | **Single NAT Gateway** (private RT `0.0.0.0/0` → NAT) |
| Web server | **nginx** serving static `index.html` on port 5000 |
| TF vs CI split | **Terraform provisions all infra** (local state); **CI only builds/pushes/deploys** |
| Image tags | **git SHA** (immutable); TF `lifecycle.ignore_changes` avoids task-def drift |
| Auth | **GitHub OIDC** → IAM role, trust `repo:OWNER/NAME:ref:refs/heads/main` |
| GitHub repo | New **private** repo (personal); `OWNER/NAME` is a TF variable |
| Lifecycle | Deploy → verify → capture URL + route-table screenshots → **`terraform destroy`** |

## Architecture

```
Internet → IGW → ALB (public subnets, SG: allow :80 from 0.0.0.0/0)
                   │  listener :80  →  target group (ip, :5000, health "/")
                   ▼
        Fargate task (private subnets, SG: allow :5000 from ALB SG only)
                   │  egress via private RT → NAT Gateway (public subnet) → IGW
                   ▼
        ECR (pull image) + CloudWatch Logs
```

## Repository layout

```
/
├─ app/
│  ├─ Dockerfile            # FROM nginx:alpine; copy site + conf; EXPOSE 5000
│  ├─ index.html            # prints "hello cloud-modules"
│  └─ nginx.conf            # listen 5000; serve /usr/share/nginx/html
├─ terraform/
│  ├─ providers.tf          # aws provider, region var, local backend
│  ├─ variables.tf          # region, github_owner_repo, image_tag, cidrs, name prefix
│  ├─ network.tf            # VPC, 2 public + 2 private subnets, IGW, NAT+EIP, route tables
│  ├─ ecr.tf                # ECR repo (immutable tags, scan on push)
│  ├─ alb.tf                # ALB, target group (ip, :5000, health "/"), listener :80, ALB SG
│  ├─ ecs.tf                # cluster, exec role, task def (:5000), service, task SG, CW logs
│  ├─ iam_oidc.tf           # GitHub OIDC provider + deploy role + least-priv policy
│  └─ outputs.tf            # alb_dns_name, ecr_repo_url, cluster/service names, oidc_role_arn
└─ .github/workflows/deploy.yml
```

## Execution order (handles ECR/ECS bootstrap chicken-and-egg)

1. Write all code (app, terraform, workflow).
2. `aws sts get-caller-identity` to confirm local AWS auth.
3. `terraform init && terraform apply -target=aws_ecr_repository.app` (+ network) → create ECR.
4. Build + push an initial image tagged `bootstrap` so the ECS service can pull on creation.
5. `terraform apply` for the rest — service starts, task pulls `bootstrap`, ALB goes healthy.
6. `curl http://<alb_dns_name>` → verify `hello cloud-modules`.
7. Create private GitHub repo, set `github_owner_repo`, push → CI deploys the `:<sha>` image.
8. Re-verify the URL after the CI-driven deploy.

## Verification

- `aws sts get-caller-identity` succeeds before any apply.
- After step 5: `curl -s http://<alb_dns_name>/` returns `hello cloud-modules`; target group
  `healthy`; task `RUNNING`.
- After step 7: Actions run green; new task-def revision references `:<sha>`;
  `aws ecs describe-services` shows the new revision and `runningCount=1`.

## Deliverables (acceptance criteria)

1. Terraform code — `terraform/`
2. GitHub Actions YAML — `.github/workflows/deploy.yml`
3. Dockerfile + app files — `app/`
4. Screenshot: **public** route table (`0.0.0.0/0` → IGW) — *manual, AWS console*
5. Screenshot: **private** route table (`0.0.0.0/0` → NAT) — *manual, AWS console*
6. URL of deployed website — ALB DNS name + **browser screenshot** of the page (URL dies after destroy)
7. Email everything to `devops@cloud-modules.com`

## Post-capture

`terraform destroy` to stop NAT/ALB/Fargate charges (~$1–2/day). Note in the email that the URL
was live and torn down for cost; screenshots retain the proof.

## Assumptions

- Page text lowercase `hello cloud-modules` (matches the PDF "must print" lines).
- HTTP only on port 80 (no HTTPS/domain requested).
- Steps 2, 4, 7 and the console screenshots require a few interactive/user actions — exact
  commands provided at each step.
