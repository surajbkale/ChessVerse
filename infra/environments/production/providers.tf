# ─────────────────────────────────────────────────────────────────────────────
# Provider configuration for production environment
# Two providers needed:
#   aws           — ap-south-1 (Mumbai) for all resources
#   aws.us_east_1 — us-east-1 (Virginia) for CloudFront ACM cert ONLY
# ─────────────────────────────────────────────────────────────────────────────

terraform {
  required_version = ">= 1.10.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "chessverse"
      Environment = "production"
      ManagedBy   = "terraform"
    }
  }
}

provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"

  default_tags {
    tags = {
      Project     = "chessverse"
      Environment = "production"
      ManagedBy   = "terraform"
    }
  }
}
