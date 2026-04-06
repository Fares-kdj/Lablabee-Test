#!/bin/bash

# ============================================================
#  LabLabee – Challenge 3: ODA Canvas
#  Test / Validation Script
#  Rebuilt from real environment inspection
# ============================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Namespaces réels observés dans l'environnement
CANVAS_NS="canvas"         # Canvas operator, Keycloak, UI
COMPONENTS_NS="components" # ODA Components + APIs + pods métier

PASS=0
FAIL=0

echo -e "${CYAN}════════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}  LabLabee – Challenge 3: ODA Canvas – Validation Tests${NC}"
echo -e "${CYAN}════════════════════════════════════════════════════════════${NC}"
echo ""

ok()   { echo -e "  ${GREEN}✓ PASS${NC} – $1"; PASS=$((PASS+1)); }
fail() { echo -e "  ${RED}✗ FAIL${NC} – $1"; FAIL=$((FAIL+1)); }
info() { echo -e "  ${YELLOW}ℹ${NC}  $1"; }

# ─── TEST 1: Kind cluster running ─────────────────────────────────────────────
echo -e "${YELLOW}[TEST 1] Kind cluster 'shared-lab'${NC}"
if kind get clusters 2>/dev/null | grep -q "^shared-lab$"; then
  ok "Kind cluster 'shared-lab' exists"
else
  fail "Kind cluster 'shared-lab' not found – run ./start-oda.sh"
fi

# ─── TEST 2: Namespaces canvas + components ────────────────────────────────────
echo ""
echo -e "${YELLOW}[TEST 2] Required namespaces${NC}"
NS_OK=0
for NS in canvas components; do
  if kubectl get namespace "$NS" >/dev/null 2>&1; then
    info "Namespace '$NS' exists ✓"
    NS_OK=$((NS_OK+1))
  else
    info "Namespace '$NS' MISSING ✗"
  fi
done
if [ "$NS_OK" -eq 2 ]; then
  ok "Both namespaces 'canvas' and 'components' exist"
else
  fail "Missing namespace(s) – expected canvas + components"
fi

# ─── TEST 3: Canvas core pods running ─────────────────────────────────────────
echo ""
echo -e "${YELLOW}[TEST 3] Canvas core pods (namespace: canvas)${NC}"
RUNNING=$(kubectl get pods -n "${CANVAS_NS}" --no-headers 2>/dev/null \
  | grep -c "Running" || echo 0)
if [ "$RUNNING" -ge 2 ]; then
  ok "${RUNNING} pods Running in namespace '${CANVAS_NS}'"
  kubectl get pods -n "${CANVAS_NS}" --no-headers 2>/dev/null \
    | awk '{printf "         %-45s %s\n", $1, $3}'
else
  fail "Expected ≥2 pods Running in 'canvas', found ${RUNNING}"
  info "Run: kubectl get pods -n ${CANVAS_NS}"
fi

# ─── TEST 4: ODA Component pods running ───────────────────────────────────────
echo ""
echo -e "${YELLOW}[TEST 4] ODA Component pods (namespace: components)${NC}"
COMP_PODS=$(kubectl get pods -n "${COMPONENTS_NS}" --no-headers 2>/dev/null \
  | grep -c "Running" || echo 0)
if [ "$COMP_PODS" -ge 2 ]; then
  ok "${COMP_PODS} component pods Running in namespace '${COMPONENTS_NS}'"
  kubectl get pods -n "${COMPONENTS_NS}" --no-headers 2>/dev/null \
    | awk '{printf "         %-45s %s\n", $1, $3}'
else
  fail "Expected ≥2 pods Running in 'components', found ${COMP_PODS}"
  info "Run: kubectl get pods -n ${COMPONENTS_NS}"
fi

# ─── TEST 5: ODA Components CRD registered ────────────────────────────────────
echo ""
echo -e "${YELLOW}[TEST 5] ODA Components CRD (namespace: components)${NC}"
COMPONENTS=$(kubectl get components -n "${COMPONENTS_NS}" --no-headers 2>/dev/null \
  | wc -l || echo 0)
if [ "$COMPONENTS" -ge 2 ]; then
  ok "${COMPONENTS} ODA Component(s) found in namespace '${COMPONENTS_NS}'"
  kubectl get components -n "${COMPONENTS_NS}" --no-headers 2>/dev/null \
    | awk '{printf "         %-35s STATUS: %s\n", $1, $2}'
else
  fail "Expected ≥2 ODA Components in 'components', found ${COMPONENTS}"
  info "Run: kubectl get components -n ${COMPONENTS_NS}"
fi

# ─── TEST 6: Exposed APIs registered (kubectl get api) ────────────────────────
echo ""
echo -e "${YELLOW}[TEST 6] Exposed APIs registered (namespace: components)${NC}"
API_COUNT=$(kubectl get api -n "${COMPONENTS_NS}" --no-headers 2>/dev/null \
  | wc -l || echo 0)
if [ "$API_COUNT" -ge 2 ]; then
  ok "${API_COUNT} API(s) registered in namespace '${COMPONENTS_NS}'"
  kubectl get api -n "${COMPONENTS_NS}" --no-headers 2>/dev/null \
    | awk '{printf "         %-45s READY: %s\n", $1, $3}'
else
  fail "Expected ≥2 APIs registered, found ${API_COUNT}"
  info "Run: kubectl get api -n ${COMPONENTS_NS}"
fi

# ─── TEST 7: ProductCatalog TMF620 API reachable ──────────────────────────────
echo ""
echo -e "${YELLOW}[TEST 7] ProductCatalog TMF620 API – http://localhost:8081${NC}"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 \
  http://localhost:8081/tmf-api/productCatalogManagement/v4/catalog 2>/dev/null \
  || echo "000")
if [ "$HTTP_CODE" = "200" ]; then
  ok "TMF620 /catalog returned HTTP 200"
  CATALOG_COUNT=$(curl -s --max-time 5 \
    http://localhost:8081/tmf-api/productCatalogManagement/v4/catalog 2>/dev/null \
    | jq 'length' 2>/dev/null || echo "?")
  info "Catalogs found: ${CATALOG_COUNT}"
else
  fail "TMF620 API not reachable (HTTP ${HTTP_CODE})"
  info "Run: kubectl get pods -n ${COMPONENTS_NS}"
  info "Run: kubectl get svc -n ${COMPONENTS_NS}"
fi

# ─── TEST 8: PartyManagement TMF632 API reachable ─────────────────────────────
echo ""
echo -e "${YELLOW}[TEST 8] PartyManagement TMF632 API – http://localhost:8082${NC}"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 \
  http://localhost:8082/tmf-api/partyManagement/v4/individual 2>/dev/null \
  || echo "000")
if [ "$HTTP_CODE" = "200" ]; then
  ok "TMF632 /individual returned HTTP 200"
else
  fail "TMF632 API not reachable (HTTP ${HTTP_CODE})"
  info "Run: kubectl get pods -n ${COMPONENTS_NS}"
  info "Run: kubectl get svc -n ${COMPONENTS_NS}"
fi

# ─── TEST 9: Canvas UI reachable ──────────────────────────────────────────────
echo ""
echo -e "${YELLOW}[TEST 9] Canvas UI – http://localhost:3003${NC}"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 \
  http://localhost:3003 2>/dev/null || echo "000")
if [ "$HTTP_CODE" = "200" ]; then
  ok "Canvas UI returned HTTP 200 at http://localhost:3003"
else
  fail "Canvas UI not reachable (HTTP ${HTTP_CODE})"
  info "Run: kubectl get svc canvas-ui -n ${CANVAS_NS}"
fi

# ─── TEST 10: Create a ProductOffering via TMF620 ─────────────────────────────
echo ""
echo -e "${YELLOW}[TEST 10] Create a ProductOffering via TMF620 API${NC}"
RESPONSE=$(curl -s --max-time 10 -X POST \
  http://localhost:8081/tmf-api/productCatalogManagement/v4/productOffering \
  -H "Content-Type: application/json" \
  -d '{
    "name": "LabLabee Test Offering",
    "lifecycleStatus": "Active",
    "validFor": { "startDateTime": "2024-01-01T00:00:00Z" }
  }' 2>/dev/null || echo "{}")
OFFERING_ID=$(echo "$RESPONSE" | jq -r '.id // empty' 2>/dev/null || echo "")
if [ -n "$OFFERING_ID" ]; then
  ok "ProductOffering created – id: ${OFFERING_ID}"
else
  fail "Could not create ProductOffering"
  info "Response: ${RESPONSE}"
fi

# ─── SUMMARY ──────────────────────────────────────────────────────────────────
echo ""
echo -e "${CYAN}════════════════════════════════════════════════════════════${NC}"
TOTAL=$((PASS + FAIL))
if [ "$FAIL" -eq 0 ]; then
  echo -e "${GREEN}  ✅  All ${TOTAL} tests passed! ODA Canvas is ready.${NC}"
  echo -e "${GREEN}  🎉 Open README.md to start the challenge!${NC}"
else
  echo -e "${YELLOW}  ⚠️  ${PASS}/${TOTAL} tests passed – ${FAIL} issue(s) to fix.${NC}"
  echo -e "  Run ${YELLOW}./start-oda.sh${NC} again if the cluster is not fully up."
fi
echo -e "${CYAN}════════════════════════════════════════════════════════════${NC}"
echo ""
