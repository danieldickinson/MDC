# Shot-by-shot storyboard

Compact reference card to print or open on a second monitor while recording.

| t | Scene | Window | Action | Overlay |
|---|-------|--------|--------|---------|
| 00:00 | Title  | Title card | hold 15s | "A developer just got phished…" |
| 00:15 | Recon  | Terminal   | `sim apis 03` | — |
| 01:05 | Recon  | Terminal (split) | `az rest` query for alert | lower-third: *Defender for APIs · T1046* |
| 01:25 | Recon  | Browser  | XDR incident card | — |
| 01:30 | Foothold | Terminal | `sim servers 02` | — |
| 02:10 | Foothold | Browser  | MDC alert page | coral box on alert |
| 03:00 | Cred    | Terminal | `sim servers 03` | — |
| 03:45 | Cred    | Browser  | XDR device timeline | *Severity: High · T1003.001* |
| 04:30 | Persist | Terminal | `sim arm 10 && sim arm 04` | — |
| 05:30 | Persist | Browser  | Sentinel incident | zoom on `Actions=[*]` |
| 06:30 | Lateral | Terminal | `sim containers 01 && sim containers 06` | — |
| 07:15 | Lateral | Browser  | XDR Kubernetes blade | — |
| 08:00 | Exfil   | Terminal | `sim storage 05` | — |
| 08:55 | Exfil   | Browser  | MDC Storage alerts | *Defender for Storage · T1567* |
| 09:30 | Cover   | Music in | `sim arm 08 && sim keyvault 08` | — |
| 10:20 | Cover   | Browser  | Sentinel — cross-plan incident graph | — |
| 11:00 | Investigate | Jupyter | notebook 02 | — |
| 11:50 | Investigate | Jupyter | MITRE scatter plot | — |
| 12:15 | Outro   | Title card | repo URL | "github.com/your-org/mdc-cwpp-workshop" |
| 12:30 | END     |  —      | fade to black | — |

Mark beats in your editor:

```
00:00 ▏░░░░░░░░░░░░░░░ Title
00:15 ▏░░░░░░░░░░░░░░░ Recon
01:30 ▏░░░░░░░░░░░░░░░ Foothold
03:00 ▏░░░░░░░░░░░░░░░ Cred
04:30 ▏░░░░░░░░░░░░░░░ Persist + priv-esc
06:30 ▏░░░░░░░░░░░░░░░ Lateral (AKS)
08:00 ▏░░░░░░░░░░░░░░░ Exfil
09:30 ▏░░░░░░░░░░░░░░░ Cover  ← music in
11:00 ▏░░░░░░░░░░░░░░░ Investigate (Jupyter)
12:15 ▏░░░░░░░░░░░░░░░ Outro
```
