# FlatFile — Launch Checklist

Everything needed to finish shipping FlatFile, written so you can pick it up cold
later. Work top to bottom. Paste-ready copy lives in `appstore/METADATA.md`; the
App Store Connect walk-through is `appstore/SUBMISSION_CHECKLIST.md`.

## Where things stand (done already)

- App is feature-complete for v1. Code is on GitHub: `kateayelet/flatfile`
  (branch `main`), working tree clean.
- Version **1.0**, build **1** in the project.
- Real app icon is in place (single 1024x1024, reused across sizes).
- Deployment targets are broad: iOS 17.0, macOS 14.0.
- App Store text and policy are generated and in the repo:
  - `appstore/METADATA.md` — name, subtitle, description, keywords, promo text,
    categories, App Privacy answers
  - `appstore/PRIVACY.md` and `docs/privacy.html` — the privacy policy to host
  - `appstore/SUBMISSION_CHECKLIST.md` — the App Store Connect steps
  - `appstore/screenshots/SHOTLIST.md` — exact sizes and the shot list
  - `README.md` and MIT `LICENSE` in the repo root

## Two decisions — both made

### 1. Pricing — freemium (DONE, code built)
Free to download and edit CSVs; a single one-time **$9.99** in-app purchase
(FlatFile Pro, non-consumable) unlocks the power tools. The StoreKit 2 flow is
built and compiling:

- `FlatFile/Services/StoreManager.swift` — the unlock state, purchase, restore,
  and live entitlement tracking. `isPro` is the single source of truth.
- `FlatFile/Views/PaywallView.swift` — the unlock screen.
- `FlatFile.storekit` — local StoreKit test config for the simulator.

**Free vs Pro line** (each is a one-line change in `TableView.swift` if you want
to move a feature):
- **Free forever:** open folders, edit any `.csv`, add/delete rows, sort, search,
  share/export, FlatNote paperclip + companion notes.
- **Pro ($9.99):** Inspect (data quality), Find & Replace, Column Stats & schema.

You still must **create the IAP in App Store Connect** (product ID
`aftrveil.FlatFile.pro`) and attach it to the first version — see
`appstore/SUBMISSION_CHECKLIST.md` section 4b.

### 2. EU trader status — exclude the EU (DONE)
v1 excludes the EU from availability, so no Digital Services Act trader
declaration is needed. Remove all EU territories under Pricing and Availability
(SUBMISSION_CHECKLIST.md step 5). Revisit if you later want EU distribution.

## What you still need to supply

1. **Support URL** (required). Easiest: make the GitHub repo public and use
   `https://github.com/kateayelet/flatfile`.
2. **Privacy Policy URL** (required). Host `docs/privacy.html` on GitHub Pages
   (or `appstore/PRIVACY.md` anywhere public) and use that link. Add your contact
   email — already set to kateayelet@aftrveil.com; change if needed.

---

## Step 0 — Build-setting fixes (Xcode, before archiving)

See `appstore/SUBMISSION_CHECKLIST.md` section 0 for the exact toggles. The two
that matter most:

- **Set User Selected Files to Read/Write** in App Sandbox, or the Mac build
  cannot save edits (FlatFile auto-saves). This is the one real correctness
  blocker.
- **Set `ITSAppUsesNonExemptEncryption = NO`** so uploads do not prompt for
  export compliance.

Also recommended: drop `xros`/`xrsimulator` from Supported Destinations unless
you intend to ship and test a native visionOS build, and set the signing team to
aftrveil (SMQ3T59TFL).

## Step 1 — Archive, TestFlight, verify

1. `open ~/06-flatfile-app/FlatFile.xcodeproj`
2. Destination **Any iOS Device (arm64)** → **Product → Archive** →
   **Distribute App → TestFlight Internal Only → Upload**. Then repeat with
   destination **Any Mac**.
3. Install via TestFlight and verify on real devices: edit-and-save a CSV on
   iPhone and on Mac, and confirm the paperclip opens FlatNote.

## Step 2 — Submit

Follow `appstore/SUBMISSION_CHECKLIST.md` end to end: App Information, Privacy,
per-version listing, screenshots, build, pricing, then Add for Review.

## Step 3 — Open source it (optional, recommended)

Making the repo public reinforces the no-lock-in promise and gives you a free
Support URL. License is already MIT.

---

## Reference: file map

```
~/06-flatfile-app/
  README.md                      project overview
  LICENSE                        MIT
  LAUNCH.md                      this file
  Claude.md                      agent context / product rules
  FlatFile.xcodeproj             open this in Xcode
  FlatFile/                      app source (SwiftUI, MVVM)
  FlatFileTests/                 tests
  docs/
    privacy.html                 privacy policy for GitHub Pages
  appstore/
    METADATA.md                  paste-ready App Store text
    PRIVACY.md                   privacy policy (markdown)
    SUBMISSION_CHECKLIST.md      App Store Connect steps
    screenshots/
      SHOTLIST.md                sizes + shot list
      iphone-6.9/  ipad-13/  mac/   (drop PNGs here)
```
