output "address" {
  value = aws_db_instance.postgres.address
}

output "endpoint" {
  value     = aws_db_instance.postgres.endpoint
  sensitive = true
}

output "username" {
  value = aws_db_instance.postgres.username
}

output "db_name" {
  value = aws_db_instance.postgres.db_name
}

output "secret_arn" {
  value = aws_db_instance.postgres.master_user_secret[0].secret_arn
}