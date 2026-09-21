provider "aws" {
  region = "us-east-1" # Укажите нужный регион AWS

}

# 1. Создаем Security Group (открываем порт 22 для SSH и порт 3000 для веб-приложения)
resource "aws_security_group" "app_sg" {
  name        = "node-app-sg"
  description = "Allow port 3000 and SSH"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 3000
    to_port     = 3000
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

# 2. Находим последний официальный образ Ubuntu
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
  owners = ["099720109477"] # Canonical
}

# 3. Создаем EC2 инстанс и автоматизируем запуск контейнера через user_data
resource "aws_instance" "app_server" {
  ami             = data.aws_ami.ubuntu.id
  instance_type   = "t2.micro" # Бесплатный уровень (Free Tier)
  security_groups = [aws_security_group.app_sg.name]

  # Скрипт, который выполнится автоматически при самом первом старте сервера
  user_data = <<-EOF
              #!/bin/bash
              apt-get update -y
              apt-get install -y docker.io
              systemctl start docker
              systemctl enable docker
              
              # Скачиваем и запускаем ваш контейнер из Docker Hub
              docker run -d -p 3000:3000 ruslanhlukhov/node-form-app:latest
              EOF

  tags = {
    Name = "NodeFormAppServer"
  }
}

# 4. Выводим в конце публичный IP адрес сервера
output "app_url" {
  value = "http://${aws_instance.app_server.public_ip}:3000"
}
