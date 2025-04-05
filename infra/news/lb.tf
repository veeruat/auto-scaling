resource "aws_security_group" "alb_sg" {
  name        = "alb-sg"
  vpc_id      = local.vpc_id

  ingress {
    description      = "Allow http from everywhere"
    from_port        = 8080
    to_port          = 8080
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  ingress {
    description      = "Allow http from quotes"
    from_port        = 8081
    to_port          = 8081
    protocol         = "tcp"
    security_groups = [aws_security_group.sg_fe.id] 
  }
  
  ingress {
    description      = "Allow http from newsfeed"
    from_port        = 8082
    to_port          = 8082
    protocol         = "tcp"
    security_groups = [aws_security_group.sg_fe.id] 
  }

  egress {
    description      = "Allow outgoing traffic"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  tags = {
    Name = "alb-sg"
  }
}

resource "aws_lb" "alb" {
  name               = "alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [local.public_subnet_id_a,local.public_subnet_id_b,local.public_subnet_id_c]
}

############################## Front End ##########################

# Front End listner
resource "aws_lb_listener" "lb_lister_fe" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 8080
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.target_group_fe.arn
  }
}

# Front End target group
resource "aws_lb_target_group" "target_group_fe" {
  name     = "target-group-fe"
  target_type = "instance"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = local.vpc_id

   tags = {
    Name = "alb_tg_fe"
  }
}

############################ Quotes Listner #########################

# Quotes listner
resource "aws_lb_listener" "lb_lister_qt" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 8082
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.target_group_qt.arn
  }
}

#Quotes target group
resource "aws_lb_target_group" "target_group_qt" {
  name     = "target-group-qt"
  target_type = "instance"
  port     = 8082
  protocol = "HTTP"
  vpc_id   = local.vpc_id
}

######################################## Newsfeed ######################################3

# Newsfeed listner
resource "aws_lb_listener" "lb_lister_nf" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 8081
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.target_group_nf.arn
  }
}

#Newsfeed target group
resource "aws_lb_target_group" "target_group_nf" {
  name     = "target-group-nf"
  target_type = "instance"
  port     = 8081
  protocol = "HTTP"
  vpc_id   = local.vpc_id
}
