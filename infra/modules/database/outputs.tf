output "cluster_endpoint" { value = aws_rds_cluster.aurora.endpoint }
output "reader_endpoint" { value = aws_rds_cluster.aurora.reader_endpoint }
output "database_name" { value = aws_rds_cluster.aurora.database_name }
output "port" { value = aws_rds_cluster.aurora.port }
output "db_secret_arn" { value = aws_secretsmanager_secret.db_credentials.arn }
output "cluster_id" { value = aws_rds_cluster.aurora.cluster_identifier }

output "db_master_password" {
  value       = random_password.db_master.result
  sensitive   = true
  description = "Aurora master password — used to build DATABASE_URL in secrets module"
}

output "database_url" {
  value       = "postgresql://chessverse_admin:${random_password.db_master.result}@${aws_rds_cluster.aurora.endpoint}:5432/${aws_rds_cluster.aurora.database_name}"
  sensitive   = true
  description = "Full DATABASE_URL with credentials — pass directly to the secrets module"
}
