# ── Launch Templates ──────────────────────────────────────────────────────────

resource "aws_launch_template" "backend" {
  name_prefix   = "${local.name_prefix}-backend-lt-"
  image_id      = data.aws_ami.ubuntu.id
  instance_type = var.ec2_instance_type

  iam_instance_profile {
    name = var.instance_profile_name
  }

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [var.backend_ec2_sg_id]
    delete_on_termination       = true
  }

  user_data = base64encode(templatefile("${path.module}/user-data/backend.sh.tpl", {
    aws_region          = var.aws_region
    secret_arn          = var.secret_arn
    ecr_backend_url     = var.ecr_backend_url
    image_tag_ssm_param = var.backend_image_tag_ssm_param
    log_group           = var.monitoring_log_group_backend
    environment         = var.environment
  }))

  monitoring { enabled = true }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required" # IMDSv2 — security best practice
    http_put_response_hop_limit = 1
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name              = "${local.name_prefix}-backend"
      ChessverseService = "backend"
      Environment       = var.environment
    }
  }

  lifecycle { create_before_destroy = true }
}

resource "aws_launch_template" "ws" {
  name_prefix   = "${local.name_prefix}-ws-lt-"
  image_id      = data.aws_ami.ubuntu.id
  instance_type = var.ec2_instance_type

  iam_instance_profile {
    name = var.instance_profile_name
  }

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [var.ws_ec2_sg_id]
    delete_on_termination       = true
  }

  user_data = base64encode(templatefile("${path.module}/user-data/ws.sh.tpl", {
    aws_region          = var.aws_region
    secret_arn          = var.secret_arn
    ecr_ws_url          = var.ecr_ws_url
    image_tag_ssm_param = var.ws_image_tag_ssm_param
    log_group           = var.monitoring_log_group_ws
    environment         = var.environment
  }))

  monitoring { enabled = true }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name              = "${local.name_prefix}-ws"
      ChessverseService = "ws"
      Environment       = var.environment
    }
  }

  lifecycle { create_before_destroy = true }
}
