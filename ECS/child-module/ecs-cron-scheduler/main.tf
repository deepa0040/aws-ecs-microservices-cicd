# CRON BEHAVIOUR on ECS: EventBridge Scheduler periodically calls ecs:RunTask
# to launch a short-lived cron-report task. This is the ECS equivalent of a
# Kubernetes CronJob (see eks/k8s-yaml/cronjob.yaml for that side).

resource "aws_scheduler_schedule" "cron_report" {
  name       = "${var.project_name}-cron-report"
  group_name = "default"

  flexible_time_window {
    mode = "OFF"
  }

  schedule_expression = var.cron_schedule_expression

  target {
    arn      = var.ecs_cluster_arn
    role_arn = var.iam_ecs_cron_scheduler_role_arn

    ecs_parameters {
      task_definition_arn = var.ecs_task_definitions_arns["cron_report"]
      launch_type         = "FARGATE"
      network_configuration {
        subnets          = var.public_subnet_ids
        security_groups  = [var.aws_security_ids["tasks"]]
        assign_public_ip = true
      }
    }

    input = jsonencode({})
  }
}
