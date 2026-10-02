output "hosted_zone_id" { value = aws_route53_zone.app.zone_id }
output "name_servers" { value = aws_route53_zone.app.name_servers }
output "app_domain" { value = local.app_domain }
output "api_domain" { value = local.api_domain }
output "health_check_id" { value = aws_route53_health_check.api.id }

# Regional cert (ap-south-1) — for ALB HTTPS listener
output "acm_certificate_arn" {
  value       = aws_acm_certificate_validation.regional.certificate_arn
  description = "ACM cert in ap-south-1 — use for ALB"
}

# Global cert (us-east-1) — for CloudFront
output "acm_certificate_arn_global" {
  value       = aws_acm_certificate_validation.global.certificate_arn
  description = "ACM cert in us-east-1 — use for CloudFront"
}
