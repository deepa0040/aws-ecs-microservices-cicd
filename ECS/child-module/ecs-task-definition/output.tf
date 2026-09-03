output "ecs_task_definitions_arns" {
  value = {
    users_service    = aws_ecs_task_definition.users_service.arn
    products_service = aws_ecs_task_definition.products_service.arn
    orders_service   = aws_ecs_task_definition.orders_service.arn
    frontend   = aws_ecs_task_definition.frontend.arn
    cron_report   = aws_ecs_task_definition.cron_report.arn
  }
}