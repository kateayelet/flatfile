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

## Captured (order matters — first shot leads the product page)

### iPhone (`iphone-6.9/`) — DONE, 1320x2868
1. `1-table.png` — the populated `field-budget` table, Sort controls + toolbar.
2. `2-inspect.png` — the Inspect view flagging duplicate rows, blank cells,
   leading-zero IDs ("Numbers other apps would alter"), and mixed date formats.

### iPad (`ipad-13/`) — DONE, 2064x2752
1. `1-table.png` — the full table on the larger canvas with the Append Row form.
2. `2-inspect.png` — the `invoices` table with the Inspect findings sheet over
   it (you can see the flagged data behind it).

### Mac (`mac/`) — DONE, 1440x900
1. `1-table.png` — sidebar + table + Raw CSV split, the full Mac layout.
2. `2-inspect.png` — the Inspect findings over the `invoices` table.
Captured by running the Mac app with `FF_SCREENSHOT`, positioning the window to
1440x900 via System Events, and `screencapture -R`. Other acceptable Mac sizes:
1280x800, 2560x1600, 2880x1800.

## How these were captured (reproducible)

The iPhone/iPad shots were generated headlessly via a DEBUG-only screenshot seam
(the `FF_SCREENSHOT` env var, see `ContentView.screenshotMode`), which seeds a
demo table and — for inspect — a dataset with deliberate data-quality issues.

```
# build for simulator
xcodebuild -project FlatFile.xcodeproj -scheme FlatFile -configuration Debug \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/ff-build build CODE_SIGNING_ALLOWED=NO
APP=/tmp/ff-build/Build/Products/Debug-iphonesimulator/FlatFile.app

# per device: create + boot + install, then for each screen:
xcrun simctl install <udid> "$APP"
SIMCTL_CHILD_FF_SCREENSHOT=demo    xcrun simctl launch <udid> aftrveil.FlatFile  # table
SIMCTL_CHILD_FF_SCREENSHOT=inspect xcrun simctl launch <udid> aftrveil.FlatFile  # inspect
xcrun simctl io <udid> screenshot <out.png>   # repeat a few times to pass the launch animation
```

iPhone device: **iPhone 17 Pro Max** (1320x2868). iPad: **iPad Pro 13-inch (M5)**
(2064x2752).

### Mac: still to capture
The seam works on Mac too. Run the Mac app with the env var set and screenshot
the window:
```
FF_SCREENSHOT=demo /path/to/FlatFile.app/Contents/MacOS/FlatFile   # then Cmd+Shift+4, space
```
Resize the window to ~1440x900 first, or capture and pad to a listed size.
