# ─────────────────────────────────────────────────────────────────────────────
# ChessVerse — Bootstrap
# Run this ONCE before any environment to create the S3 bucket
# that will store all Terraform remote state.
# State locking uses S3's native locking (requires Terraform >= 1.10).
# No DynamoDB table needed.
# This module uses LOCAL state (stored here in bootstrap/).
# ─────────────────────────────────────────────────────────────────────────────

terraform {
  required_version = ">= 1.10.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      Project   = "ChessVerse"
      ManagedBy = "Terraform"
      Module    = "bootstrap"
    }
  }
}

variable "aws_region" {
  default = "ap-south-1"
}

# ── S3 Bucket for Terraform State ────────────────────────────────────────────

resource "aws_s3_bucket" "tf_state" {
  bucket = "chessverse-terraform-state"

  # Prevent accidental deletion of state bucket
  lifecycle {
    prevent_destroy = true
  }

  tags = { Name = "chessverse-terraform-state" }
}

resource "aws_s3_bucket_versioning" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block all public access to state bucket
resource "aws_s3_bucket_public_access_block" "tf_state" {
  bucket                  = aws_s3_bucket.tf_state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

output "state_bucket_name" {
  value = aws_s3_bucket.tf_state.bucket
}

