# Infraestructura y comunicación (resumen)

Este archivo muestra, de forma concisa, los componentes que define `main.tf` y cómo se comunican entre sí.

Arquitectura principal:

+-----------------+                      +--------------------+
|    Internet /   |                      |   RDS PostgreSQL   |
|   Usuarios/API  | <----(HTTP 8080)-----|   (estudiantes-db) |
|    (clientes)   |                      |    (Puerto 5432)   |
+--------+--------+                      +---------^----------+
         |                                         |
         | (Elastic IP -> EC2 : HTTP 8080)         |
         v                                         |
+-----------------+   (SG: permite 8080/22)  +-----+--------------+
|    Elastic IP   |-------------------------->|    EC2 Instance   |
|  (Association)  |                          |    (app_server)    |
+-----------------+                          +----------+---------+
                                                        |
                                                        | (SG: permite 5432 hacia RDS)
                                                        v
                                             +--------------------+
                                             |     RDS Subnet     |
                                             |        y DB        |
                                             +--------------------+

Componentes clave (según `main.tf`):

- **VPC por defecto**: se usan subnets y VPC existentes en la cuenta.
- **Security Group EC2 (`estudiantes-ec2-sg`)**: permite SSH (22) y tráfico a la app (8080) desde Internet.
- **Security Group RDS (`estudiantes-rds-sg`)**: permite PostgreSQL (5432) únicamente desde el SG de EC2.
- **EC2 (`app_server`)**: instancia Amazon Linux 2023 que ejecuta la aplicación Spring Boot; expone la API en el puerto 8080.
- **Elastic IP (`app_eip`)**: IP pública estática asociada a la instancia EC2 para acceso desde Internet.
- **RDS PostgreSQL (`estudiantes_db`)**: instancia administrada PostgreSQL que almacena los datos de la aplicación.

Comunicación principal:

- Clientes/Internet -> Elastic IP -> EC2: puerto 8080 (API HTTP)
- EC2 -> RDS: puerto 5432 (PostgreSQL) a través del Security Group que restringe origen al SG de EC2
- SSH a EC2: puerto 22 (recomendado restringir a IPs específicas)

**Nota:** El diagrama es simplificado; `main.tf` contiene detalles sobre subnets, db subnet group, tags y otras opciones.

---

**Endpoints de la API** (base: `/api/v1/estudiantes`) y ejemplos de body

- Health check
  - Método: GET
  - Ruta: `/actuator/health`
  - Body: sin body

- Listar estudiantes
  - Método: GET
  - Ruta: `/api/v1/estudiantes`
  - Body: sin body

- Obtener estudiante por ID
  - Método: GET
  - Ruta: `/api/v1/estudiantes/{id}`
  - Body: sin body

- Crear estudiante
  - Método: POST
  - Ruta: `/api/v1/estudiantes`
  - Body (ejemplo JSON):

```json
{
  "nombre": "Juan",
  "apellido": "Pérez",
  "email": "juan.perez@example.com",
  "fechaNacimiento": "2000-05-15",
  "carrera": "Ingeniería en Sistemas",
  "promedio": 4.2,
  "activo": true
}
```

- Actualizar estudiante
  - Método: PUT
  - Ruta: `/api/v1/estudiantes/{id}`
  - Body (ejemplo JSON):

```json
{
  "nombre": "Juan Carlos",
  "apellido": "Pérez López",
  "email": "juan.carlos@example.com",
  "fechaNacimiento": "2000-05-15",
  "carrera": "Ingeniería en Sistemas",
  "promedio": 4.5,
  "activo": true
}
```

- Desactivar estudiante
  - Método: PATCH
  - Ruta: `/api/v1/estudiantes/{id}/desactivar`
  - Body: sin body

- Eliminar estudiante
  - Método: DELETE
  - Ruta: `/api/v1/estudiantes/{id}`
  - Body: sin body

---

Archivo con la definición: [main.tf](main.tf)

Si quieres, puedo también:

- generar una imagen PNG simple del diagrama y añadirla aquí
- o hacer un commit de este cambio en Git

