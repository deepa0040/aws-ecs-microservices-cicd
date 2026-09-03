aws_region = "us-east-1"
project_name = "ecs-eks-demo"
vpc_cidr  = "10.20.0.0/16"
public_subnet_cidrs = ["10.20.1.0/24", "10.20.2.0/24"]
azs = ["us-east-1a", "us-east-1b"]
image_tag  = "0.0"
cron_schedule_expression = "rate(5 minutes)"