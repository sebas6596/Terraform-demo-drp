# =============================================================================
# route53.tf — Health Checks de Route 53
#
# Los health checks monitorean el HTTP del EC2 en cada región.
# Cuando el primario falla, Route 53 puede redirigir al DR.
#
# NOTA: Los health checks de Route 53 siempre se crean en us-east-1
# independientemente de la región del recurso monitoreado — es un
# servicio global de AWS. Por eso ambos usan el provider por defecto.
# =============================================================================

# Health Check sobre el EC2 primario (us-east-1) — siempre existe
resource "aws_route53_health_check" "primary" {
  ip_address        = aws_instance.primary_web.public_ip
  port              = 80
  type              = "HTTP"
  resource_path     = "/"
  failure_threshold = "3"
  request_interval  = "30"

  tags = { Name = "${var.project_name}-primary-hc" }
}

# Health Check sobre el EC2 DR (us-east-2) — solo existe post-failover
resource "aws_route53_health_check" "dr" {
  count = var.dr_ec2_enabled ? 1 : 0

  ip_address        = aws_instance.dr_web[0].public_ip
  port              = 80
  type              = "HTTP"
  resource_path     = "/"
  failure_threshold = "3"
  request_interval  = "30"

  tags = { Name = "${var.project_name}-dr-hc" }
}
