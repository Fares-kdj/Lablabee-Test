#!/bin/bash

# ============================================================
#  LabLabee – Challenge 5: Open Gateway and CAMARA
#  Test / Validation Script – 8 automated checks
# ============================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

NAMESPACE="camara"
CLUSTER_NAME="shared-lab"
PASS=0
FAIL=0

echo -e "${CYAN}"
echo "  ╔═══════════════════════════════════════╗"
echo "  ║   LabLabee – Challenge 5: CAMARA      ║"
echo "  ║   Validation Script – 8 Tests         ║"
echo "  ╚═══════════════════════════════════════╝"
echo -e "${NC}"

check() {
  local LABEL="$1"
  local CMD="$2"
  printf "  %-52s" "${LABEL}..."
  if eval "$CMD" >/dev/null 2>&1; then
    echo -e "${GREEN}PASS${NC}"
    PASS=$((PASS + 1))
  else
    echo -e "${RED}FAIL${NC}"
    FAIL=$((FAIL + 1))
  fi
}

# ─── TEST 1: Kind cluster exists ─────────────────────────────────────────────
check "Kind cluster '${CLUSTER_NAME}' exists" \
  "kind get clusters 2>/dev/null | grep -q '^${CLUSTER_NAME}$'"

# ─── TEST 2: Services sont de type NodePort ───────────────────────────────────
check "All CAMARA services are NodePort" \
  "[ \$(kubectl get svc -n ${NAMESPACE} --no-headers 2>/dev/null | grep -c 'NodePort') -ge 4 ]"

# ─── TEST 3: QoD API health ───────────────────────────────────────────────────
check "QoD API health returns 200" \
  "[ \$(curl -s -o /dev/null -w '%{http_code}' http://localhost:8083/camara/quality-on-demand/v0/health) = '200' ]"

# ─── TEST 4: Device Location API health ──────────────────────────────────────
check "Device Location API health returns 200" \
  "[ \$(curl -s -o /dev/null -w '%{http_code}' http://localhost:8084/camara/device-location/v0/health) = '200' ]"

# ─── TEST 5: SIM Swap API health ─────────────────────────────────────────────
check "SIM Swap API health returns 200" \
  "[ \$(curl -s -o /dev/null -w '%{http_code}' http://localhost:8085/camara/sim-swap/v0/health) = '200' ]"

# ─── TEST 6: QoD session creation ────────────────────────────────────────────
SESSION_RESPONSE=$(curl -s -X POST \
  http://localhost:8083/camara/quality-on-demand/v0/sessions \
  -H "Content-Type: application/json" \
  -d '{
    "ueId": { "msisdn": "+33600000001" },
    "asId": { "ipv4addr": "1.2.3.4" },
    "qosProfile": "QOS_E",
    "duration": 300
  }' 2>/dev/null)
SESSION_ID=$(echo "$SESSION_RESPONSE" | jq -r '.sessionId // empty' 2>/dev/null)

check "QoD session creation returns sessionId" \
  "[ -n '${SESSION_ID}' ]"

# ─── TEST 7: QoD session retrieval ───────────────────────────────────────────
if [ -n "$SESSION_ID" ]; then
  check "QoD session retrieval by ID returns 200" \
    "[ \$(curl -s -o /dev/null -w '%{http_code}' http://localhost:8083/camara/quality-on-demand/v0/sessions/${SESSION_ID}) = '200' ]"
else
  printf "  %-52s" "QoD session retrieval by ID returns 200..."
  echo -e "${YELLOW}SKIP (no sessionId from test 6)${NC}"
fi

# ─── TEST 8: CAMARA UI reachable ─────────────────────────────────────────────
check "CAMARA Sandbox UI reachable at port 3000" \
  "[ \$(curl -s -o /dev/null -w '%{http_code}' http://localhost:3000) = '200' ]"

# ─── SUMMARY ──────────────────────────────────────────────────────────────────
echo ""
echo -e "  ──────────────────────────────────────────────────"
TOTAL=$((PASS + FAIL))
if [ "$FAIL" -eq 0 ]; then
  echo -e "  ${GREEN}✅  All ${TOTAL} tests passed! The sandbox is ready.${NC}"
  echo ""
  echo -e "  Run ${YELLOW}./test-camara.sh${NC} again anytime to re-validate."
  echo -e "  Open ${YELLOW}README.md${NC} to start the challenge."
else
  echo -e "  ${RED}❌  ${FAIL}/${TOTAL} test(s) failed.${NC}"
  echo ""
  echo -e "  Troubleshooting:"
  echo -e "    → Check pod status:    ${YELLOW}kubectl get pods -n ${NAMESPACE}${NC}"
  echo -e "    → Check pod logs:      ${YELLOW}kubectl logs deployment/camara-qod-mock -n ${NAMESPACE}${NC}"
  echo -e "    → Full reset:          ${YELLOW}./stop-camara.sh (option 3) → ./start-camara.sh${NC}"
fi
echo ""
