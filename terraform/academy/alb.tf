resource "aws_lb" "portal" {
  name               = "hr-alb-portal"
  load_balancer_type = "application"
  internal           = false
  security_groups    = [aws_security_group.alb_public.id]
  subnets            = aws_subnet.public[*].id
  idle_timeout       = 60

  tags = {
    Name = "alb-portal"
  }
}

resource "aws_lb_target_group" "portal" {
  name     = "tg-portal"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.academy.id

  health_check {
    enabled             = true
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    matcher             = "200-399"
    interval            = 30
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = {
    Name = "tg-portal"
  }
}

resource "aws_lb_listener" "portal_http" {
  load_balancer_arn = aws_lb.portal.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.portal.arn
  }
}

resource "aws_lb" "rest" {
  name               = "hr-alb-rest"
  load_balancer_type = "application"
  internal           = true
  security_groups    = [aws_security_group.alb_rest.id]
  subnets            = aws_subnet.app[*].id
  idle_timeout       = 60

  tags = {
    Name = "alb-rest"
  }
}

resource "aws_lb_target_group" "rest" {
  name     = "tg-rest"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = aws_vpc.academy.id

  health_check {
    enabled             = true
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    matcher             = "200-399"
    interval            = 30
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = {
    Name = "tg-rest"
  }
}

resource "aws_lb_listener" "rest" {
  load_balancer_arn = aws_lb.rest.arn
  port              = 8080
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.rest.arn
  }
}

resource "aws_lb" "haystack" {
  name               = "hr-alb-haystack"
  load_balancer_type = "application"
  internal           = true
  security_groups    = [aws_security_group.alb_haystack.id]
  subnets            = aws_subnet.app[*].id
  idle_timeout       = 60

  tags = {
    Name = "alb-haystack"
  }
}

resource "aws_lb_target_group" "haystack" {
  name     = "tg-haystack"
  port     = 8000
  protocol = "HTTP"
  vpc_id   = aws_vpc.academy.id

  health_check {
    enabled             = true
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    matcher             = "200-399"
    interval            = 30
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = {
    Name = "tg-haystack"
  }
}

resource "aws_lb_listener" "haystack" {
  load_balancer_arn = aws_lb.haystack.arn
  port              = 8000
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.haystack.arn
  }
}

# Internal NLB so two Neo4j guests share one Bolt DNS (TCP 7687).
resource "aws_lb" "neo4j" {
  name               = "hr-nlb-neo4j"
  load_balancer_type = "network"
  internal           = true
  subnets            = aws_subnet.data[*].id

  tags = {
    Name = "nlb-neo4j"
  }
}

resource "aws_lb_target_group" "neo4j" {
  name     = "tg-neo4j"
  port     = 7687
  protocol = "TCP"
  vpc_id   = aws_vpc.academy.id

  health_check {
    enabled             = true
    protocol            = "TCP"
    port                = "7687"
    interval            = 30
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = {
    Name = "tg-neo4j"
  }
}

resource "aws_lb_listener" "neo4j_bolt" {
  load_balancer_arn = aws_lb.neo4j.arn
  port              = 7687
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.neo4j.arn
  }
}
