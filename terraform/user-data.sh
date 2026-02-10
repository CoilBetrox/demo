#!/bin/bash

# Configuración optimizada para Free Tier
exec > >(tee /var/log/user-data.log) 2>&1
echo "=== INICIANDO DESPLIEGUE FREE TIER $(date) ==="

# 1. Actualizar (sin upgrade para ahorrar tiempo/ancho de banda)
apt-get update -y

# 2. Instalar Java 21 (Temurin - más ligero)
apt-get install -y wget
wget -O - https://packages.adoptium.net/artifactory/api/gpg/key/public | apt-key add -
echo "deb https://packages.adoptium.net/artifactory/deb $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/adoptium.list
apt-get update -y
apt-get install -y temurin-21-jdk

# 3. Instalar Maven y Git (sin PostgreSQL client para ahorrar espacio)
apt-get install -y maven git

# 4. Crear usuario para aplicación
useradd -m -s /bin/bash springapp

# 5. Clonar repositorio
cd /home/springapp
git clone https://github.com/CoilBetrox/demo.git app
cd app

# 6. ESPERAR A QUE RDS ESTÉ LISTO (RDS tarda 10-15 min en Free Tier)
echo "Esperando a que RDS esté disponible (puede tardar 15 minutos)..."
sleep 300  # Esperar 5 minutos mínimo

# 7. Configurar variables
cat > .env << EOF
DB_HOST=${db_host}
DB_PORT=${db_port}
DB_NAME=${db_name}
DB_USERNAME=${db_username}
DB_PASSWORD=${db_password}
SPRING_PROFILES_ACTIVE=aws
JAVA_OPTS="-Xms128m -Xmx256m"  # Menos memoria para Free Tier
EOF

# 8. Compilar
mvn clean package -DskipTests -q

# 9. Crear servicio
cat > /etc/systemd/system/estudiantes.service << EOF
[Unit]
Description=Estudiantes Microservice
After=network.target

[Service]
User=springapp
WorkingDirectory=/home/springapp/app
EnvironmentFile=/home/springapp/app/.env
ExecStart=/usr/bin/java \$JAVA_OPTS -jar target/*.jar
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# 10. Iniciar
chown -R springapp:springapp /home/springapp
systemctl daemon-reload
systemctl enable estudiantes.service
sleep 30  # Esperar un poco más
systemctl start estudiantes.service
