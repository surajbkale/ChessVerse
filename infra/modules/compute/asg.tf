# ── Auto Scaling Groups with Rolling Update + Auto-Rollback ───────────────────

resource "aws_autoscaling_group" "backend" {
  name                      = "${local.name_prefix}-backend-asg"
  min_size                  = var.backend_asg_min
  max_size                  = var.backend_asg_max
  desired_capacity          = var.backend_asg_min
  vpc_zone_identifier       = var.private_subnet_ids
  target_group_arns         = [aws_lb_target_group.backend.arn]
  health_check_type         = "ELB"
  health_check_grace_period = 120

  launch_template {
    id      = aws_launch_template.backend.id
    version = "$Latest"
  }

  # Rolling update with AUTOMATIC ROLLBACK if health checks fail on new instances
  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = var.min_healthy_percentage
      instance_warmup        = 120
      checkpoint_delay       = 300
      checkpoint_percentages = [25, 50, 100]
    }
    triggers = ["launch_template"]
  }

  tag {
    key                 = "Name"
    value               = "${local.name_prefix}-backend"
    propagate_at_launch = true
  }
  tag {
    key                 = "ChessverseService"
    value               = "backend"
    propagate_at_launch = true
  }
  tag {
    key                 = "Environment"
    value               = var.environment
    propagate_at_launch = true
  }

  lifecycle {
    ignore_changes = [desired_capacity]
  }
}

resource "aws_autoscaling_group" "ws" {
  name                      = "${local.name_prefix}-ws-asg"
  min_size                  = var.ws_asg_min
  max_size                  = var.ws_asg_max
  desired_capacity          = var.ws_asg_min
  vpc_zone_identifier       = var.private_subnet_ids
  target_group_arns         = [aws_lb_target_group.ws.arn]
  health_check_type         = "ELB"
  health_check_grace_period = 120

  launch_template {
    id      = aws_launch_template.ws.id
    version = "$Latest"
  }

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = var.min_healthy_percentage
      instance_warmup        = 120
      checkpoint_delay       = 300
      checkpoint_percentages = [25, 50, 100]
    }
    triggers = ["launch_template"]
  }

  tag {
    key                 = "Name"
    value               = "${local.name_prefix}-ws"
    propagate_at_launch = true
  }
  tag {
    key                 = "ChessverseService"
    value               = "ws"
    propagate_at_launch = true
  }
  tag {
    key                 = "Environment"
    value               = var.environment
    propagate_at_launch = true
  }

  lifecycle {
    ignore_changes = [desired_capacity]
  }
}

# ── CPU Target Tracking Scaling Policies ──────────────────────────────────────

resource "aws_autoscaling_policy" "backend_cpu" {
  name                   = "${local.name_prefix}-backend-cpu-policy"
  autoscaling_group_name = aws_autoscaling_group.backend.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 60.0
  }
}

resource "aws_autoscaling_policy" "ws_cpu" {
  name                   = "${local.name_prefix}-ws-cpu-policy"
  autoscaling_group_name = aws_autoscaling_group.ws.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 60.0
  }
}
