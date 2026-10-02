# FlatFile — Screenshot Shot List (framed ASC set)

**Status:** framed set ready for Kate / ASC operator upload · **Do not upload from agents**  
**Canvas:** warm paper `#F2F1ED` via `appstore/frame.html` + `mac-frame.html` (FlatNote pattern)  
**Footer (thesis):** Made for Mom by Kate Benediktsson  
**Date:** 2026-10-02 PT

## Required sizes

| Folder | Slot | Pixels |
|---|---|---|
| `iphone-6.9/` | iPhone 6.9" | 1320 × 2868 |
| `ipad-13/` | iPad 13" | 2064 × 2752 |
| `mac/` | Mac | 2880 × 1800 framed |

## Final framed files (upload these)

### iPhone (`iphone-6.9/`) — 6
1. `iphone-1-grid.png` — The grid is the .csv.
2. `iphone-2-templates.png` — Start from something human.
3. `iphone-3-folder.png` — Your folder. Your files.
4. `iphone-4-inspect.png` — Never guesses your data.
5. `iphone-5-paperclip.png` — Tables next to notes.
6. `iphone-6-thesis.png` — No account needed.

### iPad (`ipad-13/`) — 4
1. `ipad-1-grid.png`
2. `ipad-2-templates.png`
3. `ipad-3-inspect.png`
4. `ipad-4-paperclip.png`

### Mac (`mac/`) — 3
1. `mac-1-grid.png` — Sidebar + table (derived; live Mac recapture blocked by Screen Recording TCC)
2. `mac-2-raw.png` — Grid + Raw CSV (existing window capture reframed)
3. `mac-3-inspect.png` — Inspect

Raw UI sources live under `screenshots/raw/`. Re-frame with `node appstore/render-frames.mjs`.

## Capture seam (`FF_SCREENSHOT`)

DEBUG builds: `demo` · `inspect` · `templates` · `folder` · `paperclip` · `raw`  
Pass via `SIMCTL_CHILD_FF_SCREENSHOT=<mode>` (sim) or env on Mac.

## Notes / blockers

- Mac live window recapture needs Screen Recording permission for the agent shell — reused prior 1440×900 captures; grid cropped from table+raw for distinct hero.
- Old unframed `1-table.png` / `2-inspect.png` kept for reference; upload the `iphone-*` / `ipad-*` / `mac-*` names.
