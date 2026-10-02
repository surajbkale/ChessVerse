# ─────────────────────────────────────────────────────────────────────────────
# Module: cache
# ElastiCache Redis — used for WebSocket pub/sub and Express session store.
# M6 fix: using replication_group instead of cluster so production can have
# Multi-AZ with automatic failover (primary + replica). Staging runs single-
# node (num_cache_clusters=1) with the same resource type for parity.
# ─────────────────────────────────────────────────────────────────────────────

locals {
  name_prefix = "${var.project}-${var.environment}"
}

resource "aws_elasticache_subnet_group" "redis" {
  name       = "${local.name_prefix}-redis-subnet-group"
  subnet_ids = var.private_subnet_ids
  tags       = { Name = "${local.name_prefix}-redis-subnet-group" }
}

resource "aws_elasticache_replication_group" "redis" {
  replication_group_id = "${local.name_prefix}-redis"
  description          = "ChessVerse ${var.environment} Redis replication group"

  engine               = "redis"
  node_type            = var.node_type
  num_cache_clusters   = var.num_cache_clusters
  parameter_group_name = "default.redis7"
  engine_version       = var.engine_version
  port                 = 6379

  subnet_group_name  = aws_elasticache_subnet_group.redis.name
  security_group_ids = [var.redis_sg_id]

  # Multi-AZ + automatic failover (production only — staging uses single node)
  multi_az_enabled           = var.multi_az
  automatic_failover_enabled = var.multi_az

  # Snapshots for recovery
  snapshot_retention_limit = 1
  snapshot_window          = "03:00-04:00"
  maintenance_window       = "sun:05:00-sun:06:00"

  auto_minor_version_upgrade = true
  at_rest_encryption_enabled = true
  transit_encryption_enabled = false # within VPC, TLS not required for Redis

  tags = {
    Name        = "${local.name_prefix}-redis"
    Environment = var.environment
  }
}
