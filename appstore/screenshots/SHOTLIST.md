# FlatFile — Screenshot Shot List

App Store screenshots cannot be generated headlessly; capture them from the
running app in the simulator (and on a real Mac for the macOS set). Required
sizes and the intended shots are below. Drop the PNGs into the folders named
here; the submission checklist references these exact paths.

## Required sizes

| Folder | Device slot | Pixel size |
|---|---|---|
| `iphone-6.9/` | iPhone 6.9" (required) | 1320 x 2868 |
| `ipad-13/` | iPad 13" (required) | 2064 x 2752 |
| `mac/` | macOS | 1440 x 900 (or 1280x800 / 2560x1600 / 2880x1800) |

## Shots (order matters — first shot leads the product page)

### iPhone (`iphone-6.9/`)
1. `1-table.png` — a populated table mid-edit (a representative CSV, e.g. an
   expenses or field-log table), showing inline editing.
2. `2-folder.png` — the folder / CSV library browser, ideally with a paperclip
   indicator on a paired file.
3. `3-inspect.png` — the Inspect / data-quality view surfacing a couple of
   findings (duplicate row, empty cell).

### iPad (`ipad-13/`)
1. `1-table.png` — the table on the larger canvas.
2. `2-companion.png` — the table with the FlatNote companion note in the split
   pane (the unique pairing hook).

### Mac (`mac/`)
1. `1-table.png` — the table in a Finder-backed folder.
2. `2-inspect.png` — the Inspect view (or the Mac raw-CSV split pane).

## How to capture (iOS simulator)

1. `open ~/06-flatfile-app/FlatFile.xcodeproj`
2. Run on **iPhone 16 Pro Max** (6.9") and **iPad Pro 13"** simulators.
3. Load a clean, screenshot-worthy CSV (avoid personal data).
4. `Cmd+S` in the simulator saves a correctly-sized PNG to the Desktop; rename
   and move it into the folder above.

For Mac, run the Mac build and use `Cmd+Shift+4` then space to capture the
window, or resize to a listed size and grab the full window.
