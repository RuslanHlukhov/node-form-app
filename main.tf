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
  name_prefix = "node-app-sg"
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
  name_prefix = "db-security-group"
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


# S3 Bucket для загрузки картинок (вынесли наверх, чтобы использовать его имя в launch_template)
resource "aws_s3_bucket" "app_images" {
  bucket_prefix = "node-app-images-"
  force_destroy = true
}

# IAM роль и политика для EC2, чтобы приложение могло писать в S3
resource "aws_iam_role" "ec2_s3_role" {
  name = "node-app-ec2-s3-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "s3_access_policy" {
  name = "s3-access-policy"
  role = aws_iam_role.ec2_s3_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.app_images.arn,
          "${aws_s3_bucket.app_images.arn}/*"
        ]
      },
      {
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = aws_db_instance.postgres.master_user_secret[0].secret_arn
      }
    ]
  })
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "node-app-ec2-profile"
  role = aws_iam_role.ec2_s3_role.name
}


# 4. DataBase
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

  db_name                     = "formapp"
  username                    = "dbadmin"
  manage_master_user_password = true

  db_subnet_group_name   = aws_db_subnet_group.db_subnet_group.name
  vpc_security_group_ids = [aws_security_group.db_sg.id]

  skip_final_snapshot = true
}


# 5. ALB
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
  name        = "node-app-target-group"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = data.aws_vpc.default.id
  target_type = "instance"

  health_check {
    path                = "/health"
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


# 6. AUTO SCALING GROUP & LAUNCH TEMPLATE

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

resource "aws_launch_template" "app_lt" {
  name_prefix   = "node-app-lt-"
  image_id      = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"

  vpc_security_group_ids = [aws_security_group.app_sg.id]

  # Привязываем IAM-профиль, чтобы инстанс автоматически имел доступ к S3
  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_profile.name
  }

  user_data = base64encode(templatefile("${path.module}/user_data.sh.tpl", {
    secret_arn = aws_db_instance.postgres.master_user_secret[0].secret_arn
    db_host    = aws_db_instance.postgres.address
    db_user    = aws_db_instance.postgres.username
    db_name    = aws_db_instance.postgres.db_name
    bucket     = aws_s3_bucket.app_images.id
    app_image  = "ruslanhlukhov/node-form-app:v16"
  }))

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "NodeApp-ASG-Instance"
    }
  }
}

resource "aws_autoscaling_group" "app_asg" {
  desired_capacity    = 1
  max_size            = 2
  min_size            = 1
  vpc_zone_identifier = data.aws_subnets.default.ids

  target_group_arns = [aws_lb_target_group.app_tg.arn]
  health_check_type = "ELB"

  launch_template {
    id      = aws_launch_template.app_lt.id
    version = "$Latest"
  }

  force_delete = true

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 100
    }
  }
}


# 7. OUTPUTS

output "app_url" {
  value = "http://${aws_lb.app_alb.dns_name}"
}

output "db_endpoint" {
  value     = aws_db_instance.postgres.endpoint
  sensitive = true
}
