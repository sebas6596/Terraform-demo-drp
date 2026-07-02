# =============================================================================
# main.tf — Configuración raíz: providers y terraform block
#
# Un único workspace de Terraform Cloud gestiona AMBAS regiones.
# Se usan dos providers AWS con alias para separar los recursos:
#   provider "aws"            → us-east-1 (primary)
#   provider "aws" alias="dr" → us-east-2 (disaster recovery)
# =============================================================================

terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Terraform Cloud: descomentar y ajustar con tu organización y workspace
  # cloud {
  #   organization = "TU_ORGANIZACION"
  #   workspaces {
  #     name = "dr-pilot-light"
  #   }
  # }
}

# --- Provider región primaria (us-east-1) ---
provider "aws" {
  region = var.primary_region

  default_tags {
    tags = {
      Project   = var.project_name
      ManagedBy = "terraform"
    }
  }
}

# --- Provider región DR (us-east-2) ---
# Todos los recursos DR usan: provider = aws.dr
provider "aws" {
  alias  = "dr"
  region = var.dr_region

  default_tags {
    tags = {
      Project   = var.project_name
      ManagedBy = "terraform"
    }
  }
}
