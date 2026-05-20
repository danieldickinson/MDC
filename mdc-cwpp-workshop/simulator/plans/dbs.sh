#!/usr/bin/env bash
# Defender for OSS DBs & Cosmos — S-DB-01..10
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
confirm_safe

: "${DB_ADMIN:=mdcadmin}"
: "${DB_PASSWORD:?Set DB_PASSWORD to the lab admin password}"

PG_FQDN=$(az postgres flexible-server list -g "$RG_DATA" --query "[0].fullyQualifiedDomainName" -o tsv 2>/dev/null || echo "")
MYSQL_FQDN=$(az mysql flexible-server list -g "$RG_DATA" --query "[0].fullyQualifiedDomainName" -o tsv 2>/dev/null || echo "")
COSMOS_ACC=$(az cosmosdb list -g "$RG_DATA" --query "[0].name" -o tsv 2>/dev/null || echo "")

s01() { scenario_header S-DB-01 "PG brute force" T1110
  [[ -z "$PG_FQDN" ]] && { err "No PG server discovered"; return 1; }
  for p in $(seq 1 30); do
    PGPASSWORD="bad$p" psql "host=$PG_FQDN user=$DB_ADMIN dbname=postgres sslmode=require" -c "select 1" >/dev/null 2>&1 || true
  done
  ok "30 failed PG logins issued."
}

s02() { scenario_header S-DB-02 "MySQL via Tor (walk-through)" T1090.003
  info "Run 'torsocks mysql -h $MYSQL_FQDN -u $DB_ADMIN -p' from a clean VM."
}

s03() { scenario_header S-DB-03 "PG from suspicious IP (walk-through)" T1078
  info "Connect from a TI-listed VM IP."
}

s04() { scenario_header S-DB-04 "Login from unusual location (walk-through)" T1078
  info "Connect from a new-country egress to baseline-bust."
}

s05() { scenario_header S-DB-05 "Cosmos mass reads" T1567
  [[ -z "$COSMOS_ACC" ]] && { err "No Cosmos account discovered"; return 1; }
  local ep; ep=$(az cosmosdb show -n "$COSMOS_ACC" -g "$RG_DATA" --query documentEndpoint -o tsv)
  local key; key=$(az cosmosdb keys list -n "$COSMOS_ACC" -g "$RG_DATA" --query primaryMasterKey -o tsv)
  warn "Burst REST reads to surface anomaly; sending 200 calls."
  for i in $(seq 1 200); do
    curl -sk "${ep}dbs/db1/colls/c1/docs" \
         -H "x-ms-version: 2018-12-31" \
         -H "x-ms-date: $(date -u +%a, %d %b %Y %H:%M:%S GMT)" >/dev/null || true
  done
  ok "Burst reads issued."
}

s06() { scenario_header S-DB-06 "Cosmos key regeneration" T1098
  [[ -z "$COSMOS_ACC" ]] && return 1
  az cosmosdb keys regenerate -n "$COSMOS_ACC" -g "$RG_DATA" --key-kind primary >/dev/null
  ok "Primary key regenerated."
}

s07() { scenario_header S-DB-07 "PG privileged user (rejected on managed PG)" T1136
  [[ -z "$PG_FQDN" ]] && return 1
  PGPASSWORD="$DB_PASSWORD" psql "host=$PG_FQDN user=$DB_ADMIN dbname=postgres sslmode=require" \
    -c "CREATE ROLE pwn LOGIN PASSWORD 'P@ss' SUPERUSER;" 2>&1 | head -3 || true
}

s08() { scenario_header S-DB-08 "MySQL bulk dump" T1567
  [[ -z "$MYSQL_FQDN" ]] && return 1
  local out; out=$(mktemp)
  mysqldump -h "$MYSQL_FQDN" -u "$DB_ADMIN" -p"$DB_PASSWORD" --all-databases --ssl-mode=REQUIRED > "$out" 2>/dev/null || true
  rm -f "$out"
  ok "mysqldump issued."
}

s09() { scenario_header S-DB-09 "Dangerous extension (rejected on managed PG)" T1059
  [[ -z "$PG_FQDN" ]] && return 1
  PGPASSWORD="$DB_PASSWORD" psql "host=$PG_FQDN user=$DB_ADMIN dbname=postgres sslmode=require" \
    -c "CREATE EXTENSION plperlu;" 2>&1 | head -3 || true
}

s10() { scenario_header S-DB-10 "Cosmos: custom-UA enumeration" T1526
  [[ -z "$COSMOS_ACC" ]] && return 1
  local ep; ep=$(az cosmosdb show -n "$COSMOS_ACC" -g "$RG_DATA" --query documentEndpoint -o tsv)
  for i in $(seq 1 30); do
    curl -sk -A "pwn/1.0" "${ep}dbs" -H "x-ms-version: 2018-12-31" >/dev/null || true
  done
  ok "Enumeration with custom UA done."
}

dispatch "${1:?scenario number required (01..10)}"
