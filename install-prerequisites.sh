#!/bin/bash

# ============================================================
#  LabLabee – Challenge 3: ODA Canvas
#  Install Prerequisites – Ubuntu 24.04
#  Installs: Docker, Kind, kubectl, Helm, jq, curl
# ============================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}════════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}  LabLabee – ODA Canvas – Installing Prerequisites${NC}"
echo -e "${CYAN}  Target OS: Ubuntu 24.04 LTS${NC}"
echo -e "${CYAN}════════════════════════════════════════════════════════════${NC}"
echo ""

already_installed() {
  if command -v "$1" &>/dev/null; then
    echo -e "${GREEN}  ✓ $1 already installed – skipping.${NC}"
    return 0
  fi
  return 1
}

# ─── SYSTEM UPDATE ────────────────────────────────────────────────────────────
echo -e "${YELLOW}[1/6] Updating system packages...${NC}"
sudo apt-get update -qq
sudo apt-get install -y -qq curl wget apt-transport-https ca-certificates gnupg lsb-release jq
echo -e "${GREEN}  ✓ Base packages installed.${NC}"

# ─── DOCKER ──────────────────────────────────────────────────────────────────
echo ""
echo -e "${YELLOW}[2/6] Installing Docker...${NC}"
if already_installed docker; then :
else
  curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
  sudo sh /tmp/get-docker.sh -q
  sudo usermod -aG docker "$USER"
  echo -e "${GREEN}  ✓ Docker installed.${NC}"
  echo -e "${YELLOW}  ⚠ You must log out and back in (or run 'newgrp docker') for group changes to take effect.${NC}"
fi

# ─── KIND ─────────────────────────────────────────────────────────────────────
echo ""
echo -e "${YELLOW}[3/6] Installing Kind (Kubernetes in Docker)...${NC}"
if already_installed kind; then :
else
  KIND_VERSION="v0.22.0"
  curl -Lo /tmp/kind "https://kind.sigs.k8s.io/dl/${KIND_VERSION}/kind-linux-amd64"
  chmod +x /tmp/kind
  sudo mv /tmp/kind /usr/local/bin/kind
  echo -e "${GREEN}  ✓ Kind ${KIND_VERSION} installed → $(which kind)${NC}"
fi

# ─── KUBECTL ──────────────────────────────────────────────────────────────────
echo ""
echo -e "${YELLOW}[4/6] Installing kubectl...${NC}"
if already_installed kubectl; then :
else
  KUBECTL_VERSION=$(curl -s https://dl.k8s.io/release/stable.txt)
  curl -Lo /tmp/kubectl "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"
  chmod +x /tmp/kubectl
  sudo mv /tmp/kubectl /usr/local/bin/kubectl
  echo -e "${GREEN}  ✓ kubectl ${KUBECTL_VERSION} installed → $(which kubectl)${NC}"
fi

# ─── HELM ─────────────────────────────────────────────────────────────────────
echo ""
echo -e "${YELLOW}[5/6] Installing Helm...${NC}"
if already_installed helm; then :
else
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash -s -- --no-sudo 2>/dev/null
  sudo mv "$HOME/.helm/bin/helm" /usr/local/bin/helm 2>/dev/null || \
    sudo mv /tmp/helm /usr/local/bin/helm 2>/dev/null || \
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
  echo -e "${GREEN}  ✓ Helm installed → $(which helm)${NC}"
fi

# ─── VERIFY ───────────────────────────────────────────────────────────────────
echo ""
echo -e "${YELLOW}[6/6] Verifying all tools...${NC}"
echo ""

verify() {
  local tool=$1
  local flag=${2:---version}
  if command -v "$tool" &>/dev/null; then
    VERSION=$($tool $flag 2>&1 | head -1)
    echo -e "  ${GREEN}✓ $tool${NC} – $VERSION"
  else
    echo -e "  ${RED}✗ $tool NOT FOUND${NC}"
  fi
}

verify docker  "--version"
verify kind    "--version"
verify kubectl "version --client --short"
verify helm    "version --short"
verify jq      "--version"
verify curl    "--version"

echo ""
echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  ✅  All prerequisites installed!${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "  Next step: ${YELLOW}./start-oda.sh${NC}"
echo ""
echo -e "${YELLOW}  ⚠ If Docker was just installed, run:${NC}"
echo -e "     ${CYAN}newgrp docker${NC}   (applies group change without logout)"
echo ""
