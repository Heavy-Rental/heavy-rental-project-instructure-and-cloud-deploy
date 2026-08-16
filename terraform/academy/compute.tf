# No key_name. No tls_private_key. LabInstanceProfile (LabRole) only.
# health_check_type = EC2 until branch 3 compose (ADR 0008).

resource "aws_launch_template" "portal" {
  name_prefix   = "lt-portal-"
  image_id      = local.ami_id
  instance_type = "t3.micro"

  iam_instance_profile {
    name = data.aws_iam_instance_profile.lab.name
  }

  vpc_security_group_ids = [aws_security_group.portal.id]

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = local.root_volume_gb
      volume_type           = "gp3"
      delete_on_termination = true
      encrypted             = true
    }
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "asg-portal"
      Role = "portal"
    }
  }
}

resource "aws_autoscaling_group" "portal" {
  name                      = "asg-portal"
  min_size                  = 1
  max_size                  = 2
  desired_capacity          = 1
  vpc_zone_identifier       = aws_subnet.app[*].id
  health_check_type         = "EC2"
  health_check_grace_period = 300
  force_delete              = true
  wait_for_capacity_timeout = "10m"

  launch_template {
    id      = aws_launch_template.portal.id
    version = "$Latest"
  }

  target_group_arns = [aws_lb_target_group.portal.arn]

  tag {
    key                 = "Name"
    value               = "asg-portal"
    propagate_at_launch = true
  }
}

resource "aws_launch_template" "rest" {
  name_prefix   = "lt-rest-"
  image_id      = local.ami_id
  instance_type = "t3.small"

  iam_instance_profile {
    name = data.aws_iam_instance_profile.lab.name
  }

  vpc_security_group_ids = [aws_security_group.rest.id]

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = local.root_volume_gb
      volume_type           = "gp3"
      delete_on_termination = true
      encrypted             = true
    }
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "asg-rest"
      Role = "rest"
    }
  }
}

resource "aws_autoscaling_group" "rest" {
  name                      = "asg-rest"
  min_size                  = 1
  max_size                  = 2
  desired_capacity          = 1
  vpc_zone_identifier       = aws_subnet.app[*].id
  health_check_type         = "EC2"
  health_check_grace_period = 300
  force_delete              = true
  wait_for_capacity_timeout = "10m"

  launch_template {
    id      = aws_launch_template.rest.id
    version = "$Latest"
  }

  target_group_arns = [aws_lb_target_group.rest.arn]

  tag {
    key                 = "Name"
    value               = "asg-rest"
    propagate_at_launch = true
  }
}

resource "aws_launch_template" "haystack" {
  name_prefix   = "lt-haystack-"
  image_id      = local.ami_id
  instance_type = "t3.small"

  iam_instance_profile {
    name = data.aws_iam_instance_profile.lab.name
  }

  vpc_security_group_ids = [aws_security_group.haystack.id]

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = local.root_volume_gb
      volume_type           = "gp3"
      delete_on_termination = true
      encrypted             = true
    }
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "asg-haystack"
      Role = "haystack"
    }
  }
}

resource "aws_autoscaling_group" "haystack" {
  name                      = "asg-haystack"
  min_size                  = 1
  max_size                  = 2
  desired_capacity          = 1
  vpc_zone_identifier       = aws_subnet.app[*].id
  health_check_type         = "EC2"
  health_check_grace_period = 300
  force_delete              = true
  wait_for_capacity_timeout = "10m"

  launch_template {
    id      = aws_launch_template.haystack.id
    version = "$Latest"
  }

  target_group_arns = [aws_lb_target_group.haystack.arn]

  tag {
    key                 = "Name"
    value               = "asg-haystack"
    propagate_at_launch = true
  }
}

# Dedicated ENI - stable Bolt IP (ADR 0007).
resource "aws_network_interface" "neo4j" {
  subnet_id       = aws_subnet.data[0].id
  security_groups = [aws_security_group.neo4j.id]
  description     = "asg-neo4j Bolt ENI"

  tags = {
    Name = "eni-neo4j"
  }
}

resource "aws_launch_template" "neo4j" {
  name_prefix   = "lt-neo4j-"
  image_id      = local.ami_id
  instance_type = "t3.large"

  iam_instance_profile {
    name = data.aws_iam_instance_profile.lab.name
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  network_interfaces {
    device_index          = 0
    network_interface_id  = aws_network_interface.neo4j.id
    delete_on_termination = false
  }

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = local.root_volume_gb
      volume_type           = "gp3"
      delete_on_termination = true
      encrypted             = true
    }
  }

  block_device_mappings {
    device_name = "/dev/xvdf"
    ebs {
      volume_size           = 20
      volume_type           = "gp3"
      delete_on_termination = false
      encrypted             = true
    }
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "asg-neo4j"
      Role = "neo4j"
    }
  }
}

resource "aws_autoscaling_group" "neo4j" {
  name                      = "asg-neo4j"
  min_size                  = 1
  max_size                  = 1
  desired_capacity          = 1
  # Launch template binds a network_interface_id. ASG must not also set a subnet.
  health_check_type         = "EC2"
  health_check_grace_period = 300
  protect_from_scale_in     = true
  force_delete              = true
  wait_for_capacity_timeout = "10m"

  launch_template {
    id      = aws_launch_template.neo4j.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "asg-neo4j"
    propagate_at_launch = true
  }
}
