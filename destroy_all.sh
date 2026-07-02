#!/bin/bash
# =============================================================================
# destroy_all.sh — Destruye toda la infraestructura de la demo
# Uso: ./destroy_all.sh (desde la raíz del proyecto)
# =============================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

clear
echo -e "${BOLD}${RED}"
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║          DESTRUIR TODA LA INFRAESTRUCTURA DE DEMO         ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo -e "${YELLOW}⚠️  Se destruirá: VPCs, EC2, RDS (ambas regiones), S3 buckets, IAM roles${NC}"
echo ""
echo -e "${YELLOW}Escribe ${BOLD}DESTRUIR${NC}${YELLOW} para confirmar: ${NC}"
read -r confirmation

[[ "$confirmation" != "DESTRUIR" ]] && { echo -e "${GREEN}Cancelado.${NC}"; exit 0; }

echo -e "\n${YELLOW}Segunda confirmación (s/n): ${NC}"
read -r second
[[ ! "$second" =~ ^[Ss]$ ]] && { echo -e "${GREEN}Cancelado.${NC}"; exit 0; }

# Vaciar buckets S3 antes del destroy (terraform no puede destruir buckets con objetos)
echo -e "\n${CYAN}Vaciando buckets S3...${NC}"

PRIMARY_BUCKET=$(terraform output -raw s3_primary_bucket 2>/dev/null || echo "")
REPLICA_BUCKET=$(terraform output -raw dr_s3_bucket 2>/dev/null || echo "")

for bucket_info in "${PRIMARY_BUCKET}:us-east-1" "${REPLICA_BUCKET}:us-east-2"; do
    bucket="${bucket_info%%:*}"
    region="${bucket_info##*:}"
    if [[ -n "$bucket" && "$bucket" != *"no desplegado"* ]]; then
        echo -e "  Vaciando s3://${bucket} (${region})..."
        aws s3 rm "s3://${bucket}" --recursive --region "$region" 2>/dev/null || true
        # Eliminar versiones (el bucket tiene versioning habilitado)
        versions=$(aws s3api list-object-versions --bucket "$bucket" \
            --query '{Objects: Versions[].{Key:Key,VersionId:VersionId}}' \
            --output json --region "$region" 2>/dev/null || echo '{"Objects":[]}')
        if [[ "$versions" != '{"Objects":[]}' && "$versions" != '{"Objects": null}' ]]; then
            aws s3api delete-objects --bucket "$bucket" --delete "$versions" \
                --region "$region" 2>/dev/null || true
        fi
    fi
done

echo -e "${GREEN}✅ Buckets vaciados${NC}"

# Destruir todo
echo -e "\n${CYAN}Ejecutando terraform destroy...${NC}"
START_TIME=$(date +%s)
terraform destroy -auto-approve
END_TIME=$(date +%s)

echo ""
echo -e "${BOLD}${GREEN}"
echo "╔══════════════════════════════════════════════════╗"
echo "║       INFRAESTRUCTURA DESTRUIDA ✅               ║"
echo "╚══════════════════════════════════════════════════╝"
echo -e "${NC}"
echo -e "  Tiempo: ${CYAN}$((END_TIME - START_TIME))s${NC}"
echo -e "  Costo adicional desde ahora: ${GREEN}\$0${NC}"
echo ""
echo -e "${YELLOW}Verifica en la consola AWS que no queden recursos huérfanos.${NC}"
