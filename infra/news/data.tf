data "aws_ami" "amazon_linux_2" {
    most_recent = true

    filter {
      name   = "name"
      values = ["amzn2-ami-hvm*"]
    }

    filter {
      name   = "architecture"
      values = ["x86_64"]
    }

    owners = ["137112412989"] #amazon
  }

  data "aws_ssm_parameter" "nws_feed_token" {
    name            = "/${var.prefix}/base/app-token"
    with_decryption = true
  }

  data "aws_vpc" "vpc_id" {
    filter {
      name   = "tag:Name"
      values = ["${var.prefix}"] 
    }
  }

  data "aws_subnet" "public_a" {
    filter {
      name   = "tag:Name"
      values = ["public_a"]
    }
  }

  data "aws_subnet" "public_b" {
    filter {
      name   = "tag:Name"
      values = ["public_b"]
    }
  }
  data "aws_subnet" "subnet_c" {
    filter {
      name   = "tag:Name"
      values = ["public_c"]
    }
  }

  
  data "aws_ssm_parameter" "ecr" {
    name = "/${var.prefix}/base/ecr"
  }

  data "aws_iam_instance_profile" "existing_instance_profile" {
  name = "${var.prefix}-news_host"
}