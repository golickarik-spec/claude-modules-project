# Project Study — Understanding Every Decision

A learning companion to `plan.md`. It explains **what** each piece is, **why** it's the best
choice for this challenge, and **how** the whole thing flows end to end. Read this if you want to
be able to *defend* the design in a review, not just run it.

---

## 1. The problem in one sentence

Serve an HTML page that says `hello cloud-modules` from a Docker container on **port 5000**, let
the public reach it via an **ALB on port 80**, build all cloud infrastructure with **Terraform**,
and ship new versions automatically with **GitHub Actions** — authenticating to AWS **without
long-lived keys**.

Everything below is a consequence of taking that sentence seriously.

---

## 2. The request flow (follow one HTTP request)

```
User's browser
   │  GET http://<alb-dns>:80
   ▼
Internet Gateway (IGW)            ← the VPC's door to the internet
   │
   ▼
Application Load Balancer          ← lives in the 2 PUBLIC subnets, has a public DNS name
   │  listener on :80
   │  forwards to a Target Group
   ▼
Target Group (protocol HTTP, port 5000, target type = ip)
   │  routes to healthy targets (the running Fargate task's private IP)
   ▼
Fargate task                       ← lives in a PRIVATE subnet, no public IP
   │  nginx listening on :5000
   ▼
index.html → "hello cloud-modules"
```

**Why this shape?** The ALB is the *only* thing exposed to the internet. The container is never
directly reachable — users can only talk to it through the load balancer, on port 80, exactly as
the assignment demands. Port 80 (public) and port 5000 (container) are deliberately different: the
ALB does the translation via the target group.

---

## 3. Networking — the VPC and why 4 subnets

The assignment mandates a VPC, **2 public** and **2 private** subnets. Here's the reasoning.

- **VPC** = your private, isolated slice of the AWS network (`10.0.0.0/16`). Everything lives inside it.
- **Public subnet** = a subnet whose route table sends `0.0.0.0/0` (all internet traffic) to the
  **Internet Gateway**. Resources here *can* have public IPs and be reached from the internet.
  → We put the **ALB** and the **NAT Gateway** here.
- **Private subnet** = a subnet whose route table sends `0.0.0.0/0` to a **NAT Gateway** instead.
  Resources here have **no** public IP and **cannot** be reached from the internet, but they *can*
  reach out (for updates, image pulls, etc.).
  → We put the **Fargate task** here.

**Why two of each?** High availability. AWS wants an ALB to span at least two Availability Zones
(us-east-1a and us-east-1b). Two public subnets (one per AZ) satisfy the ALB. Two private subnets
(one per AZ) let the task be rescheduled into a healthy AZ if one fails. This is *why* the
assignment insists on pairs — it's testing whether you understand multi-AZ.

**This is exactly what your two route-table screenshots prove:**
- Public route table → a row `0.0.0.0/0 → igw-xxxx`
- Private route table → a row `0.0.0.0/0 → nat-xxxx`

That single difference *is* the definition of "public" vs "private" subnet. The screenshots are the
assignment's way of asking "do you actually understand the distinction?"

---

## 4. Why the container runs in a *private* subnet (and the NAT that makes it work)

Putting the task in a private subnet is the secure, professional default: the app has no public IP,
so no one can hit port 5000 directly — they *must* go through the ALB. Good.

But a Fargate task still needs to **pull its image from ECR**, **get an ECR auth token**, and
**push logs to CloudWatch**. Those are internet-facing AWS endpoints. A private subnet has no route
to the internet by itself. Two ways to give it one:

1. **NAT Gateway** (our choice) — a managed box in a *public* subnet that lets private resources
   make **outbound** connections while blocking **inbound** ones. The private route table points
   `0.0.0.0/0 → NAT`. Simple, one resource, textbook, and it produces the clean private
   route-table screenshot the assignment wants.
2. **VPC Interface/Gateway Endpoints** — private tunnels to specific AWS services (ecr.api,
   ecr.dkr, logs, sts, S3). No NAT, "more cloud-native," but ~4 paid endpoints, more Terraform, and
   a blander screenshot.

**Why NAT wins here:** it's the simplest thing that is *correct*, it maps 1:1 to the concept the
route-table screenshot is testing, and it's cheap when torn down after. We use a **single** NAT
(one AZ) to save cost — acceptable for a challenge; production would use one per AZ for HA.

---

## 5. Why Fargate (not EC2)

ECS runs containers two ways:
- **EC2 launch type**: *you* run and manage a fleet of EC2 instances (AMIs, autoscaling group,
  capacity provider, patching). More knobs, more cost, more to break.
- **Fargate**: **serverless** — you declare CPU/memory and AWS runs the container. No servers, no
  AMIs, no scaling groups.

For a single small container, Fargate is the least code, least cost, and least that can go wrong.
It uses `awsvpc` networking, which gives each task its own ENI and private IP — which is exactly
what lets the ALB target group use `target_type = ip` and route straight to the task. Choosing
Fargate is choosing "solve the assignment, not a server-management side quest."

---

## 6. The container — why nginx serving static HTML

The page is static text. Options were nginx (static), Flask (Python), or Node/Express.

- **nginx static** (our choice): smallest image, zero app dependencies, extremely reliable, and a
  trivial health check (`GET /` returns `200`). The fewest moving parts in the pipeline.
- **Flask**: port 5000 is Flask's famous default, so it's a tempting "hint," but it adds a Python
  runtime + `requirements.txt` and more image surface for no functional gain here.

We still listen on **5000** (via `nginx.conf`) to meet the requirement precisely — we just don't
need a heavyweight app to serve one line of HTML. **Simplest correct thing that satisfies the spec.**

`Dockerfile` (essence): `FROM nginx:alpine`, copy `nginx.conf` (listen 5000) and `index.html`,
expose 5000. That's the whole app.

---

## 7. Security groups — the two-layer lock

Security groups are stateful virtual firewalls attached to resources.

- **ALB security group**: inbound `TCP :80` from `0.0.0.0/0` (the whole internet may reach the
  load balancer). Outbound to the task SG on 5000.
- **Task security group**: inbound `TCP :5000` **only from the ALB security group** — *not* from
  the internet, not even from the whole VPC. Referencing the ALB's SG as the source (instead of an
  IP range) means "only traffic that came through our load balancer is allowed in."

**Why this is the best design:** defense in depth. Even though the task is already in a private
subnet with no public IP, the SG guarantees the *only* thing that can talk to port 5000 is the ALB.
Two independent controls (private subnet + SG source = ALB) both have to fail for the container to
be exposed.

---

## 8. Terraform provisions infra; GitHub Actions only deploys the app

This is the most important *structural* decision, so here's the full reasoning.

The assignment says the **pipeline** must: build the image, auth to AWS, push to ECR, deploy to
ECS. It says nothing about the pipeline creating VPCs or load balancers. So we split cleanly:

- **Terraform** = *slow-changing infrastructure* (VPC, subnets, ALB, ECS cluster/service, ECR,
  IAM/OIDC). You run `terraform apply` **once** locally to stand it all up. Because only you run it,
  the state can live **locally** — no need to bootstrap an S3 bucket + DynamoDB lock table.
- **GitHub Actions** = *fast-changing application* (a new image on every push). It just builds,
  pushes, and tells ECS to run the new image.

**Why not have CI run Terraform too?** That's "full GitOps," but it forces **remote state**
(S3+DynamoDB), makes every push slower and riskier (a bad commit could damage your network), and
does more than the assignment asks the pipeline to do. Separating "infra changes rarely, by a
human" from "app changes often, automatically" is the industry-standard boundary and keeps each
tool doing what it's best at.

### The drift problem this creates (and the fix)

If Terraform *owns* the ECS task definition and CI *also* updates it with a new image, then the next
`terraform apply` would try to "correct" the image back to what Terraform last knew — reverting your
deploy. The fix is `lifecycle { ignore_changes = [...] }` on the task definition's image and the
service's task definition, telling Terraform "don't fight CI over this field." This is *the* classic
ECS+Terraform gotcha, and handling it explicitly is what separates a working setup from a flaky one.

---

## 9. Image tags — why git SHA, not `:latest`

Every image CI builds is tagged with the **git commit SHA** (`:a1b2c3d…`).

- **Immutable & reproducible**: a SHA points at exactly one build forever. You can look at a running
  task and know precisely which commit it is.
- **Real rollbacks**: to roll back you redeploy an older SHA — it still exists in ECR.
- **Forces a genuine new task-def revision**: each deploy references a new image reference, so ECS
  actually rolls out.

`:latest` is the anti-pattern: it's a moving pointer, so "which code is live?" becomes unanswerable,
rollbacks are guesswork, and you often need `--force-new-deployment` hacks. We make ECR **immutable-
tag** to enforce this discipline at the registry level.

---

## 10. Secure auth — GitHub OIDC instead of AWS keys

The assignment's "**do not use access/secret keys**" is the whole point of this section.

**The old, bad way:** create an IAM user, generate a long-lived access key + secret, paste them
into GitHub secrets. Those keys never expire, can leak, and grant standing access forever.

**The modern way — OIDC federation:**
1. In AWS IAM we register GitHub's OIDC provider (`token.actions.githubusercontent.com`) as a
   trusted identity provider.
2. We create an IAM **role** whose trust policy says: *"I trust tokens from GitHub Actions, but only
   when the `sub` claim is `repo:OWNER/NAME:ref:refs/heads/main`."* — i.e. only **this repo**,
   **this branch**.
3. When the workflow runs, GitHub mints a short-lived signed OIDC token. The
   `configure-aws-credentials` action exchanges it (via STS) for **temporary** AWS credentials that
   expire in minutes.

**Why this is strictly better:** no secret is ever stored anywhere. Credentials are minted on
demand, scoped to one repo+branch, and self-destruct. If someone forks the repo or pushes to a
different branch, the trust condition fails and they get nothing. The least-privilege policy on the
role further limits it to just ECR push + ECS deploy + `PassRole` for the task execution role —
nothing else.

---

## 11. The bootstrap chicken-and-egg (and why the order matters)

There's a subtle ordering trap:
- The ECS **service** can't start until it can **pull an image** from ECR.
- But the **image** is built by CI, which can't run until the infra (including ECR) exists.
- And `terraform apply` wants to create the service *and* ECR together.

If you naively `terraform apply` everything at once, the service is created pointing at an image
that doesn't exist yet, and it never becomes healthy.

**The fix (see `plan.md` execution order):**
1. Create **ECR first** (`terraform apply -target=aws_ecr_repository.app` + network).
2. Build and push a **`bootstrap`** image so *something* is in the registry.
3. `terraform apply` the rest — the service pulls `bootstrap`, goes healthy, ALB serves the page.
4. Now normal life begins: push to `main` → CI builds the real `:<sha>` image → ECS rolls it out.

Understanding *why* this sequence exists (services need images, images need infra) is more valuable
than memorizing the commands.

---

## 12. The two-lane flow, end to end

**Lane A — Infrastructure (Terraform, run by a human, occasionally):**
```
terraform apply → VPC + subnets + IGW + NAT + ALB + TG + SGs + ECR + ECS + IAM/OIDC
```

**Lane B — Application (GitHub Actions, automatic, on every push to main):**
```
git push → checkout → OIDC → temp AWS creds → docker build →
ecr login → push :<sha> → render new task def → deploy to ECS → wait for stable
```

They meet at exactly two seams: **ECR** (Terraform creates the repo; CI pushes images into it) and
the **ECS service** (Terraform creates it; CI updates its running image). Everything else is cleanly
separated. That clean seam is what makes the design easy to reason about and hard to break.

---

## 13. Why we tear it down (and keep proof)

NAT Gateway, ALB, and Fargate all bill hourly (~$1–2/day). Once we've captured the deliverables —
the live URL, a browser screenshot of the page, and the two route-table screenshots — we run
`terraform destroy` to stop the meter. The URL goes dead, which is why the **screenshots** are the
durable evidence for the acceptance criteria. The submission email notes the stack was live and was
torn down for cost — the professional, cost-aware thing to do.

---

## 14. How each acceptance criterion is satisfied

| # | Criterion | Satisfied by |
|---|-----------|--------------|
| 1 | Terraform code | `terraform/` — VPC through OIDC |
| 2 | GitHub Actions YAML | `.github/workflows/deploy.yml` |
| 3 | Dockerfile + app | `app/Dockerfile`, `index.html`, `nginx.conf` |
| 4 | Public route table screenshot | Console: RT with `0.0.0.0/0 → IGW` |
| 5 | Private route table screenshot | Console: RT with `0.0.0.0/0 → NAT` |
| 6 | Deployed URL | ALB DNS name + browser screenshot of `hello cloud-modules` |
| 7 | Send to devops@cloud-modules.com | Email with code repo link + screenshots |

Every requirement in the PDF maps to a concrete, defensible artifact — and now you know *why* each
one is built the way it is.
