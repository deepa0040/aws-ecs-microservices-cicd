output "aws_security_ids" {
    value = {
        alb = aws_security_group.alb.id
        tasks = aws_security_group.tasks.id
    }
}