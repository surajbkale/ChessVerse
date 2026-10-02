output "redis_endpoint" { value = aws_elasticache_replication_group.redis.primary_endpoint_address }
output "redis_port" { value = aws_elasticache_replication_group.redis.port }
output "redis_url" { value = "redis://${aws_elasticache_replication_group.redis.primary_endpoint_address}:${aws_elasticache_replication_group.redis.port}" }
