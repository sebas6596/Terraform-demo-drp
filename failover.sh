#!/bin/bash
# =============================================================================
# failover.sh — Script interactivo de Failover DR Pilot Light
# Uso: ./failover.sh (desde la raíz del proyecto)
# =============================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

press_enter() {
    echo -e "\n${YELLOW}▶ Presiona ENTER para continuar...${NC}"
    read -r
}

confirm() {
    echo -e "\n${YELLOW}⚠️  $1${NC}"
    echo -e "${YELLOW}¿Continuar? (s/n): ${NC}"
    read -r response
    [[ "$response" =~ ^[Ss]$ ]] || { echo -e "${RED}Cancelado.${NC}"; exit 1; }
}

clear
echo -e "${BOLD}${CYAN}"
echo "╔════════════════════════════════════════════════════════════╗"
echo "║          DR PILOT LIGHT — DEMO DE FAILOVER EN VIVO         ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# ── Verificación previa ───────────────────────────────────────────
echo -e "${BOLD}Verificando herramientas...${NC}"
command -v terraform >/dev/null 2>&1 || { echo -e "${RED}❌ terraform no instalado${NC}"; exit 1; }
command -v aws       >/dev/null 2>&1 || { echo -e "${RED}❌ aws CLI no instalado${NC}"; exit 1; }

PRIMARY_EC2_IP=$(terraform output -raw primary_app_url 2>/dev/null | sed 's|http://||' || echo "")
DR_REPLICA_ID=$(terraform output -raw dr_rds_replica_id 2>/dev/null || echo "")
PRIMARY_EC2_ID=$(terraform output -raw primary_ec2_id 2>/dev/null || echo "")

[[ -z "$PRIMARY_EC2_IP" ]] && { echo -e "${RED}❌ No hay outputs de Terraform. Ejecuta terraform apply primero.${NC}"; exit 1; }

echo -e "${GREEN}✅ EC2 Primary IP : ${PRIMARY_EC2_IP}${NC}"
echo -e "${GREEN}✅ RDS Replica ID : ${DR_REPLICA_ID}${NC}"

press_enter

# ── PASO 0: Estado normal ─────────────────────────────────────────
clear
echo -e "${BOLD}${CYAN}[ PASO 0 ] ESTADO NORMAL${NC}"
echo -e "  ${GREEN}✅ EC2 corriendo en us-east-1 → http://${PRIMARY_EC2_IP}${NC}"
echo -e "  ${GREEN}✅ RDS MySQL activa en us-east-1${NC}"
echo -e "  ${GREEN}✅ Read Replica corriendo en us-east-2${NC}"
echo -e "  ${RED}⏸  EC2 DR → NO existe (dr_ec2_enabled=false)${NC}"
echo ""
echo -e "Verifica en browser: ${CYAN}http://${PRIMARY_EC2_IP}${NC}"
press_enter

# ── PASO 1: Simular el desastre ───────────────────────────────────
clear
echo -e "${BOLD}${RED}[ PASO 1 ] SIMULAR EL DESASTRE${NC}"
echo ""

if [[ -n "$PRIMARY_EC2_ID" ]]; then
    confirm "¿Detener el EC2 primario '${PRIMARY_EC2_ID}' en us-east-1?"
    aws ec2 stop-instances --instance-ids "$PRIMARY_EC2_ID" --region us-east-1
    echo -e "${GREEN}✅ EC2 primario detenido${NC}"
else
    echo -e "${YELLOW}Detén manualmente el EC2 desde la consola AWS en us-east-1${NC}"
fi

echo -e "${YELLOW}⏳ El health check de Route 53 tardará ~90s en detectar la falla.${NC}"
press_enter

# ── PASO 2: Promover Read Replica ─────────────────────────────────
clear
echo -e "${BOLD}${YELLOW}[ PASO 2 ] PROMOVER READ REPLICA → PRIMARY${NC}"
echo ""

if [[ -n "$DR_REPLICA_ID" ]]; then
    confirm "¿Promover '${DR_REPLICA_ID}' a instancia primaria en us-east-2?"
    aws rds promote-read-replica \
        --db-instance-identifier "$DR_REPLICA_ID" \
        --region us-east-2
    echo -e "${GREEN}✅ Promoción iniciada. Tardará 2-5 minutos.${NC}"
    echo -e "Monitorear: ${CYAN}aws rds describe-db-instances --db-instance-identifier ${DR_REPLICA_ID} --region us-east-2 --query 'DBInstances[0].DBInstanceStatus' --output text${NC}"
else
    echo -e "${YELLOW}Ejecuta manualmente:${NC}"
    echo -e "${CYAN}aws rds promote-read-replica --db-instance-identifier dr-pilot-light-dr-mysql-replica --region us-east-2${NC}"
fi

press_enter

# ── PASO 3: Activar EC2 en DR vía Terraform Cloud ────────────────
clear
echo -e "${BOLD}${GREEN}[ PASO 3 ] ACTIVAR CÓMPUTO EN DR — TERRAFORM CLOUD${NC}"
echo ""
echo -e "Es momento de activar el EC2 en us-east-2 cambiando la variable"
echo -e "${BOLD}dr_ec2_enabled${NC} de ${RED}false${NC} → ${GREEN}true${NC} en Terraform Cloud."
echo ""
echo -e "${BOLD}Pasos en la consola de Terraform Cloud:${NC}"
echo ""
echo -e "  1. Abre: ${CYAN}https://app.terraform.io${NC}"
echo -e "  2. Entra a tu organización → workspace ${YELLOW}dr-pilot-light${NC}"
echo -e "  3. Ve a ${BOLD}Variables${NC}"
echo -e "  4. Edita ${YELLOW}dr_ec2_enabled${NC} → cambia el valor a ${GREEN}true${NC} → Save"
echo -e "  5. Ve a ${BOLD}Actions → Start new run${NC}"
echo -e "  6. Selecciona ${BOLD}Plan and apply${NC} → confirma el apply"
echo ""
echo -e "${YELLOW}⏳ El apply tardará ~2-3 minutos. Espera a que el run llegue a 'Applied'.${NC}"
echo ""
echo -e "${BOLD}▶ Presiona ENTER cuando el apply en Terraform Cloud haya terminado...${NC}"
read -r

# ── PASO 4: Validar ───────────────────────────────────────────────
clear
echo -e "${BOLD}${GREEN}[ PASO 4 ] VALIDAR FAILOVER${NC}"
echo ""
echo -e "Ingresa la IP pública del EC2 DR (la encuentras en los outputs"
echo -e "del run de Terraform Cloud, o en EC2 → us-east-2 en la consola AWS):"
echo ""
echo -e "${YELLOW}IP pública del EC2 DR: ${NC}"
read -r DR_EC2_IP

if [[ -n "$DR_EC2_IP" ]]; then
    echo ""
    echo -e "Esperando que nginx arranque en ${CYAN}http://${DR_EC2_IP}${NC} ..."
    for i in $(seq 1 12); do
        curl -s --max-time 5 "http://${DR_EC2_IP}" | grep -q "Pilot Light" 2>/dev/null && \
            { echo -e "\n${GREEN}✅ App respondiendo desde us-east-2: http://${DR_EC2_IP}${NC}"; break; } || \
            { echo -n "."; sleep 10; }
    done
fi

echo ""
echo -e "${BOLD}════════════════ FAILOVER COMPLETADO ✅ ════════════════${NC}"
echo -e "  ${RED}❌ us-east-1: caída simulada${NC}"
echo -e "  ${GREEN}✅ us-east-2: EC2 activo, RDS promovida${NC}"
if [[ -n "$DR_EC2_IP" ]]; then
    echo -e "  ${GREEN}🌐 http://${DR_EC2_IP}${NC}"
fi
echo ""
echo -e "Para limpiar todo: ${CYAN}./destroy_all.sh${NC}"
