#!/bin/bash

# Log para debugging
exec > >(tee /var/log/user-data.log) 2>&1
echo "=== INICIANDO DESPLIEGUE $(date) ==="

# 1. ACTUALIZAR SISTEMA
apt-get update -y

# 2. INSTALAR JAVA 21 (ARM64)
echo "Instalando Java 21 para ARM64..."
apt-get install -y wget gnupg
wget -O - https://packages.adoptium.net/artifactory/api/gpg/key/public | apt-key add -
echo "deb https://packages.adoptium.net/artifactory/deb $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/adoptium.list
apt-get update -y
apt-get install -y temurin-21-jdk

# Verificar instalación
java --version

# 3. INSTALAR MAVEN, GIT Y POSTGRESQL CLIENT
apt-get install -y maven git postgresql-client

# 4. CREAR USUARIO PARA APLICACIÓN
useradd -m -s /bin/bash springapp

# 5. CLONAR REPOSITORIO
cd /home/springapp
git clone https://github.com/tu-usuario/estudiantes-microservice.git app
cd app

# 6. ESPERAR A QUE RDS ESTÉ DISPONIBLE (puede tardar 10-15 min)
echo "Esperando a que RDS esté disponible..."
source <(echo "DB_HOST=${db_host}; DB_PORT=${db_port}")

for i in {1..30}; do
    if PGPASSWORD=${db_password} psql -h $DB_HOST -p $DB_PORT -U ${db_username} -d postgres -c "\q" 2>/dev/null; then
        echo "✅ RDS disponible después de $((i*2)) minutos"
        break
    fi
    echo "⏳ Esperando RDS... ($i/30)"
    sleep 120
done

# 7. CONFIGURAR VARIABLES DE ENTORNO
cat > .env << EOF
DB_HOST=${db_host}
DB_PORT=${db_port}
DB_NAME=${db_name}
DB_USERNAME=${db_username}
DB_PASSWORD=${db_password}
SPRING_PROFILES_ACTIVE=aws
JAVA_OPTS="-Xms256m -Xmx512m"
EOF

# 8. COMPILAR APLICACIÓN
echo "Compilando aplicación..."
export MAVEN_OPTS="-Xmx512m"
mvn clean package -DskipTests

# 9. CREAR SERVICIO SYSTEMD
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

# 10. INICIAR SERVICIO
chown -R springapp:springapp /home/springapp
systemctl daemon-reload
systemctl enable estudiantes.service

# Esperar un poco más
sleep 30
systemctl start estudiantes.service

# 11. VERIFICAR
sleep 10
if systemctl is-active --quiet estudiantes.service; then
    echo "✅ Servicio iniciado correctamente"
    
    # Verificar salud
    echo "Verificando salud de la aplicación..."
    for i in {1..10}; do
        if curl -s http://localhost:8080/actuator/health > /dev/null 2>&1; then
            echo "✅ Aplicación respondiendo"
            break
        fi
        echo "⏳ Esperando aplicación... ($i/10)"
        sleep 5
    done
else
    echo "❌ Error al iniciar servicio"
    journalctl -u estudiantes.service -n 50
fi

echo "=== DESPLIEGUE COMPLETADO $(date) ==="
echo "🌐 URL: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):8080"