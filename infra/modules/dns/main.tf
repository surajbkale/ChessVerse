# ─────────────────────────────────────────────────────────────────────────────
# Module: dns
# Creates:
#   - Route53 hosted zone for the app subdomain
#   - ACM cert in ap-south-1 (regional, for ALB)
#   - ACM cert in us-east-1 (global, for CloudFront)
#   - DNS validation records for both certs
#   - Route53 health check on the API endpoint
#
# DNS A records (frontend → CloudFront, api → ALB) are created in the
# environment main.tf AFTER compute and storage modules run — this breaks
# the circular dependency between the dns and compute modules.
#
# After first apply: add the output `name_servers` as NS records for
# `chess.lumenvault.live` (or staging.chess.lumenvault.live) in name.com.
# ─────────────────────────────────────────────────────────────────────────────

terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      # This module needs a second AWS provider configured for us-east-1
      # (required for CloudFront ACM certs). The calling environment must
      # pass: providers = { aws = aws, aws.us_east_1 = aws.us_east_1 }
      configuration_aliases = [aws.us_east_1]
    }
  }
}

locals {
  app_domain = "${var.app_subdomain}.${var.root_domain}"
  api_domain = "api.${var.app_subdomain}.${var.root_domain}"
}

# ── Route53 Hosted Zone ───────────────────────────────────────────────────────

resource "aws_route53_zone" "app" {
  name = local.app_domain
  tags = {
    Name        = "${var.project}-${var.environment}-zone"
    Environment = var.environment
  }
}

# ── Regional ACM Certificate (ap-south-1) — for ALB ─────────────────────────

resource "aws_acm_certificate" "regional" {
  domain_name               = local.app_domain
  subject_alternative_names = [local.api_domain]
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = { Name = "${var.project}-${var.environment}-cert-regional" }
}

resource "aws_route53_record" "regional_cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.regional.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = aws_route53_zone.app.zone_id
}

resource "aws_acm_certificate_validation" "regional" {
  certificate_arn         = aws_acm_certificate.regional.arn
  validation_record_fqdns = [for r in aws_route53_record.regional_cert_validation : r.fqdn]
}

# ── Global ACM Certificate (us-east-1) — for CloudFront ─────────────────────
# CloudFront ONLY accepts certs from us-east-1. We use the aliased provider.

resource "aws_acm_certificate" "global" {
  provider                  = aws.us_east_1
  domain_name               = local.app_domain
  subject_alternative_names = [local.api_domain]
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = { Name = "${var.project}-${var.environment}-cert-global" }
}

# Reuse the same Route53 validation records — both certs validate on the same zone
resource "aws_route53_record" "global_cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.global.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = aws_route53_zone.app.zone_id
}

resource "aws_acm_certificate_validation" "global" {
  provider                = aws.us_east_1
  certificate_arn         = aws_acm_certificate.global.arn
  validation_record_fqdns = [for r in aws_route53_record.global_cert_validation : r.fqdn]
}

# ── Route53 Health Check on API endpoint ─────────────────────────────────────
# This uses the domain name string — does NOT depend on the ALB or compute module.
# The health check will start reporting once the A record is created and DNS propagates.

resource "aws_route53_health_check" "api" {
  fqdn              = local.api_domain
  port              = 443
  type              = "HTTPS"
  resource_path     = "/health"
  failure_threshold = 3
  request_interval  = 30

  tags = { Name = "${var.project}-${var.environment}-api-healthcheck" }
}
