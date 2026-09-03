# All services join the same Service Connect namespace so they can reach
# each other by short DNS name (users-service, products-service, orders-service)
# exactly like they would via a Kubernetes Service on EKS.

resource "aws_ecs_service" "users_service" {
  name            = "users-service"
  cluster         = var.ecs_cluster_arn
  task_definition = var.ecs_task_definitions_arns["users_service"]
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.public_subnet_ids
    security_groups  = [var.aws_security_ids["tasks"]]
    assign_public_ip = true
  }

  service_connect_configuration {
    enabled   = true
    namespace = var.ecs_service_discovery_namespace
    service {
      port_name      = "users-service"
      discovery_name = "users-service"
      client_alias {
        port     = 4001
        dns_name = "users-service"
      }
    }
  }
}

resource "aws_ecs_service" "products_service" {
  name            = "products-service"
  cluster         = var.ecs_cluster_arn
  task_definition = var.ecs_task_definitions_arns["products_service"]
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.public_subnet_ids
    security_groups  = [var.aws_security_ids["tasks"]]
    assign_public_ip = true
  }

  service_connect_configuration {
    enabled   = true
    namespace = var.ecs_service_discovery_namespace
    service {
      port_name      = "products-service"
      discovery_name = "products-service"
      client_alias {
        port     = 4002
        dns_name = "products-service"
      }
    }
  }
}

resource "aws_ecs_service" "orders_service" {
  name            = "orders-service"
  cluster         = var.ecs_cluster_arn
  task_definition = var.ecs_task_definitions_arns["orders_service"]
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.public_subnet_ids
    security_groups  = [var.aws_security_ids["tasks"]]
    assign_public_ip = true
  }

  service_connect_configuration {
    enabled   = true
    namespace = var.ecs_service_discovery_namespace
    service {
      port_name      = "orders-service"
      discovery_name = "orders-service"
      client_alias {
        port     = 4003
        dns_name = "orders-service"
      }
    }
  }

  depends_on = [aws_ecs_service.users_service, aws_ecs_service.products_service]
}

# resource "aws_ecs_service" "frontend" {
#   name            = "frontend"
#   cluster         = var.ecs_cluster_arn
#   task_definition = var.ecs_task_definitions_arns["frontend"]
#   desired_count   = 1
#   launch_type     = "FARGATE"

#   network_configuration {
#     subnets          = var.public_subnet_ids
#     security_groups  = [var.aws_security_ids["tasks"]]
#     assign_public_ip = true
#   }

#   service_connect_configuration {
#     enabled   = true
#     namespace = var.ecs_service_discovery_namespace
#   }

#   load_balancer {
#     target_group_arn = var.alb_target_group
#     container_name   = "frontend"
#     container_port   = 4000
#   }

#   depends_on = [ aws_ecs_service.orders_service]
# }
