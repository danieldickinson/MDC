# Attack Simulator

Bash scripts that fire the 110 scenarios from the runbook against the lab deployed by `infra/` or `terraform/`.

> ⚠️ **Run only from a controlled jumpbox in the PoC subscription.** The simulator refuses to run if `ENV_TAG != pc` or if the subscription name doesn't include `poc`/`PoC`/`sandbox` (override with `FORCE_UNSAFE=1` if you know what you're doing).

## Quick start

```bash
# Pre-flight
az login
az account set --subscription <PoC-sub-id>

# List everything
./simulator/simulator.sh list

# Run a single scenario
./simulator/simulator.sh servers 01      # EICAR drop
./simulator/simulator.sh containers 04   # crypto-miner image

# Run all scenarios in a plan
./simulator/simulator.sh keyvault all

# Demo storyline — 10-scenario kill chain
./simulator/simulator.sh kill-chain
```

## Required environment

| Var | Purpose | Default |
|-----|---------|---------|
| `ENV_TAG`        | env suffix used in lab resource names | `pc` |
| `LOCATION`       | Azure region | `westeurope` |
| `RG_*`           | resource group names | derived from `ENV_TAG` |
| `WIN_VM` / `LIN_VM` | VM names | `vm-win-mdc` / `vm-lin-mdc` |
| `SQL_PASSWORD`   | sqlcmd password (`sql.sh`) | — required |
| `DB_PASSWORD`    | PG/MySQL password (`dbs.sh`) | — required |

All other lab resource names (AKS, Storage account, Key Vault, etc.) are auto-discovered via `az` CLI.

## Required tools

| Tool | Used by |
|------|---------|
| `az` (Azure CLI) | every plan |
| `kubectl` | `containers.sh` |
| `sqlcmd` | `sql.sh` |
| `psql`, `mysqldump` | `dbs.sh` |
| `jq` | `ai.sh` |
| `python3` | `ai.sh` (Unicode payload) |
| `curl` | most plans |
| `torsocks` (optional) | Tor-themed scenarios — walk-through if missing |
| `hydra`, `sqlmap`, `azcopy` (optional) | high-fidelity variants — falls back to scripted loops |

## Scenarios

Each plan script implements 10 functions `s01..s10` matching the runbook IDs:

```
servers.sh       S-SRV-01 .. S-SRV-10
containers.sh    S-K8S-01 .. S-K8S-10
storage.sh       S-STO-01 .. S-STO-10
sql.sh           S-SQL-01 .. S-SQL-10
appservice.sh    S-APP-01 .. S-APP-10
keyvault.sh      S-KV-01  .. S-KV-10
arm.sh           S-ARM-01 .. S-ARM-10
dns.sh           S-DNS-01 .. S-DNS-10
dbs.sh           S-DB-01  .. S-DB-10
apis.sh          S-API-01 .. S-API-10
ai.sh            S-AI-01  .. S-AI-10
```

## Kill-chain demo (10 scenarios, ~15 min)

`./simulator.sh kill-chain` runs:

1. **S-API-03** — sqlmap-style scanner UA on APIM
2. **S-SRV-02** — encoded PowerShell on Windows VM
3. **S-SRV-03** — LSASS dump via ProcDump
4. **S-ARM-10** — SP credential appended (persistence)
5. **S-ARM-04** — wildcard custom role created
6. **S-K8S-01** — privileged pod in AKS
7. **S-K8S-06** — SA token misused from inside pod
8. **S-STO-05** — mass blob extraction
9. **S-ARM-08** — diagnostic settings disabled
10. **S-KV-08** — bulk delete + recover Key Vault secrets

Allow 10–30 min after the run for all alerts to surface across MDC, Defender XDR, and Sentinel.

## Idempotency & safety

- Every scenario cleans up after itself where reasonable (pods deleted, files removed, custom roles destroyed, soft-deleted secrets recovered).
- Artefacts that linger are tagged `poc-mdc-simulator=true` so they're easy to find:
  ```bash
  az resource list --tag poc-mdc-simulator=true -o table
  ```
- `arm.sh s06` (mass deletion) only deletes RGs with the `poc-mdc-simulator=true` tag and never deletes the lab RGs themselves.

## Troubleshooting

- **`Discovered: ... ='" ' '`** — the lab isn't deployed yet, or you're on the wrong subscription. Run `az account set` and `terraform apply` / `az deployment sub create` first.
- **`Run-command timed out`** — VM Run Command has a 90-second budget. Re-run; SRV-04 (brute force) may need patience.
- **`sqlmap not installed`** — install it in a containerised attacker box (`docker run -it sqlmap/sqlmap`). The script falls back to a UA-only signal otherwise.
- **AI plan: 429** — your OpenAI deployment is rate-limited. Increase TPM in the deployment or slow the loop.
