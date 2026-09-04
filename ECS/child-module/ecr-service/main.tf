# One ECR repo per image. Build & push each service before `terraform apply`
# (the ECS services will fail to start otherwise). See ecs/README.md.

locals {
  images = [
    "frontend",
    "users-service",
    "products-service",
    "orders-service",
    "sidecar-logger",
    "init-check",
    "cron-report",
  ]
}

resource "aws_ecr_repository" "repo" {
  for_each             = toset(local.images)
  name                 = "${var.project_name}/${each.value}"
  image_tag_mutability = "IMMUTABLE"
  force_delete         = true
}
