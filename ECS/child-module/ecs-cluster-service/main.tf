resource "aws_ecs_cluster" "this" {
  name = "${var.project_name}-cluster"
  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

# Cloud Map namespace used for ECS Service Connect (internal service discovery:
# users-service / products-service / orders-service DNS names, similar to
# how Kubernetes Services give you DNS inside a cluster).
resource "aws_service_discovery_http_namespace" "this" {
  name = "${var.project_name}.local"
}

resource "aws_cloudwatch_log_group" "this" {
  for_each          = toset(["frontend", "users-service", "products-service", "orders-service", "cron-report"])
  name              = "/ecs/${var.project_name}/${each.value}"
  retention_in_days = 3
}
