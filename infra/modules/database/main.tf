# ─────────────────────────────────────────────────────────────────────────────
# Module: database
# Aurora PostgreSQL Serverless v2 — replaces Neon external DB.
# DB credentials are auto-generated and stored in Secrets Manager.
# ─────────────────────────────────────────────────────────────────────────────

terraform {
  required_providers {
    aws    = { source = "hashicorp/aws" }
    random = { source = "hashicorp/random" }
  }
}


locals {
  name_prefix = "${var.project}-${var.environment}"
  cluster_id  = "${local.name_prefix}-aurora"
}

# ── DB Subnet Group ───────────────────────────────────────────────────────────

resource "aws_db_subnet_group" "aurora" {
  name       = "${local.name_prefix}-aurora-subnet-group"
  subnet_ids = var.private_subnet_ids
  tags       = { Name = "${local.name_prefix}-aurora-subnet-group" }
}

# ── Aurora Cluster Parameter Group ───────────────────────────────────────────

resource "aws_rds_cluster_parameter_group" "aurora" {
  name        = "${local.name_prefix}-aurora-params"
  family      = "aurora-postgresql15"
  description = "ChessVerse Aurora PostgreSQL 15 parameter group"

  parameter {
    name  = "log_statement"
    value = "ddl"
  }

  parameter {
    name  = "log_min_duration_statement"
    value = "1000" # Log queries taking more than 1 second
  }
}

# ── Random DB Password ────────────────────────────────────────────────────────

resource "random_password" "db_master" {
  length           = 32
  special          = true
  override_special = "!#$%^&*()-_=+[]{}|;:,.<>?"
}

# ── Secrets Manager — DB Credentials ─────────────────────────────────────────

resource "aws_secretsmanager_secret" "db_credentials" {
  name                    = "${local.name_prefix}/aurora/credentials"
  description             = "Aurora PostgreSQL master credentials for ${local.name_prefix}"
  recovery_window_in_days = 7
  tags                    = { Name = "${local.name_prefix}-aurora-credentials" }
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username     = "chessverse_admin"
    password     = random_password.db_master.result
    host         = aws_rds_cluster.aurora.endpoint
    port         = 5432
    dbname       = var.db_name
    database_url = "postgresql://chessverse_admin:${random_password.db_master.result}@${aws_rds_cluster.aurora.endpoint}:5432/${var.db_name}"
  })

  # Re-create when cluster endpoint changes
  depends_on = [aws_rds_cluster.aurora]
}

# ── Aurora Serverless v2 Cluster ──────────────────────────────────────────────

resource "aws_rds_cluster" "aurora" {
  cluster_identifier = local.cluster_id
  engine             = "aurora-postgresql"
  engine_version     = var.engine_version
  engine_mode        = "provisioned" # Required for Serverless v2
  database_name      = var.db_name
  master_username    = "chessverse_admin"
  master_password    = random_password.db_master.result

  db_subnet_group_name            = aws_db_subnet_group.aurora.name
  vpc_security_group_ids          = [var.aurora_sg_id]
  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.aurora.name

  # Serverless v2 scaling configuration
  serverlessv2_scaling_configuration {
    min_capacity = var.min_acu
    max_capacity = var.max_acu
  }

  # Backup & recovery
  backup_retention_period      = var.backup_retention_days
  preferred_backup_window      = "02:00-03:00"
  preferred_maintenance_window = "sun:04:00-sun:05:00"
  copy_tags_to_snapshot        = true
  deletion_protection          = var.deletion_protection
  skip_final_snapshot          = var.skip_final_snapshot
  final_snapshot_identifier    = var.skip_final_snapshot ? null : "${local.cluster_id}-final-snapshot"

  # Storage encryption
  storage_encrypted = true

  # Enable enhanced monitoring and logs
  enabled_cloudwatch_logs_exports = ["postgresql"]

  tags = {
    Name        = local.cluster_id
    Environment = var.environment
  }
}

# ── Aurora Serverless v2 Instance ─────────────────────────────────────────────
# Serverless v2 requires at least one instance in the cluster

resource "aws_rds_cluster_instance" "writer" {
  identifier           = "${local.cluster_id}-writer"
  cluster_identifier   = aws_rds_cluster.aurora.id
  instance_class       = "db.serverless"
  engine               = aws_rds_cluster.aurora.engine
  engine_version       = aws_rds_cluster.aurora.engine_version
  db_subnet_group_name = aws_db_subnet_group.aurora.name

  # Enhanced monitoring (60-second granularity)
  monitoring_interval = 60
  monitoring_role_arn = aws_iam_role.rds_monitoring.arn

  auto_minor_version_upgrade = true

  tags = { Name = "${local.cluster_id}-writer" }
}

# ── IAM Role for Enhanced Monitoring ─────────────────────────────────────────

resource "aws_iam_role" "rds_monitoring" {
  name = "${local.name_prefix}-rds-monitoring-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "monitoring.rds.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  role       = aws_iam_role.rds_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# ── Aurora Reader Instance (M5 fix) ───────────────────────────────────────────
# count = 0 in staging (single writer, cheaper)
# count = 1 in production (enables near-instant failover + read offloading)

resource "aws_rds_cluster_instance" "reader" {
  count                = var.reader_count
  identifier           = "${local.cluster_id}-reader-${count.index + 1}"
  cluster_identifier   = aws_rds_cluster.aurora.id
  instance_class       = "db.serverless"
  engine               = aws_rds_cluster.aurora.engine
  engine_version       = aws_rds_cluster.aurora.engine_version
  db_subnet_group_name = aws_db_subnet_group.aurora.name

  # Failover priority: 1 = first to be promoted if writer fails
  promotion_tier = 1

  monitoring_interval = 60
  monitoring_role_arn = aws_iam_role.rds_monitoring.arn

  auto_minor_version_upgrade = true

  tags = { Name = "${local.cluster_id}-reader-${count.index + 1}" }
}
