# VPC Outputs
output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.main.cidr_block
}

# Subnet Outputs
output "public_subnet_ids" {
  description = "Map of public subnet IDs"
  value       = { for k, s in aws_subnet.public : k => s.id }
}

output "private_subnet_ids" {
  description = "Map of private subnet IDs"
  value       = { for k, s in aws_subnet.private : k => s.id }
}

output "public_subnet_list" {
  description = "List of public subnet IDs (for convenience)"
  value       = [for s in aws_subnet.public : s.id]
}

output "private_subnet_list" {
  description = "List of private subnet IDs (for convenience)"
  value       = [for s in aws_subnet.private : s.id]
}

# NAT Gateway Outputs
output "nat_gateway_id" {
  description = "ID of the NAT Gateway"
  value       = aws_nat_gateway.main.id
}

output "nat_gateway_eip" {
  description = "Elastic IP address of the NAT Gateway"
  value       = aws_eip.nat.public_ip
}

# ALB Outputs
output "alb_arn" {
  description = "ARN of the shared Application Load Balancer"
  value       = var.create_shared_alb ? aws_lb.shared[0].arn : null
}

output "alb_dns_name" {
  description = "DNS name of the shared Application Load Balancer"
  value       = var.create_shared_alb ? aws_lb.shared[0].dns_name : null
}

output "alb_zone_id" {
  description = "Zone ID of the shared Application Load Balancer"
  value       = var.create_shared_alb ? aws_lb.shared[0].zone_id : null
}

output "alb_security_group_id" {
  description = "Security group ID of the shared ALB"
  value       = var.create_shared_alb ? aws_security_group.alb[0].id : null
}

# Target Group Outputs
output "target_group_arns" {
  description = "Map of target group ARNs by cluster name"
  value       = { for k, tg in aws_lb_target_group.clusters : k => tg.arn }
}

output "target_group_ids" {
  description = "Map of target group IDs by cluster name"
  value       = { for k, tg in aws_lb_target_group.clusters : k => tg.id }
}

# Listener Outputs
output "http_listener_arn" {
  description = "ARN of the HTTP listener"
  value       = var.create_shared_alb ? aws_lb_listener.http[0].arn : null
}
