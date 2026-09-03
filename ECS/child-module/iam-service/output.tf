output "iam_ecs_task_definition_execution_role_arn" {
    value = aws_iam_role.execution.arn
}

output "iam_ecs_task_role_arn" {
    value = aws_iam_role.task.arn
}

output "iam_ecs_cron_scheduler_role_arn" {
    value = aws_iam_role.scheduler.arn
}