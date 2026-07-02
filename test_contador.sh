#!/bin/bash
# =============================================================================
# test_contador.sh — Prueba del contador RTO sin infraestructura AWS
# Simula el flujo completo del failover con tiempos ficticios
# =============================================================================

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

clear
echo -e "${BOLD}${CYAN}"
echo "╔════════════════════════════════════════════════════════════╗"
echo "║         TEST CONTADOR RTO — SIN INFRAESTRUCTURA            ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo -e "Este script simula el flujo del failover para probar el contador."
echo -e "No se conecta a AWS ni ejecuta ningún comando real."
echo ""

press_enter

# ── Simular Paso 1 — inicio del contador ─────────────────────────
clear
echo -e "${BOLD}${RED}[ PASO 1 ] SIMULAR EL DESASTRE${NC}"
echo ""

RTO_START=$(date +%s)
RTO_START_LABEL=$(date '+%H:%M:%S')
echo -e "${BOLD}🕐 Inicio del RTO: ${RTO_START_LABEL}${NC}"
echo ""
echo -e "${GREEN}✅ [simulado] EC2 primario detenido${NC}"
echo -e "${YELLOW}⏳ Simulando espera del health check (3 segundos)...${NC}"
sleep 3

press_enter

# ── Simular Paso 2 ────────────────────────────────────────────────
clear
echo -e "${BOLD}${YELLOW}[ PASO 2 ] PROMOVER READ REPLICA${NC}"
echo ""
echo -e "${GREEN}✅ [simulado] Promoción iniciada${NC}"
echo -e "${YELLOW}⏳ Simulando espera de promoción RDS (5 segundos)...${NC}"
sleep 5

press_enter

# ── Simular Paso 3 ────────────────────────────────────────────────
clear
echo -e "${BOLD}${GREEN}[ PASO 3 ] TERRAFORM CLOUD APPLY${NC}"
echo ""
echo -e "${GREEN}✅ [simulado] Apply completado en Terraform Cloud${NC}"
echo -e "${YELLOW}⏳ Simulando arranque del EC2 (4 segundos)...${NC}"
sleep 4

echo ""
echo -e "${BOLD}▶ Presiona ENTER cuando el apply en Terraform Cloud haya terminado...${NC}"
read -r

# ── Simular Paso 4 — fin del contador ────────────────────────────
clear
echo -e "${BOLD}${GREEN}[ PASO 4 ] VALIDAR FAILOVER${NC}"
echo ""
echo -e "${YELLOW}⏳ Simulando espera de nginx (3 segundos)...${NC}"
sleep 3
echo -e "${GREEN}✅ [simulado] App respondiendo desde us-east-2: http://1.2.3.4${NC}"

# ── Cálculo de RTO ────────────────────────────────────────────────
RTO_END=$(date +%s)
RTO_END_LABEL=$(date '+%H:%M:%S')
RTO_TOTAL=$((RTO_END - RTO_START))
RTO_MIN=$((RTO_TOTAL / 60))
RTO_SEC=$((RTO_TOTAL % 60))

echo ""
echo -e "${BOLD}${CYAN}"
echo "  ┌─────────────────────────────────────────────┐"
echo "  │          MÉTRICAS DEL FAILOVER               │"
echo "  ├─────────────────────────────────────────────┤"
printf "  │  🕐 Inicio del desastre  : %-17s│\n" "$RTO_START_LABEL"
printf "  │  🕑 Servicio restaurado  : %-17s│\n" "$RTO_END_LABEL"
printf "  │  ⏱  RTO real de la demo  : %d min %02d seg%8s│\n" "$RTO_MIN" "$RTO_SEC" ""
echo "  ├─────────────────────────────────────────────┤"
echo "  │  📊 RPO  : ~0 seg (replicación continua)    │"
echo "  └─────────────────────────────────────────────┘"
echo -e "${NC}"
echo -e "  ${RED}❌ us-east-1: caída simulada${NC}"
echo -e "  ${GREEN}✅ us-east-2: EC2 activo, RDS promovida${NC}"
echo -e "  ${GREEN}🌐 http://1.2.3.4${NC}"
echo ""
echo -e "${YELLOW}Test completado. El contador funciona correctamente.${NC}"
