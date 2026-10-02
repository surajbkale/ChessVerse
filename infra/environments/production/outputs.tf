output "alb_dns_name" { value = module.compute.alb_dns_name }
output "cloudfront_domain" { value = module.storage.cloudfront_domain_name }
output "frontend_s3_bucket" { value = module.storage.bucket_name }
output "cloudfront_distribution_id" { value = module.storage.cloudfront_distribution_id }

output "aurora_endpoint" {
  value     = module.database.cluster_endpoint
  sensitive = true
}

output "redis_url" {
  value     = module.cache.redis_url
  sensitive = true
}

output "dns_name_servers" {
  value       = module.dns.name_servers
  description = "Add these NS records to name.com for DNS delegation"
}

output "ecr_registry" {
  value       = split("/", module.ecr.backend_repository_url)[0]
  description = "Set as ECR_REGISTRY in GitHub Secrets"
}

output "app_url" { value = "https://${module.dns.app_domain}" }
output "api_url" { value = "https://${module.dns.api_domain}" }
output "sns_alerts_arn" { value = module.monitoring.sns_topic_arn }
output "cloudwatch_dashboard" { value = "https://console.aws.amazon.com/cloudwatch/home#dashboards:name=${module.monitoring.dashboard_name}" }

