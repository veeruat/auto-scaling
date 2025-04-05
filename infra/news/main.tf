  # Generate ssh keys
  resource "aws_key_pair" "ssh_key" {
    key_name   = "${var.prefix}-news"
    public_key = file("${path.module}/../id_rsa.pub")
  }

  ########### front end SG ###########
  resource "aws_security_group" "sg_fe" {
  name        = "fe-sg"
  vpc_id      = local.vpc_id

  ingress {
    description      = "Allow http from everywhere"
    from_port        = 8080
    to_port          = 8080
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }
  ingress {
    description      = "Allow SSH from everywhere"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = [var.source_ip]
  }

  egress {
    description      = "Allow outgoing traffic"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  tags = {
    Name = "fe-sg"
  }
}

  ########### quotes SG ##############
  resource "aws_security_group" "qt_sg" {
    name        = "qt-sg"
    vpc_id      = local.vpc_id

    ingress {
      description      = "Allow http from everywhere"
      from_port        = 8082
      to_port          = 8082
      protocol         = "tcp"
      security_groups  = [aws_security_group.alb_sg.id] 
    }

    ingress {
      description      = "Allow SSH from everywhere"
      from_port        = 22
      to_port          = 22
      protocol         = "tcp"
      cidr_blocks      = [var.source_ip]
    }

    egress {
      description      = "Allow outgoing traffic"
      from_port        = 0
      to_port          = 0
      protocol         = "-1"
      cidr_blocks      = ["0.0.0.0/0"]
    }

    tags = {
      Name = "qt-sg"
    }
  }

  ########### newsfeed SG ##############
  resource "aws_security_group" "nf_sg" {
    name        = "nf-sg"
    vpc_id      = local.vpc_id

    ingress {
      description      = "Allow http from everywhere"
      from_port        = 8081
      to_port          = 8081
      protocol         = "tcp"
      security_groups  = [aws_security_group.alb_sg.id]
    }

    ingress {
      description      = "Allow SSH from everywhere"
      from_port        = 22
      to_port          = 22
      protocol         = "tcp"
      cidr_blocks      = [var.source_ip]
    }

    egress {
      description      = "Allow outgoing traffic"
      from_port        = 0
      to_port          = 0
      protocol         = "-1"
      cidr_blocks      = ["0.0.0.0/0"]
    }

    tags = {
      Name = "nf-sg"
    }
  }


  ############################################## Front End #############################

  # Launch  template for Front End

  resource "aws_launch_template" "launch_template_fe" {

    name = "launch-template-fe"
    
    image_id = "${data.aws_ami.amazon_linux_2.id}"
    instance_type = var.instance_type
    iam_instance_profile {
    name = data.aws_iam_instance_profile.existing_instance_profile.name
  }
    key_name = aws_key_pair.ssh_key.key_name
    
    #user_data = filebase64("${path.module}/userdata-front_end.sh")

    user_data = base64encode(<<-EOF
    
    #!/bin/bash -e

    AWS_DEFAULT_REGION=${var.region}
    DOCKER_IMAGE="${local.ecr_url}front_end:latest"
    QUOTE_SERVICE_URL="http://${aws_lb.alb.dns_name}:${var.quotes_service_port}"
    NEWSFEED_SERVICE_URL="http://${aws_lb.alb.dns_name}:${var.newsfeed_service_port} "
    STATIC_URL="http://${aws_s3_bucket.news.website_endpoint}"
    APP_TOKEN="${local.newsfeed_token}"
    FRONTEND_PORT=${var.frontend_service_port}

  ####### Docker installation #########
  if hash docker 2>/dev/null; then
    echo "Docker aleady installed"
  else
    sudo yum update -y
    sudo amazon-linux-extras install -y docker
    sudo service docker start
    sudo usermod -a -G docker ec2-user
  fi

  ########### Provision Docker Image ###########
  echo "Provisioning docker image $DOCKER_IMAGE"

  # cleanup previous deployment
  docker stop front_end || true
  docker rm front_end || true

  eval $(aws ecr get-login --region $AWS_DEFAULT_REGION --no-include-email)

  docker pull $DOCKER_IMAGE

  docker run -d \
    --restart always \
    --name front_end \
    -e QUOTE_SERVICE_URL=$QUOTE_SERVICE_URL \
    -e NEWSFEED_SERVICE_URL=$NEWSFEED_SERVICE_URL \
    -e STATIC_URL=$STATIC_URL \
    -e NEWSFEED_SERVICE_TOKEN="$APP_TOKEN" \
    -p $FRONTEND_PORT:$FRONTEND_PORT \
    $DOCKER_IMAGE

  EOF
  )

    block_device_mappings {
      device_name = "/dev/sda1"

      ebs {
        volume_size = 8
        volume_type = "gp2"
        delete_on_termination = true
      }
    }

    network_interfaces {
      associate_public_ip_address = true
      security_groups = [aws_security_group.sg_fe.id]
    }
  }

  resource "aws_autoscaling_group" "auto_scale_grp_fe" {
    name                      = "auto-scale-grp-fe"
    max_size                  = 5
    min_size                  = 1
    health_check_type         = "ELB"    # optional
    desired_capacity          = 1
    target_group_arns = [aws_lb_target_group.target_group_fe.arn]

    vpc_zone_identifier       = [local.public_subnet_id_a,local.public_subnet_id_b,local.public_subnet_id_c]
    
    launch_template {
      id      = aws_launch_template.launch_template_fe.id
      version = "$Latest"
    }
  }

  ############################################## Quotes #############################
  # Launch  template for quotes

  resource "aws_launch_template" "launch_temp_quotes" {

    name = "launch-temp-quotes"
    
    image_id = "${data.aws_ami.amazon_linux_2.id}"
    instance_type = var.instance_type
    key_name = aws_key_pair.ssh_key.key_name
    iam_instance_profile {
    name = data.aws_iam_instance_profile.existing_instance_profile.name
  }
    
    user_data = base64encode(<<-EOF
    
    #!/bin/bash -e

  DOCKER_IMAGE=${local.ecr_url}quotes:latest
  AWS_DEFAULT_REGION=${var.region}
  QUOTES_PORT=${var.quotes_service_port}

  ####### Docker installation #########
  if hash docker 2>/dev/null; then
    echo "Docker aleady installed"
  else
    sudo yum update -y
    sudo amazon-linux-extras install -y docker
    sudo service docker start
    sudo usermod -a -G docker ec2-user
  fi

  ########### Provision Docker Image ###########
  echo "Provisioning docker image $DOCKER_IMAGE"



  echo "Provisioning docker image $DOCKER_IMAGE"

  # cleanup previous deployment
  docker stop quotes || true
  docker rm quotes || true

  # -------- modified ----- with region

  eval $(aws ecr get-login --region $AWS_DEFAULT_REGION --no-include-email)

  docker pull $DOCKER_IMAGE

  docker run -d \
    --name quotes \
    --restart always \
    -p $QUOTES_PORT:$QUOTES_PORT \
    $DOCKER_IMAGE

  EOF
  )

    block_device_mappings {
      device_name = "/dev/sda1"

      ebs {
        volume_size = 8
        volume_type = "gp2"
        delete_on_termination = true
      }
    }

    network_interfaces {
      associate_public_ip_address = true
      security_groups = [aws_security_group.qt_sg.id]
    }
  }

  resource "aws_autoscaling_group" "auto_scale_grp_quotes" {
    name                      = "auto-scale-grp-quotes"
    max_size                  = 5
    min_size                  = 1
    health_check_type         = "ELB"    # optional
    desired_capacity          = 1   
    target_group_arns = [aws_lb_target_group.target_group_qt.arn]
    vpc_zone_identifier       = [local.public_subnet_id_a,local.public_subnet_id_b,local.public_subnet_id_c]
    
    launch_template {
      id      = aws_launch_template.launch_temp_quotes.id
      version = "$Latest"
    }
  }

  ############################################## newsFeed #############################
  # Launch  template for quotes

  resource "aws_launch_template" "launch_temp_nf" {

    name = "launch-temp-nf"
    
    image_id = "${data.aws_ami.amazon_linux_2.id}"
    instance_type = var.instance_type
    key_name = aws_key_pair.ssh_key.key_name
    iam_instance_profile {
    name = data.aws_iam_instance_profile.existing_instance_profile.name
  }
    
    user_data = base64encode(<<-EOF
    
    #!/bin/bash -e

  DOCKER_IMAGE=${local.ecr_url}newsfeed:latest
  AWS_DEFAULT_REGION=${var.region}
  NEWSFEED_PORT=${var.newsfeed_service_port}


  ####### Docker installation #########
  if hash docker 2>/dev/null; then
    echo "Docker aleady installed"
  else
    sudo yum update -y
    sudo amazon-linux-extras install -y docker
    sudo service docker start
    sudo usermod -a -G docker ec2-user
  fi

  ########### Provision Docker Image ###########


  echo "Provisioning docker image $DOCKER_IMAGE"

  # cleanup previous deployment
  docker stop newsfeed || true
  docker rm newsfeed || true

  # -------- Modified --- with region parameterization
  eval $(aws ecr get-login --region $AWS_DEFAULT_REGION --no-include-email)

  docker pull $DOCKER_IMAGE

  docker run -d \
    --name newsfeed \
    --restart always \
    -p $NEWSFEED_PORT:$NEWSFEED_PORT \
  $DOCKER_IMAGE

  EOF
  )

    block_device_mappings {
      device_name = "/dev/sda1"

      ebs {
        volume_size = 8
        volume_type = "gp2"
        delete_on_termination = true
      }
    }

    network_interfaces {
      associate_public_ip_address = true
      security_groups = [aws_security_group.nf_sg.id]
    }
  }

  resource "aws_autoscaling_group" "auto_scale_grp_nf" {
    name                      = "auto-scale-grp-nf"
    max_size                  = 5
    min_size                  = 1
    health_check_type         = "ELB"    # optional
    desired_capacity          = 1
    target_group_arns = [aws_lb_target_group.target_group_nf.arn]
    vpc_zone_identifier       = [local.public_subnet_id_a,local.public_subnet_id_b,local.public_subnet_id_c]
    
    launch_template {
      id      = aws_launch_template.launch_temp_nf.id
      version = "$Latest"
    }
  }


  ############################## Auto Scaling Policies ######################

  resource "aws_autoscaling_policy" "cpu_scaling_fe" {
    name                   = "cpu-scaling-fe"
    policy_type            = "TargetTrackingScaling"
    autoscaling_group_name = aws_autoscaling_group.auto_scale_grp_fe.name

    target_tracking_configuration {
      predefined_metric_specification {
        predefined_metric_type = "ASGAverageCPUUtilization"
      }
      target_value = 50.0  # Scale out if CPU usage exceeds 50%
    }
  }

  resource "aws_autoscaling_policy" "cpu_scaling_qu" {
    name                   = "cpu-scaling-qu"
    policy_type            = "TargetTrackingScaling"
    autoscaling_group_name = aws_autoscaling_group.auto_scale_grp_quotes.name

    target_tracking_configuration {
      predefined_metric_specification {
        predefined_metric_type = "ASGAverageCPUUtilization"
      }
      target_value = 50.0  # Scale out if CPU usage exceeds 50%
    }
  }

  resource "aws_autoscaling_policy" "cpu_scaling_nf" {
    name                   = "cpu-scaling-nf"
    policy_type            = "TargetTrackingScaling"
    autoscaling_group_name = aws_autoscaling_group.auto_scale_grp_nf.name

    target_tracking_configuration {
      predefined_metric_specification {
        predefined_metric_type = "ASGAverageCPUUtilization"
      }
      target_value = 50.0  # Scale out if CPU usage exceeds 50%
    }
  }

  output "frontend_url" {
    value = "http://${aws_lb.alb.dns_name}:${var.frontend_service_port}"
  }
