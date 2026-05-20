#!/usr/bin/env bash
# Defender for SQL — S-SQL-01..10
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
confirm_safe

: "${SQL_USER:=mdcadmin}"
: "${SQL_PASSWORD:?Set SQL_PASSWORD env var to the lab admin password}"
DB="dbpoc"
FQDN="$SQL_SERVER.database.windows.net"

run_sql() {
  if ! have sqlcmd; then err "sqlcmd not installed"; return 1; fi
  sqlcmd -S "$FQDN" -d "$DB" -U "$SQL_USER" -P "$SQL_PASSWORD" -l 5 -Q "$1"
}

s01() { scenario_header S-SQL-01 "Classic SQL injection-ish query" T1190
  run_sql "SELECT name FROM sys.tables WHERE name = '' OR '1'='1' --';" || true
}

s02() { scenario_header S-SQL-02 "Trigger SQL syntax error" T1190
  run_sql "SELECT * FROM dbo.users WHERE name = '" 2>&1 || true
}

s03() { scenario_header S-SQL-03 "Login from unusual location (walk-through)" T1078
  warn "Switch VPN to another country and re-run a simple SELECT to baseline-bust."
  run_sql "SELECT GETDATE();" || true
}

s04() { scenario_header S-SQL-04 "Brute force" T1110
  for i in $(seq 1 30); do
    sqlcmd -S "$FQDN" -d "$DB" -U sa -P "wrong$i" -l 2 -Q "SELECT 1;" >/dev/null 2>&1 || true
  done
  ok "30 failed logins issued."
}

s05() { scenario_header S-SQL-05 "Login from suspicious IP (walk-through)" T1078
  warn "Run from a TI-listed IP for the actual signal."
  run_sql "SELECT @@VERSION;" || true
}

s06() { scenario_header S-SQL-06 "Harmful application (sqlmap user-agent)" T1190
  # No live SQL injection point — but a suspicious UA from the app tier suffices for many demos.
  if have sqlmap; then
    warn "sqlmap requires a vulnerable URL; not running without explicit target."
  else
    info "sqlmap not installed; falling back to UA simulation via curl"
    curl -s -o /dev/null -A "sqlmap/1.7.10#stable (http://sqlmap.org)" "https://${SQL_SERVER}.database.windows.net" || true
  fi
}

s07() { scenario_header S-SQL-07 "Enable xp_cmdshell (suspicious statement)" T1059
  warn "Azure SQL DB blocks this — succeeds only on SQL Server VMs."
  run_sql "EXEC sp_configure 'show advanced options', 1; RECONFIGURE; EXEC sp_configure 'xp_cmdshell', 1; RECONFIGURE;" || true
}

s08() { scenario_header S-SQL-08 "Unusual data extraction (SELECT *)" T1213
  run_sql "SELECT TOP 1000 name, object_id, type_desc FROM sys.objects;" || true
}

s09() { scenario_header S-SQL-09 "Access by unfamiliar principal" T1078
  run_sql "
    IF NOT EXISTS (SELECT 1 FROM sys.sql_logins WHERE name='appsvc_new')
      CREATE LOGIN appsvc_new WITH PASSWORD = '$SQL_PASSWORD';
    SELECT name FROM sys.sql_logins WHERE name='appsvc_new';" || true
}

s10() { scenario_header S-SQL-10 "OS command via xp_cmdshell" T1059
  warn "Will fail on Azure SQL DB — succeeds on SQL Server VM."
  run_sql "EXEC xp_cmdshell 'whoami';" || true
}

dispatch "${1:?scenario number required (01..10)}"
