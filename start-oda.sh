#!/bin/bash

# ============================================================
#  LabLabee – Challenge 3: Open Digital Architecture (ODA)
#  Start Script – spins up a Kind cluster + ODA Canvas
# ============================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

CLUSTER_NAME="oda-lab"
NAMESPACE="canvas"
CANVAS_VERSION="1.1.0"

echo -e "${CYAN}"
echo "  ██████╗ ██████╗  █████╗      ██████╗ █████╗ ███╗   ██╗██╗   ██╗ █████╗ ███████╗"
echo "  ██╔═══██╗██╔══██╗██╔══██╗    ██╔════╝██╔══██╗████╗  ██║██║   ██║██╔══██╗██╔════╝"
echo "  ██║   ██║██║  ██║███████║    ██║     ███████║██╔██╗ ██║██║   ██║███████║███████╗"
echo "  ██║   ██║██║  ██║██╔══██║    ██║     ██╔══██║██║╚██╗██║╚██╗ ██╔╝██╔══██║╚════██║"
echo "  ╚██████╔╝██████╔╝██║  ██║    ╚██████╗██║  ██║██║ ╚████║ ╚████╔╝ ██║  ██║███████║"
echo "   ╚═════╝ ╚═════╝ ╚═╝  ╚═╝     ╚═════╝╚═╝  ╚═╝╚═╝  ╚═══╝  ╚═══╝  ╚═╝  ╚═╝╚══════╝"
echo -e "${NC}"
echo -e "${BLUE}  LabLabee – Challenge 3: Open Digital Architecture (ODA Canvas)${NC}"
echo -e "${BLUE}  Based on tmforum-oda/oda-canvas (v${CANVAS_VERSION})${NC}"
echo ""

# ─── 1. CHECK PREREQUISITES ───────────────────────────────────────────────────
echo -e "${YELLOW}[1/6] Checking prerequisites...${NC}"

check_tool() {
  if ! command -v "$1" &>/dev/null; then
    echo -e "${RED}  ✗ '$1' not found. Please install it first.${NC}"
    echo -e "      See README.md → Prerequisites section for instructions."
    exit 1
  else
    echo -e "${GREEN}  ✓ $1 found: $(command -v $1)${NC}"
  fi
}

check_tool docker
check_tool kind
check_tool kubectl
check_tool helm
check_tool curl
check_tool jq

# Check available memory
AVAILABLE_MEM=$(free -m | awk '/^Mem:/{print $7}')
if [ "$AVAILABLE_MEM" -lt 3500 ]; then
  echo -e "${RED}  ✗ Not enough memory: ${AVAILABLE_MEM}MB available, 4000MB required.${NC}"
  exit 1
else
  echo -e "${GREEN}  ✓ Memory OK: ${AVAILABLE_MEM}MB available${NC}"
fi

# ─── 2. CREATE KIND CLUSTER ───────────────────────────────────────────────────
echo ""
echo -e "${YELLOW}[2/6] Creating Kind cluster '${CLUSTER_NAME}'...${NC}"

if kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
  echo -e "${GREEN}  ✓ Cluster '${CLUSTER_NAME}' already exists – skipping creation.${NC}"
else
  kind create cluster --name "${CLUSTER_NAME}" --config kind-config.yaml --wait 90s
  echo -e "${GREEN}  ✓ Kind cluster '${CLUSTER_NAME}' created.${NC}"
fi

kubectl cluster-info --context "kind-${CLUSTER_NAME}" >/dev/null 2>&1
echo -e "${GREEN}  ✓ kubectl context set to kind-${CLUSTER_NAME}${NC}"

# ─── 3. INSTALL CERT-MANAGER ──────────────────────────────────────────────────
echo ""
echo -e "${YELLOW}[3/6] Installing cert-manager (required by ODA Canvas)...${NC}"

kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.3/cert-manager.yaml >/dev/null

echo -n "  Waiting for cert-manager pods to be ready"
for i in $(seq 1 30); do
  READY=$(kubectl get pods -n cert-manager --no-headers 2>/dev/null | grep -c "Running" || true)
  if [ "$READY" -ge 3 ]; then
    echo -e " ${GREEN}✓${NC}"
    break
  fi
  echo -n "."
  sleep 5
done

echo -e "${GREEN}  ✓ cert-manager ready.${NC}"

# ─── 4. INSTALL ODA CANVAS VIA HELM ──────────────────────────────────────────
echo ""
echo -e "${YELLOW}[4/6] Installing ODA Canvas (Helm chart v${CANVAS_VERSION})...${NC}"

# Add tmforum-oda Helm repo
helm repo add oda-canvas https://tmforum-oda.github.io/oda-canvas/ 2>/dev/null || true
helm repo update >/dev/null

# Create namespace
kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f - >/dev/null

# Install Canvas
helm upgrade --install canvas oda-canvas/canvas-oda \
  --namespace "${NAMESPACE}" \
  --version "${CANVAS_VERSION}" \
  --values canvas-values.yaml \
  --wait \
  --timeout 10m

echo -e "${GREEN}  ✓ ODA Canvas installed in namespace '${NAMESPACE}'.${NC}"

# ─── 5. DEPLOY ODA COMPONENTS ────────────────────────────────────────────────
echo ""
echo -e "${YELLOW}[5/6] Deploying ODA Components...${NC}"

echo "  → Deploying Product Catalog Management (TMF620)..."
kubectl apply -f manifests/productcatalog-component.yaml -n "${NAMESPACE}" >/dev/null
echo -e "${GREEN}  ✓ ProductCatalog component applied.${NC}"

echo "  → Deploying Party Management (TMF632)..."
kubectl apply -f manifests/partymanagement-component.yaml -n "${NAMESPACE}" >/dev/null
echo -e "${GREEN}  ✓ PartyManagement component applied.${NC}"

echo -n "  Waiting for components to reach 'Complete' status"
for i in $(seq 1 36); do
  COMPLETE=$(kubectl get components -n "${NAMESPACE}" --no-headers 2>/dev/null | grep -c "Complete" || true)
  if [ "$COMPLETE" -ge 2 ]; then
    echo -e " ${GREEN}✓${NC}"
    break
  fi
  echo -n "."
  sleep 5
done

# ─── 6. SETUP PORT-FORWARDS ──────────────────────────────────────────────────
echo ""
echo -e "${YELLOW}[6/6] Setting up port-forwards...${NC}"

# Kill any existing port-forwards
pkill -f "kubectl port-forward" 2>/dev/null || true
sleep 1

# Canvas UI
kubectl port-forward svc/canvas-oda-canvas-ui 3000:3000 -n "${NAMESPACE}" >/dev/null 2>&1 &
echo -e "${GREEN}  ✓ Canvas UI       → http://localhost:3000${NC}"

# ProductCatalog API
kubectl port-forward svc/productcatalog-api 8081:8080 -n "${NAMESPACE}" >/dev/null 2>&1 &
echo -e "${GREEN}  ✓ ProductCatalog API → http://localhost:8081${NC}"

# PartyManagement API
kubectl port-forward svc/partymanagement-api 8082:8080 -n "${NAMESPACE}" >/dev/null 2>&1 &
echo -e "${GREEN}  ✓ PartyManagement API → http://localhost:8082${NC}"

sleep 3

# ─── DONE ────────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  ✅  ODA Canvas is UP and READY!${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "  🌐 Canvas UI            → ${CYAN}http://localhost:3000${NC}"
echo -e "  🔌 ProductCatalog API   → ${CYAN}http://localhost:8081/tmf-api/productCatalogManagement/v4${NC}"
echo -e "  🔌 PartyManagement API  → ${CYAN}http://localhost:8082/tmf-api/partyManagement/v4${NC}"
echo ""
echo -e "  📋 Run ${YELLOW}./test-oda.sh${NC} to validate the installation."
echo -e "  📚 Open ${YELLOW}README.md${NC} for the full challenge instructions."
echo ""
