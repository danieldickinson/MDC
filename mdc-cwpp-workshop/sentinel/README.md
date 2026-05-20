# Sentinel Content Pack — CWPP

Companion analytics rules, playbooks and workbook for the runbook scenarios.

## Contents

| Path | Purpose |
|------|---------|
| `analytics-rules/01-mdc-high-severity-alerts.yaml` | Surfaces all High/Critical MDC alerts grouped by entity |
| `analytics-rules/02-eicar-test-file.yaml` | Validation rule — fires on EICAR detections (S-SRV-01, S-STO-01) |
| `analytics-rules/03-suspicious-powershell.yaml` | Encoded PowerShell on protected hosts (S-SRV-02) |
| `analytics-rules/04-lsass-access.yaml` | LSASS credential dumping (S-SRV-03) |
| `analytics-rules/05-aks-privileged-pod.yaml` | Privileged pod / hostPath in AKS (S-K8S-01/02) |
| `analytics-rules/06-storage-tor-or-anon.yaml` | Storage anonymous or Tor/TI access (S-STO-02/03/04) |
| `analytics-rules/07-sql-injection.yaml` | SQL injection payloads / xp_cmdshell (S-SQL-01/07/10) |
| `analytics-rules/08-keyvault-mass-secret-access.yaml` | Mass secret enumeration (S-KV-01) |
| `analytics-rules/09-arm-suspicious-ops.yaml` | Bulk delete / wildcard role / SP cred add (S-ARM-04/06/08/10) |
| `analytics-rules/10-dns-tunneling-or-dga.yaml` | DNS tunneling / DGA (S-DNS-01/02) |
| `analytics-rules/11-api-bola-enumeration.yaml` | BOLA / IDOR pattern (S-API-06) |
| `analytics-rules/12-ai-prompt-injection.yaml` | Defender for AI signals (S-AI-01..05) |
| `analytics-rules/13-cross-plan-kill-chain.yaml` | Same identity firing across multiple CWPP plans |
| `playbooks/post-alert-to-teams.json` | Logic App: post Sentinel incident to a Teams channel |
| `playbooks/isolate-vm-on-mde-alert.json` | Logic App: call MDE isolateMachine API for Host entities |
| `workbooks/cwpp-overview.json` | Workbook: alerts by severity / plan / tactic over time |

## Deploy

### One-shot script

```bash
# Resource group must already host the Log Analytics workspace + Sentinel
./scripts/deploy-sentinel-rules.sh <subscription-id> <rg-name> <law-name>
```

Requires:
- `az` CLI logged in with Owner / Sentinel Contributor on the workspace.
- `python3` with PyYAML (`pip install pyyaml`) **or** `yq` (`brew install yq`).

### Manual

For each YAML rule, convert to ARM payload and PUT to:

```
PUT /subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.OperationalInsights/workspaces/{ws}/providers/Microsoft.SecurityInsights/alertRules/{guid}?api-version=2023-11-01
```

For playbooks:

```bash
az deployment group create -g <rg> --template-file sentinel/playbooks/post-alert-to-teams.json
```

After deploying the Teams playbook:
1. In Azure Portal → Logic Apps → `cwpp-post-to-teams` → API connections → authorize the Teams connection.
2. Replace `REPLACE-WITH-TEAMS-GROUP-ID` and `REPLACE-WITH-TEAMS-CHANNEL-ID` in the workflow with your IDs (get them from Teams channel URL).
3. Sentinel → Automation → Add → Trigger: When incident is created → Action: Run playbook → `cwpp-post-to-teams`.

## Mapping rules → scenarios

```
S-SRV-01, S-STO-01           → analytics-rules/02-eicar-test-file.yaml
S-SRV-02                     → analytics-rules/03-suspicious-powershell.yaml
S-SRV-03                     → analytics-rules/04-lsass-access.yaml
S-K8S-01, S-K8S-02           → analytics-rules/05-aks-privileged-pod.yaml
S-STO-02, S-STO-03, S-STO-04 → analytics-rules/06-storage-tor-or-anon.yaml
S-SQL-01, S-SQL-07, S-SQL-10 → analytics-rules/07-sql-injection.yaml
S-KV-01, S-KV-04             → analytics-rules/08-keyvault-mass-secret-access.yaml
S-ARM-04, S-ARM-06, S-ARM-08,
S-ARM-10                     → analytics-rules/09-arm-suspicious-ops.yaml
S-DNS-01, S-DNS-02, S-DNS-08 → analytics-rules/10-dns-tunneling-or-dga.yaml
S-API-06                     → analytics-rules/11-api-bola-enumeration.yaml
S-AI-01..S-AI-05             → analytics-rules/12-ai-prompt-injection.yaml
(any cross-plan combo)       → analytics-rules/13-cross-plan-kill-chain.yaml
+ every High/Critical alert  → analytics-rules/01-mdc-high-severity-alerts.yaml
```

## Tuning notes

- All rules use a 15–30 minute query period. For demos, that's tight enough to fire during the live session; for prod, increase to 1h and add suppression.
- Thresholds (e.g. 20 secrets in KV rule, 50 BOLA hits) are workshop-friendly. Tune up for prod.
- Cross-plan rule (#13) requires at least 2 hours of alert data on a single identity — run the demo flow end-to-end first.
- Storage rule (#06) requires `StorageBlobLogs` diagnostic setting on the storage account → LAW. Bicep enables this implicitly via Defender for Storage.

## Decommission

```bash
WS_ID=$(az monitor log-analytics workspace show -g <rg> -n <ws> --query id -o tsv)
for ID in 01 02 03 04 05 06 07 08 09 10 11 12 13; do
  RULE_GUID="7a9a3f9c-8c40-4e9f-9b3d-1a2b3c4d5e${ID}"
  az rest --method delete \
    --url "https://management.azure.com${WS_ID}/providers/Microsoft.SecurityInsights/alertRules/${RULE_GUID}?api-version=2023-11-01" || true
done
```
