terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# VPC
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  
  tags = {
    Name = "estudiantes-vpc"
  }
}

# Subnets públicas
resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true
  
  tags = {
    Name = "estudiantes-public-a"
  }
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "${var.aws_region}b"
  map_public_ip_on_launch = true
  
  tags = {
    Name = "estudiantes-public-b"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  
  tags = {
    Name = "estudiantes-igw"
  }
}

# Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  
  tags = {
    Name = "estudiantes-public-rt"
  }
}

# Route Table Associations
resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}

# Security Group para EC2
resource "aws_security_group" "ec2_sg" {
  name        = "estudiantes-ec2-sg"
  description = "Security group para instancia EC2"
  vpc_id      = aws_vpc.main.id
  
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Restringir a tu IP en producción
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
  vpc_id      = aws_vpc.main.id
  
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

# DB Subnet Group (DEBE crearse ANTES del RDS)
resource "aws_db_subnet_group" "main" {
  name       = "estudiantes-db-subnet-group"
  subnet_ids = [aws_subnet.public_a.id, aws_subnet.public_b.id]
  
  tags = {
    Name = "estudiantes-db-subnet-group"
  }
}

# RDS PostgreSQL
resource "aws_db_instance" "estudiantes_db" {
  identifier           = "estudiantes-db"
  engine              = "postgres"
  engine_version      = "15.3"
  instance_class      = var.rds_instance_class
  allocated_storage   = 20
  storage_type        = "gp3"
  storage_encrypted   = true
  
  db_name             = "estudiantesdb"
  username            = var.db_username
  password            = var.db_password
  
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  db_subnet_group_name   = aws_db_subnet_group.main.name
  
  publicly_accessible    = false
  skip_final_snapshot   = true
  multi_az              = false # Cambiar a true para producción
  
  backup_retention_period = 7
  backup_window          = "03:00-04:00"
  maintenance_window     = "sun:04:00-sun:05:00"
  
  tags = {
    Name = "estudiantes-db"
  }
}

# Data source para AMI de Ubuntu
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

# EC2 Instance
resource "aws_instance" "app_server" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.ec2_instance_type
  key_name               = var.key_pair_name
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  subnet_id              = aws_subnet.public_a.id
  
  user_data = templatefile("${path.module}/user-data.sh", {
    db_host     = aws_db_instance.estudiantes_db.address
    db_port     = aws_db_instance.estudiantes_db.port
    db_name     = aws_db_instance.estudiantes_db.name
    db_username = var.db_username
    db_password = var.db_password
  })
  
  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }
  
  tags = {
    Name = "estudiantes-app-server"
  }
  
  depends_on = [aws_db_instance.estudiantes_db]
}

# Elastic IP para EC2
resource "aws_eip" "app_eip" {
  domain = "vpc"
  instance = aws_instance.app_server.id
  
  tags = {
    Name = "estudiantes-app-eip"
  }
}