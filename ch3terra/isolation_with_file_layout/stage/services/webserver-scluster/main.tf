provider "aws" {
  region = "eu-central-1"

}
terraform {
  backend "s3" {
    bucket         = "terraform-state-loc"
    key            = "stage/services/webserver-cluster/terraform.tfstate"
    region         = "eu-central-1"
    dynamodb_table = "tf-state-lock"
    encrypt        = true

  }
}

resource "aws_instance" "example" {
  ami           = "ami-023adaba598e661ac"
  instance_type = "t2.micro"

  user_data = templatefile("user-data.sh", {
    server_port = var.server_port
    db_address  = data.terraform_remote_state.db.outputs.address
    db_port     = data.terraform_remote_state.db.outputs.port
  })

  user_data_replace_on_change = true

  vpc_security_group_ids = [aws_security_group.instance.id]

  tags = {
    Name = "HelloTerraform"
  }
}

# This security groups allows incoming requests on port 8080 from any IP(cicdr_blocks)

resource "aws_security_group" "instance" {
  name = "terraform-example-instance"
  ingress {
    from_port   = var.server_port
    to_port     = var.server_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
##############################
##############################
# CLUSTER OF MACHINES WITH ASG
##############################
##############################

# configuration for EC2 instances in ASG.
resource "aws_launch_configuration" "example" {
  image_id        = "ami-023adaba598e661ac"
  instance_type   = "t2.micro"
  security_groups = [aws_security_group.instance.id]

  user_data = templatefile("user-data.sh", {
    server_port = var.server_port
    db_address  = data.terraform_remote_state.db.outputs.address
    db_port     = data.terraform_remote_state.db.outputs.port
  })

}

resource "aws_autoscaling_group" "example" {
  launch_configuration = aws_launch_configuration.example.name
  vpc_zone_identifier  = data.aws_subnets.default.ids
  target_group_arns    = [aws_lb_target_group.asg.arn]
  health_check_type    = "ELB"
  min_size             = 2
  max_size             = 10
  tag {
    key                 = "Name"
    value               = "terraform-asg-example"
    propagate_at_launch = true
  }
  lifecycle {
    create_before_destroy = true
  }
}

data "aws_vpc" "default" {
  default = true

}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }

}

##############################
##############################
# APPLICATION LOAD BALANCER
##############################
##############################


resource "aws_lb" "example" {
  name               = "terraform-asg-example"
  load_balancer_type = "application"
  subnets            = data.aws_subnets.default.ids
  security_groups    = [aws_security_group.alb.id]

}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.example.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "404: page not found boy"
      status_code  = "404"
    }
  }
}

resource "aws_security_group" "alb" {
  name = "terraform-example-alb"

  # ALLOW INBOUND HTTP requests
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  # ALLOW ALL OUTBOUND requests
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_lb_target_group" "asg" {
  name     = "terraform-asg-example"
  port     = var.server_port
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 15
    timeout             = 3
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_listener_rule" "asg" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 100
  condition {
    path_pattern {
      values = ["*"]
    }
  }
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.asg.arn
  }
}

data "terraform_remote_state" "db" {
  backend = "s3"
  config = {
    bucket = "terraform-state-loc"
    key    = "stage/data-stores/mysql/terraform.tfstate"
    region = "eu-central-1"
  }

}