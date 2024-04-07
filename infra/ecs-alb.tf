#############################################################################
## ALB 
#############################################################################
resource "aws_security_group" "alb_sg" {
  name        = "alb_sg"
  description = "alb to sg"
  vpc_id      = module.codepipeline-vpc.vpc.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "alb_sg"
  }
}

resource "aws_lb" "ecs_alb" {
  name               = "ecs-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = values(module.codepipeline-vpc.vpc.was_subnets) ## Private Subnets

  enable_deletion_protection = false

  tags = {
    Name = "ecs_alb"
  }
}

#############################################################################
## ALB Target Group
#############################################################################
resource "aws_lb_target_group" "ecs_tg_blue" {
  name                 = "ecs-blue-tg"
  port                 = 3000 ## ECS Port
  protocol             = "HTTP"
  target_type          = "ip"
  vpc_id               = module.codepipeline-vpc.vpc.vpc_id
  deregistration_delay = 10 // 이거때문에 배포시간 늦어짐 ... Default 300 적절하게 수정

  health_check {
    path                = "/health"
    protocol            = "HTTP"
    port                = "3000"
    interval            = 30
    timeout             = 5
    unhealthy_threshold = 2
    healthy_threshold   = 2
  }
}

resource "aws_lb_target_group" "ecs_tg_green" {
  name                 = "ecs-green-tg"
  port                 = 3000 ## ECS Port
  protocol             = "HTTP"
  target_type          = "ip"
  vpc_id               = module.codepipeline-vpc.vpc.vpc_id
  deregistration_delay = 10 // 이거때문에 배포시간 늦어짐 ... Default 300 적절하게 수정

  health_check {
    path                = "/health"
    protocol            = "HTTP"
    port                = "3000"
    interval            = 30
    timeout             = 5
    unhealthy_threshold = 2
    healthy_threshold   = 2
  }
}

#############################################################################
## ALB Listener
#############################################################################
resource "aws_lb_listener" "ecs_80" {
  load_balancer_arn = aws_lb.ecs_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ecs_tg_blue.arn
  }
}
