variable "project" {
  type = string
}

variable "environment" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "public_subnet_ids" {
  type = list(string)
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "alb_sg_id" {
  type = string
}

variable "backend_ec2_sg_id" {
  type = string
}

variable "ws_ec2_sg_id" {
  type = string
}

variable "instance_profile_name" {
  type = string
}

variable "acm_certificate_arn" {
  type        = string
  description = "Regional ACM cert ARN (ap-south-1) for ALB HTTPS listener"
}

variable "secret_arn" {
  type = string
}

variable "ecr_backend_url" {
  type = string
}

variable "ecr_ws_url" {
  type = string
}

variable "monitoring_log_group_backend" {
  type = string
}

variable "monitoring_log_group_ws" {
  type = string
}

variable "ec2_instance_type" {
  type    = string
  default = "t3.small"
}

variable "backend_asg_min" {
  type    = number
  default = 1
}

variable "backend_asg_max" {
  type    = number
  default = 4
}

variable "ws_asg_min" {
  type    = number
  default = 1
}

variable "ws_asg_max" {
  type    = number
  default = 4
}

# B5 fix: separate SSM param per service so backend and WS can be deployed independently.
# The deploy workflow writes each SHA to its own parameter. User-data reads the relevant one at boot.
variable "backend_image_tag_ssm_param" {
  type        = string
  description = "SSM Parameter path for the backend Docker image tag (e.g. /chessverse/staging/backend-image-tag)"
}

variable "ws_image_tag_ssm_param" {
  type        = string
  description = "SSM Parameter path for the WS Docker image tag (e.g. /chessverse/staging/ws-image-tag)"
}

# M7 fix: configurable per environment (50 for staging, 90 for production)
variable "min_healthy_percentage" {
  type        = number
  default     = 50
  description = "Minimum % of healthy instances required during an ASG instance refresh rolling update"
}

# M3 fix: configurable ALB log retention per environment
variable "alb_log_retention_days" {
  type        = number
  default     = 30
  description = "Days to retain ALB access logs in S3 (use 90+ for production)"
}

