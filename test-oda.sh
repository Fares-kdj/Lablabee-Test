#!/bin/bash

# ============================================================
#  LabLabee – Challenge 3: ODA Canvas
#  Test / Validation Script
# ============================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

NAMESPACE="canvas"
PASS=0
FAIL=0

echo -e "${CYAN}════════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}  LabLabee – Challenge 3: ODA Canvas – Validation Tests${NC}"
echo -e "${CYAN}════════════════════════════════════════════════════════════${NC}"
echo ""

ok()   { echo -e "  ${GREEN}✓ PASS${NC} – $1"; PASS=$((PASS+1)); }
fail() { echo -e "  ${RED}✗ FAIL${NC} – $1"; FAIL=$((FAIL+1)); }
info() { echo -e "  ${YELLOW}ℹ${NC}  $1"; }

# ─── TEST 1: Kind cluster running ────────────────────────────────────────────
echo -e "${YELLOW}[TEST 1] Kind cluster status${NC}"
if kind get clusters 2>/dev/null | grep -q "oda-lab"; then
  ok "Kind cluster 'oda-lab' exists"
else
  fail "Kind cluster 'oda-lab' not found – run ./start-oda.sh"
fi

# ─── TEST 2: ODA Canvas namespace ────────────────────────────────────────────
echo ""
echo -e "${YELLOW}[TEST 2] ODA Canvas namespace${NC}"
if kubectl get namespace "${NAMESPACE}" >/dev/null 2>&1; then
  ok "Namespace '${NAMESPACE}' exists"
else
  fail "Namespace '${NAMESPACE}' not found"
fi

# ─── TEST 3: Canvas pods running ─────────────────────────────────────────────
echo ""
echo -e "${YELLOW}[TEST 3] Canvas core pods${NC}"
RUNNING=$(kubectl get pods -n "${NAMESPACE}" --no-headers 2>/dev/null | grep -c "Running" || echo 0)
if [ "$RUNNING" -ge 2 ]; then
  ok "${RUNNING} pods Running in namespace '${NAMESPACE}'"
  kubectl get pods -n "${NAMESPACE}" --no-headers 2>/dev/null | awk '{printf "         %-45s %s\n", $1, $3}'
else
  fail "Expected ≥2 pods Running, found ${RUNNING}"
  info "Run: kubectl get pods -n ${NAMESPACE} for details"
fi

# ─── TEST 4: ODA Components deployed ─────────────────────────────────────────
echo ""
echo -e "${YELLOW}[TEST 4] ODA Components${NC}"
COMPONENTS=$(kubectl get components -n "${NAMESPACE}" --no-headers 2>/dev/null | wc -l || echo 0)
if [ "$COMPONENTS" -ge 2 ]; then
  ok "${COMPONENTS} ODA Component(s) found"
  kubectl get components -n "${NAMESPACE}" --no-headers 2>/dev/null | awk '{printf "         %-35s STATUS: %s\n", $1, $2}'
else
  fail "Expected ≥2 ODA Components, found ${COMPONENTS}"
fi

# ─── TEST 5: ProductCatalog API reachable ─────────────────────────────────────
echo ""
echo -e "${YELLOW}[TEST 5] ProductCatalog TMF620 API (port 8081)${NC}"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 \
  http://localhost:8081/tmf-api/productCatalogManagement/v4/catalog 2>/dev/null || echo "000")
if [ "$HTTP_CODE" = "200" ]; then
  ok "TMF620 /catalog endpoint returned HTTP 200"
  CATALOG_COUNT=$(curl -s --max-time 5 \
    http://localhost:8081/tmf-api/productCatalogManagement/v4/catalog 2>/dev/null | jq 'length' 2>/dev/null || echo "?")
  info "Catalogs found: ${CATALOG_COUNT}"
else
  fail "TMF620 API not reachable (HTTP ${HTTP_CODE}) – check port-forward"
  info "Run: kubectl port-forward svc/productcatalog-api 8081:8080 -n ${NAMESPACE}"
fi

# ─── TEST 6: PartyManagement API reachable ────────────────────────────────────
echo ""
echo -e "${YELLOW}[TEST 6] PartyManagement TMF632 API (port 8082)${NC}"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 \
  http://localhost:8082/tmf-api/partyManagement/v4/individual 2>/dev/null || echo "000")
if [ "$HTTP_CODE" = "200" ]; then
  ok "TMF632 /individual endpoint returned HTTP 200"
else
  fail "TMF632 API not reachable (HTTP ${HTTP_CODE}) – check port-forward"
  info "Run: kubectl port-forward svc/partymanagement-api 8082:8080 -n ${NAMESPACE}"
fi

# ─── TEST 7: Exposed APIs registered in Canvas ───────────────────────────────
echo ""
echo -e "${YELLOW}[TEST 7] Exposed APIs registered in Canvas${NC}"
API_COUNT=$(kubectl get apiv1 -n "${NAMESPACE}" --no-headers 2>/dev/null | wc -l || echo 0)
if [ "$API_COUNT" -ge 2 ]; then
  ok "${API_COUNT} API(s) registered in Canvas"
  kubectl get apiv1 -n "${NAMESPACE}" --no-headers 2>/dev/null | awk '{printf "         %-40s READY: %s\n", $1, $2}'
else
  fail "Expected ≥2 APIs registered, found ${API_COUNT}"
fi

# ─── TEST 8: Create a ProductOffering via TMF620 ─────────────────────────────
echo ""
echo -e "${YELLOW}[TEST 8] Create a ProductOffering via TMF620 API${NC}"
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
  fail "Could not create ProductOffering – check TMF620 API"
  info "Response: ${RESPONSE}"
fi

# ─── SUMMARY ─────────────────────────────────────────────────────────────────
echo ""
echo -e "${CYAN}════════════════════════════════════════════════════════════${NC}"
TOTAL=$((PASS + FAIL))
if [ "$FAIL" -eq 0 ]; then
  echo -e "${GREEN}  ✅  All tests passed: ${PASS}/${TOTAL}${NC}"
  echo -e "${GREEN}  🎉 Your ODA Canvas lab is ready. Open README.md to start!${NC}"
else
  echo -e "${YELLOW}  ⚠️  ${PASS}/${TOTAL} tests passed – ${FAIL} issue(s) to fix.${NC}"
  echo -e "  Run ${YELLOW}./start-oda.sh${NC} again if the cluster is not fully up."
fi
echo -e "${CYAN}════════════════════════════════════════════════════════════${NC}"
echo ""
