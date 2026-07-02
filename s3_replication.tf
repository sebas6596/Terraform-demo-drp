# =============================================================================
# s3_replication.tf — Buckets S3 y Cross-Region Replication (CRR)
#
# Bucket origen en us-east-1 replica automáticamente todos los objetos
# al bucket destino en us-east-2. Ambos requieren versioning habilitado.
# =============================================================================

# --- IAM Role para que S3 pueda replicar entre regiones ---
resource "aws_iam_role" "s3_replication" {
  name = "${var.project_name}-s3-replication-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "s3.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "s3_replication" {
  name = "${var.project_name}-s3-replication-policy"
  role = aws_iam_role.s3_replication.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:GetReplicationConfiguration", "s3:ListBucket"]
        Resource = "arn:aws:s3:::${var.s3_primary_bucket_name}"
      },
      {
        Effect   = "Allow"
        Action   = ["s3:GetObjectVersionForReplication", "s3:GetObjectVersionAcl", "s3:GetObjectVersionTagging"]
        Resource = "arn:aws:s3:::${var.s3_primary_bucket_name}/*"
      },
      {
        Effect   = "Allow"
        Action   = ["s3:ReplicateObject", "s3:ReplicateDelete", "s3:ReplicateTags"]
        Resource = "arn:aws:s3:::${var.s3_replica_bucket_name}/*"
      }
    ]
  })
}

# --- Bucket origen (us-east-1) ---
resource "aws_s3_bucket" "primary" {
  bucket = var.s3_primary_bucket_name
  tags   = { Name = "${var.project_name}-primary-bucket", Role = "source" }
}

resource "aws_s3_bucket_versioning" "primary" {
  bucket = aws_s3_bucket.primary.id
  versioning_configuration { status = "Enabled" }
}

# --- Bucket destino (us-east-2) ---
resource "aws_s3_bucket" "dr_replica" {
  provider = aws.dr
  bucket   = var.s3_replica_bucket_name
  tags     = { Name = "${var.project_name}-dr-bucket", Role = "replica" }
}

resource "aws_s3_bucket_versioning" "dr_replica" {
  provider = aws.dr
  bucket   = aws_s3_bucket.dr_replica.id
  versioning_configuration { status = "Enabled" }
}

# --- Regla de replicación: todos los objetos → bucket destino ---
resource "aws_s3_bucket_replication_configuration" "primary_to_dr" {
  depends_on = [aws_s3_bucket_versioning.primary]

  role   = aws_iam_role.s3_replication.arn
  bucket = aws_s3_bucket.primary.id

  rule {
    id     = "replicate-all"
    status = "Enabled"

    filter {}

    destination {
      bucket        = aws_s3_bucket.dr_replica.arn
      storage_class = "STANDARD"
    }

    delete_marker_replication { status = "Enabled" }
  }
}

# --- Archivo de prueba para validar que la replicación funciona ---
resource "aws_s3_object" "test_file" {
  bucket  = aws_s3_bucket.primary.id
  key     = "demo/test-replication.txt"
  content = "DR Pilot Light Demo — validar que este archivo aparece en us-east-2"
  etag    = md5("DR Pilot Light Demo test file")
  tags    = { Purpose = "test-replication" }
}
