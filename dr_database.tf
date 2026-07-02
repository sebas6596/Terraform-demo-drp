# =============================================================================
# dr_database.tf — RDS Read Replica en us-east-2
#
# CONCEPTO PILOT LIGHT — CAPA DE DATOS:
# Esta réplica está SIEMPRE corriendo, replicando continuamente desde us-east-1.
# Es el "fuego piloto": pequeño, barato, pero listo para activarse.
#
# FAILOVER — cómo promover la réplica:
#   AWS CLI:
#     aws rds promote-read-replica \
#       --db-instance-identifier dr-pilot-light-dr-mysql-replica \
#       --region us-east-2
#
#   AWS Console:
#     RDS → Databases → seleccionar réplica → Actions → Promote
#
# Tras la promoción, la réplica se convierte en instancia primaria independiente
# y acepta escrituras. La replicación desde us-east-1 se detiene.
# =============================================================================

# DB Subnet Group DR
resource "aws_db_subnet_group" "dr" {
  provider = aws.dr

  name        = "${var.project_name}-dr-db-subnet-group"
  subnet_ids  = aws_subnet.dr_private[*].id
  description = "Subnet group RDS DR us-east-2"

  tags = { Name = "${var.project_name}-dr-db-subnet-group", Environment = "dr" }
}

# Read Replica cross-region — SIEMPRE corriendo (Pilot Light de datos)
resource "aws_db_instance" "dr_replica" {
  provider = aws.dr

  identifier     = "${var.project_name}-dr-mysql-replica"
  instance_class = var.db_instance_class

  # replicate_source_db con ARN cross-region habilita la replicación
  # NO se especifica engine/username/password — se heredan de la primaria
  replicate_source_db = aws_db_instance.primary.arn

  db_subnet_group_name   = aws_db_subnet_group.dr.name
  vpc_security_group_ids = [aws_security_group.dr_rds.id]

  backup_retention_period = 1
  publicly_accessible     = false
  multi_az                = false

  deletion_protection = false
  skip_final_snapshot = true

  tags = { Name = "${var.project_name}-dr-mysql-replica", Environment = "dr", Role = "read-replica" }
}
