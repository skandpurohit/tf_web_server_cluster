resource "aws_launch_configuration" "ec2-launch-template" {
  image_id = "ami-0557a15b87f6559cf"
  instance_type = "t2.micro"
  security_groups = [aws_security_group.ec2-lt-sg.id]


  user_data = <<-EOF
              #!/bin/bash
              echo "Hello, World" > index.html
              nohup busybox httpd -f -p 8080 &
              EOF


    # Required when using a launch configuration with an auto scaling group
    lifecycle {
      create_before_destroy = true
    }
}

resource "aws_security_group" "ec2-lt-sg" {
  ingress = [ {
    cidr_blocks = [ "172.31.0.0/16" ]
      description = "value"
      from_port = var.server-port
      protocol = "tcp"
      to_port = var.server-port
      ipv6_cidr_blocks = []
      prefix_list_ids = []
      self = false
      security_groups = []
  } ]
}


resource "aws_autoscaling_group" "ec2-asg" {
  launch_configuration = aws_launch_configuration.ec2-launch-template.name
  vpc_zone_identifier = data.aws_subnets.default.ids

  target_group_arns = [aws_lb_target_group.web-server-tg.arn]
  health_check_type = "ELB"


    min_size = 1
    max_size = 2

    tag {
        key = "Name"
        value = "tf-ec2-webserver"
        propagate_at_launch = true
    }
}

resource "aws_lb" "ec2-lb" {
    name = "web-app-lb"
    load_balancer_type = "application"
    subnets = data.aws_subnets.default.ids
    security_groups = [aws_security_group.webserver-lb-sg.id]
}

resource "aws_lb_listener" "http" {
    load_balancer_arn = aws_lb.ec2-lb.arn
    port = 80
    protocol = "HTTP"

    #By default , return a simple 404 page
    default_action {
      type = "fixed-response"

      fixed_response {
        content_type = "text/plain"
        message_body = "404: page not found"
        status_code = 404
      }
    
    }
}

resource "aws_security_group" "webserver-lb-sg" {
  name = "web-server-lb-sg"

  # Allow inbound HTTP requests
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound requests
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_lb_target_group" "web-server-tg" {
  name = "web-server-tg"
  port = var.server-port
  protocol = "HTTP"
  vpc_id = data.aws_vpc.default.id

  health_check {
    path = "/"
    protocol = "HTTP"
    matcher = "200"
    interval = 15
    timeout = 3
    healthy_threshold = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_listener_rule" "asg" {
    listener_arn = aws_lb_listener.http.arn
    priority = 100

    condition {
      path_pattern {
        values = ["*"]
      }
    }

    action {
        type = "forward"
        target_group_arn = aws_lb_target_group.web-server-tg.arn
    }
}