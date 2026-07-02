# =============================================================================
# primary_compute.tf — EC2 con nginx en us-east-1 (siempre activo)
#
# Obtiene la AMI de Amazon Linux 2023 dinámicamente para evitar hardcodear
# un AMI ID que cambia por región y en el tiempo.
# =============================================================================

data "aws_ami" "primary_al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# EC2 primario — siempre count=1 en us-east-1
resource "aws_instance" "primary_web" {
  ami           = data.aws_ami.primary_al2023.id
  instance_type = var.instance_type
  subnet_id     = aws_subnet.primary_public[0].id

  vpc_security_group_ids = [aws_security_group.primary_ec2.id]
  key_name               = var.key_name != "" ? var.key_name : null

  # user_data inline con templatefile — instala nginx y genera la página HTML
  user_data = base64encode(templatefile("${path.module}/user_data.sh.tpl", {
    region = var.primary_region
  }))

  tags = { Name = "${var.project_name}-primary-web", Environment = "primary", Role = "webserver" }
}
