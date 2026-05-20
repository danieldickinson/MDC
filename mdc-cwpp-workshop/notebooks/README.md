# KQL Hunting Notebooks

Companion notebooks for the workshop. Each one runs KQL against your Log Analytics workspace and renders the results as a pandas DataFrame (with a chart where it's useful).

## Notebooks

| # | File | Use when |
|---|------|----------|
| 01 | `01-cwpp-alerts-overview.ipynb` | Daily standup, demo wrap-up, dashboard. |
| 02 | `02-kill-chain-investigation.ipynb` | A specific identity is suspect — reconstruct what they touched across plans. |
| 03 | `03-storage-anomaly-hunt.ipynb` | Defender for Storage alerts; finds anonymous / Tor / mass-read / mass-delete patterns. |
| 04 | `04-aks-audit-hunt.ipynb` | Defender for Containers; privileged pods, hostPath mounts, exec, cluster-admin bindings. |
| 05 | `05-keyvault-mass-access.ipynb` | Defender for Key Vault; mass enumeration, denied spikes, policy-change-then-read. |

## Setup

```bash
# (recommended) create a venv
python3 -m venv .venv && source .venv/bin/activate

pip install azure-identity azure-monitor-query pandas matplotlib jupyter

# Set the workspace customer ID (NOT the ARM resource id — the GUID)
export LAW_WORKSPACE_ID="<workspace-customer-id-guid>"

# Authenticate any way DefaultAzureCredential can pick up:
az login
# - or -
# export AZURE_CLIENT_ID, AZURE_CLIENT_SECRET, AZURE_TENANT_ID

jupyter lab
```

## Permissions the calling principal needs

- **Log Analytics Reader** on the workspace (read queries).
- If `AzureActivity`, `SigninLogs`, `KeyVaultData`, `StorageBlobLogs`, `AzureDiagnostics` aren't all in the workspace, the corresponding cells will return empty DataFrames — verify diagnostic settings.

## Tips

- Each notebook starts with a "Shared setup" cell — run it once at the top.
- Adjust `hours=` in calls to `kql()` to widen the lookback window. The function pushes the timespan to the API, which is cheaper than `where TimeGenerated > ago(...)` inside the query.
- Notebooks default to the last **24 hours**. Anomaly-based MDC alerts can take longer to baseline; for early-PoC investigation, bump to 7 days.
- Notebook 02 (kill chain) expects a single `SUSPECT` string — UPN, app ID, or object-id substring. The query uses `has` so partial matches work.

## CI

`.github/workflows/notebooks.yml` validates `nbformat`, runs `nbqa flake8` (relaxed) and gates PRs touching `notebooks/**`.
