# Remote state for staging environment
# Run `terraform init` after setting up the bootstrap S3 bucket.
# required_version and required_providers are in providers.tf.
terraform {
  backend "s3" {
    bucket       = "chessverse-terraform-state"
    key          = "staging/terraform.tfstate"
    region       = "ap-south-1"
    encrypt      = true
    use_lockfile = true # S3 native locking — no DynamoDB needed (Terraform >= 1.10)
  }
}
