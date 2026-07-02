# DR Pilot Light — Demo en AWS con Terraform

Implementación mínima viable del patrón **Pilot Light** de Disaster Recovery en AWS. Diseñada para demos educativas en vivo: desplegable en menos de 30 minutos, costo menor a $1 USD por 2 horas de ejecución.

---

## ¿Qué es el patrón Pilot Light?

Como el fuego piloto de una caldera: una llama pequeña siempre encendida, lista para activar el sistema completo.

- **Capa de datos** → siempre corriendo en la región DR (replicación continua)
- **Capa de cómputo** → apagada en la región DR (definida en IaC, `count=0`)
- **Failover** → promover la DB y ejecutar `terraform apply` con `ec2_enabled=true`

| Componente | us-east-1 (primary) | us-east-2 (DR) |
|---|---|---|
| VPC + Networking | ✅ Activo | ✅ Activo |
| EC2 + nginx | ✅ Corriendo | ⏸ count=0 |
| RDS MySQL | ✅ Primaria | ✅ Read Replica |
| S3 Bucket | ✅ Origen CRR | ✅ Destino CRR |
| Route 53 HC | ✅ Activo | ⏸ Esperando EC2 |

---

## Arquitectura

```
┌─────────────────────────────────────────────────────────────────┐
│                    ESTADO NORMAL (Pilot Light)                   │
├──────────────────────────┬──────────────────────────────────────┤
│   us-east-1 (PRIMARY)    │        us-east-2 (DR)                │
│                          │                                       │
│  ┌──────────────────┐    │    ┌──────────────────┐              │
│  │   VPC 10.0.0.0/16│    │    │  VPC 10.1.0.0/16 │              │
│  │                  │    │    │                  │              │
│  │  Public Subnet   │    │    │  Public Subnet   │              │
│  │  ┌────────────┐  │    │    │  ┌────────────┐  │              │
│  │  │  EC2 nginx │  │    │    │  │   EC2      │  │              │
│  │  │  ✅ ON     │  │    │    │  │  ⏸ count=0 │  │              │
│  │  └─────┬──────┘  │    │    │  └────────────┘  │              │
│  │        │ HTTP    │    │    │                  │              │
│  │  Private Subnet  │    │    │  Private Subnet  │              │
│  │  ┌────────────┐  │    │    │  ┌────────────┐  │              │
│  │  │  RDS MySQL │──┼────┼───▶│  │ Read Replica│  │              │
│  │  │  Primary   │  │Repl│    │  │  ✅ ON     │  │              │
│  │  └────────────┘  │    │    │  └────────────┘  │              │
│  └──────────────────┘    │    └──────────────────┘              │
│                          │                                       │
│  S3 Bucket ──────────────┼──CRR──▶ S3 Bucket Replica           │
│  Route53 HC ✅           │    Route53 HC (espera EC2)            │
└──────────────────────────┴──────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                   POST-FAILOVER                                  │
├──────────────────────────┬──────────────────────────────────────┤
│   us-east-1 (CAÍDA)      │        us-east-2 (ACTIVO)            │
│                          │                                       │
│  ┌──────────────────┐    │    ┌──────────────────┐              │
│  │  EC2 ❌ STOPPED  │    │    │  EC2 nginx ✅ ON  │              │
│  │  RDS ❌ STOPPED  │    │    │  RDS Primary ✅   │              │
│  └──────────────────┘    │    └──────────────────┘              │
│                          │                                       │
│  Route53 HC ❌ FAIL      │    Route53 HC ✅ ACTIVE               │
└──────────────────────────┴──────────────────────────────────────┘
```

---

## Estructura del proyecto

```
dr-pilot-light/
├── modules/
│   ├── networking/     # VPC, subnets, IGW, Security Groups
│   ├── compute/        # EC2 + nginx via user_data
│   └── database/       # RDS MySQL primaria y Read Replica
├── primary/            # Stack us-east-1 — todo activo
├── dr/                 # Stack us-east-2 — solo datos
└── scripts/
    ├── failover.sh     # Guía interactiva del failover
    └── destroy_all.sh  # Limpia todo al terminar
```

---

## Pre-requisitos

- **Terraform >= 1.5** (recomendado via [tfswitch](https://tfswitch.warrensbox.com/))
- **AWS CLI v2** configurado con perfil SSO o credenciales con permisos suficientes
- Permisos IAM necesarios: EC2, RDS, S3, IAM (roles), Route53, VPC

```bash
# Verificar versiones
terraform version
aws --version
aws sts get-caller-identity  # Verificar credenciales activas
```

---

## Despliegue paso a paso

### 1. Clonar el repositorio

```bash
git clone <repo-url>
cd dr-pilot-light
```

### 2. Configurar credenciales AWS

```bash
# Opción A: SSO
aws sso login --profile tu-perfil

# Opción B: Variables de entorno
export AWS_ACCESS_KEY_ID="..."
export AWS_SECRET_ACCESS_KEY="..."
export AWS_DEFAULT_REGION="us-east-1"
```

### 3. Configurar variables

Edita `primary/terraform.tfvars` y cambia los nombres de los buckets S3 (deben ser globalmente únicos):

```hcl
s3_bucket_name         = "dr-pilot-light-primary-TU_ACCOUNT_ID"
s3_replica_bucket_name = "dr-pilot-light-replica-TU_ACCOUNT_ID"
```

Configura el password de RDS via variable de entorno (no hardcodear):

```bash
export TF_VAR_db_password="TuPasswordSeguro123!"
```

### 4. Desplegar la región primaria (us-east-1)

```bash
cd primary
terraform init
terraform apply
```

Al finalizar, copia el output `rds_arn` — lo necesitarás para el stack DR:

```bash
terraform output rds_arn
# Ejemplo: arn:aws:rds:us-east-1:123456789012:db:dr-pilot-light-primary-mysql
```

### 5. Configurar y desplegar el stack DR (us-east-2)

Edita `dr/terraform.tfvars` y pega el ARN de RDS obtenido:

```hcl
source_db_arn = "arn:aws:rds:us-east-1:123456789012:db:dr-pilot-light-primary-mysql"
```

```bash
cd ../dr
terraform init
terraform apply
```

### 6. Verificar el estado inicial

```bash
# Ver URL de la app primaria
cd ../primary && terraform output app_url

# Ver estado del stack DR
cd ../dr && terraform output pilot_light_status
```

Abre la URL en el browser — debería mostrar `Respondiendo desde: us-east-1`.

> **Nota:** La instancia EC2 tarda ~60-90 segundos en completar el `user_data` (instalación de nginx). Si la página no carga inmediatamente, espera un momento.

---

## Failover paso a paso

### Opción A: Script interactivo (recomendado para demo)

```bash
./scripts/failover.sh
```

El script guía cada paso con mensajes claros y mide el RTO.

### Opción B: Manual

**Paso 1 — Simular el desastre** (desde AWS Console o CLI):
```bash
# Obtener el ID del EC2 primario
EC2_ID=$(cd primary && terraform output -raw ec2_instance_id)

# Detener EC2 en us-east-1
aws ec2 stop-instances --instance-ids $EC2_ID --region us-east-1
```

**Paso 2 — Promover la Read Replica:**
```bash
aws rds promote-read-replica \
  --db-instance-identifier dr-pilot-light-dr-mysql-replica \
  --region us-east-2

# Monitorear hasta que el estado sea 'available'
watch -n 10 "aws rds describe-db-instances \
  --db-instance-identifier dr-pilot-light-dr-mysql-replica \
  --region us-east-2 \
  --query 'DBInstances[0].DBInstanceStatus' --output text"
```

**Paso 3 — Activar el EC2 en DR:**
```bash
# Editar dr/terraform.tfvars: ec2_enabled = false → true
sed -i 's/ec2_enabled = false/ec2_enabled = true/' dr/terraform.tfvars

cd dr
terraform apply -auto-approve
terraform output app_url
```

**Paso 4 — Validar:**
```bash
# La URL debe mostrar "Respondiendo desde: us-east-2"
curl http://$(cd dr && terraform output -raw ec2_public_ip)
```

---

## Destruir todo al terminar

```bash
./scripts/destroy_all.sh
```

El script pide doble confirmación antes de destruir. Destruye DR primero, luego Primary.

También puedes hacerlo manualmente:
```bash
cd dr && terraform destroy -auto-approve
cd ../primary && terraform destroy -auto-approve
```

---

## Estimación de costos

Stack corriendo durante 2 horas en us-east-1 + us-east-2:

| Recurso | Región | Precio/hora | 2 horas |
|---|---|---|---|
| EC2 t3.micro | us-east-1 | $0.0104 | $0.021 |
| RDS db.t3.micro | us-east-1 | $0.017 | $0.034 |
| RDS db.t3.micro (replica) | us-east-2 | $0.017 | $0.034 |
| S3 (< 1GB) | ambas | ~$0.00 | ~$0.00 |
| Route 53 HC | global | $0.005/HC/mes | ~$0.00 |
| **Total estimado** | | | **~$0.09** |

> **Por qué no ALB ni NAT Gateway:** ALB cuesta ~$0.008/hora mínimo + LCU. NAT Gateway cuesta $0.045/hora. Para una demo de 2 horas, ambos triplicarían el costo sin agregar valor educativo.

---

## Módulos: qué hace cada uno

### `modules/networking`
Crea la VPC base reutilizable en ambas regiones. Incluye subnets públicas (EC2) y privadas (RDS), Internet Gateway, tabla de rutas, y Security Groups para EC2 (HTTP/SSH) y RDS (MySQL solo desde EC2).

### `modules/compute`
EC2 con Amazon Linux 2023 + nginx via `user_data`. La variable `ec2_enabled` controla `count=0` vs `count=1`. El template `user_data.sh.tpl` genera la página HTML con región, hostname y timestamp.

### `modules/database`
RDS MySQL 8.0 con `db.t3.micro`. La variable `is_replica` controla si crea una instancia primaria (`is_replica=false`) o una Read Replica cross-region (`is_replica=true`). El backup de 1 día es requerido para habilitar la replicación.

---

## Consideraciones importantes para despliegue en cuenta nueva

1. **Límites de servicio**: Las cuentas nuevas de AWS tienen límites por defecto de 5 VPCs por región y 40 instancias EC2. Este proyecto crea 2 VPCs y 1-2 EC2, bien dentro del límite.

2. **Backup en RDS**: La instancia primaria requiere `backup_retention_period >= 1` para poder crear Read Replicas. Ya está configurado, pero la réplica no puede crearse hasta que el primer backup automático se complete (~1 hora después del primer apply). Para la demo, despliega primary con anticipación.

3. **S3 bucket names**: Los nombres deben ser globalmente únicos en todo AWS. Usa tu Account ID como sufijo para garantizarlo.

4. **Tiempo de propagación de la réplica**: La Read Replica tarda 5-10 minutos en crearse y sincronizarse. Planifica el deploy del stack DR con tiempo.

5. **user_data y nginx**: El script de arranque tarda ~60-90 segundos. La URL no responde inmediatamente después del `terraform apply`.
