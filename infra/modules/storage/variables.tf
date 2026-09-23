variable "project" {
  type = string
}

variable "environment" {
  type = string
}

variable "app_domain" {
  type        = string
  description = "App domain e.g. chess.lumenvault.live"
}

variable "acm_certificate_arn" {
  type        = string
  description = "Global ACM cert ARN from us-east-1 — required for CloudFront"
}
