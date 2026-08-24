# ecs.tf — ECS cluster, task execution role, logs, task definition, service

# ECS cluster
resource "aws_ecs_cluster" "main" {
  name = "cloud-modules-cluster"
}

# Trust policy allowing ECS tasks to assume the execution role
data "aws_iam_policy_document" "ecs_task_execution_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

# Task execution role — used by the ECS agent to pull images and write logs
resource "aws_iam_role" "ecs_task_execution" {
  name               = "${var.name_prefix}-ecs-task-execution"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_execution_assume.json
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# CloudWatch log group for container logs
resource "aws_cloudwatch_log_group" "app" {
  name              = "/ecs/cloud-modules"
  retention_in_days = 7
}

# Fargate task definition
resource "aws_ecs_task_definition" "app" {
  family                   = "cloud-modules-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn

  container_definitions = jsonencode([
    {
      name      = "app"
      image     = "${aws_ecr_repository.app.repository_url}:${var.image_tag}"
      essential = true
      portMappings = [
        {
          containerPort = 5000
          hostPort      = 5000
          protocol      = "tcp"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.app.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "app"
        }
      }
    }
  ])

  # CI registers new revisions with updated images; ignore that drift here.
  lifecycle {
    ignore_changes = [container_definitions]
  }
}

# Security group for the Fargate tasks — only the ALB may reach the app port
resource "aws_security_group" "task" {
  name        = "${var.name_prefix}-task-sg"
  description = "Allow app traffic from the ALB only"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "App port from ALB"
    from_port       = 5000
    to_port         = 5000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name_prefix}-task-sg"
  }
}

# ECS service running the task behind the ALB
resource "aws_ecs_service" "app" {
  name            = "cloud-modules-svc"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.task.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = "app"
    container_port   = 5000
  }

  # The listener must exist before the service registers targets.
  depends_on = [aws_lb_listener.http]

  # CI updates the service with new task-def revisions; ignore that drift.
  lifecycle {
    ignore_changes = [task_definition]
  }
}
