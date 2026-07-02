# =============================================================================
# outputs.tf — Valores relevantes post-apply
# =============================================================================

# --- Primary ---
output "primary_app_url" {
  description = "URL de la aplicación en us-east-1 — abrir en browser"
  value       = "http://${aws_instance.primary_web.public_ip}"
}

output "primary_ec2_id" {
  description = "ID del EC2 primario (para detenerlo en la demo del desastre)"
  value       = aws_instance.primary_web.id
}

output "primary_rds_endpoint" {
  description = "Endpoint MySQL primario"
  value       = aws_db_instance.primary.endpoint
}

output "primary_rds_arn" {
  description = "ARN de la RDS primaria (informativo)"
  value       = aws_db_instance.primary.arn
}

output "primary_s3_bucket" {
  description = "Bucket S3 origen en us-east-1"
  value       = aws_s3_bucket.primary.id
}

# --- DR ---
output "dr_app_url" {
  description = "URL de la app DR — disponible solo cuando dr_ec2_enabled=true"
  value       = var.dr_ec2_enabled ? "http://${aws_instance.dr_web[0].public_ip}" : "EC2 DR no desplegado (dr_ec2_enabled=false)"
}

output "dr_rds_replica_id" {
  description = "ID de la RDS Read Replica — usar para promoverla en el failover"
  value       = aws_db_instance.dr_replica.id
}

output "dr_rds_replica_endpoint" {
  description = "Endpoint de la Read Replica en us-east-2"
  value       = aws_db_instance.dr_replica.endpoint
}

output "dr_s3_bucket" {
  description = "Bucket S3 réplica en us-east-2"
  value       = aws_s3_bucket.dr_replica.id
}

# --- Estado del Pilot Light ---
output "pilot_light_status" {
  description = "Estado actual del patrón Pilot Light"
  value       = var.dr_ec2_enabled ? "⚠️  FAILOVER ACTIVO — EC2 corriendo en us-east-2" : "🔥 PILOT LIGHT — Datos replicando, cómputo DR apagado"
}
