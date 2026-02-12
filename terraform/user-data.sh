#!/bin/bash

# Configurar logging
exec > >(tee /var/log/user-data.log) 2>&1
echo "=== INICIANDO DESPLIEGUE EN AMAZON LINUX $(date) ==="

# --------------------------------------------------
# 1. ACTUALIZAR SISTEMA
# --------------------------------------------------
echo "Actualizando sistema Amazon Linux..."
sudo yum update -y

# --------------------------------------------------
# 2. INSTALAR JAVA 17 (Corretto)
# --------------------------------------------------
echo "Instalando Java 17 (Amazon Corretto)..."
sudo yum install -y java-17-amazon-corretto-devel

# Verificar instalación
java -version
echo "JAVA_HOME: $(dirname $(dirname $(readlink -f $(which java))))"

# --------------------------------------------------
# 3. INSTALAR MAVEN Y GIT
# --------------------------------------------------
echo "Instalando Maven y Git..."
sudo yum install -y maven git

# Verificar
mvn --version
git --version

# --------------------------------------------------
# 4. INSTALAR POSTGRESQL CLIENT
# --------------------------------------------------
echo "Instalando PostgreSQL client..."
sudo amazon-linux-extras enable postgresql14
sudo yum install -y postgresql

# --------------------------------------------------
# 5. CREAR USUARIO PARA LA APLICACIÓN
# --------------------------------------------------
echo "Creando usuario springapp..."
sudo useradd -m -s /bin/bash springapp

# --------------------------------------------------
# 6. CLONAR REPOSITORIO
# --------------------------------------------------
echo "Clonando repositorio del proyecto..."
cd /home/springapp

# IMPORTANTE: Reemplaza con TU repositorio
GIT_REPO="https://github.com/CoilBetrox/demo.git"
sudo -u springapp git clone $GIT_REPO app

cd /home/springapp/app

# --------------------------------------------------
# 7. ESPERAR A QUE RDS ESTÉ DISPONIBLE
# --------------------------------------------------
echo "Esperando a que RDS esté disponible..."
# RDS puede tardar 10-15 minutos en estar completamente disponible
for i in {1..5}; do
  if PGPASSWORD=${db_password} psql -h ${db_host} -p ${db_port} -U ${db_username} -d postgres -c "\q" 2>/dev/null; then
    echo "✅ RDS disponible después de $((i*2)) minutos"
    break
  fi
  echo "⏳ Esperando RDS... ($i/20)"
  sleep 60  # Esperar 1 minuto entre intentos (máximo ~5 minutos)
done

# --------------------------------------------------
# 8. CONFIGURAR VARIABLES DE ENTORNO
# --------------------------------------------------
echo "Configurando variables de entorno..."
cat > /home/springapp/.env << EOF
# Configuración RDS
DB_HOST=${db_host}
DB_PORT=${db_port}
DB_NAME=${db_name}
DB_USERNAME=${db_username}
DB_PASSWORD=${db_password}

# Configuración Spring
SPRING_PROFILES_ACTIVE=aws
JAVA_OPTS="-Xms256m -Xmx512m -XX:+UseG1GC"
EOF

chown springapp:springapp /home/springapp/.env

# --------------------------------------------------
# 9. COMPILAR APLICACIÓN
# --------------------------------------------------
echo "Compilando aplicación con Maven..."
cd /home/springapp/app

# Configurar Maven para usar más memoria
export MAVEN_OPTS="-Xmx1024m -XX:+UseG1GC"

sudo -u springapp mvn clean package -DskipTests

# Verificar que se creó el JAR
JAR_FILE=$(find /home/springapp/app/target -name "*.jar" -type f | head -n 1)
if [ -z "$JAR_FILE" ]; then
  echo "❌ ERROR: No se encontró archivo JAR"
  echo "Contenido de target/:"
  ls -la /home/springapp/app/target/
  exit 1
fi

echo "✅ JAR generado: $JAR_FILE"

# Crear un enlace estable al JAR para que systemd no dependa de globs
ln -sf "$JAR_FILE" /home/springapp/app/app.jar
chown springapp:springapp /home/springapp/app/app.jar

# --------------------------------------------------
# 10. CONFIGURAR SERVICIO SYSTEMD
# --------------------------------------------------
echo "Configurando servicio systemd..."
cat > /etc/systemd/system/estudiantes.service << EOF
[Unit]
Description=Estudiantes Microservice
After=network.target

[Service]
Type=simple
User=springapp
Group=springapp
WorkingDirectory=/home/springapp/app

# Cargar variables de entorno
EnvironmentFile=/home/springapp/.env

# Comando de ejecución
ExecStart=/usr/bin/java \$JAVA_OPTS -jar /home/springapp/app/app.jar

# Reinicio automático
Restart=always
RestartSec=10

# Logs
StandardOutput=journal
StandardError=journal
SyslogIdentifier=estudiantes-app

# Seguridad
NoNewPrivileges=true
ProtectSystem=full
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF

# --------------------------------------------------
# 11. CONFIGURAR PERMISOS Y SELINUX
# --------------------------------------------------
echo "Configurando permisos..."
chown -R springapp:springapp /home/springapp

# Configurar SELinux para permitir el puerto 8080
sudo yum install -y policycoreutils-python-utils
sudo semanage port -a -t http_port_t -p tcp 8080 2>/dev/null || true

# --------------------------------------------------
# 12. INICIAR SERVICIO
# --------------------------------------------------
echo "Iniciando servicio..."
sudo systemctl daemon-reload
sudo systemctl enable estudiantes.service

# Esperar un poco más para RDS
echo "Esperando 60 segundos antes de iniciar..."
sleep 60

sudo systemctl start estudiantes.service

# --------------------------------------------------
# 13. VERIFICAR ESTADO
# --------------------------------------------------
sleep 10
SERVICE_STATUS=$(sudo systemctl is-active estudiantes.service)

if [ "$SERVICE_STATUS" = "active" ]; then
  echo "✅ Servicio iniciado correctamente"
  
  # Verificar salud de la aplicación
  echo "Verificando salud de la aplicación..."
  for i in {1..10}; do
    if curl -s http://localhost:8080/actuator/health > /dev/null 2>&1; then
      echo "✅ Aplicación respondiendo correctamente"
      break
    fi
    echo "⏳ Esperando aplicación... ($i/10)"
    sleep 10
  done
else
  echo "❌ Error al iniciar el servicio"
  sudo journalctl -u estudiantes.service --no-pager -n 50
  exit 1
fi

# --------------------------------------------------
# 14. CONFIGURAR FIREWALL
# --------------------------------------------------
echo "Configurando firewall..."
sudo systemctl start firewalld 2>/dev/null || true
sudo systemctl enable firewalld 2>/dev/null || true
sudo firewall-cmd --permanent --add-port=8080/tcp 2>/dev/null || true
sudo firewall-cmd --reload 2>/dev/null || true

# --------------------------------------------------
# 15. MOSTRAR INFORMACIÓN
# --------------------------------------------------
echo "=== DESPLIEGUE COMPLETADO $(date) ==="
echo ""
echo "✅ Amazon Linux 2023 configurado"
echo "✅ Java 17 (Corretto) instalado"
echo "✅ Maven y Git instalados"
echo "✅ PostgreSQL client instalado"
echo "✅ Aplicación compilada y desplegada"
echo ""
echo "📊 INFORMACIÓN DE ACCESO:"
echo "IP Pública: $(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo 'No disponible')"
echo "API Base URL: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo 'localhost'):8080/api/v1"
echo ""
echo "🔧 COMANDOS ÚTILES:"
echo "Conectar por SSH: ssh -i estudiantes-key.pem ec2-user@<IP_PUBLICA>"
echo "Ver logs: sudo journalctl -u estudiantes.service -f"
echo "Reiniciar: sudo systemctl restart estudiantes.service"
echo "Estado: sudo systemctl status estudiantes.service"