variable "project" {
  type = string
}

variable "environment" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "redis_sg_id" {
  type = string
}

variable "node_type" {
  type    = string
  default = "cache.t3.micro"
}


variable "engine_version" {
  type    = string
  default = "7.1"
}

# M6 fix: production uses Multi-AZ replication group (primary + replica)
variable "multi_az" {
  type        = bool
  default     = false
  description = "Enable Multi-AZ with automatic failover. Set true for production."
}

variable "num_cache_clusters" {
  type        = number
  default     = 1
  description = "Number of cache clusters (nodes). Use 2 for production (primary + replica)."
}
