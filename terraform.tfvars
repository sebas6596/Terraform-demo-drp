# =============================================================================
# terraform.tfvars — Valores por defecto del proyecto
#
# Las variables sensibles (db_password, credenciales AWS) NO van aquí.
# Configurarlas en Terraform Cloud como variables de tipo "sensitive".
# Ver: variables_terraform_cloud.md para la lista completa.
# =============================================================================

project_name   = "dr-pilot-light"
primary_region = "us-east-1"
dr_region      = "us-east-2"

# Networking primary
primary_vpc_cidr        = "10.0.0.0/16"
primary_azs             = ["us-east-1a", "us-east-1b"]
primary_public_subnets  = ["10.0.1.0/24", "10.0.2.0/24"]
primary_private_subnets = ["10.0.10.0/24", "10.0.11.0/24"]

# Networking DR
dr_vpc_cidr        = "10.1.0.0/16"
dr_azs             = ["us-east-2a", "us-east-2b"]
dr_public_subnets  = ["10.1.1.0/24", "10.1.2.0/24"]
dr_private_subnets = ["10.1.10.0/24", "10.1.11.0/24"]

# Compute
instance_type  = "t3.micro"
key_name       = ""

# PILOT LIGHT: false = cómputo DR apagado (estado normal)
# Cambiar a true para activar el failover
dr_ec2_enabled = false

# Database
db_instance_class = "db.t3.micro"
db_username       = "admin"
db_name           = "pilotdb"
# db_password → configurar como variable sensible en Terraform Cloud

# S3 — CAMBIAR: deben ser globalmente únicos en todo AWS
# Recomendación: usar tu Account ID como sufijo
# Ejemplo: "dr-pilot-light-primary-123456789012"
s3_primary_bucket_name = "dr-pilot-light-primary-REEMPLAZAR"
s3_replica_bucket_name = "dr-pilot-light-replica-REEMPLAZAR"
