data "aws_caller_identity" "current" {}

locals {
  account_id = data.aws_caller_identity.current.id
  ecr_url    = "${local.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com"
}

# ---------------- users-service ----------------
resource "aws_ecs_task_definition" "users_service" {
  family                   = "${var.project_name}-users-service"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = var.iam_ecs_task_definition_execution_role_arn
  task_role_arn            = var.iam_ecs_task_role_arn

  container_definitions = jsonencode([
    {
      name      = "users-service"
      image     = "${var.ecr_repository_urls["users-service"]}:${var.image_tag}"
      essential = true
      portMappings = [{ containerPort = 4001, name = "users-service" }]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = var.ecs_log_group["users-service"]
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "users-service"
        }
      }
    }
  ])
}

# ---------------- products-service ----------------
resource "aws_ecs_task_definition" "products_service" {
  family                   = "${var.project_name}-products-service"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = var.iam_ecs_task_definition_execution_role_arn
  task_role_arn            = var.iam_ecs_task_role_arn

  container_definitions = jsonencode([
    {
      name      = "products-service"
      image     = "${var.ecr_repository_urls["products-service"]}:${var.image_tag}"
      essential = true
      portMappings = [{ containerPort = 4002, name = "products-service" }]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = var.ecs_log_group["products-service"]
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "products-service"
        }
      }
    }
  ])
}

# ---------------- orders-service (INIT CONTAINER + SIDECAR demo) ----------------
resource "aws_ecs_task_definition" "orders_service" {
  family                   = "${var.project_name}-orders-service"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = var.iam_ecs_task_definition_execution_role_arn
  task_role_arn            = var.iam_ecs_task_role_arn

  container_definitions = jsonencode([
    # 1) INIT CONTAINER BEHAVIOUR:
    #    non-essential container that must exit 0 (SUCCESS) before the main
    #    "orders-service" container is allowed to start. ECS equivalent of a
    #    Kubernetes initContainer.
    {
      name      = "init-check"
      image     = "${var.ecr_repository_urls["init-check"]}:${var.image_tag}"
      essential = false
      environment = [
        { name = "DEPENDENCY_URLS", value = "http://users-service:4001/health,http://products-service:4002/health" }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = var.ecs_log_group["orders-service"]
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "init-check"
        }
      }
    },
    # 2) MAIN APPLICATION CONTAINER
    {
      name         = "orders-service"
      image        = "${var.ecr_repository_urls["orders-service"]}:${var.image_tag}"
      essential    = true
      portMappings = [{ containerPort = 4003, name = "orders-service" }]
      environment = [
        { name = "USERS_SERVICE_URL", value = "http://users-service:4001" },
        { name = "PRODUCTS_SERVICE_URL", value = "http://products-service:4002" }
      ]
      dependsOn = [
        { containerName = "init-check", condition = "SUCCESS" }
      ]
      healthCheck = {
        command     = ["CMD-SHELL", "wget -qO- http://localhost:4003/health || exit 1"]
        interval    = 10
        timeout     = 3
        retries     = 3
        startPeriod = 5
      }
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = var.ecs_log_group["orders-service"]
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "orders-service"
        }
      }
    },
    # 3) SIDECAR CONTAINER BEHAVIOUR:
    #    runs for the whole lifetime of the task alongside orders-service,
    #    reaches it over "localhost" because both containers share the same
    #    ENI/network namespace in awsvpc mode, and only starts once the main
    #    container reports HEALTHY.
    {
      name      = "sidecar-logger"
      image     = "${var.ecr_repository_urls["sidecar-logger"]}:${var.image_tag}"
      essential = false
      environment = [
        { name = "APP_HOST", value = "localhost" },
        { name = "APP_PORT", value = "4003" },
        { name = "SIDECAR_INTERVAL_MS", value = "10000" }
      ]
      dependsOn = [
        { containerName = "orders-service", condition = "HEALTHY" }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = var.ecs_log_group["orders-service"]
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "sidecar-logger"
        }
      }
    }
  ])
}

# ---------------- frontend ----------------
resource "aws_ecs_task_definition" "frontend" {
  family                   = "${var.project_name}-frontend"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = var.iam_ecs_task_definition_execution_role_arn
  task_role_arn            = var.iam_ecs_task_role_arn

  container_definitions = jsonencode([
    {
      name         = "frontend"
      image        = "${var.ecr_repository_urls["frontend"]}:${var.image_tag}"
      essential    = true
      portMappings = [{ containerPort = 4000, name = "frontend" }]
      environment = [
        { name = "ORDERS_SERVICE_URL", value = "http://orders-service:4003" },
        { name = "USERS_SERVICE_URL", value = "http://users-service:4001" },
        { name = "PRODUCTS_SERVICE_URL", value = "http://products-service:4002" }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = var.ecs_log_group["frontend"]
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "frontend"
        }
      }
    }
  ])
}

# ---------------- cron-report (CRON BEHAVIOUR demo) ----------------
# This task definition is NOT run as a long-lived ECS Service. It is invoked
# periodically by the EventBridge Scheduler rule in scheduled-task-cron.tf,
# which is ECS's equivalent of a Kubernetes CronJob.
resource "aws_ecs_task_definition" "cron_report" {
  family                   = "${var.project_name}-cron-report"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = var.iam_ecs_task_definition_execution_role_arn
  task_role_arn            = var.iam_ecs_task_role_arn

  container_definitions = jsonencode([
    {
      name      = "cron-report"
      image     = "${var.ecr_repository_urls["cron-report"]}:${var.image_tag}"
      essential = true
      environment = [
        { name = "ORDERS_SERVICE_URL", value = "http://orders-service:4003" }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = var.ecs_log_group["cron-report"]
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "cron-report"
        }
      }
    }
  ])
}
