# ARM template artefacts

This folder hosts portal-ready ARM JSON. Two flavours:

## 1. `mdc-foundation.json` — minimal, self-contained

Subscription-scope ARM template that:

- Enables **all 13 CWPP plans** (Standard tier, highest sub-plan).
- Creates a **Log Analytics workspace** + onboards **Microsoft Sentinel**.
- Wires the MDC default workspace setting + auto-provisioning.

It has **no Bicep dependency** — you can upload this JSON directly to the portal.

### Deploy from the Azure Portal

1. Portal → search for **"Deploy a custom template"**.
2. Click **Build your own template in the editor**.
3. Paste `mdc-foundation.json` → Save.
4. Pick **Subscription** as the scope. Region → your choice. Fill `envTag` (e.g. `pc`).
5. Review + create.

### Deploy from CLI

```bash
SUB=$(az account show --query id -o tsv)
az deployment sub create \
  --name mdc-foundation-$(date +%s) \
  --location westeurope \
  --template-file scripts/arm/mdc-foundation.json \
  --parameters envTag=pc
```

### Deploy via "Deploy to Azure" button

After publishing this folder to a public URL (raw GitHub, blob storage with anon access, etc.):

```markdown
[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/<URL-encoded raw URL to mdc-foundation.json>/createUIDefinitionUri/<URL-encoded raw URL to createUiDefinition.json>)
```

`createUiDefinition.json` in this folder is the matching Custom Deployment wizard (single field: `envTag`).

## 2. `../export-arm.sh` — full lab ARM export

For the **full lab** (VMs, AKS, Storage, SQL, App Service, Key Vault, DBs, APIM, OpenAI) run:

```bash
./scripts/export-arm.sh
```

That compiles every Bicep module in `infra/` into `dist/arm/*.json`, plus a `createUiDefinition.json` and a `deploy-button.md` snippet ready to paste into your repo's README.

The full lab requires the Bicep CLI (`az bicep install`) — but the **foundation** ARM template above is portal-deployable with no CLI.

## When to use which

| Need | Use |
|------|-----|
| Just enable plans + workspace + Sentinel; deploy workloads later by hand | `mdc-foundation.json` |
| Stand up the whole lab end-to-end for a workshop | `infra/main.bicep` (Bicep) or `terraform/` |
| Mirror the Bicep lab to a portal-friendly ARM artefact | `scripts/export-arm.sh` → `dist/arm/main.json` |

## Idempotency

`mdc-foundation.json` is fully idempotent: redeploying does not duplicate plans, workspaces, or solutions. Names default to a hash of the subscription ID, so it's safe to redeploy from multiple parallel workshops.
