#!/bin/bash

# ============================================================
#  LabLabee – Shared Lab Cluster
#  Crée le cluster Kind partagé (Challenge 03 + 05)
#  À lancer UNE SEULE FOIS avant start-oda.sh ou start-camara.sh
# ============================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

CLUSTER_NAME="shared-lab"

echo -e "${CYAN}"
echo "  ███████╗██╗  ██╗ █████╗ ██████╗ ███████╗██████╗     ██╗      █████╗ ██████╗ "
echo "  ██╔════╝██║  ██║██╔══██╗██╔══██╗██╔════╝██╔══██╗    ██║     ██╔══██╗██╔══██╗"
echo "  ███████╗███████║███████║██████╔╝█████╗  ██║  ██║    ██║     ███████║██████╔╝"
echo "  ╚════██║██╔══██║██╔══██║██╔══██╗██╔══╝  ██║  ██║    ██║     ██╔══██║██╔══██╗"
echo "  ███████║██║  ██║██║  ██║██║  ██║███████╗██████╔╝    ███████╗██║  ██║██████╔╝"
echo "  ╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝╚═════╝     ╚══════╝╚═╝  ╚═╝╚═════╝ "
echo -e "${NC}"
echo -e "${BLUE}  LabLabee – Shared Lab Cluster (Challenge 03 + Challenge 05)${NC}"
echo ""

# ─── CHECK PREREQUISITES ──────────────────────────────────────────────────────
echo -e "${YELLOW}[1/3] Checking prerequisites...${NC}"

check_tool() {
  if ! command -v "$1" &>/dev/null; then
    echo -e "${RED}  ✗ '$1' not found. Run ./install-prerequisites.sh first.${NC}"; exit 1
  else
    echo -e "${GREEN}  ✓ $1${NC}"
  fi
}
check_tool docker
check_tool kind
check_tool kubectl

AVAILABLE_MEM=$(free -m | awk '/^Mem:/{print $7}')
if [ "$AVAILABLE_MEM" -lt 3500 ]; then
  echo -e "${RED}  ✗ Not enough memory: ${AVAILABLE_MEM}MB available, 4000MB required.${NC}"; exit 1
else
  echo -e "${GREEN}  ✓ Memory OK: ${AVAILABLE_MEM}MB available${NC}"
fi

# ─── CREATE OR REUSE CLUSTER ──────────────────────────────────────────────────
echo ""
echo -e "${YELLOW}[2/3] Setting up Kind cluster '${CLUSTER_NAME}'...${NC}"

if kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
  echo -e "${GREEN}  ✓ Cluster '${CLUSTER_NAME}' already exists – reusing it.${NC}"
else
  echo "  → Creating cluster '${CLUSTER_NAME}'..."
  kind create cluster --name "${CLUSTER_NAME}" --config kind-config.yaml --wait 90s
  echo -e "${GREEN}  ✓ Cluster '${CLUSTER_NAME}' created.${NC}"
fi

kubectl cluster-info --context "kind-${CLUSTER_NAME}" >/dev/null 2>&1
echo -e "${GREEN}  ✓ kubectl context: kind-${CLUSTER_NAME}${NC}"

# ─── SHOW STATUS ──────────────────────────────────────────────────────────────
echo ""
echo -e "${YELLOW}[3/3] Cluster status${NC}"
kubectl get nodes
echo ""

echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  ✅  Cluster '${CLUSTER_NAME}' is ready!${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "  Next steps:"
echo -e "    → Deploy ODA Canvas  : ${YELLOW}./start-oda.sh${NC}"
echo -e "    → Deploy CAMARA      : ${YELLOW}./start-camara.sh${NC}"
echo -e "    → Stop everything    : ${YELLOW}./stop-lab.sh${NC}"
echo ""
