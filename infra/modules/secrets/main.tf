# ─────────────────────────────────────────────────────────────────────────────
# Module: secrets
# Single Secrets Manager secret per environment containing all app config.
# EC2 instances fetch this at boot and write it to /opt/chessverse/.env
# ─────────────────────────────────────────────────────────────────────────────

locals {
  name_prefix = "${var.project}-${var.environment}"
}

resource "aws_secretsmanager_secret" "app" {
  name                    = "${local.name_prefix}/app-config"
  description             = "ChessVerse ${var.environment} app configuration"
  recovery_window_in_days = 7

  tags = {
    Name        = "${local.name_prefix}-app-config"
    Environment = var.environment
  }
}

resource "aws_secretsmanager_secret_version" "app" {
  secret_id = aws_secretsmanager_secret.app.id

  secret_string = jsonencode({
    DATABASE_URL         = var.database_url
    REDIS_URL            = var.redis_url
    JWT_SECRET           = var.jwt_secret
    COOKIE_SECRET        = var.cookie_secret
    GOOGLE_CLIENT_ID     = var.google_client_id
    GOOGLE_CLIENT_SECRET = var.google_client_secret
    GITHUB_CLIENT_ID     = var.github_client_id
    GITHUB_CLIENT_SECRET = var.github_client_secret
    ALLOWED_HOSTS        = var.allowed_hosts
    AUTH_REDIRECT_URL    = var.auth_redirect_url
    FRONTEND_URL         = var.frontend_url
    BACKEND_URL          = var.backend_url
    NODE_ENV             = "production"
  })
}
