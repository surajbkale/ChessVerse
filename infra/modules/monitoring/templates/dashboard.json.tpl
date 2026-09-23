{
  "widgets": [
    {
      "type": "text",
      "x": 0, "y": 0, "width": 24, "height": 1,
      "properties": { "markdown": "## ChessVerse ${environment} — Infrastructure Dashboard" }
    },
    {
      "type": "metric",
      "x": 0, "y": 1, "width": 8, "height": 6,
      "properties": {
        "title": "ALB Request Count", "view": "timeSeries",
        "metrics": [["AWS/ApplicationELB", "RequestCount", "LoadBalancer", "${alb_arn_suffix}"]],
        "period": 60, "region": "${aws_region}"
      }
    },
    {
      "type": "metric",
      "x": 8, "y": 1, "width": 8, "height": 6,
      "properties": {
        "title": "ALB 5XX Errors", "view": "timeSeries",
        "metrics": [
          ["AWS/ApplicationELB", "HTTPCode_ELB_5XX_Count",    "LoadBalancer", "${alb_arn_suffix}"],
          ["AWS/ApplicationELB", "HTTPCode_Target_5XX_Count", "LoadBalancer", "${alb_arn_suffix}"]
        ],
        "period": 60, "region": "${aws_region}"
      }
    },
    {
      "type": "metric",
      "x": 16, "y": 1, "width": 8, "height": 6,
      "properties": {
        "title": "ALB Response Time (p99)", "view": "timeSeries",
        "metrics": [["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", "${alb_arn_suffix}", {"stat": "p99"}]],
        "period": 60, "region": "${aws_region}"
      }
    },
    {
      "type": "metric",
      "x": 0, "y": 7, "width": 12, "height": 6,
      "properties": {
        "title": "Backend + WS CPU Utilization", "view": "timeSeries",
        "metrics": [
          ["AWS/EC2", "CPUUtilization", "AutoScalingGroupName", "${backend_asg_name}", {"label": "Backend CPU"}],
          ["AWS/EC2", "CPUUtilization", "AutoScalingGroupName", "${ws_asg_name}",      {"label": "WS CPU"}]
        ],
        "period": 60, "region": "${aws_region}"
      }
    },
    {
      "type": "metric",
      "x": 12, "y": 7, "width": 12, "height": 6,
      "properties": {
        "title": "Aurora CPU + Connections", "view": "timeSeries",
        "metrics": [
          ["AWS/RDS", "CPUUtilization",       "DBClusterIdentifier", "${aurora_cluster_id}"],
          ["AWS/RDS", "DatabaseConnections",  "DBClusterIdentifier", "${aurora_cluster_id}"]
        ],
        "period": 60, "region": "${aws_region}"
      }
    },
    {
      "type": "metric",
      "x": 0, "y": 13, "width": 12, "height": 6,
      "properties": {
        "title": "Redis CPU + Evictions", "view": "timeSeries",
        "metrics": [
          ["AWS/ElastiCache", "CPUUtilization", "CacheClusterId", "${redis_cluster_id}"],
          ["AWS/ElastiCache", "Evictions",      "CacheClusterId", "${redis_cluster_id}"]
        ],
        "period": 60, "region": "${aws_region}"
      }
    },
    {
      "type": "alarm",
      "x": 12, "y": 13, "width": 12, "height": 6,
      "properties": {
        "title": "All Alarms Status",
        "alarms": ${alarm_arns_json}
      }
    }
  ]
}
