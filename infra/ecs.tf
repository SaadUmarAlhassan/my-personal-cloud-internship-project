data "aws_iam_policy_document" "ecs_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "exec" {
  name               = "${var.group_name}-ecs-exec"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume.json
}

resource "aws_iam_role_policy_attachment" "exec" {
  role       = aws_iam_role.exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}


resource "aws_cloudwatch_log_group" "app" {
  name              = "/ecs/${var.group_name}"
  retention_in_days = 7
}

data "aws_ecr_repository" "app" {
  name = "task-tracker"
}


resource "aws_ecs_task_definition" "web" {
  family                   = "${var.group_name}-task-tracker"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256 # 0.25 vCPU
  memory                   = 512 # 0.5 GB
  execution_role_arn       = aws_iam_role.exec.arn

  container_definitions = jsonencode([{
    name      = "web"
    image     = "${data.aws_ecr_repository.app.repository_url}:${var.image_tag}"
    essential = true

    portMappings = [{
      containerPort = var.container_port
      protocol      = "tcp"
    }]

    environment = [
      { name = "APP_VERSION", value = var.image_tag },
      { name  = "DATABASE_URL",
        value = "postgresql://tasks:${var.db_password}@${aws_db_instance.tasks.address}:5432/tasks"
      }
    ]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.app.name
        "awslogs-region"        = var.region
        "awslogs-stream-prefix" = "ecs"
      }
    }
  }])
}

resource "aws_ecs_cluster" "main" {
  name = "${var.group_name}-cluster"
}

# Combined resource from Week 4 and 5

resource "aws_ecs_service" "web" {
  name            = "${var.group_name}-web"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.web.arn
  desired_count   = var.desired_count # Uses your new variable instead of hardcoded 2
  launch_type     = "FARGATE"

  #week  5
  health_check_grace_period_seconds = 60

  # deployment that wont drop reuests

  deployment_minimum_healthy_percent = 100 # never go below the current count
  deployment_maximum_percent         = 200 # may temporarily run double
  deployment_circuit_breaker {
    enable   = true
    rollback = true # a deployment that never goes healthy is
  }

  network_configuration {
    subnets          = data.aws_subnets.default.ids
    security_groups  = [aws_security_group.app.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.web.arn
    container_name   = "web"
    container_port   = var.container_port
  }

  # The listener must exist before the service registers targets
  depends_on = [aws_lb_listener.http]
}
