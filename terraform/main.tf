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
  region = var.aws_region
}

# 1. VPC por defecto
data "aws_vpc" "default" {
  default = true
}

# 2. Subnets por defecto
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
  filter {
    name   = "availability-zone"
    values = ["us-east-1a", "us-east-1b", "us-east-1c", "us-east-1d", "us-east-1f"]
  }
}

# 3. Security Group para EC2
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

# 4. Security Group para RDS
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

# 5. DB Subnet Group
resource "aws_db_subnet_group" "main" {
  name       = "estudiantes-db-subnet-group"
  subnet_ids = data.aws_subnets.default.ids
  
  tags = {
    Name = "estudiantes-db-subnet-group"
  }
}

# 6. RDS PostgreSQL
resource "aws_db_instance" "estudiantes_db" {
  identifier           = "estudiantes-db"
  engine              = "postgres"
  engine_version      = "16.6"
  instance_class      = var.rds_instance_class
  allocated_storage   = 20
  storage_type        = "gp2"
  storage_encrypted   = false
  
  db_name             = "estudiantesdb"
  username            = var.db_username
  password            = var.db_password
  
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  db_subnet_group_name   = aws_db_subnet_group.main.name
  publicly_accessible    = false
  
  skip_final_snapshot   = true
  multi_az              = false
  backup_retention_period = 1
  
  backup_window          = "03:00-04:00"
  maintenance_window     = "sun:04:00-sun:05:00"
  
  performance_insights_enabled = false
  monitoring_interval          = 0
  auto_minor_version_upgrade   = true
  
  apply_immediately = true
  
  tags = {
    Name = "estudiantes-db"
  }
}

# 7. EC2 Instance con Amazon Linux 2023
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023*-x86_64"] 
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "app_server" {
  # Amazon Linux 2023 - Más estable y compatible
  ami                    = data.aws_ami.amazon_linux_2023.id
  
  instance_type          = "t3.micro"
  key_name               = var.key_pair_name
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  subnet_id              = data.aws_subnets.default.ids[0]
  
  # User data específico para Amazon Linux
  user_data = templatefile("${path.module}/user-data.sh", {
    db_host     = aws_db_instance.estudiantes_db.endpoint
    db_port     = aws_db_instance.estudiantes_db.port
    db_name     = "estudiantesdb"
    db_username = var.db_username
    db_password = var.db_password
  })
  
  root_block_device {
    volume_size = 8
    volume_type = "gp2"
  }
  
  tags = {
    Name = "estudiantes-app-server"
  }
  
  depends_on = [aws_db_instance.estudiantes_db]
}

# 8. Elastic IP
resource "aws_eip" "app_eip" {
  instance = aws_instance.app_server.id
  domain   = "vpc"

  tags = {
    Name = "estudiantes-app-eip"
  }
}