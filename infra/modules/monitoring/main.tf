# ─────────────────────────────────────────────────────────────────────────────
# Module: monitoring
# CloudWatch Log Groups, Alarms, Dashboard, and SNS alerting.
# ─────────────────────────────────────────────────────────────────────────────

locals {
  name_prefix = "${var.project}-${var.environment}"
}

# ── Log Groups ────────────────────────────────────────────────────────────────

resource "aws_cloudwatch_log_group" "backend" {
  name              = "/chessverse/${var.environment}/backend"
  retention_in_days = var.log_retention_days
  tags              = { Name = "${local.name_prefix}-backend-logs" }
}

resource "aws_cloudwatch_log_group" "ws" {
  name              = "/chessverse/${var.environment}/ws"
  retention_in_days = var.log_retention_days
  tags              = { Name = "${local.name_prefix}-ws-logs" }
}

# ── SNS Topic + Email Subscription ───────────────────────────────────────────

resource "aws_sns_topic" "alerts" {
  name = "${local.name_prefix}-alerts"
  tags = { Name = "${local.name_prefix}-alerts" }
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# ── CloudWatch Alarms ─────────────────────────────────────────────────────────

# ALB — 5XX error rate > 5%
resource "aws_cloudwatch_metric_alarm" "alb_5xx" {
  alarm_name          = "${local.name_prefix}-alb-5xx-high"
  alarm_description   = "ALB 5XX error rate > 5% for 5 minutes"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  threshold           = 5
  treat_missing_data  = "notBreaching"

  metric_query {
    id          = "error_rate"
    expression  = "(m2 / m1) * 100"
    label       = "5XX Error Rate %"
    return_data = true
  }
  metric_query {
    id = "m1"
    metric {
      namespace   = "AWS/ApplicationELB"
      metric_name = "RequestCount"
      dimensions  = { LoadBalancer = var.alb_arn_suffix }
      period      = 300
      stat        = "Sum"
    }
  }
  metric_query {
    id = "m2"
    metric {
      namespace   = "AWS/ApplicationELB"
      metric_name = "HTTPCode_ELB_5XX_Count"
      dimensions  = { LoadBalancer = var.alb_arn_suffix }
      period      = 300
      stat        = "Sum"
    }
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]
}

# ALB — Target response time p99 > 1s
resource "aws_cloudwatch_metric_alarm" "alb_latency" {
  alarm_name          = "${local.name_prefix}-alb-latency-high"
  alarm_description   = "ALB p99 response time > 1s for 5 minutes"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  threshold           = 1
  treat_missing_data  = "notBreaching"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "TargetResponseTime"
  dimensions          = { LoadBalancer = var.alb_arn_suffix }
  period              = 300
  # L1 fix: percentile stats require extended_statistic, not statistic
  extended_statistic = "p99"
  alarm_actions      = [aws_sns_topic.alerts.arn]
  ok_actions         = [aws_sns_topic.alerts.arn]
}

# Backend ASG — CPU > 80% for 10 minutes
resource "aws_cloudwatch_metric_alarm" "backend_cpu" {
  alarm_name          = "${local.name_prefix}-backend-cpu-high"
  alarm_description   = "Backend ASG CPU > 80% for 10 minutes"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  threshold           = 80
  treat_missing_data  = "breaching" # M2 fix: alarm if instance stops sending metrics
  namespace           = "AWS/EC2"
  metric_name         = "CPUUtilization"
  dimensions          = { AutoScalingGroupName = var.backend_asg_name }
  period              = 300
  statistic           = "Average"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
}

# WebSocket ASG — CPU > 80%
resource "aws_cloudwatch_metric_alarm" "ws_cpu" {
  alarm_name          = "${local.name_prefix}-ws-cpu-high"
  alarm_description   = "WebSocket ASG CPU > 80% for 10 minutes"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  threshold           = 80
  treat_missing_data  = "breaching" # M2 fix
  namespace           = "AWS/EC2"
  metric_name         = "CPUUtilization"
  dimensions          = { AutoScalingGroupName = var.ws_asg_name }
  period              = 300
  statistic           = "Average"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
}

# Aurora — CPU > 70%
resource "aws_cloudwatch_metric_alarm" "aurora_cpu" {
  alarm_name          = "${local.name_prefix}-aurora-cpu-high"
  alarm_description   = "Aurora CPU > 70% for 10 minutes"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  threshold           = 70
  treat_missing_data  = "breaching" # M2 fix
  namespace           = "AWS/RDS"
  metric_name         = "CPUUtilization"
  dimensions          = { DBClusterIdentifier = var.aurora_cluster_id }
  period              = 300
  statistic           = "Average"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
}

# Aurora — Volume bytes left (Serverless v2 has shared auto-scaling storage — no FreeLocalStorage)
resource "aws_cloudwatch_metric_alarm" "aurora_storage" {
  alarm_name          = "${local.name_prefix}-aurora-storage-low"
  alarm_description   = "Aurora Serverless v2 volume bytes left < 5GB"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  threshold           = 5368709120 # 5 GB in bytes
  namespace           = "AWS/RDS"
  metric_name         = "AuroraVolumeBytesLeftTotal"
  dimensions          = { DBClusterIdentifier = var.aurora_cluster_id }
  period              = 300
  statistic           = "Average"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
}

# Redis — CPU > 70%
resource "aws_cloudwatch_metric_alarm" "redis_cpu" {
  alarm_name          = "${local.name_prefix}-redis-cpu-high"
  alarm_description   = "Redis CPU > 70% for 10 minutes"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  threshold           = 70
  namespace           = "AWS/ElastiCache"
  metric_name         = "CPUUtilization"
  dimensions          = { CacheClusterId = var.redis_cluster_id }
  period              = 300
  statistic           = "Average"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
}

# Redis — Evictions (memory pressure signal)
resource "aws_cloudwatch_metric_alarm" "redis_evictions" {
  alarm_name          = "${local.name_prefix}-redis-evictions"
  alarm_description   = "Redis is evicting keys — memory pressure"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  threshold           = 0
  treat_missing_data  = "notBreaching"
  namespace           = "AWS/ElastiCache"
  metric_name         = "Evictions"
  dimensions          = { CacheClusterId = var.redis_cluster_id }
  period              = 300
  statistic           = "Sum"
  alarm_actions       = [aws_sns_topic.alerts.arn]
}

# Route53 Health Check — API endpoint down
resource "aws_cloudwatch_metric_alarm" "api_health" {
  alarm_name          = "${local.name_prefix}-api-health-check-failed"
  alarm_description   = "API /health endpoint is failing Route53 health check"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  threshold           = 1
  namespace           = "AWS/Route53"
  metric_name         = "HealthCheckStatus"
  dimensions          = { HealthCheckId = var.route53_health_check_id }
  period              = 60
  statistic           = "Minimum"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
}

# ── CloudWatch Dashboard ──────────────────────────────────────────────────────

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${local.name_prefix}-dashboard"

  # R7 fix: dashboard JSON extracted to templates/dashboard.json.tpl for readability.
  dashboard_body = templatefile("${path.module}/templates/dashboard.json.tpl", {
    environment     = var.environment
    aws_region      = var.aws_region
    alb_arn_suffix  = var.alb_arn_suffix
    backend_asg_name = var.backend_asg_name
    ws_asg_name      = var.ws_asg_name
    aurora_cluster_id = var.aurora_cluster_id
    redis_cluster_id  = var.redis_cluster_id
    alarm_arns_json = jsonencode([
      aws_cloudwatch_metric_alarm.alb_5xx.arn,
      aws_cloudwatch_metric_alarm.alb_latency.arn,
      aws_cloudwatch_metric_alarm.backend_cpu.arn,
      aws_cloudwatch_metric_alarm.ws_cpu.arn,
      aws_cloudwatch_metric_alarm.aurora_cpu.arn,
      aws_cloudwatch_metric_alarm.aurora_storage.arn,
      aws_cloudwatch_metric_alarm.redis_cpu.arn,
      aws_cloudwatch_metric_alarm.api_health.arn,
    ])
  })
}
