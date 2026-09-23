variable "project" {
  type = string
}

variable "environment" {
  type = string
}

variable "alert_email" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "log_retention_days" {
  type    = number
  default = 30
}

variable "alb_arn_suffix" {
  type        = string
  description = "ALB ARN suffix (e.g. app/name/id) — used for CloudWatch dimensions"
}

variable "backend_tg_arn_suffix" {
  type        = string
  description = "Backend target group ARN suffix"
}

variable "ws_tg_arn_suffix" {
  type        = string
  description = "WS target group ARN suffix"
}

variable "backend_asg_name" {
  type = string
}

variable "ws_asg_name" {
  type = string
}

variable "aurora_cluster_id" {
  type = string
}

variable "redis_cluster_id" {
  type = string
}

variable "route53_health_check_id" {
  type = string
}
