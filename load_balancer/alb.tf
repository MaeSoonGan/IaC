resource "aws_lb" "main" {
  name               = "${var.prefix}-alb"
  internal           = true
  load_balancer_type = "application"

  subnets         = [var.public_subnet_a_id, var.public_subnet_c_id]
  security_groups = [var.alb_sg_id]

  tags = {
    Name = "${var.prefix}-alb"
  }
}

resource "aws_lb_target_group" "eks" {
  name        = "${var.prefix}-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "instance"

  health_check {
    path                = "/health"
    protocol            = "HTTP"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = {
    Name = "${var.prefix}-tg"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.eks.arn
  }
}

# HTTPS 리스너 (ACM 인증서 확보 후 주석 해제)
# resource "aws_lb_listener" "https" {
#   load_balancer_arn = aws_lb.main.arn
#   port              = 443
#   protocol          = "HTTPS"
#   ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
#   certificate_arn   = var.acm_certificate_arn
#
#   default_action {
#     type             = "forward"
#     target_group_arn = aws_lb_target_group.eks.arn
#   }
# }
