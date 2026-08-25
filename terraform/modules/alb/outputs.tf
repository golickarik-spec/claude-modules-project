# alb module — outputs

output "alb_dns_name" {
  description = "Public DNS name of the Application Load Balancer."
  value       = aws_lb.main.dns_name
}

output "alb_sg_id" {
  description = "ID of the ALB security group (source for the task security group)."
  value       = aws_security_group.alb.id
}

output "target_group_arn" {
  description = "ARN of the target group the ECS service registers with."
  value       = aws_lb_target_group.app.arn
}

output "listener_arn" {
  description = "ARN of the HTTP listener."
  value       = aws_lb_listener.http.arn
}
