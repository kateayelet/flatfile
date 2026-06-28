# FlatFile

A CSV editor for iPhone, iPad, and Mac that keeps your data plain, portable, and
yours. Every table is just a `.csv` file in storage you already control.

Spreadsheets love to "help" — open a CSV in Numbers or Excel and leading zeros
vanish, long codes turn into scientific notation, and anything that looks like a
date gets reformatted. FlatFile never guesses. Every cell is text exactly as you
typed it. What you see is what is in the file.

## Why FlatFile

Every table is a plain `.csv` file (RFC 4180, UTF-8). No proprietary format, no
internal database, no lock-in, readable in any app on any device years from now.
Files live wherever you keep them through the Files app and Finder — FlatFile uses
your storage, not its own. No ads, no tracking, no analytics, no server.

## Features

- **Inline table editing** with auto-save after every edit, written atomically so
  an interrupted save never corrupts the file
- **Folder browser** for a whole directory of CSVs, plus single-file open
- **Add and delete rows**, sort by column, search and filter
- **Inspect view** that surfaces data-quality issues (duplicate rows, empty
  cells, mixed formats) without auto-fixing anything
- **Zero inference** — every cell stays text; no silent type coercion
- **Fast on large files** — thousands of rows scroll smoothly (virtualized grid)
- **Optional `.flatfile` sidecar** remembers column preferences without touching
  the `.csv`
- **FlatNote pairing** — a same-named `.md` next to a `.csv` shows a paperclip
  that opens the companion note
- **iPhone, iPad, and Mac**, light and dark

## Build and run

Requires Xcode 17+ and iOS 17 / macOS 14+.

```
open FlatFile.xcodeproj
```

## Shipping

See [`LAUNCH.md`](LAUNCH.md) for the launch checklist and
[`appstore/`](appstore/) for App Store Connect metadata, the privacy policy, and
the submission checklist.

## License

MIT — see [`LICENSE`](LICENSE).

---

FlatFile is a tool by aftrveil. Pairs with FlatNote.
