#!/usr/bin/env bash
# Defender for APIs — S-API-01..10
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
confirm_safe

APIM=$(az apim list -g "$RG_APPS" --query "[0].name" -o tsv 2>/dev/null || echo "")
[[ -n "$APIM" ]] || { err "No APIM service found in $RG_APPS"; exit 1; }
APIM_URL="https://${APIM}.azure-api.net"

s01() { scenario_header S-API-01 "Sensitive data exposure (synthetic)" T1213
  warn "Walk-through — patch the petstore backend to return mocked SSN/PAN."
}

s02() { scenario_header S-API-02 "Unauth call to sensitive endpoint" T1190
  curl -s -o /dev/null -w "%{http_code}\n" "${APIM_URL}/petstore/v2/user/login?username=admin&password=admin" || true
}

s03() { scenario_header S-API-03 "Suspicious user-agent" T1046
  curl -s -o /dev/null -w "%{http_code}\n" -A "sqlmap/1.7.10 (http://sqlmap.org)" "${APIM_URL}/petstore/v2/pet/1" || true
  curl -s -o /dev/null -w "%{http_code}\n" -A "nikto/2.5.0" "${APIM_URL}/petstore/v2/pet/2" || true
}

s04() { scenario_header S-API-04 "Tor access" T1090.003
  if have torsocks; then
    torsocks curl -s -o /dev/null -w "%{http_code}\n" "${APIM_URL}/petstore/v2/pet/1" || true
  else
    warn "torsocks not installed."
  fi
}

s05() { scenario_header S-API-05 "Suspicious IP (walk-through)" T1078
  info "Run curl from a TI-listed VM IP."
}

s06() { scenario_header S-API-06 "BOLA / IDOR enumeration" T1087
  for id in $(seq 1 500); do
    curl -s -o /dev/null -w "" "${APIM_URL}/petstore/v2/pet/$id" || true
  done
  ok "Enumerated /pet/1..500."
}

s07() { scenario_header S-API-07 "Auth failure spike" T1110
  for i in $(seq 1 200); do
    curl -s -o /dev/null -w "" -H "Ocp-Apim-Subscription-Key: invalid$i" "${APIM_URL}/petstore/v2/pet/1" || true
  done
  ok "200 unauthenticated calls."
}

s08() { scenario_header S-API-08 "Path fuzzing" T1046
  for p in admin login backup .env wp-login .git/config phpinfo phpMyAdmin server-status \
           api/v1/users api/v1/admin api/v2/admin debug actuator config users.json users.csv; do
    curl -s -o /dev/null -w "" "${APIM_URL}/petstore/v2/$p" || true
  done
  ok "Fuzzed APIM paths."
}

s09() { scenario_header S-API-09 "Hit deprecated endpoint (walk-through)" T1526
  info "Call an undocumented route flagged as 'shadow' in API inventory."
}

s10() { scenario_header S-API-10 "Subscription key multi-geo (walk-through)" T1078
  info "Use the same Ocp-Apim-Subscription-Key from US/EU/APAC egresses within minutes."
}

dispatch "${1:?scenario number required (01..10)}"
