# One-pager

A single-page customer-facing chart for the workshop. Designed under the **Sentinel Cartography** philosophy — see [`DESIGN_PHILOSOPHY.md`](DESIGN_PHILOSOPHY.md).

| File | Purpose |
|------|---------|
| `ONE-PAGER.pdf` | A4 portrait, designed for printing on heavy stock or sending as a single PDF attachment. |
| `thumbnail.png` | 2.5×-scale raster preview, for embedding in emails and proposals. |
| `DESIGN_PHILOSOPHY.md` | The aesthetic manifesto driving the composition. |
| `build_one_pager.py` | Self-contained ReportLab builder. |
| `fonts/` | Bundled OFL-licensed typefaces (Instrument Serif, IBM Plex Mono). |

## Regenerate

```bash
pip install reportlab pypdfium2
python one-pager/build_one_pager.py
```

The script reads fonts from `one-pager/fonts/` — no internet, no external dependencies.

## What it communicates

The page is an admiralty-style chart of the workshop:

- **A constellation of eleven plans** orbiting one PoC subscription (the optical centre).
- **A gold thread** tracing the demo kill-chain across the constellation.
- **A single coral mark** for the LSASS / credential-dump alert — the moment compromise becomes credible.
- **A 11 × 10 matrix** of one hundred and ten scenario marks.
- **A tactic strip** along the bottom — the workshop's coverage of the MITRE ATT&CK matrix.
- **The deliverables list** in eight numbered glyphs.
- **A wax-seal mark** at the bottom centre. Edition 2026.05.20.

## Use it for

- The slide before a pitch deck.
- The page on the proposal cover.
- A printed handout that survives the workshop and stays on the SOC engineer's desk.
- A LinkedIn / social hero image (export the PDF to PNG at 2× scale).

## Style notes

- **Palette** — midnight navy / ice / coral / gold. No gradients, no drop-shadows.
- **Type** — Instrument Serif for the heading, IBM Plex Mono for every other glyph.
- **Grid** — a 0.25 cm minor + 1.25 cm major lattice spans the entire field; the chart sits on it.
- **No marketing language** — the page is a map, not a brochure. The viewer extracts meaning from form, not adjectives.
