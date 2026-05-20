# Terraform Lab Infrastructure

Terraform equivalent of [`../infra/`](../infra/) (Bicep). Deploys the same set of resources to a PoC subscription.

## Prerequisites

```bash
terraform -version    # >= 1.7
az login
az account set --subscription <PoC-sub-id>
```

The deploying principal needs **Owner** at subscription scope.

## Deploy

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars — set admin_password and allowed_source_cidr

terraform init
terraform plan  -out plan.tfplan
terraform apply plan.tfplan
```

Approximate runtime: ~25 minutes (APIM Developer dominates).

## State backend

For workshop use the default local state is fine. For team / repeated use, configure a remote backend (Azure Storage):

```hcl
# backend.tf
terraform {
  backend "azurerm" {
    resource_group_name  = "rg-tfstate"
    storage_account_name = "tfstateXXXX"
    container_name       = "tfstate"
    key                  = "mdc-cwpp.tfstate"
  }
}
```

## Module layout

```
terraform/
├── versions.tf
├── variables.tf
├── main.tf
├── outputs.tf
├── terraform.tfvars.example
└── modules/
    ├── monitoring/     (LAW + Sentinel + MDC connector via AzAPI)
    ├── mdc-plans/      (all 13 CWPP plans Standard)
    ├── servers/        (VNet + NSG + Win/Linux VMs + MDE)
    ├── containers/     (AKS + Defender profile)
    ├── storage/        (Storage v2 + malware scanning via AzAPI)
    ├── sql/            (Server + DB + auditing)
    ├── appservice/     (Linux App Service Plan + site)
    ├── keyvault/       (Vault + 3 demo secrets)
    ├── databases/      (PG + MySQL + Cosmos)
    ├── apim/           (APIM Developer + Petstore)
    └── openai/         (Azure OpenAI + gpt-4o-mini)
```

## Notes

- The `azapi` provider is used for two resources not yet first-class in `azurerm`:
  - `Microsoft.SecurityInsights/onboardingStates` (Sentinel onboarding)
  - `Microsoft.Security/defenderForStorageSettings` (per-account Defender for Storage v2 + malware scanning + sensitive-data discovery)
- This mirrors the Bicep deployment's resource layout 1:1 — outputs are named identically (snake_case here vs camelCase in Bicep).
- `terraform destroy` cleans everything; KV may need `purge_protection` set to `false` first if you need to fully purge soft-deleted vaults.

## Choose Bicep or Terraform?

| Choose Bicep | Choose Terraform |
|--------------|------------------|
| Azure-only environment | Multi-cloud or already on Terraform |
| Microsoft-first toolchain | Existing TF state + modules |
| Faster to GA for new Azure RPs | Better policy-as-code ecosystem (Sentinel, OPA) |

The runbook, Sentinel rules, and Excel matrix are agnostic to either choice.
