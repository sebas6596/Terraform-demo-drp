# =============================================================================
# primary_database.tf — RDS MySQL instancia primaria en us-east-1
#
# backup_retention_period = 1 es REQUERIDO para poder crear Read Replicas
# cross-region. Sin backup habilitado, la réplica falla al crearse.
# =============================================================================

# DB Subnet Group primario
# RDS requiere mínimo 2 subnets en AZs distintas aunque Multi-AZ sea false
resource "aws_db_subnet_group" "primary" {
  name        = "${var.project_name}-primary-db-subnet-group"
  subnet_ids  = aws_subnet.primary_private[*].id
  description = "Subnet group RDS primaria us-east-1"

  tags = { Name = "${var.project_name}-primary-db-subnet-group", Environment = "primary" }
}

resource "aws_db_instance" "primary" {
  identifier     = "${var.project_name}-primary-mysql"
  engine         = "mysql"
  engine_version = "8.0"
  instance_class = var.db_instance_class

  allocated_storage = 20
  storage_type      = "gp2"
  storage_encrypted = true

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.primary.name
  vpc_security_group_ids = [aws_security_group.primary_rds.id]

  # Multi-AZ desactivado para reducir costo en demo (en producción: true)
  multi_az            = false
  publicly_accessible = false

  # Backup habilitado — REQUERIDO para cross-region Read Replica
  backup_retention_period = 1
  backup_window           = "03:00-04:00"
  maintenance_window      = "Mon:04:00-Mon:05:00"

  deletion_protection = false
  skip_final_snapshot = true

  tags = { Name = "${var.project_name}-primary-mysql", Environment = "primary", Role = "primary" }
}
