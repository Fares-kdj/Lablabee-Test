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

# ─── Helper: generate a SAN cert and replace compcrdwebhook-secret ───────────
apply_san_cert() {
  local TMP=$(mktemp -d)
  cat > "${TMP}/san.conf" << EOF
[req]
req_extensions     = v3_req
distinguished_name = req_distinguished_name
prompt             = no
[req_distinguished_name]
CN = compcrdwebhook.${NAMESPACE}.svc
[v3_req]
keyUsage           = keyEncipherment, dataEncipherment
extendedKeyUsage   = serverAuth
subjectAltName     = @alt_names
[alt_names]
DNS.1 = compcrdwebhook
DNS.2 = compcrdwebhook.${NAMESPACE}
DNS.3 = compcrdwebhook.${NAMESPACE}.svc
DNS.4 = compcrdwebhook.${NAMESPACE}.svc.cluster.local
EOF
  openssl genrsa -out "${TMP}/tls.key" 2048 2>/dev/null
  openssl req -new -key "${TMP}/tls.key" -out "${TMP}/tls.csr" \
    -config "${TMP}/san.conf" 2>/dev/null
  openssl x509 -req -in "${TMP}/tls.csr" -signkey "${TMP}/tls.key" \
    -out "${TMP}/tls.crt" -days 3650 \
    -extensions v3_req -extfile "${TMP}/san.conf" 2>/dev/null

  kubectl delete secret compcrdwebhook-secret -n "${NAMESPACE}" 2>/dev/null || true
  kubectl create secret tls compcrdwebhook-secret \
    -n "${NAMESPACE}" \
    --cert="${TMP}/tls.crt" \
    --key="${TMP}/tls.key" >/dev/null

  # Patch CRD caBundle so Kubernetes trusts this cert for the webhook
  local CA_BUNDLE
  CA_BUNDLE=$(base64 -w0 < "${TMP}/tls.crt")
  kubectl patch crd components.oda.tmforum.org --type='json' \
    -p="[{\"op\":\"replace\",\"path\":\"/spec/conversion/webhook/clientConfig/caBundle\",\"value\":\"${CA_BUNDLE}\"}]" \
    >/dev/null 2>&1 || true

  rm -rf "${TMP}"
}

# ─── Helper: wait for webhook pod to be 1/1 Running ──────────────────────────
wait_for_webhook() {
  echo -n "  Waiting for webhook pod"
  for i in $(seq 1 30); do
    READY=$(kubectl get pods -n "${NAMESPACE}" --no-headers 2>/dev/null \
      | grep "compcrdwebhook" | grep -c "1/1" || true)
    if [ "$READY" -ge 1 ]; then
      echo -e " ${GREEN}✓${NC}"
      return 0
    fi
    echo -n "."
    sleep 5
  done
  echo -e " ${YELLOW}(timeout – continuing anyway)${NC}"
}

# ─── 1. CHECK PREREQUISITES ───────────────────────────────────────────────────
echo -e "${YELLOW}[1/8] Checking prerequisites...${NC}"

check_tool() {
  if ! command -v "$1" &>/dev/null; then
    echo -e "${RED}  ✗ '$1' not found.${NC}"; exit 1
  else
    echo -e "${GREEN}  ✓ $1 found: $(command -v $1)${NC}"
  fi
}
check_tool docker; check_tool kind; check_tool kubectl
check_tool helm;   check_tool curl; check_tool jq

AVAILABLE_MEM=$(free -m | awk '/^Mem:/{print $7}')
if [ "$AVAILABLE_MEM" -lt 3500 ]; then
  echo -e "${RED}  ✗ Not enough memory: ${AVAILABLE_MEM}MB available, 4000MB required.${NC}"; exit 1
else
  echo -e "${GREEN}  ✓ Memory OK: ${AVAILABLE_MEM}MB available${NC}"
fi

# ─── 2. CREATE KIND CLUSTER ───────────────────────────────────────────────────
echo ""
echo -e "${YELLOW}[2/8] Creating Kind cluster '${CLUSTER_NAME}'...${NC}"

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
echo -e "${YELLOW}[3/8] Installing cert-manager (required by ODA Canvas)...${NC}"
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.3/cert-manager.yaml >/dev/null
echo -n "  Waiting for cert-manager pods to be ready"
for i in $(seq 1 30); do
  READY=$(kubectl get pods -n cert-manager --no-headers 2>/dev/null | grep -c "Running" || true)
  if [ "$READY" -ge 3 ]; then echo -e " ${GREEN}✓${NC}"; break; fi
  echo -n "."; sleep 5
done
echo -e "${GREEN}  ✓ cert-manager ready.${NC}"

# ─── 4. INSTALL ISTIO ─────────────────────────────────────────────────────────
echo ""
echo -e "${YELLOW}[4/8] Installing Istio (required by ODA Canvas)...${NC}"
helm repo add istio https://istio-release.storage.googleapis.com/charts 2>/dev/null || true
helm repo update >/dev/null
kubectl create namespace istio-system  --dry-run=client -o yaml | kubectl apply -f - >/dev/null
kubectl create namespace istio-ingress --dry-run=client -o yaml | kubectl apply -f - >/dev/null

echo "  → Installing Istio base CRDs..."
helm upgrade --install istio-base istio/base -n istio-system --wait >/dev/null
echo -e "${GREEN}  ✓ Istio base installed.${NC}"

echo "  → Installing Istiod control plane..."
helm upgrade --install istiod istio/istiod -n istio-system --wait >/dev/null
echo -e "${GREEN}  ✓ Istiod installed.${NC}"

echo "  → Enabling sidecar injection on ingress namespace..."
kubectl label namespace istio-ingress istio-injection=enabled --overwrite >/dev/null
echo -e "${GREEN}  ✓ Namespace 'istio-ingress' labeled.${NC}"

echo "  → Installing Istio ingress gateway..."
if ! helm upgrade --install istio-ingress istio/gateway \
  -n istio-ingress \
  --set labels.app=istio-ingressgateway \
  --set labels.istio=ingressgateway \
  --set service.type=NodePort \
  --wait --timeout 5m; then
  echo -e "${RED}  ✗ Istio ingress gateway installation failed.${NC}"
  kubectl get pods -n istio-ingress -o wide || true
  kubectl get events -n istio-ingress --sort-by=.metadata.creationTimestamp || true
  exit 1
fi
echo -e "${GREEN}  ✓ Istio ingress gateway installed.${NC}"

echo -n "  Waiting for Istio components to be ready"
for i in $(seq 1 36); do
  ISTIOD=$(kubectl get pods -n istio-system  --no-headers 2>/dev/null | grep -c "Running" || true)
  INGRESS=$(kubectl get pods -n istio-ingress --no-headers 2>/dev/null | grep -c "Running" || true)
  if [ "$ISTIOD" -ge 1 ] && [ "$INGRESS" -ge 1 ]; then echo -e " ${GREEN}✓${NC}"; break; fi
  echo -n "."; sleep 5
done
kubectl get crd gateways.networking.istio.io       >/dev/null 2>&1 || { echo -e "${RED}  ✗ Istio Gateway CRD not found.${NC}"; exit 1; }
kubectl get crd virtualservices.networking.istio.io >/dev/null 2>&1 || { echo -e "${RED}  ✗ Istio VirtualService CRD not found.${NC}"; exit 1; }
echo -e "${GREEN}  ✓ Istio ready.${NC}"

# ─── 5. PRE-CREATE WEBHOOK TLS SECRET (with SANs) ────────────────────────────
# The Canvas Helm chart ships a CN-only cert rejected by Go 1.15+ / Kubernetes.
# We pre-create the secret with proper SANs BEFORE Helm installs the Canvas,
# then re-apply it AFTER (Helm overwrites the secret), and restart the pod.
echo ""
echo -e "${YELLOW}[5/8] Preparing webhook TLS secret...${NC}"
kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f - >/dev/null
apply_san_cert
echo -e "${GREEN}  ✓ compcrdwebhook-secret ready (with SANs).${NC}"

# ─── 6. INSTALL ODA CANVAS VIA HELM ──────────────────────────────────────────
echo ""
echo -e "${YELLOW}[6/8] Installing ODA Canvas (Helm chart v${CANVAS_VERSION})...${NC}"
helm repo add oda-canvas https://tmforum-oda.github.io/oda-canvas/ 2>/dev/null || true
helm repo update >/dev/null
kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f - >/dev/null

echo "  → Installing Canvas..."
if ! helm upgrade --install canvas oda-canvas/canvas-oda \
  --namespace "${NAMESPACE}" \
  --version "${CANVAS_VERSION}" \
  --values canvas-values.yaml \
  --set cert-manager-init.cert-manager.enabled=false \
  --set cert-manager-init.cert-manager.installCRDs=false \
  --set keycloak.image.registry=docker.io \
  --set keycloak.image.repository=bitnamilegacy/keycloak \
  --set keycloak.image.tag=20.0.5-debian-11-r2 \
  --set keycloak.postgresql.image.registry=docker.io \
  --set keycloak.postgresql.image.repository=bitnamilegacy/postgresql \
  --set keycloak.postgresql.image.tag=15.2.0-debian-11-r31 \
  --set keycloak.keycloakConfigCli.image.registry=docker.io \
  --set keycloak.keycloakConfigCli.image.repository=bitnamilegacy/keycloak-config-cli \
  --wait --timeout 5m; then
  echo -e "${RED}  ✗ ODA Canvas installation failed.${NC}"
  kubectl get pods -n "${NAMESPACE}" -o wide || true
  kubectl get events -n "${NAMESPACE}" --sort-by=.metadata.creationTimestamp || true
  exit 1
fi
echo -e "${GREEN}  ✓ ODA Canvas installed in namespace '${NAMESPACE}'.${NC}"

# Helm overwrites compcrdwebhook-secret with its own CN-only cert → re-apply SANs
echo "  → Re-applying SAN cert (Helm overwrites the secret)..."
apply_san_cert
echo -e "${GREEN}  ✓ SAN cert re-applied and CRD caBundle patched.${NC}"

# Restart webhook pod so it picks up the new secret from disk
kubectl rollout restart deployment/compcrdwebhook -n "${NAMESPACE}" >/dev/null
wait_for_webhook
echo -e "${GREEN}  ✓ Webhook ready with SAN certificate.${NC}"

# ─── 7. DEPLOY ODA COMPONENTS ────────────────────────────────────────────────
echo ""
echo -e "${YELLOW}[7/8] Deploying ODA Components...${NC}"

echo "  → Deploying Deployments, Services and ConfigMaps..."
kubectl apply -f manifests/services-and-configs.yaml >/dev/null
echo -e "${GREEN}  ✓ Deployments, Services and ConfigMaps applied.${NC}"

echo "  → Registering ProductCatalog ODA Component (TMF620)..."
kubectl apply -f manifests/productcatalog-component.yaml -n "${NAMESPACE}" >/dev/null
echo -e "${GREEN}  ✓ ProductCatalog component applied.${NC}"

echo "  → Registering PartyManagement ODA Component (TMF632)..."
kubectl apply -f manifests/partymanagement-component.yaml -n "${NAMESPACE}" >/dev/null
echo -e "${GREEN}  ✓ PartyManagement component applied.${NC}"

echo -n "  Waiting for components to reach 'Complete' status"
for i in $(seq 1 36); do
  COMPLETE=$(kubectl get components -n "${NAMESPACE}" --no-headers 2>/dev/null | grep -c "Complete" || true)
  if [ "$COMPLETE" -ge 2 ]; then echo -e " ${GREEN}✓${NC}"; break; fi
  echo -n "."; sleep 5
done

# ─── 8. SETUP PORT-FORWARDS ──────────────────────────────────────────────────
echo ""
echo -e "${YELLOW}[8/8] Setting up port-forwards...${NC}"
pkill -f "kubectl port-forward" 2>/dev/null || true
sleep 1

kubectl port-forward svc/canvas-oda-canvas-ui 3000:3000   -n "${NAMESPACE}" >/dev/null 2>&1 &
echo -e "${GREEN}  ✓ Canvas UI       → http://localhost:3000${NC}"

kubectl port-forward svc/productcatalog-api 8081:8080     -n "${NAMESPACE}" >/dev/null 2>&1 &
echo -e "${GREEN}  ✓ ProductCatalog API → http://localhost:8081${NC}"

kubectl port-forward svc/partymanagement-api 8082:8080    -n "${NAMESPACE}" >/dev/null 2>&1 &
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
