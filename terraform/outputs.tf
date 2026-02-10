output "ec2_public_ip" {
  description = "IP pública de la instancia EC2"
  value       = aws_eip.app_eip.public_ip
}

output "rds_endpoint" {
  description = "Endpoint de la base de datos RDS"
  value       = aws_db_instance.estudiantes_db.endpoint
}

output "application_url" {
  description = "URL de la aplicación"
  value       = "http://${aws_eip.app_eip.public_ip}:8080"
}

output "api_base_url" {
  description = "URL base de las APIs"
  value       = "http://${aws_eip.app_eip.public_ip}:8080/api/v1"
}