# ─────────────────────────────────────────────────────────────────────────────
# Production Environment — chess.lumenvault.live
# ─────────────────────────────────────────────────────────────────────────────

locals {
  project       = "chessverse"
  environment   = "production"
  aws_region    = var.aws_region
  root_domain   = "lumenvault.live"
  app_subdomain = "chess"
  alert_email   = "surajkalecsit@gmail.com"
}

# ── ECR Repositories (owned by production) ────────────────────────────────────
module "ecr" {
  source  = "../../modules/ecr"
  project = local.project
}

# ── Networking ────────────────────────────────────────────────────────────────
module "networking" {
  source               = "../../modules/networking"
  project              = local.project
  environment          = local.environment
  vpc_cidr             = "10.0.0.0/16"
  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs = ["10.0.10.0/24", "10.0.11.0/24"]
  availability_zones   = ["ap-south-1a", "ap-south-1b"]
  single_nat_gateway   = false # I1 fix: one NAT GW per AZ for production AZ resilience
}

# ── Database ──────────────────────────────────────────────────────────────────
module "database" {
  source                = "../../modules/database"
  project               = local.project
  environment           = local.environment
  aws_region            = local.aws_region
  vpc_id                = module.networking.vpc_id
  private_subnet_ids    = module.networking.private_subnet_ids
  aurora_sg_id          = module.networking.aurora_sg_id
  db_name               = "chessverse"
  min_acu               = 1
  max_acu               = 16
  backup_retention_days = 14
  deletion_protection   = true
  skip_final_snapshot   = false
  # M5: production gets 1 reader for near-instant failover
  reader_count = 1
}

# ── Cache ─────────────────────────────────────────────────────────────────────
module "cache" {
  source             = "../../modules/cache"
  project            = local.project
  environment        = local.environment
  private_subnet_ids = module.networking.private_subnet_ids
  redis_sg_id        = module.networking.redis_sg_id
  node_type          = "cache.t3.small"
  # M6: production uses Multi-AZ replication group (primary + replica)
  multi_az           = true
  num_cache_clusters = 2
}

# ── IAM ───────────────────────────────────────────────────────────────────────
module "iam" {
  source      = "../../modules/iam"
  project     = local.project
  environment = local.environment
  secret_arns = [module.secrets.secret_arn]
}

# ── Secrets ───────────────────────────────────────────────────────────────────
module "secrets" {
  source      = "../../modules/secrets"
  project     = local.project
  environment = local.environment
  # Full DATABASE_URL with password (Bug #7 fix)
  database_url         = module.database.database_url
  redis_url            = module.cache.redis_url
  jwt_secret           = var.jwt_secret
  cookie_secret        = var.cookie_secret
  google_client_id     = var.google_client_id
  google_client_secret = var.google_client_secret
  github_client_id     = var.github_client_id
  github_client_secret = var.github_client_secret
  allowed_hosts        = "https://${local.app_subdomain}.${local.root_domain}"
  auth_redirect_url    = "https://${local.app_subdomain}.${local.root_domain}/game/random"
  frontend_url         = "https://${local.app_subdomain}.${local.root_domain}"
  backend_url          = "https://api.${local.app_subdomain}.${local.root_domain}"
}

# ── DNS + ACM (Bug #8 fix: no A records, no circular dep) ────────────────────
module "dns" {
  source        = "../../modules/dns"
  project       = local.project
  environment   = local.environment
  root_domain   = local.root_domain
  app_subdomain = local.app_subdomain
  aws_region    = local.aws_region

  # Bug #9 fix: pass us-east-1 provider alias for CloudFront ACM cert
  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }
}

# ── Monitoring ────────────────────────────────────────────────────────────────
module "monitoring" {
  source      = "../../modules/monitoring"
  project     = local.project
  environment = local.environment
  alert_email = local.alert_email
  aws_region  = local.aws_region

  log_retention_days = 90

  # Bug #5 fix: use arn_suffix for CloudWatch dimensions
  alb_arn_suffix          = module.compute.alb_arn_suffix
  backend_tg_arn_suffix   = module.compute.backend_tg_arn_suffix
  ws_tg_arn_suffix        = module.compute.ws_tg_arn_suffix
  backend_asg_name        = module.compute.backend_asg_name
  ws_asg_name             = module.compute.ws_asg_name
  aurora_cluster_id       = module.database.cluster_id
  redis_cluster_id        = "${local.project}-${local.environment}-redis"
  route53_health_check_id = module.dns.health_check_id
}

# ── Storage (uses global cert for CloudFront) ─────────────────────────────────
module "storage" {
  source      = "../../modules/storage"
  project     = local.project
  environment = local.environment
  app_domain  = "${local.app_subdomain}.${local.root_domain}"
  # Bug #9 fix: global cert (us-east-1) for CloudFront
  acm_certificate_arn = module.dns.acm_certificate_arn_global
}

# ── Compute (uses regional cert for ALB) ─────────────────────────────────────
module "compute" {
  source                = "../../modules/compute"
  project               = local.project
  environment           = local.environment
  aws_region            = local.aws_region
  vpc_id                = module.networking.vpc_id
  public_subnet_ids     = module.networking.public_subnet_ids
  private_subnet_ids    = module.networking.private_subnet_ids
  alb_sg_id             = module.networking.alb_sg_id
  backend_ec2_sg_id     = module.networking.backend_ec2_sg_id
  ws_ec2_sg_id          = module.networking.ws_ec2_sg_id
  instance_profile_name = module.iam.instance_profile_name
  # Bug #9 fix: regional cert (ap-south-1) for ALB
  acm_certificate_arn          = module.dns.acm_certificate_arn
  secret_arn                   = module.secrets.secret_arn
  ecr_backend_url              = module.ecr.backend_repository_url
  ecr_ws_url                   = module.ecr.ws_repository_url
  monitoring_log_group_backend = module.monitoring.log_group_backend
  monitoring_log_group_ws      = module.monitoring.log_group_ws
  ec2_instance_type            = "t3.medium"
  backend_asg_min              = 2
  backend_asg_max              = 6
  ws_asg_min                   = 2
  ws_asg_max                   = 6
  # H1/L2 fix: image tag is read from SSM at boot, not baked into Terraform state
  # B5 fix: separate SSM paths per service so backend and WS deploys are independent
  backend_image_tag_ssm_param = aws_ssm_parameter.backend_image_tag.name
  ws_image_tag_ssm_param      = aws_ssm_parameter.ws_image_tag.name
  # M7: production keeps 90% healthy during rolling deploys (never halves capacity)
  min_healthy_percentage = 90
  # M3: production retains ALB logs for 90 days
  alb_log_retention_days = 90
}

# ── SSM Parameters — image tags (B4/B5 fix) ────────────────────────────
# Created here so the parameter always exists before any EC2 instance boots.
# The deploy workflow overwrites these with the real git SHA on each deploy.
resource "aws_ssm_parameter" "backend_image_tag" {
  name  = "/chessverse/production/backend-image-tag"
  type  = "String"
  value = "latest" # overwritten by deploy workflow on first deploy
  tags  = { Name = "chessverse-production-backend-image-tag" }
}

resource "aws_ssm_parameter" "ws_image_tag" {
  name  = "/chessverse/production/ws-image-tag"
  type  = "String"
  value = "latest" # overwritten by deploy workflow on first deploy
  tags  = { Name = "chessverse-production-ws-image-tag" }
}

# ── DNS A Records (Bug #8 fix: after compute+storage, no circular dep) ────────
# Frontend: chess.lumenvault.live → CloudFront
resource "aws_route53_record" "frontend" {
  zone_id = module.dns.hosted_zone_id
  name    = "${local.app_subdomain}.${local.root_domain}"
  type    = "A"

  alias {
    name                   = module.storage.cloudfront_domain_name
    zone_id                = "Z2FDTNDATAQYW2" # CloudFront global hosted zone (constant)
    evaluate_target_health = false
  }
}

# API: api.chess.lumenvault.live → ALB
resource "aws_route53_record" "api" {
  zone_id = module.dns.hosted_zone_id
  name    = "api.${local.app_subdomain}.${local.root_domain}"
  type    = "A"

  alias {
    name                   = module.compute.alb_dns_name
    zone_id                = module.compute.alb_zone_id
    evaluate_target_health = true
  }
}
