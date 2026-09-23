# H4 fix: data source — never hardcode the ELB service account ID
data "aws_elb_service_account" "main" {}

# H1 fix: needed to scope ALB log S3 policy to the correct account-specific path
data "aws_caller_identity" "current" {}

# ── Application Load Balancer ─────────────────────────────────────────────────

resource "aws_lb" "main" {
  name               = "${local.name_prefix}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.alb_sg_id]
  subnets            = var.public_subnet_ids

  # WebSocket connections can be idle for long stretches between moves.
  # Default is 60s which kills active game connections. Set to 1 hour.
  idle_timeout = 3600

  enable_deletion_protection = var.environment == "production"

  # ALB access logs
  access_logs {
    bucket  = aws_s3_bucket.alb_logs.bucket
    prefix  = "alb"
    enabled = true
  }

  tags = { Name = "${local.name_prefix}-alb" }
}

# S3 bucket for ALB access logs
resource "aws_s3_bucket" "alb_logs" {
  bucket = "${local.name_prefix}-alb-logs"
  # L7 fix: protect production logs from accidental destroy
  force_destroy = var.environment != "production"
  tags          = { Name = "${local.name_prefix}-alb-logs" }
}

resource "aws_s3_bucket_public_access_block" "alb_logs" {
  bucket                  = aws_s3_bucket.alb_logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id
  rule {
    id     = "expire-old-logs"
    status = "Enabled"
    # M3 fix: retention is now configurable per environment
    expiration { days = var.alb_log_retention_days }
  }
}

# H4 fix: use data source instead of hardcoded region-specific account ID
resource "aws_s3_bucket_policy" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      # H1 fix: ALB writes to <prefix>/AWSLogs/<account-id>/elasticloadbalancing/<region>/…
      # The policy must cover that full path — using /* ensures it regardless of region/account.
      Effect    = "Allow"
      Principal = { AWS = data.aws_elb_service_account.main.arn }
      Action    = "s3:PutObject"
      Resource  = "${aws_s3_bucket.alb_logs.arn}/*"
    }]
  })
}

# ── Target Groups ─────────────────────────────────────────────────────────────

resource "aws_lb_target_group" "backend" {
  name     = "${local.name_prefix}-backend-tg"
  port     = 3000
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    path                = "/health"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
    matcher             = "200"
  }

  deregistration_delay = 30 # Wait 30s for in-flight requests before draining

  tags = { Name = "${local.name_prefix}-backend-tg" }
}

resource "aws_lb_target_group" "ws" {
  name     = "${local.name_prefix}-ws-tg"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  # WebSocket connections need longer idle timeout
  health_check {
    path                = "/health"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
    matcher             = "200"
  }

  # Sticky sessions — ALB pins each WS client to one instance
  # Redis pub/sub handles cross-instance game events, but the TCP
  # WebSocket connection itself must stay on one instance.
  stickiness {
    type            = "lb_cookie"
    cookie_duration = 86400
    enabled         = true
  }

  deregistration_delay = 60 # WS connections may be long-lived

  tags = { Name = "${local.name_prefix}-ws-tg" }
}

# ── Listeners ─────────────────────────────────────────────────────────────────

# HTTP → redirect to HTTPS
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# HTTPS listener
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.acm_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend.arn
  }
}

# /ws/* → WebSocket target group (higher priority = evaluated first)
resource "aws_lb_listener_rule" "ws" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ws.arn
  }

  condition {
    path_pattern { values = ["/ws/*"] }
  }
}
# All other paths fall through to the default action on the HTTPS listener
# which already points to the backend target group — no redundant rule needed.
