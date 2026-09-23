output "backend_repository_url" { value = aws_ecr_repository.backend.repository_url }
output "ws_repository_url" { value = aws_ecr_repository.ws.repository_url }
output "registry_id" { value = aws_ecr_repository.backend.registry_id }
