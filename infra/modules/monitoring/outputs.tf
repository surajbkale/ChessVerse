output "log_group_backend" { value = aws_cloudwatch_log_group.backend.name }
output "log_group_ws" { value = aws_cloudwatch_log_group.ws.name }
output "sns_topic_arn" { value = aws_sns_topic.alerts.arn }
output "dashboard_name" { value = aws_cloudwatch_dashboard.main.dashboard_name }
