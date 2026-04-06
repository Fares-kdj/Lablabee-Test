#!/bin/bash

# ============================================================
#  LabLabee – Shared Lab
#  Stop / Cleanup Script – Challenge 03 + Challenge 05
# ============================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

CLUSTER_NAME="shared-lab"

echo -e "${CYAN}"
echo "  ╔════════════════════════════════════════════╗"
echo "  ║   LabLabee – Shared Lab – Stop & Cleanup   ║"
echo "  ╚════════════════════════════════════════════╝"
echo -e "${NC}"

# Afficher ce qui tourne actuellement
echo -e "${YELLOW}Current state:${NC}"
if kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
  echo -e "  ${GREEN}✓ Cluster '${CLUSTER_NAME}' is running${NC}"
  echo ""
  echo "  Deployed namespaces:"
  for NS in canvas components camara; do
    if kubectl get namespace "$NS" >/dev/null 2>&1; then
      PODS=$(kubectl get pods -n "$NS" --no-headers 2>/dev/null | grep -c "Running" || echo 0)
      echo -e "    ${GREEN}●${NC} $NS  (${PODS} pods running)"
    fi
  done
else
  echo -e "  ${RED}✗ Cluster '${CLUSTER_NAME}' is not running${NC}"
  exit 0
fi

echo ""
echo -e "${YELLOW}Choose what to stop:${NC}"
echo ""
echo -e "  ${GREEN}1)${NC} Stop ODA Canvas only       (delete canvas + components namespaces)"
echo -e "  ${GREEN}2)${NC} Stop CAMARA only            (delete camara namespace)"
echo -e "  ${GREEN}3)${NC} Stop both challenges        (delete canvas + components + camara)"
echo -e "  ${RED}4)${NC} Delete entire cluster       (full cleanup – shared-lab deleted)"
echo ""
read -rp "  Your choice [1/2/3/4]: " CHOICE

case "$CHOICE" in
  1)
    echo ""
    echo -e "${YELLOW}Removing ODA Canvas (canvas + components namespaces)...${NC}"
    kubectl delete namespace canvas    --ignore-not-found=true
    kubectl delete namespace components --ignore-not-found=true
    echo -e "${GREEN}  ✓ ODA Canvas removed.${NC}"
    echo -e "  Cluster '${CLUSTER_NAME}' still running."
    echo -e "  Redeploy ODA with: ${YELLOW}./start-oda.sh${NC}"
    ;;
  2)
    echo ""
    echo -e "${YELLOW}Removing CAMARA (camara namespace)...${NC}"
    kubectl delete namespace camara --ignore-not-found=true
    echo -e "${GREEN}  ✓ CAMARA removed.${NC}"
    echo -e "  Cluster '${CLUSTER_NAME}' still running."
    echo -e "  Redeploy CAMARA with: ${YELLOW}./start-camara.sh${NC}"
    ;;
  3)
    echo ""
    echo -e "${YELLOW}Removing all challenge namespaces...${NC}"
    kubectl delete namespace canvas components camara --ignore-not-found=true
    echo -e "${GREEN}  ✓ All challenge namespaces removed.${NC}"
    echo -e "  Cluster '${CLUSTER_NAME}' still running."
    echo -e "  Redeploy: ${YELLOW}./start-oda.sh${NC} and/or ${YELLOW}./start-camara.sh${NC}"
    ;;
  4)
    echo ""
    echo -e "${YELLOW}Deleting Kind cluster '${CLUSTER_NAME}'...${NC}"
    kind delete cluster --name "${CLUSTER_NAME}" 2>/dev/null && \
      echo -e "${GREEN}  ✓ Cluster '${CLUSTER_NAME}' deleted.${NC}" || \
      echo -e "${YELLOW}  ⚠ Cluster not found (already deleted?).${NC}"
    echo -e "${YELLOW}Pruning Docker...${NC}"
    docker system prune -f >/dev/null
    echo -e "${GREEN}  ✓ Docker pruned.${NC}"
    echo ""
    echo -e "${GREEN}Full cleanup complete.${NC}"
    echo -e "  Fresh start: ${YELLOW}./start-cluster.sh${NC}"
    ;;
  *)
    echo -e "${RED}Invalid choice. Nothing was changed.${NC}"
    exit 1
    ;;
esac
echo ""
