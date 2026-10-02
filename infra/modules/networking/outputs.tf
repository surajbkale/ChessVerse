output "vpc_id" { value = aws_vpc.main.id }
output "public_subnet_ids" { value = aws_subnet.public[*].id }
output "private_subnet_ids" { value = aws_subnet.private[*].id }
output "alb_sg_id" { value = aws_security_group.alb.id }
output "backend_ec2_sg_id" { value = aws_security_group.backend_ec2.id }
output "ws_ec2_sg_id" { value = aws_security_group.ws_ec2.id }
output "redis_sg_id" { value = aws_security_group.redis.id }
output "aurora_sg_id" { value = aws_security_group.aurora.id }
