//
//  Claude.md
//  FlatFile
//
//  Created by Kate Ayelet Benediktsson on 4/6/26.
//
# FlatFile — Claude Agent Context
**by AftrVeil** | v1.0

---

## What This App Is

FlatFile is a frictionless CSV table editor for iOS and Mac.
It is the CSV equivalent of a markdown scratch pad.
Every table is a `.csv` file. No proprietary format, ever.
The file is the truth. The app is just a window into it.

Companion app: FlatNote (markdown, same company, separate project).

---

## Core Principles — Never Violate These

1. Every table = one `.csv` file. RFC 4180 compliant. UTF-8.
2. No proprietary format. No internal database. No app-managed sync.
3. Storage is the user's choice — we use the iOS Files API, not our own sandbox.
4. The app must work fully offline. AI features require network; nothing else does.
5. Minimal. Do not add features not listed in this document.

---

## Platform & Technical Specs

- **Language:** Swift 6.0
- **UI:** SwiftUI only. No UIKit unless absolutely forced.
- **Minimum deployment:** iOS 17.0
- **Architecture:** MVVM with `@Observable`
- **Package manager:** Swift Package Manager
- **Storage:** FileManager + UIDocumentPickerViewController (iOS Files API)
- **CSV parsing:** Custom lightweight parser, RFC 4180 compliant. No third-party CSV libraries.
- **AI:** Anthropic API, claude-sonnet-4. Used only in AI capture mode.
- **Testing:** Swift Testing with XCTest UI Tests

---

## Project Structure

```
FlatFile/
├── Models/
│   ├── CSVDocument.swift        # The core data model — a parsed .csv file
│   └── CSVRow.swift             # A single row
├── Views/
│   ├── TableListView.swift      # List of .csv files in connected folder
│   ├── TableView.swift          # Main rendered table view
│   ├── RowAppendView.swift      # Single-row form at bottom for quick append
│   └── RawCSVView.swift         # Raw CSV text editor (Mac only)
├── ViewModels/
│   └── TableViewModel.swift     # Drives TableView, owns file read/write
├── Services/
│   ├── CSVParser.swift          # RFC 4180 parser/serializer
│   ├── FileService.swift        # Files API, folder access, read/write
│   └── AIService.swift          # Anthropic API calls for AI capture mode
├── Utilities/
│   └── PaperclipHelper.swift    # Detects paired .md file (FlatNote pairing)
└── CLAUDE.md                    # This file
```

---

## Features to Build (MVP v1.0)

### Must Have
- [ ] Open a folder via Files API, list all `.csv` files
- [ ] Select a `.csv` file, render it as a table (headers + rows)
- [ ] Tap `+` → RowAppendView → fill row → appends to file
- [ ] Tap any cell → edit inline → saves to file
- [ ] Long-press row → delete row
- [ ] Sort by column (tap header)
- [ ] Share / export current `.csv` file
- [ ] Paperclip icon — detect same-named `.md` in same folder, show icon if found
- [ ] AI capture mode — user describes table in plain language → generates `.csv` with headers

### Nice to Have (v1, not blocking)
- [ ] Filter / search rows
- [ ] Paste CSV from clipboard → new table
- [ ] Raw CSV split-pane (Mac target only)

### Explicitly Out of Scope — Do Not Build
- No formulas
- No cell data types (everything is a String in v1)
- No charts
- No relational linking between tables
- No collaboration
- No in-app sync or cloud account
- No web version
- No markdown table rendering (that's FlatNote's job)

---

## FlatNote Paperclip Convention

FlatFile and FlatNote pair via shared filename, same folder, different extension.

Example:
```
/observations/morgellons-fibers.csv   ← this app
/observations/morgellons-fibers.md    ← FlatNote companion
```

Implementation in `PaperclipHelper.swift`:
- Given the URL of the current `.csv` file
- Check if a file with the same name but `.md` extension exists in the same directory
- If yes: show paperclip icon in toolbar
- If tapped: open the `.md` file (hand off to FlatNote via `UIApplication.open` or Files)
- No database, no linking layer. Filesystem is the index.

---

## CSV Parser Rules

RFC 4180 compliant. Key behaviors:
- First row = headers always
- Comma delimiter
- Fields containing commas or newlines must be quoted
- Double-quote to escape a quote inside a quoted field
- Blank lines at end of file are ignored
- Parser must never crash on malformed input — degrade gracefully

---

## AI Capture Mode

When user taps "New with AI":
1. Show a plain text prompt field: *"What do you want to track?"*
2. Send to Anthropic API with a system prompt that returns only valid CSV
3. Parse the response as CSV
4. Open the result as a new table immediately
5. User names and saves the file

System prompt for AI (in `AIService.swift`):
```
You generate CSV tables. The user will describe what they want to track.
Respond with ONLY valid RFC 4180 CSV — no explanation, no markdown, no backticks.
First row must be headers. Include 2-3 example rows to help the user understand the format.
Keep headers short, lowercase, underscore-separated (e.g. "date", "location", "fiber_color").
```

---

## File Naming Convention

- User-named files preferred
- If AI-generated and not yet named: prompt user to name before saving
- Never auto-generate filenames silently
- `.csv` extension always lowercase

---

## Important Warnings

- **Never modify `.pbxproj` directly.** Create Swift files and tell the developer to add them to the Xcode project manually if needed.
- **Never use UserDefaults to store table data.** All data lives in `.csv` files.
- **Never create a Core Data stack.** No database of any kind.
- **SwiftUI only.** Do not introduce UIKit view controllers.
- This app must feel native, fast, and invisible. No loading spinners for local file operations.

---

*FlatFile is a tool by AftrVeil. Truth is fractal.*
