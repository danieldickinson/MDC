# Recorded Demo Script — MDC CWPP "Phished Developer" Kill Chain

**Runtime:** 12:30 ± 30s
**Format:** 1920×1080, 60 fps recommended (slow zooms hold up better)
**Voice:** calm, slightly serious — this is a breach narrative, not a product demo
**Music:** none for the first 9 minutes; light tension cue at 09:30 (cover-tracks act); silence on outro

---

## Pre-flight (do this BEFORE you press record)

| Step | Detail |
|------|--------|
| Run lab | `terraform apply` (or `az deployment sub create`) ≥ 1 hr ahead so baseline analytics warm up |
| Pre-deploy Sentinel pack | `./scripts/deploy-sentinel-rules.sh` — confirm rules show **Enabled** |
| Warm caches | Open MDC, Defender XDR, Sentinel, Teams in 4 browser tabs, signed in |
| Hide clutter | Close Slack/email · `do not disturb` · disable notifications |
| Shell font | iTerm: JetBrains Mono 18pt · prompt = `$ ` only |
| Editor | VS Code maximized · zoom level 2 · activity bar hidden |
| Aliases | `alias sim=./simulator/simulator.sh` so the takes are short |
| Browser zoom | 110% in Edge — MDC blade fonts otherwise read too small at 1080p |
| Backup | Take a snapshot before record; if alerts fail to fire, restore and re-run |

---

## Title card (00:00 – 00:15)

**Screen:** Solid navy background. Centered title: *"A developer just got phished. Watch Defender for Cloud catch every move."*

**Narration:**
> "A developer just got phished. In the next twelve minutes, we'll follow the attacker through eleven Defender for Cloud plans — and watch every step light up."

**Visual cue:** fade to black at 00:14.

---

## Scene 1 — Initial recon (00:15 – 01:30)

**Action:** terminal full-screen. Run:

```bash
sim apis 03    # sqlmap UA against APIM
```

Show the curl loop streaming `403`/`401` responses for ~10s. While it runs, switch focus to a second pane and tail:

```bash
az rest --method get \
  --url "https://management.azure.com/subscriptions/$SUB/providers/Microsoft.Security/alerts?api-version=2022-01-01" \
  --query "value[?contains(properties.alertDisplayName,'API')]|[0].properties.alertDisplayName"
```

Wait — first alert should appear by ~01:00.

**On-screen overlay (01:05):** lower-third banner — *"Defender for APIs · S-API-03 · MITRE T1046"*.

**Narration:**
> "First contact. An external client is hitting our APIM endpoint with a `sqlmap` user-agent. Defender for APIs flags it inside a minute — and we have our first lead."

**B-roll (cut at 01:25):** browser → security.microsoft.com → Incidents — the new MDC alert correlated into a Defender XDR incident.

---

## Scene 2 — Foothold (01:30 – 03:00)

**Action:** terminal — switch to the Windows VM jumpbox (RDP-in window pre-positioned bottom-right).

```bash
sim servers 02    # encoded PowerShell
```

Pause on the base64 blob. Hover the mouse on screen so the viewer can see it.

**Action:** While the simulator runs, switch to MDC portal — Security alerts blade — filter by Sev=Medium+, last 30 min. Scroll to *"Suspicious PowerShell command line"*.

**Narration:**
> "On the host, the foothold is a classic encoded PowerShell download cradle. Microsoft Defender for Endpoint catches the base64 obfuscation pattern in under two minutes — and ties it back to the compromised user."

**Visual cue:** highlight the alert card in MDC with a coral box overlay.

---

## Scene 3 — Credential dumping (03:00 – 04:30)

**Action:** continue on the Win VM:

```bash
sim servers 03    # LSASS via ProcDump
```

ProcDump output rolls. Wait for completion (~30s).

**Cut to:** Defender XDR → Incidents → expand the device timeline. ProcDump → `lsass.exe` open with `VM_READ`.

**Narration:**
> "Now the attacker reaches for credentials — ProcDump against LSASS. This is the moment most engagements pivot from intrusion to compromise. MDC raises a High alert; Defender XDR stitches it onto the same incident as the PowerShell."

**On-screen overlay (04:20):** *"Severity: High · T1003.001 LSASS Memory"*.

---

## Scene 4 — Persistence & priv-esc (04:30 – 06:30)

**Action:** terminal — switch to attacker's `az` session.

```bash
sim arm 10        # SP credential add  → persistence
sim arm 04        # wildcard custom role → priv-esc
```

Both finish in ~30s combined. Show the role JSON that gets created.

**Cut to:** Sentinel → Incidents → wait for **ARM suspicious-ops** rule to fire (this is one of the analytics rules we shipped).

**Narration:**
> "With creds in hand the attacker pivots to Azure Resource Manager. They mint a service-principal credential — that's the persistence. Then a custom role with wildcard `*` actions — that's the privilege escalation. Defender for Resource Manager flags both inside fifteen minutes; our Sentinel rule pulls them into a single ARM-tampering incident."

**Visual cue:** zoom on the `"Actions": ["*"]` line of the role JSON.

---

## Scene 5 — Lateral to AKS (06:30 – 08:00)

**Action:** terminal —

```bash
sim containers 01    # privileged pod
sim containers 06    # service-account token misuse
```

Show `kubectl get pods` — `pwn-priv` running.

**Cut to:** MDC → Security alerts — *"Privileged container detected"*. Click into Defender XDR's Kubernetes blade.

**Narration:**
> "From the control plane it's a short hop into the data plane. The attacker stands up a privileged pod in our AKS cluster, then uses the mounted service-account token to call the Kubernetes API — straight into the cluster's secrets store. Defender for Containers raises both within minutes."

---

## Scene 6 — Data theft (08:00 – 09:30)

**Action:** terminal —

```bash
sim storage 05    # mass extraction
```

Watch `azcopy` stream blob downloads. ~30s.

**Cut to:** MDC → Storage account alerts — *"Unusual extraction of data from a storage account"*.

**Narration:**
> "Then the payoff: a burst of blob downloads from a storage account that has never seen this principal before. Defender for Storage spots the anomaly inside minutes, and now we know exactly which files left the building."

**On-screen overlay (09:15):** *"Defender for Storage · MITRE T1567"*.

---

## Scene 7 — Cover the tracks (09:30 – 11:00)

**Music in:** light tension cue, low.

**Action:** terminal —

```bash
sim arm 08        # disable diagnostic settings
sim keyvault 08   # bulk delete + recover
```

Show the diagnostic-setting `null` after deletion; then the KV soft-deleted secrets list.

**Cut to:** Sentinel → Incidents — the **Cross-plan kill chain** rule fires. This is the one that ties every prior alert together, by *identity*, into a single incident.

**Narration:**
> "Finally, the attacker tries to disappear — disabling diagnostic settings and bulk-deleting Key Vault secrets. But Defender for Cloud was watching the control plane the whole time. And our Sentinel correlation rule is keyed off identity, not resource, so every move we've seen — APIM, MDE, ARM, AKS, Storage, Key Vault — collapses into a single incident."

**Visual cue:** at 10:50, screen-record the Sentinel incident graph expanding to show all six plans involved.

---

## Scene 8 — Investigation in Jupyter (11:00 – 12:15)

**Action:** switch to Jupyter Lab. Open `notebooks/02-kill-chain-investigation.ipynb`. Set `SUSPECT = "attacker@example.com"`. Run all cells.

Show the rendered MITRE-tactic scatter plot — coral dots spread across **Initial Access → Impact**.

**Narration:**
> "From here it's an analyst's job. The kill-chain notebook reconstructs the entire timeline against MITRE — every plan, every tactic, on one chart. The SOC has everything they need: who, what, when, where, and how to revoke the principal."

**Music fade out at 12:00.**

---

## Outro (12:15 – 12:30)

**Screen:** navy card — *"Defender for Cloud · CWPP · 11 plans · 110 simulations · github.com/your-org/mdc-cwpp-workshop"*.

**Narration:**
> "All eleven CWPP plans, 110 scenario simulations, infrastructure, and Sentinel content — open-source in the repo. Try it in your own subscription."

**Fade to black.**

---

## B-roll list (cut these around the main narrative if a take feels thin)

| ID | Shot | Duration |
|----|------|----------|
| B1 | Top-down on the runbook (printed) | 4s |
| B2 | Slow zoom into the Excel matrix — scenario rows scrolling | 5s |
| B3 | Mouse hovering the "Privileged" toggle in Defender for Storage settings | 3s |
| B4 | Teams desktop receiving the playbook card | 5s |
| B5 | `bicep build infra/main.bicep` terminal scroll | 4s |
| B6 | VS Code with the analytics-rule YAML open, syntax highlighted | 4s |
| B7 | The KQL coverage workbook tiles updating live | 6s |
| B8 | `terraform destroy -auto-approve` — tear-down satisfaction shot | 5s |

---

## Recording / encoding notes

- Use **OBS Studio** with two scenes: `Terminal Full` and `Browser Full` plus a "Picture-in-Picture" scene combining both.
- Capture system audio + microphone on separate tracks for post mixing.
- Export `.mov` ProRes 422 LT at 1920×1080 → archive master; deliver `.mp4` H.264 18 Mbps for sharing.
- Burn-in lower-third overlays in post (Final Cut / DaVinci) using the on-screen overlay cues above.
- Pre-roll one slate frame (3s) — "MDC CWPP workshop · take N · date".
- Hard cut on **00:00:00** of the title card — no fade-in.

## QA checklist before publishing

- [ ] Subtitles burned in (use OpenAI Whisper + manual pass for product names).
- [ ] Every alert name on screen matches the runbook text.
- [ ] Sensitive resource IDs / GUIDs blurred or replaced via Affinity post.
- [ ] No real tenant ID visible in `az account show` lines.
- [ ] Final length within 12:00 – 13:00 — anything longer loses attention.
- [ ] Audio peaks below −1 dB; voice averaged at −18 LUFS.
- [ ] Captioned MP4 + clean MP4 + frame.png thumbnail in `dist/`.
