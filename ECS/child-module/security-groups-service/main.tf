resource "aws_security_group" "alb" {
  name        = "${var.project_name}-alb-sg"
  description = "Allow inbound HTTP to the ALB"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "tasks" {
  name        = "${var.project_name}-tasks-sg"
  description = "Allow traffic between ECS tasks and from the ALB"
  vpc_id      = var.vpc_id

  # allow all traffic between tasks in this SG (frontend -> orders-service -> users/products-service)
  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
  }
  # allow ALB -> frontend task
  ingress {
    from_port       = 4000
    to_port         = 4000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
