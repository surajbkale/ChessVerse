variable "project" {
  type = string
}

variable "environment" {
  type = string
}

variable "root_domain" {
  type        = string
  description = "Root domain e.g. lumenvault.live"
}

variable "app_subdomain" {
  type        = string
  description = "App subdomain prefix e.g. chess or staging.chess"
}

variable "aws_region" {
  type = string
}
