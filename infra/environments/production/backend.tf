# Remote state for production environment
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

  backend "s3" {
    bucket       = "chessverse-terraform-state"
    key          = "production/terraform.tfstate"
    region       = "ap-south-1"
    encrypt      = true
    use_lockfile = true # S3 native locking — no DynamoDB needed (Terraform >= 1.10)
  }
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      Project     = "ChessVerse"
      Environment = "production"
      ManagedBy   = "Terraform"
    }
  }
}
