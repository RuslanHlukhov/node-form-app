provider "aws" {
  region     = "us-east-1"
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
}


# Network

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# 1. Security Group ALB
resource "aws_security_group" "alb_sg" {
  name        = "alb-security-group"
  description = "Allow HTTP traffic from the internet"
  vpc_id      = data.aws_vpc.default.id

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
  lifecycle {
    create_before_destroy = true
  }
}

# 2. Security Group for ASG (port 3000 only from ALB)
resource "aws_security_group" "app_sg" {
  name_prefix        = "node-app-sg"
  description = "Allow port 3000 from ALB and SSH"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# 3. Security Group for BD 
resource "aws_security_group" "db_sg" {
  name_prefix        = "db-security-group"
  description = "Allow PostgreSQL access from app servers"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.app_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
    lifecycle {
    create_before_destroy = true
  }
}


# 3. DataBase
resource "aws_db_subnet_group" "db_subnet_group" {
  name       = "my-app-db-subnet-group"
  subnet_ids = data.aws_subnets.default.ids

  tags = {
    Name = "App DB Subnet Group"
  }
}

resource "aws_db_instance" "postgres" {
  identifier        = "node-app-postgres-db"
  engine            = "postgres"
  engine_version    = "15"
  instance_class    = "db.t3.micro"
  allocated_storage = 20
  
  db_name  = "formapp"
  username = "dbadmin"
  password = var.db_password
  
  db_subnet_group_name   = aws_db_subnet_group.db_subnet_group.name
  vpc_security_group_ids = [aws_security_group.db_sg.id]
  
  skip_final_snapshot = true
}


# 4. ALB
resource "aws_lb" "app_alb" {
  name               = "node-app-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = data.aws_subnets.default.ids

  tags = {
    Name = "AppLoadBalancer"
  }
}

resource "aws_lb_target_group" "app_tg" {
  name     = "node-app-target-group"
  port     = 3000
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id
  target_type = "instance"

  health_check {
    path                = "/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_listener" "web" {
  load_balancer_arn = aws_lb.app_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }
}


# 5. AUTO SCALING GROUP (ASG)

data "aws_ami" "ubuntu" {
  most_recent = true
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  owners = ["099720109477"]
}

# 6. EC2 instances
resource "aws_launch_template" "app_lt" {
  name_prefix   = "node-app-lt-"
  image_id      = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"

  vpc_security_group_ids = [aws_security_group.app_sg.id]

user_data = base64encode(<<-EOF
              #!/bin/bash
              # Install Docker
              apt-get update -y
              apt-get install -y docker.io git
              systemctl start docker
              systemctl enable docker
              
              # Run container 
              docker run -d -p 3000:3000 \
                -e DATABASE_URL="postgres://${aws_db_instance.postgres.username}:${aws_db_instance.postgres.password}@${aws_db_instance.postgres.endpoint}/${aws_db_instance.postgres.db_name}" \
                --restart always \
                ruslanhlukhov/node-form-app:latest
              EOF
)

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "NodeApp-ASG-Instance"
    }
  }
}

# 7. Auto Scailing group
resource "aws_autoscaling_group" "app_asg" {
  desired_capacity    = 1 # Default count servers
  max_size            = 2 # Max. Servers
  min_size            = 1 # Min. servers
  vpc_zone_identifier = data.aws_subnets.default.ids

  target_group_arns = [aws_lb_target_group.app_tg.arn]
  health_check_type = "ELB" # Health ALB

  launch_template {
    id      = aws_launch_template.app_lt.id
    version = "$Latest"
  }

  force_delete = true
}



# 8. OUTPUTS

output "app_url" {
  value = "http://${aws_lb.app_alb.dns_name}"
}

output "db_endpoint" {
  value     = aws_db_instance.postgres.endpoint
  sensitive = true
}