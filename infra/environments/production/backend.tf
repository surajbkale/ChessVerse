# Remote state for production environment
terraform {
  required_version = ">= 1.10.0"

  backend "s3" {
    bucket       = "chessverse-terraform-state"
    key          = "production/terraform.tfstate"
    region       = "ap-south-1"
    encrypt      = true
    use_lockfile = true # S3 native locking — no DynamoDB needed (Terraform >= 1.10)
  }
}
