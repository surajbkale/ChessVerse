variable "project" {
  type = string
}

variable "environment" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "aurora_sg_id" {
  type = string
}

variable "db_name" {
  type    = string
  default = "chessverse"
}

variable "engine_version" {
  type    = string
  default = "15.4"
}

variable "min_acu" {
  type    = number
  default = 0.5
}

variable "max_acu" {
  type    = number
  default = 4
}

variable "backup_retention_days" {
  type    = number
  default = 7
}

variable "deletion_protection" {
  type    = bool
  default = false
}

variable "skip_final_snapshot" {
  type    = bool
  default = true
}

variable "aws_region" {
  type = string
}

# M5 fix: production gets 1 reader instance for failover + read scaling.
# Staging keeps 0 (single writer only) to save cost.
variable "reader_count" {
  type        = number
  default     = 0
  description = "Number of Aurora reader instances. Use 1 for production for near-instant failover."
}
