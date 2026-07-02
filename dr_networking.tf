# =============================================================================
# dr_networking.tf — VPC, subnets, IGW y Security Groups en us-east-2
#
# La VPC DR es necesaria para alojar la RDS Read Replica aunque el EC2
# no esté desplegado. Misma estructura que primary, distinto CIDR (10.1.x.x).
# =============================================================================

# --- VPC DR ---
resource "aws_vpc" "dr" {
  provider = aws.dr

  cidr_block           = var.dr_vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "${var.project_name}-dr-vpc", Environment = "dr" }
}

# --- Internet Gateway DR ---
resource "aws_internet_gateway" "dr" {
  provider = aws.dr
  vpc_id   = aws_vpc.dr.id
  tags     = { Name = "${var.project_name}-dr-igw", Environment = "dr" }
}

# --- Subnets públicas DR ---
resource "aws_subnet" "dr_public" {
  provider = aws.dr
  count    = length(var.dr_public_subnets)

  vpc_id                  = aws_vpc.dr.id
  cidr_block              = var.dr_public_subnets[count.index]
  availability_zone       = var.dr_azs[count.index]
  map_public_ip_on_launch = true

  tags = { Name = "${var.project_name}-dr-public-${count.index + 1}", Environment = "dr", Tier = "public" }
}

# --- Subnets privadas DR (RDS Replica vive aquí) ---
resource "aws_subnet" "dr_private" {
  provider = aws.dr
  count    = length(var.dr_private_subnets)

  vpc_id                  = aws_vpc.dr.id
  cidr_block              = var.dr_private_subnets[count.index]
  availability_zone       = var.dr_azs[count.index]
  map_public_ip_on_launch = false

  tags = { Name = "${var.project_name}-dr-private-${count.index + 1}", Environment = "dr", Tier = "private" }
}

# --- Route table pública DR ---
resource "aws_route_table" "dr_public" {
  provider = aws.dr
  vpc_id   = aws_vpc.dr.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.dr.id
  }

  tags = { Name = "${var.project_name}-dr-rt-public", Environment = "dr" }
}

resource "aws_route_table_association" "dr_public" {
  provider = aws.dr
  count    = length(aws_subnet.dr_public)

  subnet_id      = aws_subnet.dr_public[count.index].id
  route_table_id = aws_route_table.dr_public.id
}

# --- Security Group EC2 DR ---
resource "aws_security_group" "dr_ec2" {
  provider = aws.dr

  name        = "${var.project_name}-dr-sg-ec2"
  description = "EC2 DR: permite HTTP y SSH"
  vpc_id      = aws_vpc.dr.id

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

  tags = { Name = "${var.project_name}-dr-sg-ec2", Environment = "dr" }
}

# --- Security Group RDS DR ---
resource "aws_security_group" "dr_rds" {
  provider = aws.dr

  name        = "${var.project_name}-dr-sg-rds"
  description = "RDS DR: MySQL solo desde EC2"
  vpc_id      = aws_vpc.dr.id

  ingress {
    description     = "MySQL desde EC2"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.dr_ec2.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-dr-sg-rds", Environment = "dr" }
}
