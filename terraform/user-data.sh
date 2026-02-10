#!/bin/bash

# Actualizar sistema
apt-get update -y
apt-get upgrade -y

# Instalar Java 17
apt-get install -y openjdk-17-jdk

# Instalar PostgreSQL client (opcional)
apt-get install -y postgresql-client

# Crear usuario para la aplicación
useradd -m -s /bin/bash springapp

# Descargar y desplegar la aplicación
# NOTA: Necesitarás subir tu JAR a S3 o repositorio
cd /home/springapp

# Ejemplo con un JAR desde S3 (descomentar y configurar)
# aws s3 cp s3://tu-bucket/estudiantes-microservice.jar app.jar

# O si compilas directamente en la instancia
# git clone <tu-repo>
# cd estudiantes-microservice
# mvn clean package
# cp target/*.jar app.jar

# Configurar variables de entorno
cat > /home/springapp/.env << EOF
DB_HOST=${db_host}
DB_PORT=${db_port}
DB_NAME=${db_name}
DB_USERNAME=${db_username}
DB_PASSWORD=${db_password}
SPRING_PROFILES_ACTIVE=aws
EOF

# Crear servicio systemd
cat > /etc/systemd/system/estudiantes.service << EOF
[Unit]
Description=Estudiantes Microservice
After=network.target

[Service]
User=springapp
WorkingDirectory=/home/springapp
EnvironmentFile=/home/springapp/.env
ExecStart=/usr/bin/java -jar app.jar
SuccessExitStatus=143
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Iniciar servicio
chown -R springapp:springapp /home/springapp
systemctl daemon-reload
systemctl enable estudiantes.service
systemctl start estudiantes.service

# Configurar firewall
ufw allow 22
ufw allow 80
ufw allow 443
ufw allow 8080
ufw --force enable
