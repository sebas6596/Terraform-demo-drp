# =============================================================================
# variables.tf — Todas las variables del proyecto
# =============================================================================

# --- General ---
variable "project_name" {
  description = "Nombre del proyecto, usado en tags y nombres de recursos"
  type        = string
  default     = "dr-pilot-light"
}

# --- Regiones ---
variable "primary_region" {
  description = "Región primaria AWS"
  type        = string
  default     = "us-east-1"
}

variable "dr_region" {
  description = "Región de Disaster Recovery"
  type        = string
  default     = "us-east-2"
}

# --- Networking: región primaria ---
variable "primary_vpc_cidr" {
  description = "CIDR de la VPC primaria"
  type        = string
  default     = "10.0.0.0/16"
}

variable "primary_azs" {
  description = "Availability Zones en us-east-1"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "primary_public_subnets" {
  description = "CIDRs de subnets públicas en us-east-1"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "primary_private_subnets" {
  description = "CIDRs de subnets privadas en us-east-1 (para RDS)"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.11.0/24"]
}

# --- Networking: región DR ---
variable "dr_vpc_cidr" {
  description = "CIDR de la VPC DR (distinto al de primary para evitar conflictos)"
  type        = string
  default     = "10.1.0.0/16"
}

variable "dr_azs" {
  description = "Availability Zones en us-east-2"
  type        = list(string)
  default     = ["us-east-2a", "us-east-2b"]
}

variable "dr_public_subnets" {
  description = "CIDRs de subnets públicas en us-east-2"
  type        = list(string)
  default     = ["10.1.1.0/24", "10.1.2.0/24"]
}

variable "dr_private_subnets" {
  description = "CIDRs de subnets privadas en us-east-2 (para RDS Replica)"
  type        = list(string)
  default     = ["10.1.10.0/24", "10.1.11.0/24"]
}

# --- Compute ---
variable "instance_type" {
  description = "Tipo de instancia EC2"
  type        = string
  default     = "t3.micro"
}

variable "key_name" {
  description = "Key pair para SSH (dejar vacío si no se necesita en la demo)"
  type        = string
  default     = ""
}

# VARIABLE CLAVE del patrón Pilot Light:
# false → EC2 DR no existe (count=0) — estado inicial
# true  → EC2 DR corriendo — estado post-failover
variable "dr_ec2_enabled" {
  description = "Pilot Light: false=cómputo DR apagado | true=failover activo"
  type        = bool
  default     = false
}

# --- Database ---
variable "db_instance_class" {
  description = "Tipo de instancia RDS"
  type        = string
  default     = "db.t3.micro"
}

variable "db_username" {
  description = "Usuario administrador de MySQL"
  type        = string
  default     = "admin"
}

variable "db_password" {
  description = "Password de MySQL — usar variable sensible en Terraform Cloud"
  type        = string
  sensitive   = true
}

variable "db_name" {
  description = "Nombre de la base de datos inicial"
  type        = string
  default     = "pilotdb"
}

# --- S3 ---
variable "s3_primary_bucket_name" {
  description = "Nombre del bucket S3 origen en us-east-1 (debe ser globalmente único)"
  type        = string
}

variable "s3_replica_bucket_name" {
  description = "Nombre del bucket S3 destino en us-east-2 (debe ser globalmente único)"
  type        = string
}
