# github-oidc module — GitHub Actions OIDC provider and deploy role
#
# NOTE: aws_iam_openid_connect_provider.github is ACCOUNT-GLOBAL — only one provider
# per account may exist for token.actions.githubusercontent.com. Instantiate this
# module ONCE per AWS account even when running many clusters.

# OIDC identity provider for GitHub Actions
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

# Trust policy — allow the GitHub repo's branch to assume this role via OIDC
data "aws_iam_policy_document" "gha_assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    # AWS requires the trust policy to be scoped by `sub` (or `job_workflow_ref`).
    # This repo emits GitHub's immutable-ID subject format, e.g.
    #   repo:owner@<orgid>/name@<repoid>:ref:refs/heads/main
    # so we match with wildcards over the numeric IDs. Both the immutable-ID and
    # the classic (no-ID) forms are accepted; each stays pinned to this
    # owner/repo and the allowed branch.
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        "repo:${split("/", var.github_owner_repo)[0]}@*/${split("/", var.github_owner_repo)[1]}@*:ref:refs/heads/${var.allowed_branch}",
        "repo:${var.github_owner_repo}:ref:refs/heads/${var.allowed_branch}",
      ]
    }
  }
}

resource "aws_iam_role" "gha_deploy" {
  name               = "${var.name_prefix}-gha-deploy"
  assume_role_policy = data.aws_iam_policy_document.gha_assume.json
}

# Least-privilege deploy permissions for CI
data "aws_iam_policy_document" "gha_deploy" {
  # ECR auth token is account-wide and cannot be resource-scoped.
  statement {
    sid       = "EcrAuth"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  # Push/pull image layers to the app repository.
  statement {
    sid = "EcrPushPull"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer",
      "ecr:PutImage",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
    ]
    resources = [var.ecr_repository_arn]
  }

  # Register new task-def revisions and roll the service.
  statement {
    sid = "EcsDeploy"
    actions = [
      "ecs:RegisterTaskDefinition",
      "ecs:UpdateService",
      "ecs:DescribeServices",
      "ecs:DescribeTaskDefinition",
    ]
    resources = ["*"]
  }

  # Allow passing the task execution role to ECS during task-def registration.
  statement {
    sid       = "PassExecutionRole"
    actions   = ["iam:PassRole"]
    resources = [var.ecs_task_execution_role_arn]

    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "gha_deploy" {
  name   = "${var.name_prefix}-gha-deploy"
  role   = aws_iam_role.gha_deploy.id
  policy = data.aws_iam_policy_document.gha_deploy.json
}
