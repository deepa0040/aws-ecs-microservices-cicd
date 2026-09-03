# module "VPC" {
#   source = "./../child-module/vpc-service"
#   vpc_cidr = var.vpc_cidr
#   public_subnet_cidrs = var.public_subnet_cidrs
#   azs = var.azs
#   project_name = var.project_name
# }

# module "Security_Group" {
#   source = "./../child-module/security-groups-service"
#   project_name = var.project_name
#   vpc_id = module.VPC.vpc_id
# }

# module "IAM" {
#   source = "./../child-module/iam-service"
#   project_name = var.project_name
#   aws_ecs_cluster_arn = module.ECS_cluster.ecs_cluster_arn
#   ecs_task_definitions_arns = module.ECS_task_definition.ecs_task_definitions_arns
# }

module "ECR" {
  source = "./../child-module/ecr-service"
  project_name = var.project_name
}

# module "ECS_cluster" {
#   source = "./../child-module/ecs-cluster-service"
#   project_name = var.project_name
# }

# module "ECS_task_definition" {
#   source = "../child-module/ecs-task-definition"
#   project_name = var.project_name
#   aws_region   = var.aws_region
#   iam_ecs_task_definition_execution_role_arn = module.IAM.iam_ecs_task_definition_execution_role_arn
#   iam_ecs_task_role_arn = module.IAM.iam_ecs_task_role_arn
#   ecs_log_group = module.ECS_cluster.ecs_cloudwatch_log_group_names
#   ecr_repository_urls = module.ECR.ecr_repository_urls
#   image_tag = var.image_tag
# }

# module "ECS_service" {
#   source = "../child-module/ecs-services"
#   ecs_cluster_arn = module.ECS_cluster.ecs_cluster_arn
#   ecs_task_definitions_arns = module.ECS_task_definition.ecs_task_definitions_arns
#   aws_security_ids = module.Security_Group.aws_security_ids
#   public_subnet_ids = module.VPC.public_subnet_ids
#   ecs_service_discovery_namespace = module.ECS_cluster.ecs_service_discovery_namespace
#   alb_target_group = module.ALB.alb_target_group
# }

# module "ALB" {
#   source = "../child-module/alb-service"
#   project_name = var.project_name
#   aws_security_ids = module.Security_Group.aws_security_ids
#   public_subnet_ids = module.VPC.public_subnet_ids
#   vpc_id = module.VPC.vpc_id
# }

# module "ECS_cron_scheduler" {
#   source = "../child-module/ecs-cron-scheduler"
#   project_name = var.project_name
#   cron_schedule_expression = var.cron_schedule_expression
#   ecs_cluster_arn = module.ECS_cluster.ecs_cluster_arn
#   iam_ecs_cron_scheduler_role_arn = module.IAM.iam_ecs_cron_scheduler_role_arn
#   ecs_task_definitions_arns = module.ECS_task_definition.ecs_task_definitions_arns
#   aws_security_ids = module.Security_Group.aws_security_ids
#   public_subnet_ids = module.VPC.public_subnet_ids
# }