output "ecs_cluster_name" {
  value = aws_ecs_cluster.this.name
}

output "ecs_cluster_arn" {
  value = aws_ecs_cluster.this.arn
}

output "ecs_cloudwatch_log_group_names" {
  description = "CloudWatch Log Group names"
  value = {
    for k, v in aws_cloudwatch_log_group.this : k => v.name
  }
}

# output "ecs_cloudwatch_log_group_arns" {
#   description = "CloudWatch Log Group ARNs"
#   value = {
#     for k, v in aws_cloudwatch_log_group.this : k => v.arn
#   }
# }

output "ecs_service_discovery_namespace" {
  value = aws_service_discovery_http_namespace.this.arn
}