locals {
    vpc_id         = data.aws_vpc.vpc_id.id
    public_subnet_id_a      = data.aws_subnet.public_a.id
    public_subnet_id_b      = data.aws_subnet.public_b.id
    public_subnet_id_c      = data.aws_subnet.subnet_c.id
    ecr_url        = data.aws_ssm_parameter.ecr.value
    newsfeed_token = data.aws_ssm_parameter.nws_feed_token.value
  }