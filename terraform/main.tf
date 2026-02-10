terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# VPC por defecto (para evitar crear una nueva)
data "aws_vpc" "default" {
  default = true
}

# Subnets por defecto
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Security Group para EC2
resource "aws_security_group" "ec2_sg" {
  name        = "estudiantes-ec2-sg"
  description = "Security group para instancia EC2"
  vpc_id      = data.aws_vpc.default.id
  
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  ingress {
    description = "Spring Boot App"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = {
    Name = "estudiantes-ec2-sg"
  }
}

# Security Group para RDS
resource "aws_security_group" "rds_sg" {
  name        = "estudiantes-rds-sg"
  description = "Security group para RDS PostgreSQL"
  vpc_id      = data.aws_vpc.default.id
  
  ingress {
    description     = "PostgreSQL desde EC2"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2_sg.id]
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = {
    Name = "estudiantes-rds-sg"
  }
}

# DB Subnet Group
resource "aws_db_subnet_group" "main" {
  name       = "estudiantes-db-subnet-group"
  subnet_ids = data.aws_subnets.default.ids
  
  tags = {
    Name = "estudiantes-db-subnet-group"
  }
}

# RDS PostgreSQL - CONFIGURACIÓN FREE TIER
resource "aws_db_instance" "estudiantes_db" {
  identifier           = "estudiantes-db"
  engine              = "postgres"
  engine_version      = "17.6"
  instance_class      = "db.t3.micro"    # REQUERIDO para Free Tier
  
  # STORAGE para Free Tier
  allocated_storage   = 20               # Máximo para Free Tier
  storage_type        = "gp2"            # gp3 no está en Free Tier
  storage_encrypted   = false            # Encryption no está en Free Tier
  
  # CREDENCIALES
  db_name             = "estudiantesdb"
  username            = "estudiantesadmin"
  password            = "6xleyU2b209S"
  
  # NETWORK
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  db_subnet_group_name   = aws_db_subnet_group.main.name
  publicly_accessible    = false
  
  # FREE TIER SETTINGS
  skip_final_snapshot   = true
  multi_az              = false          # IMPORTANTE: false para Free Tier
  backup_retention_period = 1            # MÁXIMO 1 día para Free Tier
  
  # Otros settings
  backup_window          = "03:00-04:00"
  maintenance_window     = "sun:04:00-sun:05:00"
  
  # Deshabilitar features no disponibles en Free Tier
  performance_insights_enabled = false
  monitoring_interval          = 0
  auto_minor_version_upgrade   = true
  
  tags = {
    Name = "estudiantes-db"
  }
}

# EC2 Instance
resource "aws_instance" "app_server" {
  ami                    = "ami-0dd9f0e7df0f0a138"
  instance_type          = "t2.micro"      # Free Tier
  key_name               = "estudiantes-key"
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  subnet_id              = data.aws_subnets.default.ids[0]
  
  user_data = templatefile("${path.module}/user-data.sh", {
    db_host     = aws_db_instance.estudiantes_db.address
    db_port     = aws_db_instance.estudiantes_db.port
    db_name     = "estudiantesdb"
    db_username = "estudiantesadmin"
    db_password = "6xleyU2b209S"
  })
  
  # Storage Free Tier
  root_block_device {
    volume_size = 8               # Free Tier: 30GB máximo total
    volume_type = "gp2"
  }
  
  tags = {
    Name = "estudiantes-app-server"
  }
  
  depends_on = [aws_db_instance.estudiantes_db]
}

# Elastic IP (gratis si está asociada)
resource "aws_eip" "app_eip" {
  instance = aws_instance.app_server.id
  
  tags = {
    Name = "estudiantes-app-eip"
  }
}
