```bash
./start-oda.sh
# This will be transmitted as an alias — tell the user to use: "ODA up"
```

### Step 1: Verify the ODA Canvas is Running

```bash
kubectl get pods -n canvas
```

**✅ Expected result:**
- All pods in `Running` state
- `canvas-oda-component-operator` and `canvas-oda-api-operator` visible
- No pods in `Error` or `CrashLoopBackOff` state

### Step 2: Verify Deployed ODA Components

```bash
kubectl get components -n canvas
```

**✅ Expected result:**
- `productcatalog` – STATUS: `Complete`
- `partymanagement` – STATUS: `Complete`

---

## 📂 PRACTICE 3.1: Navigating the ODA Canvas UI

### Step 1: Open the Canvas Dashboard

1. Open **http://localhost:3000** in your browser
2. You will land on the **ODA Canvas Overview** page
3. Locate the **component list** in the left panel — you should see `productcatalog` and `partymanagement`

**💡 Explanation:**
The ODA Canvas is a **Kubernetes-based runtime** that hosts and manages ODA Components.
It acts like an "operating environment" for telecom software — just as an OS manages processes,
the Canvas manages independently deployable business components.
- Each component declares its **Exposed APIs** (what it publishes)
- Each component declares its **Dependent APIs** (what it needs from others)
- The Canvas enforces these contracts at deployment time

### Step 2: Explore the ProductCatalog Component

1. Click on **"productcatalog"** in the component list
2. Observe its detail panel:
   - **Exposed APIs tab**: TMF620 Product Catalog Management v4
   - **Dependent APIs tab**: TMF632 Party Management (consumed from `partymanagement`)
   - **Events tab**: `ProductOfferingCreateEvent`, `ProductOfferingDeleteEvent`
3. Click on the TMF620 API link — it opens the live Swagger UI

**📸 To capture:**
- Screenshot of the Canvas Overview showing both components with `Complete` status
- Screenshot of the `productcatalog` Exposed APIs tab

### Step 3: Understand Component Taxonomy

Navigate through both components and identify their ODA domain:

| Component | ODA Domain | TMF API |
|---|---|---|
| productcatalog | Core Commerce | TMF620 Product Catalog |
| partymanagement | Party & Contract | TMF632 Party Management |

```bash
# CLI equivalent: describe both components
kubectl describe component productcatalog -n canvas
kubectl describe component partymanagement -n canvas
```

**💡 Key fields to observe in the output:**
- `coreFunction.exposedAPIs` – which APIs are published to the Canvas
- `coreFunction.dependentAPIs` – which APIs are consumed from the Canvas
- `coreFunction.publishedEvents` – async event types published
- `Status.conditions` – deployment health reported by the Canvas operator

**✅ Expected result:**
- Both components show `type: Ready` condition with `status: "True"`

---

## 📂 PRACTICE 3.2: Reading ODA Component API Declarations (YAML Manifests)

### Step 1: Export the ProductCatalog Component Manifest

```bash
kubectl get component productcatalog -n canvas -o yaml
```

Study the output carefully. The manifest is the **full API contract** of the component —
no code reading required. Everything the Canvas needs to manage this component is declared here.

### Step 2: Identify the Exposed APIs Section

From the YAML output, locate the `coreFunction.exposedAPIs` block:

```yaml
coreFunction:
  exposedAPIs:
    - name: productcatalogmanagement
      specification: >-
        https://tmforum-rand.github.io/TMForum-ODA-Asset-Build/swaggers/TMF620-ProductCatalog-v4.0.0.swagger.json
      implementation: /productcatalog/tmf-api/productCatalogManagement/v4
      path: /productcatalog/tmf-api/productCatalogManagement/v4
      port: 8080
      resources:
        - catalog
        - category
        - productOffering
        - productOfferingPrice
        - productSpecification
```

**💡 Meaning of each field:**
- `specification` – points to the official TM Forum Swagger/OpenAPI spec for this API
- `implementation` – the actual URL path served by this component's container
- `resources` – the REST resource types this component implements from the TMF spec
- `port` – the internal container port

**📸 To capture:**
- Screenshot of the `exposedAPIs` section in the terminal output

### Step 3: Trace the dependentAPIs

```bash
kubectl get component productcatalog -n canvas -o jsonpath='{.spec.coreFunction.dependentAPIs}' | jq .
```

**✅ Expected result:**
```json
[
  {
    "name": "partymanagement",
    "specification": "...TMF632...",
    "resources": ["individual", "organization"]
  }
]
```

This tells you that `productcatalog` **needs** `partymanagement` to function —
it calls TMF632 to resolve party references in product offerings.

### Step 4: List All Registered APIs in the Canvas

```bash
kubectl get apiv1 -n canvas -o wide
```

**💡 This output shows:**
- Every API currently registered by all deployed components
- The implementation URL the Canvas resolved
- Whether the API is ready to accept traffic

**📸 To capture:**
- Screenshot of the full `kubectl get apiv1` output with all columns

### Step 5: Inspect Published Events

```bash
kubectl get component productcatalog -n canvas \
  -o jsonpath='{.spec.coreFunction.publishedEvents}' | jq .
```

**✅ Expected result:**
```json
[
  { "name": "ProductOfferingCreateEvent", "href": "...hub" },
  { "name": "ProductOfferingDeleteEvent", "href": "...hub" },
  { "name": "ProductSpecificationCreateEvent", "href": "...hub" }
]
```

**📸 To capture:**
- Screenshot of the published events list

---

## 📂 PRACTICE 3.3: Calling TMF APIs and Triggering Events

### Step 1: Explore the ProductCatalog API

```bash
# List all catalogs
curl -s http://localhost:8081/tmf-api/productCatalogManagement/v4/catalog | jq .

# List all product offerings
curl -s http://localhost:8081/tmf-api/productCatalogManagement/v4/productOffering | jq .

# List all product specifications
curl -s http://localhost:8081/tmf-api/productCatalogManagement/v4/productSpecification | jq .
```

**✅ Expected result:**
- JSON arrays returned for each resource type
- At least the seed data entries are visible (`LabLabee Enterprise Catalog`, etc.)

### Step 2: Create a New ProductOffering via REST

```bash
curl -s -X POST \
  http://localhost:8081/tmf-api/productCatalogManagement/v4/productOffering \
  -H "Content-Type: application/json" \
  -d '{
    "name": "LabLabee 5G Private Network – Enterprise",
    "description": "Dedicated 5G private network slice for enterprise campus",
    "lifecycleStatus": "Active",
    "validFor": {
      "startDateTime": "2024-06-01T00:00:00Z",
      "endDateTime": "2026-06-01T00:00:00Z"
    }
  }' | jq .
```

**💡 What just happened:**
When you POST a new ProductOffering, the TMF620 component:
1. Persists the resource and returns it with a generated `id`
2. Publishes a `ProductOfferingCreateEvent` to the Canvas event bus
3. Any component subscribed to that event (e.g., a billing component) is notified

**📸 To capture:**
- Screenshot of the full JSON response, especially the `id` field

### Step 3: Retrieve the Created Offering by ID

```bash
# Replace <id> with the id returned in Step 2
OFFERING_ID="<paste your id here>"

curl -s http://localhost:8081/tmf-api/productCatalogManagement/v4/productOffering/${OFFERING_ID} | jq .
```

**✅ Expected result:**
- Full ProductOffering object returned with all fields

### Step 4: Create a Party (Individual) via TMF632

```bash
curl -s -X POST \
  http://localhost:8082/tmf-api/partyManagement/v4/individual \
  -H "Content-Type: application/json" \
  -d '{
    "givenName": "Alice",
    "familyName": "Durand",
    "gender": "female",
    "status": "initialized",
    "contactMedium": [
      {
        "mediumType": "email",
        "preferred": true,
        "characteristic": {
          "emailAddress": "alice.durand@lablabee.io"
        }
      }
    ]
  }' | jq .
```

**✅ Expected result:**
- Individual resource created with a generated `id`

### Step 5: List All Registered Parties

```bash
curl -s http://localhost:8082/tmf-api/partyManagement/v4/individual | jq .
curl -s http://localhost:8082/tmf-api/partyManagement/v4/organization | jq .
```

**📸 To capture:**
- Screenshot of the individual list showing Alice Durand and the seed data entries

### Step 6: Map the Component Dependency in Action

Now trace the cross-component dependency:

```bash
# Get the Individual ID created in Step 4
INDIVIDUAL_ID="<paste your id here>"

# Reference it in a new ProductOffering (as a related party)
curl -s -X POST \
  http://localhost:8081/tmf-api/productCatalogManagement/v4/productOffering \
  -H "Content-Type: application/json" \
  -d "{
    \"name\": \"SD-WAN for Alice Durand Corp\",
    \"lifecycleStatus\": \"Active\",
    \"relatedParty\": [
      {
        \"id\": \"${INDIVIDUAL_ID}\",
        \"@referredType\": \"Individual\",
        \"role\": \"owner\"
      }
    ]
  }" | jq .
```

**💡 This demonstrates the `dependentAPI` in action:**
- `productcatalog` calls `partymanagement` (TMF632) to validate the `relatedParty` reference
- This cross-component call is **brokered by the Canvas** using the registered API paths

**📸 To capture:**
- Screenshot of the final ProductOffering JSON with the `relatedParty` array populated

---

## 🛑 Stop and Clean Up

### Stop the environment (interactive)
```bash
./stop-oda.sh
```
Choose:
- **Option 1** – Stop port-forwards only (fastest restart next time)
- **Option 2** – Delete ODA components, keep Kind cluster
- **Option 3** – Delete entire Kind cluster (full cleanup)

### Manual cleanup if needed
```bash
kind delete cluster --name oda-lab
docker system prune -f
```

---

## 📝 Useful Reference Commands

### ODA Canvas – kubectl

```bash
kubectl get components -n canvas                          # List ODA components
kubectl describe component <name> -n canvas               # Full component details
kubectl get apiv1 -n canvas -o wide                       # All registered APIs
kubectl get subscriptions -n canvas                       # Event subscriptions
kubectl logs deployment/canvas-oda-component-operator -n canvas -f   # Operator logs
kubectl get events -n canvas --sort-by='.lastTimestamp'   # Recent events
```

### TMF620 – Product Catalog API

```bash
curl http://localhost:8081/tmf-api/productCatalogManagement/v4/catalog
curl http://localhost:8081/tmf-api/productCatalogManagement/v4/productOffering
curl http://localhost:8081/tmf-api/productCatalogManagement/v4/productSpecification
curl http://localhost:8081/tmf-api/productCatalogManagement/v4/category
```

### TMF632 – Party Management API

```bash
curl http://localhost:8082/tmf-api/partyManagement/v4/individual
curl http://localhost:8082/tmf-api/partyManagement/v4/organization
```

### Kind / Docker

```bash
kind get clusters                          # List Kind clusters
kind get nodes --name oda-lab              # List nodes
docker stats                               # Live container resource usage
kubectl top nodes                          # Node CPU/memory usage
kubectl top pods -n canvas                 # Pod CPU/memory usage
```

---

## 🎓 Key Concepts to Remember

### ODA Architecture
- **ODA Component** : Independently deployable business capability exposing TMF Open APIs
- **ODA Canvas** : Kubernetes-based runtime — manages, monitors, and enforces API contracts
- **Exposed APIs** : TMF APIs a component publishes for others to consume via the Canvas
- **Dependent APIs** : TMF APIs a component requires — the Canvas resolves and routes these calls
- **Events** : Async notifications published to the Canvas event bus when resources change

### ODA Component Taxonomy
- **Core Commerce** : Product Catalog (TMF620), Product Ordering (TMF622), Billing (TMF678)
- **Production** : Service Ordering (TMF641), Service Inventory (TMF638), Resource Management (TMF639)
- **Intelligence** : AI/ML pipelines, analytics, autonomous network decision engines
- **Party & Contract** : Party Management (TMF632), Agreement (TMF651), Contract

### Important Points
1. ODA Components are **Kubernetes CRDs** — the entire component contract is declared in YAML
2. The Canvas enforces **API compliance at deploy time** — a component cannot lie about its APIs
3. `dependentAPIs` are resolved by the Canvas through **service mesh routing** — no hardcoded URLs
4. Real operator examples: **Deutsche Telekom**, **Orange**, **Vodafone** all have public ODA roadmaps
5. ODA is the **architectural bridge** between TM Forum Open APIs (what to call) and real deployments (how to deploy)

---

## 🏆 Bonus Challenges

### Bonus 1: Write Your Own ODA Component Manifest
Create a `manifests/serviceordering-component.yaml` for a fictional Service Ordering component that:
- Exposes TMF641 (Service Ordering) as its core API
- Declares TMF620 (Product Catalog) and TMF632 (Party Management) as dependentAPIs
- Publishes `ServiceOrderCreateEvent`

### Bonus 2: Map an End-to-End Flow
Draw the component interaction for: **"Customer places a 5G enterprise product order"**
→ Which components are called? In what sequence? Which TMF APIs are used?

### Bonus 3: Stress the Canvas
Scale the `productcatalog` deployment to 0 replicas, observe the Canvas status change, then scale back:
```bash
kubectl scale deployment productcatalog --replicas=0 -n canvas
kubectl get components -n canvas -w
kubectl scale deployment productcatalog --replicas=1 -n canvas
```

---

## ❓ Troubleshooting

### Pods stuck in Pending
```bash
kubectl describe pod <pod-name> -n canvas
# Look for: Insufficient memory / CPU → reduce limits in canvas-values.yaml and restart
```

### Component stays in status "In Progress"
```bash
kubectl describe component productcatalog -n canvas
# Check "Events" section at the bottom for error messages
```

### APIs return 000 / connection refused
```bash
# Port-forwards may have died — reapply
kubectl port-forward svc/productcatalog-api 8081:8080 -n canvas &
kubectl port-forward svc/partymanagement-api 8082:8080 -n canvas &
```

### Full reset
```bash
./stop-oda.sh     # option 3 – delete cluster
./start-oda.sh    # fresh start
```

---

## 📚 Additional Resources

- [TM Forum ODA Official Page](https://www.tmforum.org/oda/)
- [tmforum-oda/oda-canvas GitHub](https://github.com/tmforum-oda/oda-canvas)
- [ODA Canvas Helm Chart](https://tmforum-oda.github.io/oda-canvas/)
- [TM Forum Open API Table](https://www.tmforum.org/oda/open-apis/table/)
- [ODA Component Quickstart (official)](https://github.com/tmforum-oda/oda-canvas/blob/main/QUICKSTART.md)
- [TR290 – ODA Canvas Technical Specification](https://www.tmforum.org/resources/specification/tr290-oda-canvas-technical-specification/)

---

## ✅ Validation Checklist

- [ ] Kind cluster `oda-lab` running (`kind get clusters`)
- [ ] All Canvas pods in `Running` state (`kubectl get pods -n canvas`)
- [ ] 2 ODA Components in `Complete` status (`kubectl get components -n canvas`)
- [ ] 2+ APIs registered in Canvas (`kubectl get apiv1 -n canvas`)
- [ ] Canvas UI accessible at http://localhost:3000
- [ ] TMF620 API returns HTTP 200 (`curl localhost:8081/...`)
- [ ] TMF632 API returns HTTP 200 (`curl localhost:8082/...`)
- [ ] ProductOffering created via REST (with `id` in response)
- [ ] Individual created via TMF632
- [ ] Cross-component call (relatedParty) executed successfully
- [ ] Screenshots captured for the report

---

**🎉 Congratulations! You have completed the ODA Canvas Challenge!**
