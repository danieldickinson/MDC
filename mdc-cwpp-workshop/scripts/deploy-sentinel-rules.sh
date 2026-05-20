#!/usr/bin/env bash
# Deploy all CWPP analytics rules + playbooks to Sentinel.
# Usage:
#   ./deploy-sentinel-rules.sh <subscription-id> <resource-group> <workspace-name>
set -euo pipefail

SUB="${1:?subscription-id required}"
RG="${2:?resource-group required}"
WS="${3:?workspace-name required}"

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RULES_DIR="$REPO_DIR/sentinel/analytics-rules"
PLAYBOOK_DIR="$REPO_DIR/sentinel/playbooks"
WORKBOOK_DIR="$REPO_DIR/sentinel/workbooks"

az account set --subscription "$SUB"

WS_ID=$(az monitor log-analytics workspace show -g "$RG" -n "$WS" --query id -o tsv)
LOCATION=$(az group show -n "$RG" --query location -o tsv)

echo "==> Deploying analytics rules"
shopt -s nullglob

# Convert YAML to JSON inline using python (PyYAML usually available; falls back to yq)
yaml_to_json() {
  local f="$1"
  python3 -c "import sys,yaml,json; print(json.dumps(yaml.safe_load(open(sys.argv[1]))))" "$f" \
    || yq -o json '.' "$f"
}

for f in "$RULES_DIR"/*.yaml; do
  RULE_JSON=$(yaml_to_json "$f")
  RULE_ID=$(echo "$RULE_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])")
  RULE_NAME=$(echo "$RULE_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['name'])")
  echo "   - $RULE_NAME ($RULE_ID)"

  # Build ARM payload
  PROPS=$(echo "$RULE_JSON" | python3 -c "
import sys, json
r = json.load(sys.stdin)
props = {
  'displayName': r['name'],
  'description': r.get('description',''),
  'severity': r.get('severity','Medium'),
  'enabled': True,
  'kind': r.get('kind','Scheduled'),
  'query': r['query'],
  'queryFrequency': r.get('queryFrequency','PT15M' if r.get('queryFrequency','15m').endswith('m') else r['queryFrequency']),
  'queryPeriod': r.get('queryPeriod','PT1H'),
  'triggerOperator': r.get('triggerOperator','GreaterThan'),
  'triggerThreshold': r.get('triggerThreshold',0),
  'suppressionDuration': r.get('suppressionDuration','PT1H'),
  'suppressionEnabled': r.get('suppressionEnabled', False),
  'tactics': r.get('tactics', []),
  'techniques': r.get('relevantTechniques', []),
  'incidentConfiguration': r.get('incidentConfiguration', {'createIncident': True}),
  'entityMappings': r.get('entityMappings', []),
  'eventGroupingSettings': r.get('eventGroupingSettings', {'aggregationKind':'SingleAlert'}),
}
# Convert e.g. '15m' -> 'PT15M', '1h' -> 'PT1H'
def iso(d):
  if isinstance(d,str) and d[-1] in 'mh' and d[:-1].isdigit():
    return 'PT' + d[:-1] + d[-1].upper()
  return d
props['queryFrequency'] = iso(props['queryFrequency'])
props['queryPeriod']    = iso(props['queryPeriod'])
props['suppressionDuration'] = iso(props['suppressionDuration'])
print(json.dumps({'kind': r.get('kind','Scheduled'), 'properties': props}))
")

  az rest --method put \
    --url "https://management.azure.com${WS_ID}/providers/Microsoft.SecurityInsights/alertRules/${RULE_ID}?api-version=2023-11-01" \
    --headers "Content-Type=application/json" \
    --body "$PROPS" >/dev/null
done

echo "==> Deploying playbooks"
for pb in "$PLAYBOOK_DIR"/*.json; do
  PB_NAME=$(basename "$pb" .json)
  echo "   - $PB_NAME"
  az deployment group create \
    --resource-group "$RG" \
    --name "playbook-$PB_NAME-$(date +%s)" \
    --template-file "$pb" >/dev/null
done

echo "==> Deploying workbook"
WB_FILE="$WORKBOOK_DIR/cwpp-overview.json"
WB_GUID=$(uuidgen | tr A-Z a-z)
WB_PAYLOAD=$(python3 -c "
import json,sys
with open('$WB_FILE') as f: j=f.read()
print(json.dumps({
  'location':'$LOCATION',
  'kind':'shared',
  'properties':{
    'displayName':'MDC CWPP Overview',
    'serializedData': j,
    'category':'sentinel',
    'sourceId':'$WS_ID',
    'version':'1.0'
  }
}))
")
az rest --method put \
  --url "https://management.azure.com/subscriptions/${SUB}/resourceGroups/${RG}/providers/Microsoft.Insights/workbooks/${WB_GUID}?api-version=2023-06-01" \
  --headers "Content-Type=application/json" \
  --body "$WB_PAYLOAD" >/dev/null

echo "Done."
echo "Open Sentinel → Analytics → Active rules to verify."
