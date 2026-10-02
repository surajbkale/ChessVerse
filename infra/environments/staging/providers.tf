# ─────────────────────────────────────────────────────────────────────────────
# Provider configuration for staging environment
# Two providers are needed:
#   aws           — ap-south-1 (Mumbai) for all resources
#   aws.us_east_1 — us-east-1 (Virginia) for CloudFront ACM cert ONLY
#                   (CloudFront only accepts certs from us-east-1)
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
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "chessverse"
      Environment = "staging"
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
      Environment = "staging"
      ManagedBy   = "terraform"
    }
  }
}
