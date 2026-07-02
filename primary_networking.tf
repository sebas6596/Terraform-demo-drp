# =============================================================================
# primary_networking.tf — VPC, subnets, IGW y Security Groups en us-east-1
#
# DISEÑO:
# - Subnets públicas: EC2 con IP pública directa (sin NAT Gateway)
# - Subnets privadas: RDS sin acceso a internet
# =============================================================================

# --- VPC primaria ---
resource "aws_vpc" "primary" {
  cidr_block           = var.primary_vpc_cidr
  enable_dns_support   = true  # Requerido para resolver endpoints de RDS
  enable_dns_hostnames = true  # Requerido para hostname público en EC2

  tags = { Name = "${var.project_name}-primary-vpc", Environment = "primary" }
}

# --- Internet Gateway primario ---
resource "aws_internet_gateway" "primary" {
  vpc_id = aws_vpc.primary.id
  tags   = { Name = "${var.project_name}-primary-igw", Environment = "primary" }
}

# --- Subnets públicas primarias (EC2 vive aquí) ---
resource "aws_subnet" "primary_public" {
  count             = length(var.primary_public_subnets)
  vpc_id            = aws_vpc.primary.id
  cidr_block        = var.primary_public_subnets[count.index]
  availability_zone = var.primary_azs[count.index]

  # IP pública automática al lanzar instancias → no necesitamos NAT Gateway
  map_public_ip_on_launch = true

  tags = { Name = "${var.project_name}-primary-public-${count.index + 1}", Environment = "primary", Tier = "public" }
}

# --- Subnets privadas primarias (RDS vive aquí) ---
resource "aws_subnet" "primary_private" {
  count             = length(var.primary_private_subnets)
  vpc_id            = aws_vpc.primary.id
  cidr_block        = var.primary_private_subnets[count.index]
  availability_zone = var.primary_azs[count.index]

  map_public_ip_on_launch = false

  tags = { Name = "${var.project_name}-primary-private-${count.index + 1}", Environment = "primary", Tier = "private" }
}

# --- Route table pública primaria → Internet Gateway ---
resource "aws_route_table" "primary_public" {
  vpc_id = aws_vpc.primary.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.primary.id
  }

  tags = { Name = "${var.project_name}-primary-rt-public", Environment = "primary" }
}

resource "aws_route_table_association" "primary_public" {
  count          = length(aws_subnet.primary_public)
  subnet_id      = aws_subnet.primary_public[count.index].id
  route_table_id = aws_route_table.primary_public.id
}

# --- Security Group EC2 primario ---
# HTTP 80 y SSH 22 desde internet (demo educativa)
resource "aws_security_group" "primary_ec2" {
  name        = "${var.project_name}-primary-sg-ec2"
  description = "EC2 primary: permite HTTP y SSH"
  vpc_id      = aws_vpc.primary.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-primary-sg-ec2", Environment = "primary" }
}

# --- Security Group RDS primario ---
# MySQL 3306 solo desde el SG del EC2 (mínimo privilegio)
resource "aws_security_group" "primary_rds" {
  name        = "${var.project_name}-primary-sg-rds"
  description = "RDS primary: MySQL solo desde EC2"
  vpc_id      = aws_vpc.primary.id

  ingress {
    description     = "MySQL desde EC2"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.primary_ec2.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-primary-sg-rds", Environment = "primary" }
}
