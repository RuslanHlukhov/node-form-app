resource "aws_security_group" "alb_sg" {
  name = "alb-security-group"
  description = "Allow HTTP traffic from the internet"
  vpc_id = var.vpc_id
ingress{
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
}
egress{
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
}
lifecycle {
    create_before_destroy = true
}
}

resource "aws_security_group" "app_sg" {
  name_prefix = "node-app-sg"
  description = "Allow port 3000 from ALB and SSH"
  vpc_id = var.vpc_id


ingress{
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
}
ingress {
    from_port = 3000
    to_port = 3000
    protocol = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
}
egress{
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks =["0.0.0.0/0"]
}
}

resource "aws_security_group" "db_sg" {
  name_prefix = "db-security-group"
  description = "Allow PostgressSQL access from app server"
  vpc_id = var.vpc_id

ingress{
    from_port = 5432
    to_port = 5432
    protocol = "tcp"
    security_groups = [aws_security_group.app_sg.id]
}

egress{
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
}
lifecycle{
    create_before_destroy = true
}
}