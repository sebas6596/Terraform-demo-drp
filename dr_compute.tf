# =============================================================================
# dr_compute.tf — EC2 con nginx en us-east-2
#
# CONCEPTO PILOT LIGHT:
# dr_ec2_enabled = false → count=0 → el recurso NO existe en AWS
# dr_ec2_enabled = true  → count=1 → EC2 levanta (activado en el failover)
#
# Para hacer el failover:
#   1. Cambiar dr_ec2_enabled = true en terraform.tfvars (o variable en TF Cloud)
#   2. Ejecutar terraform apply
# =============================================================================

data "aws_ami" "dr_al2023" {
  provider = aws.dr

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

# EC2 DR — count=0 en estado normal (Pilot Light apagado)
resource "aws_instance" "dr_web" {
  provider = aws.dr
  count    = var.dr_ec2_enabled ? 1 : 0

  ami           = data.aws_ami.dr_al2023.id
  instance_type = var.instance_type
  subnet_id     = aws_subnet.dr_public[0].id

  vpc_security_group_ids = [aws_security_group.dr_ec2.id]
  key_name               = var.key_name != "" ? var.key_name : null

  user_data = base64encode(templatefile("${path.module}/user_data.sh.tpl", {
    region = var.dr_region
  }))

  tags = { Name = "${var.project_name}-dr-web", Environment = "dr", Role = "webserver" }
}
