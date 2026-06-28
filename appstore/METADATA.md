# FlatFile — App Store Submission Package

Everything here is ready to paste into App Store Connect. FlatFile is a universal
app: iPhone, iPad, and Mac, one purchase. Every table is a plain `.csv` file in
the user's own storage — there is no account and no app sync.

Fields map to the "App Information" page (set once for the app) and the
per-version "Distribution" pages (one for iOS, one for macOS).

---

## App Information (set once, applies to all platforms)

- **Name:** FlatFile
- **Subtitle (max 30):** Plain CSV editor, no lock-in
- **Primary category:** Productivity
- **Secondary category:** Utilities
- **Age rating:** 4+ (no objectionable content)
- **Copyright:** 2026 Kate Ayelet
- **Bundle ID:** aftrveil.FlatFile
- **Legal entity / team:** aftrveil (SMQ3T59TFL)

## URLs (you must provide these)

- **Support URL (required):** a reachable page. Simplest: make the GitHub repo
  public and use `https://github.com/kateayelet/flatfile`, or a one-page site
  with a contact email.
- **Privacy Policy URL (required):** host `PRIVACY.md` (or `docs/privacy.html`)
  publicly — GitHub Pages is easiest — and paste that URL. Fill in the contact
  email in PRIVACY.md first.
- **Marketing URL (optional):** leave blank or point to a landing page.

---

## Promotional Text (max 170, editable any time without review)

A fast CSV table editor that never guesses. Every table stays a plain .csv in
your own files. No accounts, no proprietary format, no lock-in. Works offline.

## Description (max 4000)

FlatFile is a CSV editor for people who want their data to stay plain, portable,
and theirs. It runs on iPhone, iPad, and Mac, and every table is just a `.csv`
file in storage you already control.

Spreadsheets love to "help." Open a CSV in Numbers or Excel and it quietly
rewrites your data: leading zeros vanish, long codes turn into scientific
notation, anything that looks like a date gets reformatted. FlatFile does none of
that. Every cell is text exactly as you typed it. What you see is what is in the
file.

WHAT YOU GET

- A clean table view with inline editing. Tap a cell, type, done.
- Auto-save after every edit, written safely so an interrupted save never
  corrupts your file.
- Open a whole folder of CSVs and browse them, or open a single file.
- Add and delete rows, sort and search, all on the plain file.
- Inspect view that surfaces data-quality issues — duplicate rows, empty cells,
  mixed formats — and never auto-fixes them behind your back.
- Smooth on big files: thousands of rows scroll without lag.

YOUR DATA BELONGS TO YOU

- Every table is a plain `.csv` file (RFC 4180, UTF-8). No proprietary format, no
  internal database, no lock-in. Readable in any app, on any device, years from
  now.
- Files live wherever you keep them through the Files app on iOS and Finder on
  Mac. FlatFile uses your storage, not its own.
- Export or share any table as a standard `.csv`.

PAIRS WITH FLATNOTE

Keep a `.csv` and a same-named `.md` in the same folder and FlatFile shows a
paperclip linking the two. Tap it to jump to the note in FlatNote — your data and
the notes about it, side by side, with no database in between.

QUIET BY DESIGN

- No ads. No tracking. No analytics. No server. Nothing about you leaves your
  device.
- Fully offline. Works on iPhone, iPad, and Mac, in light and dark.

FlatFile keeps the format simple so your data stays yours.

## Keywords (max 100 chars, comma-separated)

csv,editor,table,spreadsheet,data,plain text,import,export,offline,files,delimited,no lock-in

## What's New

**iOS (version 1.0):** First release. Plain `.csv` table editing with inline
edits, auto-save, a folder browser, sort and search, an Inspect data-quality
view, FlatNote pairing, and export to standard `.csv`.

**macOS (version 1.0):** FlatFile runs natively on Mac. Open and edit your CSV
files directly in Finder-backed folders, with the same zero-inference editing as
iPhone and iPad.

---

## App Privacy (the questionnaire in App Store Connect)

Answer: **Data Not Collected.**

FlatFile does not collect any data. Tables are stored as `.csv` files on the
device and in whatever storage the user chooses through the Files app. There is
no analytics, no tracking, no third-party SDKs, and no server the app talks to.
When asked "Do you or your third-party partners collect data from this app?",
answer **No**.

**Encryption:** set `ITSAppUsesNonExemptEncryption = NO` in the build so the
export-compliance prompt does not appear (see SUBMISSION_CHECKLIST.md — FlatFile
uses `GENERATE_INFOPLIST_FILE`, so this is a build setting, not an Info.plist
entry).

**EU trader status:** App Store Connect requires you to declare trader status
(EU Digital Services Act) before the app can be distributed in the EU. Set this
under App Information. If you are an individual not acting as a trader, declare
accordingly, or limit availability to exclude the EU.

---

## Pricing

Decision pending — see LAUNCH.md ("Pricing decision"). Recommended for launch:
**paid up front, one-time ~$9.99** (no in-app purchase code to build). A free
tier with a $9.99 unlock would require StoreKit work that is not built yet and is
best done as a fast-follow update.

---

## Screenshots

Required per platform. Capture into `appstore/screenshots/` (see SHOTLIST.md):

- `iphone-6.9/` — 1320 x 2868 (required iPhone size): table, folder browser,
  inspect
- `ipad-13/` — 2064 x 2752 (required iPad size): table, companion-note split
- `mac/` — REQUIRED for the Mac listing. Acceptable sizes: 1280x800, 1440x900,
  2560x1600, or 2880x1800.

Upload the iPhone set under the 6.9" display, the iPad set under the 13" display,
and the Mac set under the macOS screenshots section. The first shots are shown on
the product page, so order (table first) is intentional.
