# Data sources to lookup existing VPC resources
data "aws_vpc" "selected" {
  count = var.vpc_name != null ? 1 : 0

  tags = {
    Name = var.vpc_name
  }
}

data "aws_subnets" "private" {
  count = var.private_subnet_tags != null ? 1 : 0

  filter {
    name   = "vpc-id"
    values = [local.vpc_id]
  }

  tags = var.private_subnet_tags
}

data "aws_lb_target_group" "selected" {
  count = var.alb_target_group_name != null ? 1 : 0
  name  = var.alb_target_group_name
}

data "aws_lb" "selected" {
  count = var.alb_name != null ? 1 : 0
  name  = var.alb_name
}
