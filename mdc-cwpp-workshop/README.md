# Microsoft Defender for Cloud — CWPP Workshop Kit

End-to-end material for delivering a hands-on workshop on Defender for Cloud's CWPP alert capabilities.

## Repository layout

```
mdc-cwpp-workshop/
├── README.md                           ← you are here
├── RUNBOOK.md                          ← 23-section workshop runbook (~45 KB)
├── MDC_CWPP_Workshop_Matrix.xlsx       ← 18-sheet scenario matrix + agenda + MITRE
├── slides/                             ← 33-slide PPTX workshop deck
│   └── MDC_CWPP_Workshop_Deck.pptx
├── docx/                               ← Polished Word version of the runbook
│   └── RUNBOOK.docx
├── one-pager/                          ← Single-page PDF chart (Sentinel Cartography)
│   ├── ONE-PAGER.pdf · thumbnail.png
│   └── DESIGN_PHILOSOPHY.md
├── demo-script/                        ← Recorded-demo shot-by-shot script
│   ├── DEMO_SCRIPT.md
│   └── STORYBOARD.md
├── infra/                              ← Bicep lab infrastructure (Microsoft-native)
│   └── main.bicep + 11 modules + README
├── terraform/                          ← Terraform variant (azurerm + azapi)
│   └── main.tf + 11 modules + README
├── sentinel/                           ← Sentinel content pack
│   ├── analytics-rules/                (13 YAML rules — CWPP-aligned)
│   ├── playbooks/                      (Teams notification + auto-isolate VM)
│   └── workbooks/                      (CWPP overview dashboard)
├── notebooks/                          ← 5 Jupyter notebooks for live KQL hunting
├── simulator/                          ← Attack-simulator scripts
│   ├── simulator.sh                    (master dispatch + kill-chain demo)
│   ├── plans/                          (11 per-plan scripts · 10 scenarios each)
│   └── lib/common.sh
├── scripts/
│   ├── deploy-sentinel-rules.sh        (one-shot deploy of rules/playbooks/workbook)
│   ├── export-arm.sh                   (Bicep → ARM JSON for portal upload)
│   └── arm/
│       ├── mdc-foundation.json         (portal-ready foundation ARM template)
│       ├── createUiDefinition.json     (matching custom-deploy wizard)
│       └── README.md
└── .github/
    └── workflows/                      (Bicep · Terraform · Sentinel · Notebooks · Docs CI)
```

## Quick start

```bash
# 1. Deploy the lab (pick one)
cd infra && cp parameters.example.json parameters.json && $EDITOR parameters.json
az deployment sub create --location westeurope \
  --template-file main.bicep --parameters @parameters.json

#  – or –
cd terraform && cp terraform.tfvars.example terraform.tfvars && $EDITOR terraform.tfvars
terraform init && terraform apply

# 2. Deploy Sentinel content
cd ../scripts && ./deploy-sentinel-rules.sh <sub-id> rg-mdc-pc-edge law-mdc-pc-<suffix>

# 3. Fire scenarios from a controlled jumpbox
./simulator/simulator.sh kill-chain          # demo storyline
./simulator/simulator.sh containers all      # all 10 K8s scenarios

# 4. Hunt live in Jupyter
export LAW_WORKSPACE_ID="<workspace-customer-id>"
cd notebooks && jupyter lab

# 5. Present
open slides/MDC_CWPP_Workshop_Deck.pptx

# 6. Teardown
az group list --tag env=poc-mdc --query "[].name" -o tsv | \
  xargs -I{} az group delete -n {} --yes --no-wait
```

## What's in the kit

| Deliverable | Count / detail |
|-------------|----------------|
| Runbook sections | 23 |
| Scenarios documented | **110** across 11 CWPP plans |
| Excel sheets | 18 (summary + 11 plans + MITRE + agenda + lab setup + automation + demo flow + legend) |
| Bicep modules | 12 (orchestrator + 11) |
| Terraform modules | 11 (mirror of Bicep) |
| ARM templates | 1 portal-ready foundation + full-lab export script |
| Sentinel analytics rules | 13 |
| Sentinel playbooks | 2 (Teams · auto-isolate) |
| Sentinel workbooks | 1 (CWPP overview) |
| Simulator scripts | 11 per-plan + master + kill-chain |
| Jupyter notebooks | 5 |
| GitHub Actions workflows | 5 |
| Slide deck | 33 slides · 16:9 |
| Word runbook | DOCX · 624 paragraphs · auto-TOC |
| Customer one-pager | A4 PDF · Sentinel Cartography design |
| Demo recording script | 12-min shot list + storyboard |

## Deployment paths

| Choose | When |
|--------|------|
| `scripts/arm/mdc-foundation.json` | You just want plans + LAW + Sentinel · zero Bicep/Terraform tooling needed · portal-uploadable |
| `infra/` (Bicep) | Full lab · Microsoft-native toolchain · fastest path to new RPs |
| `terraform/` | Full lab · multi-cloud team · existing TF state |

## Safety reminders

- Run **only** in an isolated PoC subscription. Several scenarios (LSASS dump, brute force, `xp_cmdshell`, prompt injection) generate real attack telemetry.
- Notify your SOC at least 24h ahead, or run in a tenant your SOC does not monitor.
- Tag every resource `env=poc-mdc` so the teardown loop catches it.
- Same-day teardown is non-negotiable. APIM Developer + AKS + Premium App Service dominate spend (~€60/day at list).

## Where to start

| Persona | Start here |
|---------|------------|
| Workshop facilitator | `slides/MDC_CWPP_Workshop_Deck.pptx` → `RUNBOOK.md` |
| Lab provisioner | `infra/README.md` or `terraform/README.md` |
| Detection engineer | `sentinel/README.md` |
| Red team / simulator | `simulator/README.md` |
| SOC analyst on the day | `notebooks/README.md` |
| Compliance / GRC | `MDC_CWPP_Workshop_Matrix.xlsx` (MITRE Coverage sheet) |
| Customer / exec pitch | `one-pager/ONE-PAGER.pdf` |
| Video producer / DevRel | `demo-script/DEMO_SCRIPT.md` |
| Reader preferring Word | `docx/RUNBOOK.docx` |
