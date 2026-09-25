resource "aws_db_subnet_group" "db_subnet_group" {
  name = "my-app-db-subnet-group"
  subnet_ids = var.subnet_ids
  tags = {
    Name = "App DB Subnet Group"
    Owner = "Ruslan Hlukhov"
  }
}

resource "aws_db_instance" "postgres" {
  identifier = "node-app-postgres-db"
  engine = "postgres"
  engine_version = "15"
  instance_class = "db.t3.micro"
  allocated_storage = 20

  db_name = "formapp"
  username = "dbadmin"
  manage_master_user_password = true

  db_subnet_group_name = aws_db_subnet_group.db_subnet_group.name
  vpc_security_group_ids = [var.db_sg_id]

  skip_final_snapshot = true
}