variable "project" {
  type = string
}

variable "environment" {
  type = string
}

variable "secret_arns" {
  type        = list(string)
  description = "List of Secrets Manager ARNs this EC2 role may read. Required — do not leave empty."
}
