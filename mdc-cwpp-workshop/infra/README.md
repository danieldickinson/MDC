# Bicep Lab Infrastructure

End-to-end deployment of all CWPP workloads for the workshop.

## What this deploys

| Resource Group | Resources |
|----------------|-----------|
| `rg-mdc-<env>-edge` | Log Analytics workspace, Sentinel, Key Vault, MDC connector |
| `rg-mdc-<env>-servers` | Windows + Linux VM (MDE auto-enrolled), AKS cluster with Defender profile, VNet, NSG |
| `rg-mdc-<env>-data` | Storage account (Defender for Storage v2 + malware scanning), Azure SQL DB, PostgreSQL flexible, MySQL flexible, Cosmos DB |
| `rg-mdc-<env>-apps` | App Service Plan + Linux web app, APIM Developer tier with Petstore API, Azure OpenAI with gpt-4o-mini |
| (subscription scope) | All 13 MDC pricing plans set to Standard with their highest sub-plan |

## Cost notice

A 4–8h workshop costs roughly **€40–€80** at list pricing (APIM Developer + AKS + Premium App Service are the main drivers). **Destroy after use.**

## Prerequisites

```bash
az --version           # >= 2.60
az bicep version       # >= 0.30
az account show
az account set --subscription <PoC-sub-id>
```

The deploying principal needs **Owner** at the subscription scope (to enable MDC plans and create RBAC custom roles in some labs).

## Deploy

```bash
cp infra/parameters.example.json infra/parameters.json
# Edit infra/parameters.json — set adminPassword and allowedSourceCidr to your egress IP /32

az deployment sub create \
  --name mdc-cwpp-workshop-$(date +%s) \
  --location westeurope \
  --template-file infra/main.bicep \
  --parameters @infra/parameters.json
```

Deployment takes ~25 minutes (APIM Developer takes the longest — ~20 min).

## Validate

```bash
# All MDC plans should show 'Standard'
az security pricing list -o table

# Sentinel data connector should be 'Enabled'
SUB=$(az account show --query id -o tsv)
RG=rg-mdc-pc-edge
LAW=$(az monitor log-analytics workspace list -g $RG --query "[0].name" -o tsv)
az sentinel data-connector list \
  --resource-group $RG \
  --workspace-name $LAW -o table 2>/dev/null || \
  az rest --method get \
    --url "https://management.azure.com/subscriptions/$SUB/resourceGroups/$RG/providers/Microsoft.OperationalInsights/workspaces/$LAW/providers/Microsoft.SecurityInsights/dataConnectors?api-version=2023-11-01"
```

## Tear down

```bash
az group list --tag env=poc-mdc --query "[].name" -o tsv | \
  xargs -I{} az group delete -n {} --yes --no-wait

# Optionally downgrade MDC plans
for PLAN in VirtualMachines Containers StorageAccounts SqlServers SqlServerVirtualMachines AppServices KeyVaults Arm Dns OpenSourceRelationalDatabases CosmosDbs Api AI; do
  az security pricing create --name "$PLAN" --tier "Free"
done
```

## Module layout

```
infra/
├── main.bicep                  # Orchestrator (subscription scope)
├── parameters.example.json
└── modules/
    ├── monitoring.bicep        # LAW + Sentinel + MDC connector
    ├── mdc-plans.bicep         # Enable all CWPP plans
    ├── servers.bicep           # VNet, NSG, Windows + Linux VMs with MDE
    ├── containers.bicep        # AKS with Defender profile
    ├── storage.bicep           # Storage + Malware scanning
    ├── sql.bicep               # SQL Server + DB + Auditing
    ├── appservice.bicep        # App Service Plan + Linux site
    ├── keyvault.bicep          # Key Vault + 3 demo secrets
    ├── databases.bicep         # PG + MySQL + Cosmos
    ├── apim.bicep              # APIM Developer + Petstore API
    └── openai.bicep            # Azure OpenAI + gpt-4o-mini
```

## Known caveats

- **Azure OpenAI capacity**: gpt-4o-mini may be region-constrained. If `westeurope` fails on the OpenAI module, redeploy `openai.bicep` separately into `swedencentral` or `eastus`.
- **APIM Developer SKU**: ~20 min to provision; SLA-less, do not use in prod.
- **Allowing 0.0.0.0/0**: the example permits everything for ease of demos — restrict before sharing the environment.
- **Public network access**: every resource is intentionally public-facing so attendees can hit them from laptops. This is **not** a hardened baseline.
