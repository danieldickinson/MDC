#!/usr/bin/env bash
# Compile Bicep main + modules to ARM JSON for portal upload / GitOps mirroring.
# Output goes to dist/arm/.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$REPO_DIR/dist/arm"
mkdir -p "$OUT"

command -v az >/dev/null || { echo "Azure CLI required"; exit 1; }
command -v bicep >/dev/null 2>&1 || az bicep install >/dev/null

echo "==> Compiling main.bicep → ARM JSON"
az bicep build --file "$REPO_DIR/infra/main.bicep" --outfile "$OUT/main.json"

echo "==> Compiling each module separately (for inspection / reuse)"
for f in "$REPO_DIR/infra/modules/"*.bicep; do
  name=$(basename "$f" .bicep)
  az bicep build --file "$f" --outfile "$OUT/$name.json"
  echo "   - $name.json"
done

echo
echo "==> Generating createUiDefinition.json (portal Custom Deploy wizard)"
cat > "$OUT/createUiDefinition.json" <<'EOF'
{
  "$schema": "https://schema.management.azure.com/schemas/0.1.2-preview/CreateUIDefinition.MultiVm.json#",
  "handler": "Microsoft.Azure.CreateUIDef",
  "version": "0.1.2-preview",
  "parameters": {
    "config": { "isWizard": false, "basics": { "description": "MDC CWPP Workshop lab" } },
    "basics": [
      {
        "name": "envTag",
        "type": "Microsoft.Common.TextBox",
        "label": "Env tag (2 letters)",
        "defaultValue": "pc",
        "constraints": { "required": true, "regex": "^[a-z]{2}$", "validationMessage": "Two lowercase letters." }
      },
      {
        "name": "adminUsername",
        "type": "Microsoft.Common.TextBox",
        "label": "VM admin username",
        "defaultValue": "mdcadmin",
        "constraints": { "required": true, "regex": "^[a-z][a-z0-9]{2,15}$" }
      },
      {
        "name": "adminPassword",
        "type": "Microsoft.Common.PasswordBox",
        "label": { "password": "Admin password", "confirmPassword": "Confirm password" },
        "constraints": { "required": true, "regex": "^.{12,}$", "validationMessage": "Min 12 chars." }
      },
      {
        "name": "allowedSourceCidr",
        "type": "Microsoft.Common.TextBox",
        "label": "Allowed source CIDR (your egress IP/32)",
        "defaultValue": "0.0.0.0/0"
      }
    ],
    "steps": [],
    "outputs": {
      "envTag":            "[basics('envTag')]",
      "adminUsername":     "[basics('adminUsername')]",
      "adminPassword":     "[basics('adminPassword')]",
      "allowedSourceCidr": "[basics('allowedSourceCidr')]",
      "location":          "[location()]"
    }
  }
}
EOF

echo
echo "==> Writing deploy-button.md"
SUB_ENC='%2Fsubscriptions%2F%3CSUBSCRIPTION-ID%3E'
TEMPLATE_URL_HINT='https://raw.githubusercontent.com/<owner>/<repo>/main/dist/arm/main.json'
UI_URL_HINT='https://raw.githubusercontent.com/<owner>/<repo>/main/dist/arm/createUiDefinition.json'

cat > "$OUT/deploy-button.md" <<EOF
# Deploy to Azure

After publishing \`dist/arm/main.json\` and \`dist/arm/createUiDefinition.json\` to a public URL (raw GitHub, Azure Storage with anonymous access, etc.), update the placeholder URLs and use:

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/$(printf %s "$TEMPLATE_URL_HINT" | python3 -c "import sys,urllib.parse; print(urllib.parse.quote(sys.stdin.read().strip(), safe=''))")/createUIDefinitionUri/$(printf %s "$UI_URL_HINT" | python3 -c "import sys,urllib.parse; print(urllib.parse.quote(sys.stdin.read().strip(), safe=''))"))

[![Visualize](https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/visualizebutton.svg?sanitize=true)](http://armviz.io/#/?load=$(printf %s "$TEMPLATE_URL_HINT" | python3 -c "import sys,urllib.parse; print(urllib.parse.quote(sys.stdin.read().strip(), safe=''))"))

> Subscription-scoped deployment — the deployer must have Owner + Security Admin.
EOF

ls -la "$OUT"
echo "Done. Artefacts written to $OUT"
