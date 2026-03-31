#!/bin/bash

# ============================================================
#  LabLabee – Challenge 3: ODA Canvas
#  Stop / Cleanup Script
# ============================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

CLUSTER_NAME="oda-lab"

echo -e "${CYAN}════════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}  LabLabee – Challenge 3: ODA Canvas – Stop & Cleanup${NC}"
echo -e "${CYAN}════════════════════════════════════════════════════════════${NC}"
echo ""

# Kill port-forwards
echo -e "${YELLOW}Stopping port-forwards...${NC}"
pkill -f "kubectl port-forward" 2>/dev/null && \
  echo -e "${GREEN}  ✓ Port-forwards stopped.${NC}" || \
  echo -e "  (no port-forwards were running)"

echo ""

# Ask user what to do
echo -e "${YELLOW}What do you want to do?${NC}"
echo "  1) Just stop port-forwards (keep cluster – fastest restart)"
echo "  2) Delete ODA components only (keep Kind cluster)"
echo "  3) Delete the entire Kind cluster (full cleanup)"
echo ""
read -rp "Choose [1/2/3]: " CHOICE

case "$CHOICE" in
  1)
    echo -e "${GREEN}✓ Port-forwards stopped. Cluster is still running.${NC}"
    echo -e "  Restart with: ${YELLOW}./start-oda.sh${NC}"
    ;;
  2)
    echo -e "${YELLOW}Deleting ODA components...${NC}"
    kubectl delete -f manifests/ -n canvas --ignore-not-found >/dev/null 2>&1
    helm uninstall canvas -n canvas 2>/dev/null || true
    kubectl delete namespace canvas --ignore-not-found >/dev/null 2>&1
    echo -e "${GREEN}  ✓ ODA components and namespace deleted.${NC}"
    echo -e "  Kind cluster '${CLUSTER_NAME}' still running."
    echo -e "  Restart ODA with: ${YELLOW}./start-oda.sh${NC}"
    ;;
  3)
    echo -e "${YELLOW}Deleting Kind cluster '${CLUSTER_NAME}'...${NC}"
    kind delete cluster --name "${CLUSTER_NAME}"
    echo -e "${GREEN}  ✓ Cluster '${CLUSTER_NAME}' deleted. All data removed.${NC}"
    echo -e "  Full restart with: ${YELLOW}./start-oda.sh${NC}"
    ;;
  *)
    echo -e "${RED}Invalid choice. Nothing was deleted.${NC}"
    ;;
esac

echo ""
