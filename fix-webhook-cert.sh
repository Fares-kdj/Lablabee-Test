#!/bin/bash
# ============================================================
#  Fix: ODA Canvas webhook TLS certificate (CN → SAN)
#  The compcrdwebhook uses a legacy CN-only cert rejected by
#  Go 1.15+ TLS client. We regenerate with proper SANs.
# ============================================================

set -e
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

NAMESPACE="canvas"
SECRET="compcrdwebhook-secret"
SERVICE="compcrdwebhook"

echo -e "${YELLOW}[1/4] Generating new TLS certificate with SANs...${NC}"

# Create OpenSSL config with SAN
cat > /tmp/webhook-csr.conf << EOF
[req]
req_extensions = v3_req
distinguished_name = req_distinguished_name
prompt = no

[req_distinguished_name]
CN = ${SERVICE}.${NAMESPACE}.svc

[v3_req]
keyUsage = keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = ${SERVICE}
DNS.2 = ${SERVICE}.${NAMESPACE}
DNS.3 = ${SERVICE}.${NAMESPACE}.svc
DNS.4 = ${SERVICE}.${NAMESPACE}.svc.cluster.local
EOF

# Generate key and self-signed cert with SAN
openssl genrsa -out /tmp/webhook.key 2048 2>/dev/null
openssl req -new -key /tmp/webhook.key -out /tmp/webhook.csr \
  -config /tmp/webhook-csr.conf 2>/dev/null
openssl x509 -req -in /tmp/webhook.csr -signkey /tmp/webhook.key \
  -out /tmp/webhook.crt -days 3650 \
  -extensions v3_req -extfile /tmp/webhook-csr.conf 2>/dev/null

echo -e "${GREEN}  ✓ Certificate generated with SANs${NC}"

# Verify SANs are present
echo -e "${YELLOW}  Verifying SANs in certificate:${NC}"
openssl x509 -in /tmp/webhook.crt -noout -text 2>/dev/null | grep -A3 "Subject Alternative Name" || echo "  (checking...)"

echo ""
echo -e "${YELLOW}[2/4] Replacing Kubernetes secret '${SECRET}'...${NC}"

kubectl delete secret "${SECRET}" -n "${NAMESPACE}" --ignore-not-found >/dev/null
kubectl create secret tls "${SECRET}" \
  --cert=/tmp/webhook.crt \
  --key=/tmp/webhook.key \
  -n "${NAMESPACE}"

echo -e "${GREEN}  ✓ Secret '${SECRET}' replaced${NC}"

echo ""
echo -e "${YELLOW}[3/4] Patching webhook with new caBundle...${NC}"

CA_BUNDLE=$(base64 -w0 < /tmp/webhook.crt)

# Patch the conversion webhook CA bundle in the CRD
kubectl patch crd components.oda.tmforum.org --type='json' \
  -p="[{\"op\":\"replace\",\"path\":\"/spec/conversion/webhook/clientConfig/caBundle\",\"value\":\"${CA_BUNDLE}\"}]"

echo -e "${GREEN}  ✓ CRD caBundle patched${NC}"

echo ""
echo -e "${YELLOW}[4/4] Restarting webhook pod...${NC}"

kubectl rollout restart deployment/compcrdwebhook -n "${NAMESPACE}"
kubectl rollout status deployment/compcrdwebhook -n "${NAMESPACE}" --timeout=60s

echo ""
echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  ✅  Webhook certificate fixed!${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
echo ""
echo "  Now apply your components:"
echo "    kubectl apply -f manifests/partymanagement-component.yaml"
echo "    kubectl apply -f manifests/productcatalog-component.yaml"
echo ""

# Cleanup
rm -f /tmp/webhook.key /tmp/webhook.csr /tmp/webhook.crt /tmp/webhook-csr.conf
