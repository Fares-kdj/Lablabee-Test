# 🚀 Quick Start Guide - Challenge 3: Open Digital Architecture (ODA)

## Setup in 3 Steps

### Step 1: Install Prerequisites
```bash
# Make the script executable (once only)
chmod +x install-prerequisites.sh

# Run the installer (Docker + Kind + kubectl + Helm + jq)
./install-prerequisites.sh
```

⚠️ If Docker was just installed, apply group changes before continuing:
```bash
newgrp docker
```

**Manually verify each tool:**
```bash
docker --version
kind --version
kubectl version --client --short
helm version --short
jq --version
```

### Step 2: Start the ODA Canvas Environment
```bash
# Make all scripts executable (once only)
chmod +x start-oda.sh test-oda.sh stop-oda.sh

# Launch the environment
./start-oda.sh
```

⏱️ **Startup time: 5-8 minutes** (downloads images on first run)

What it does automatically:
- Creates a Kind (Kubernetes-in-Docker) cluster named `oda-lab`
- Installs cert-manager (required by ODA Canvas)
- Installs ODA Canvas via Helm chart (tmforum-oda official)
- Deploys 2 ODA Components: ProductCatalog (TMF620) + PartyManagement (TMF632)
- Sets up port-forwards so APIs are accessible from your browser

### Step 3: Validate the Installation
```bash
./test-oda.sh
```

✅ All 8 tests should pass before starting the challenge.

---

## 🌐 Access to Web Interfaces

Once the environment is started, open your browser:

| Interface | URL | Description |
|---|---|---|
| ODA Canvas UI | http://localhost:3000 | Visual component dashboard |
| ProductCatalog API | http://localhost:8081/tmf-api/productCatalogManagement/v4 | TMF620 REST API |
| PartyManagement API | http://localhost:8082/tmf-api/partyManagement/v4 | TMF632 REST API |

---

## 📝 Essential Commands

### Environment Management
```bash
# Start everything
./start-oda.sh

# Stop (interactive – choose level of cleanup)
./stop-oda.sh

# View Canvas logs
kubectl logs deployment/canvas-oda-component-operator -n canvas -f
```

### ODA Component Commands
```bash
# List all deployed ODA Components
kubectl get components -n canvas

# Describe a specific component (see its exposedAPIs, dependentAPIs)
kubectl describe component productcatalog -n canvas

# List all APIs registered in the Canvas
kubectl get apiv1 -n canvas -o wide

# Get a component manifest as YAML (key exercise!)
kubectl get component productcatalog -n canvas -o yaml
```

### Quick API Test Calls
```bash
# List product catalogs
curl http://localhost:8081/tmf-api/productCatalogManagement/v4/catalog

# List product offerings
curl http://localhost:8081/tmf-api/productCatalogManagement/v4/productOffering

# List individuals (PartyManagement)
curl http://localhost:8082/tmf-api/partyManagement/v4/individual

# Pretty-print JSON output
curl http://localhost:8081/tmf-api/productCatalogManagement/v4/catalog | jq .
```

---

## ❓ Quick Troubleshooting

### Containers won't start / cluster not responding
```bash
# Check all pods
kubectl get pods -n canvas

# See detailed logs
kubectl logs deployment/canvas-oda-component-operator -n canvas

# Full reset
./stop-oda.sh   # choose option 3
./start-oda.sh
```

### Port already in use
```bash
sudo lsof -i :3000
sudo lsof -i :8081
sudo lsof -i :8082
sudo kill -9 <PID>
```

### APIs return 000 / connection refused
```bash
# Re-apply port-forwards manually
kubectl port-forward svc/productcatalog-api 8081:8080 -n canvas &
kubectl port-forward svc/partymanagement-api 8082:8080 -n canvas &
```

### Not enough memory
```bash
free -h   # Must show ≥ 4GB available

# If < 4GB, edit oda.env and reduce:
# ODA_COMPONENT_MEMORY_LIMIT=256m
# ODA_CANVAS_MEMORY_LIMIT=128m
# Then restart: ./stop-oda.sh (option 2) → ./start-oda.sh
```

---

## 📁 File Structure

```
challenge3-oda/
├── start-oda.sh                  ← Main startup script
├── stop-oda.sh                   ← Stop / cleanup script
├── test-oda.sh                   ← Validation script
├── install-prerequisites.sh      ← Install Docker/Kind/kubectl/Helm
├── kind-config.yaml              ← Kind cluster definition
├── canvas-values.yaml            ← Helm values for ODA Canvas
├── oda.env                       ← Environment configuration
├── manifests/
│   ├── productcatalog-component.yaml   ← TMF620 ODA Component + Deployment
│   └── partymanagement-component.yaml  ← TMF632 ODA Component + Deployment
├── data/
│   └── seed-data.json            ← Sample data for the lab
├── README.md                     ← Full challenge guide
└── QUICKSTART.md                 ← This file
```

---

## 📚 Full Documentation

- **README.md** : Complete challenge guide with 3 Practices (RECOMMENDED)
- **manifests/** : ODA Component YAML files to study and modify
- **oda.env** : Environment variables to customize the lab

---

## ✅ Pre-Start Checklist

- [ ] Docker installed and functional (`docker run hello-world`)
- [ ] Kind installed (`kind --version`)
- [ ] kubectl installed (`kubectl version --client`)
- [ ] Helm installed (`helm version`)
- [ ] At least 4 GB of RAM available (`free -h`)
- [ ] Ports 3000, 8081, 8082 free
- [ ] Environment started (`./start-oda.sh`)
- [ ] All 8 tests passed (`./test-oda.sh`)
- [ ] Canvas UI accessible at http://localhost:3000

**🎉 You are ready for the ODA Canvas Challenge!**
