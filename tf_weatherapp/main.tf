provider "aws" {
  region = "ap-southeast-2"
}

resource "aws_security_group" "weather_instance_sg" {
  name_prefix = "weather_sg_"
  vpc_id      = "vpc-0862f4a4297360be6"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

data "aws_iam_instance_profile" "existing_profile" {
  name = "AmazonSSMManagedInstanceCoreRole"
}

resource "aws_lb_target_group" "weather_tg" {
  name     = "weather-target-group"
  port     = 80
  protocol = "TCP"
  vpc_id   = "vpc-0862f4a4297360be6"
}

resource "aws_lb" "nlb" {
  name               = "weather-nlb"
  internal           = false
  load_balancer_type = "network"
  subnets            = ["subnet-0d7fe8799bd4adf8d", "subnet-06231c5dd89076c17"]
  enable_deletion_protection = false

  tags = {
    Name = "weather-nlb"
  }

  depends_on = [
    aws_lb_target_group.weather_tg
  ]
}

resource "aws_lb_listener" "nlb_listener" {
  load_balancer_arn = aws_lb.nlb.arn
  port              = 80
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.weather_tg.arn
  }
}

resource "aws_launch_configuration" "weather_lc" {
  name_prefix          = "weather_lc_"
  image_id             = "ami-00f6bbfca72e0fe87"
  instance_type        = "t3.micro"
  security_groups      = [aws_security_group.weather_instance_sg.id]
  iam_instance_profile = data.aws_iam_instance_profile.existing_profile.arn

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "weather_asg" {
  desired_capacity     = 2
  max_size             = 10
  min_size             = 2
  vpc_zone_identifier  = ["subnet-0d7fe8799bd4adf8d", "subnet-06231c5dd89076c17"]
  launch_configuration = aws_launch_configuration.weather_lc.id
  health_check_type    = "EC2"
  health_check_grace_period = 300
  target_group_arns    = [aws_lb_target_group.weather_tg.arn]

  tag {
    key                 = "Name"
    value               = "weather-instance"
    propagate_at_launch = true
  }
}
