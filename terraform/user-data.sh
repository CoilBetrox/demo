#!/bin/bash

# Log para debugging
exec > >(tee /var/log/user-data.log) 2>&1
echo "=== INICIANDO DESPLIEGUE $(date) ==="

# --------------------------------------------------
# 1. ACTUALIZAR SISTEMA
# --------------------------------------------------
echo "Actualizando sistema..."
apt-get update -y
apt-get upgrade -y

# --------------------------------------------------
# 2. INSTALAR JAVA 21 (Tu versión)
# --------------------------------------------------
echo "Instalando Java 21..."
apt-get install -y wget gnupg
wget -O - https://packages.adoptium.net/artifactory/api/gpg/key/public | apt-key add -
echo "deb https://packages.adoptium.net/artifactory/deb $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/adoptium.list
apt-get update -y
apt-get install -y temurin-21-jdk

# Verificar instalación
java --version

# --------------------------------------------------
# 3. INSTALAR GIT Y MAVEN
# --------------------------------------------------
echo "Instalando Git y Maven..."
apt-get install -y git maven

# Verificar instalaciones
git --version
mvn --version

# --------------------------------------------------
# 4. INSTALAR POSTGRESQL CLIENT
# --------------------------------------------------
echo "Instalando PostgreSQL client..."
apt-get install -y postgresql-client

# --------------------------------------------------
# 5. CREAR USUARIO PARA LA APLICACIÓN
# --------------------------------------------------
echo "Creando usuario springapp..."
useradd -m -s /bin/bash springapp

# --------------------------------------------------
# 6. CLONAR Y COMPILAR EL PROYECTO
# --------------------------------------------------
echo "Clonando repositorio del proyecto..."
cd /home/springapp

# IMPORTANTE: Reemplaza con TU repositorio GitHub
GIT_REPO="https://github.com/CoilBetrox/demo.git"
git clone $GIT_REPO estudiantes-app

cd estudiantes-app

# --------------------------------------------------
# 7. ESPERAR A QUE RDS ESTÉ DISPONIBLE
# --------------------------------------------------
echo "Esperando que RDS esté disponible..."
source <(echo "DB_HOST=${db_host}; DB_PORT=${db_port}")

for i in {1..30}; do
    if pg_isready -h $DB_HOST -p $DB_PORT 2>/dev/null; then
        echo "✅ RDS está disponible después de $i intentos"
        break
    fi
    echo "⏳ Esperando RDS... ($i/30)"
    sleep 10
done

# --------------------------------------------------
# 8. COMPILAR PROYECTO CON MAVEN
# --------------------------------------------------
echo "Compilando proyecto con Maven..."
mvn clean package -DskipTests

# Encontrar el archivo JAR generado
JAR_FILE=$(find target -name "*.jar" -type f | head -n 1)

if [ -z "$JAR_FILE" ]; then
    echo "❌ ERROR: No se encontró archivo JAR después de compilar"
    echo "Contenido del directorio target:"
    ls -la target/
    exit 1
fi

echo "✅ JAR generado: $JAR_FILE"

# Mover JAR a ubicación principal
cp $JAR_FILE /home/springapp/app.jar

# --------------------------------------------------
# 9. CONFIGURAR VARIABLES DE ENTORNO
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
JAVA_OPTS="-Xms256m -Xmx512m"
EOF

# --------------------------------------------------
# 10. CONFIGURAR SERVICIO SYSTEMD
# --------------------------------------------------
echo "Configurando servicio systemd..."
cat > /etc/systemd/system/estudiantes.service << EOF
[Unit]
Description=Estudiantes Microservice
After=network.target

[Service]
User=springapp
WorkingDirectory=/home/springapp
EnvironmentFile=/home/springapp/.env

# Usar JAVA_OPTS desde .env
ExecStart=/usr/bin/java \$JAVA_OPTS -jar app.jar

SuccessExitStatus=143
Restart=always
RestartSec=10

# Logs
StandardOutput=journal
StandardError=journal
SyslogIdentifier=estudiantes-app

[Install]
WantedBy=multi-user.target
EOF

# --------------------------------------------------
# 11. CONFIGURAR PERMISOS
# --------------------------------------------------
echo "Configurando permisos..."
chown -R springapp:springapp /home/springapp
chmod 600 /home/springapp/.env

# --------------------------------------------------
# 12. INICIAR SERVICIO
# --------------------------------------------------
echo "Iniciando servicio..."
systemctl daemon-reload
systemctl enable estudiantes.service

# Esperar un poco más para RDS
echo "Esperando 15 segundos antes de iniciar..."
sleep 15

systemctl start estudiantes.service

# Verificar estado
sleep 5
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
    journalctl -u estudiantes.service --no-pager -n 30
    exit 1
fi

# --------------------------------------------------
# 13. CONFIGURAR FIREWALL
# --------------------------------------------------
echo "Configurando firewall..."
ufw --force enable
ufw allow 22/tcp
ufw allow 8080/tcp
ufw reload

# --------------------------------------------------
# 14. MOSTRAR INFORMACIÓN
# --------------------------------------------------
echo "=== DESPLIEGUE COMPLETADO $(date) ==="
echo "✅ Java 21 instalado"
echo "✅ Git y Maven instalados"
echo "✅ Proyecto compilado"
echo "✅ Servicio iniciado"
echo ""
echo "📊 INFORMACIÓN DE ACCESO:"
echo "IP Pública: $(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)"
echo "API Base URL: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):8080/api/v1"
echo ""
echo "🔧 COMANDOS ÚTILES:"
echo "Ver logs: sudo journalctl -u estudiantes.service -f"
echo "Reiniciar: sudo systemctl restart estudiantes.service"
echo "Estado: sudo systemctl status estudiantes.service"