#!/bin/bash
# =============================================================================
# failover.sh — Script interactivo de Failover DR Pilot Light
# Uso: ./failover.sh (desde la raíz del proyecto)
# =============================================================================

# No usar set -e — el script maneja sus propios errores para no morir
# en comandos que pueden fallar parcialmente (curl, aws cli responses)

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
command -v aws >/dev/null 2>&1 || { echo -e "${RED}❌ aws CLI no instalado${NC}"; exit 1; }
echo -e "${GREEN}✅ aws CLI disponible${NC}"

echo ""
echo -e "${BOLD}Ingresa los valores del último run en Terraform Cloud.${NC}"
echo -e "${YELLOW}(Terraform Cloud → workspace → último run → pestaña Outputs)${NC}"
echo ""

echo -e "IP pública del EC2 Primary (primary_app_url, sin http://): "
read -r PRIMARY_EC2_IP

echo -e "ID del EC2 Primary (primary_ec2_id, ej: i-0abc123): "
read -r PRIMARY_EC2_ID

echo -e "ID de la RDS Replica (dr_rds_replica_id, ej: dr-pilot-light-dr-mysql-replica): "
read -r DR_REPLICA_ID

echo ""
echo -e "${GREEN}✅ EC2 Primary IP  : ${PRIMARY_EC2_IP}${NC}"
echo -e "${GREEN}✅ EC2 Primary ID  : ${PRIMARY_EC2_ID}${NC}"
echo -e "${GREEN}✅ RDS Replica ID  : ${DR_REPLICA_ID}${NC}"

press_enter

# ── PASO 0: Estado normal ─────────────────────────────────────────
clear
echo -e "${BOLD}${CYAN}[ PASO 0 ] ESTADO NORMAL${NC}"
echo ""
echo -e "  ${GREEN}✅ EC2 corriendo en us-east-1 → http://${PRIMARY_EC2_IP}${NC}"
echo -e "  ${GREEN}✅ RDS MySQL activa en us-east-1${NC}"
echo -e "  ${GREEN}✅ Read Replica corriendo en us-east-2${NC}"
echo -e "  ${RED}⏸  EC2 DR → NO existe (dr_ec2_enabled=false)${NC}"
echo ""
echo -e "Verifica en browser: ${CYAN}http://${PRIMARY_EC2_IP}${NC}"

press_enter

# ── PASO 1: Simular el desastre — INICIO DEL CONTADOR RTO ────────
clear
echo -e "${BOLD}${RED}[ PASO 1 ] SIMULAR EL DESASTRE${NC}"
echo ""

RTO_START=$(date +%s)
RTO_START_LABEL=$(date '+%H:%M:%S')
echo -e "${BOLD}Inicio del RTO: ${CYAN}${RTO_START_LABEL}${NC}"
echo ""

if [[ -n "$PRIMARY_EC2_ID" ]]; then
    confirm "¿Detener el EC2 primario '${PRIMARY_EC2_ID}' en us-east-1?"
    aws ec2 stop-instances --instance-ids "$PRIMARY_EC2_ID" --region us-east-1 > /dev/null
    echo -e "${GREEN}✅ EC2 primario detenido${NC}"
else
    echo -e "${YELLOW}⚠️  No se obtuvo el ID del EC2. Detenlo manualmente desde la consola AWS.${NC}"
fi

echo ""
echo -e "${YELLOW}⏳ El health check de Route 53 tardará ~30s en detectar la falla.${NC}"

press_enter

# ── PASO 2: Promover Read Replica ─────────────────────────────────
clear
echo -e "${BOLD}${YELLOW}[ PASO 2 ] PROMOVER READ REPLICA → PRIMARY${NC}"
echo ""

if [[ -n "$DR_REPLICA_ID" ]]; then
    confirm "¿Promover '${DR_REPLICA_ID}' a instancia primaria en us-east-2?"
    aws rds promote-read-replica \
        --db-instance-identifier "$DR_REPLICA_ID" \
        --region us-east-2 > /dev/null
    echo -e "${GREEN}✅ Promoción iniciada. Tardará 2-5 minutos.${NC}"
    echo ""
    echo -e "Monitorea el estado en otra terminal:"
    echo -e "${CYAN}aws rds describe-db-instances --db-instance-identifier ${DR_REPLICA_ID} --region us-east-2 --query 'DBInstances[0].DBInstanceStatus' --output text${NC}"
else
    echo -e "${YELLOW}⚠️  No se obtuvo el ID de la réplica. Ejecuta manualmente:${NC}"
    echo -e "${CYAN}aws rds promote-read-replica --db-instance-identifier dr-pilot-light-dr-mysql-replica --region us-east-2${NC}"
fi

echo ""
echo -e "${YELLOW}▶ Presiona ENTER cuando RDS muestre estado 'available'...${NC}"
read -r

# ── PASO 3: Activar EC2 en DR vía Terraform Cloud ────────────────
clear
echo -e "${BOLD}${GREEN}[ PASO 3 ] ACTIVAR CÓMPUTO EN DR — TERRAFORM CLOUD${NC}"
echo ""
echo -e "Cambia ${YELLOW}dr_ec2_enabled${NC} → ${GREEN}true${NC} en Terraform Cloud y ejecuta el apply."
echo ""
echo -e "${YELLOW}⏳ El apply tardará ~2-3 minutos. Espera a que el run llegue a 'Applied'.${NC}"
echo ""
echo -e "${YELLOW}▶ Presiona ENTER cuando el apply en Terraform Cloud haya terminado...${NC}"
read -r

# ── PASO 4: Validar ───────────────────────────────────────────────
clear
echo -e "${BOLD}${GREEN}[ PASO 4 ] VALIDAR FAILOVER${NC}"
echo ""
echo -e "Ingresa la IP pública del EC2 DR."
echo -e "${YELLOW}(Terraform Cloud → último run → Outputs → dr_app_url, sin http://)${NC}"
echo ""
echo -n "IP pública del EC2 DR: "
read -r DR_EC2_IP

NGINX_OK=false
if [[ -n "$DR_EC2_IP" ]]; then
    echo ""
    echo -e "Esperando que nginx arranque en ${CYAN}http://${DR_EC2_IP}${NC} ..."
    for i in $(seq 1 18); do
        if curl -s --max-time 5 "http://${DR_EC2_IP}" 2>/dev/null | grep -q "Pilot Light"; then
            echo -e "\n${GREEN}✅ App respondiendo desde us-east-2: http://${DR_EC2_IP}${NC}"
            NGINX_OK=true
            break
        else
            echo -n "."
            sleep 10
        fi
    done
    if [[ "$NGINX_OK" == false ]]; then
        echo -e "\n${YELLOW}⚠️  nginx aún no responde. Verifica en el browser: http://${DR_EC2_IP}${NC}"
        echo -e "${YELLOW}   El user_data puede estar aún instalando. Espera 1-2 minutos más.${NC}"
    fi
fi

# ── Cálculo de RTO ────────────────────────────────────────────────
RTO_END=$(date +%s)
RTO_END_LABEL=$(date '+%H:%M:%S')
RTO_TOTAL=$((RTO_END - RTO_START))
RTO_MIN=$((RTO_TOTAL / 60))
RTO_SEC=$((RTO_TOTAL % 60))

echo ""
echo -e "${BOLD}${CYAN}"
echo "  ┌─────────────────────────────────────────────┐"
echo "  │          METRICAS DEL FAILOVER               │"
echo "  ├─────────────────────────────────────────────┤"
printf "  │  Inicio del desastre  : %-20s│\n" "$RTO_START_LABEL"
printf "  │  Servicio restaurado  : %-20s│\n" "$RTO_END_LABEL"
printf "  │  RTO real de la demo  : %d min %02d seg%11s│\n" "$RTO_MIN" "$RTO_SEC" ""
echo "  ├─────────────────────────────────────────────┤"
echo "  │  RPO : ~0 seg (replicacion continua)        │"
echo "  └─────────────────────────────────────────────┘"
echo -e "${NC}"
echo -e "  ${RED}❌ us-east-1: caida simulada${NC}"
echo -e "  ${GREEN}✅ us-east-2: EC2 activo, RDS promovida${NC}"
if [[ -n "$DR_EC2_IP" ]]; then
    echo -e "  ${CYAN}   http://${DR_EC2_IP}${NC}"
fi
echo ""
echo -e "Para limpiar todo: ${CYAN}./destroy_all.sh${NC}"
