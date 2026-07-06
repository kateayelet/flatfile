# FlatFile — App Store Submission Checklist

A start-to-finish guide for App Store Connect. Copy text fields from
`METADATA.md`. Do the steps in order.

Legal entity / team: aftrveil (SMQ3T59TFL). Bundle ID: aftrveil.FlatFile.

---

## 0. Before you start — build-setting fixes (do these in Xcode first)

These are checkbox-level changes in **Signing & Capabilities** and **Build
Settings**. They are not done yet and two of them block a working Mac build.

- [ ] **Mac file saving (BLOCKER).** App Sandbox is on with **User Selected
      Files = Read Only**. FlatFile auto-saves, so on Mac it cannot write to the
      files the user picks. In Signing & Capabilities → App Sandbox, set
      **User Selected File** to **Read/Write** (build setting
      `ENABLE_USER_SELECTED_FILES = readwrite`).
- [ ] **Drop the visionOS target (recommended).** `SUPPORTED_PLATFORMS` includes
      `xros xrsimulator` and there is an unpolished visionOS deployment target.
      Unless you intend to test and ship a native visionOS build, remove
      `xros`/`xrsimulator` from Supported Destinations so review only covers
      iPhone, iPad, and Mac.
- [ ] **Export compliance.** Add build setting
      `INFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO` (or set it in the Info
      tab) so the export-compliance prompt never appears on upload.
- [ ] **Signing team.** Set **DEVELOPMENT_TEAM** to aftrveil (SMQ3T59TFL) on all
      targets; keep automatic signing.
- [ ] **Unique build number** per upload. Bump `CURRENT_PROJECT_VERSION` for each
      new archive (it is currently 1).
- [ ] **StoreKit local testing (optional but recommended).** To exercise the Pro
      unlock in the simulator before the IAP exists in App Store Connect: Product →
      Scheme → Edit Scheme → Run → Options → **StoreKit Configuration** →
      `FlatFile.storekit`. Buy/restore then works against the local config. Turn it
      off (or leave it — it is ignored in release builds) before archiving.

---

## 1. Build, test on device, upload

- [ ] Open `~/06-flatfile-app/FlatFile.xcodeproj`.
- [ ] Destination **Any iOS Device (arm64)** → **Product → Archive** →
      **Distribute App → TestFlight Internal Only → Upload**.
- [ ] Repeat for Mac: destination **Any Mac** → Archive → Upload. Mac and iOS
      builds are separate uploads under the same app.
- [ ] Builds take a few minutes to an hour to finish "Processing."

**Verify on real devices (could not be tested in the simulator):**
- [ ] iOS: open a folder of CSVs, edit a cell, confirm the `.csv` on disk
      changed (check in the Files app).
- [ ] Mac: edit and save a CSV in a user-picked folder (this is what the
      Read/Write sandbox fix above enables).
- [ ] Paperclip: put a same-named `.md` next to a `.csv` and confirm the
      paperclip appears and opens FlatNote.

---

## 2. App Information (set once, all platforms)

- [ ] **Subtitle:** Plain CSV editor, no lock-in
- [ ] **Category:** Primary Productivity, Secondary Utilities
- [ ] **Content Rights:** does not use third-party content.
- [ ] **Age Rating:** answer all No → 4+.
- [ ] **EU Trader status:** DECISION — **exclude the EU** for v1. No trader
      declaration needed; instead remove EU territories in step 5 (Availability).

---

## 3. Privacy

- [ ] **App Privacy → Data Collection:** "No, we do not collect data."
- [ ] **Privacy Policy URL:** paste your hosted PRIVACY.md / privacy.html URL.

---

## 4. Per-version listing (fill for both the iOS and the macOS version)

- [ ] **Promotional Text** — from METADATA.md
- [ ] **Description** — from METADATA.md
- [ ] **Keywords** — from METADATA.md
- [ ] **Support URL** — your page
- [ ] **What's New** — from METADATA.md (use the matching platform's text)
- [ ] **Copyright:** 2026 Kate Ayelet

### Screenshots (drag in from appstore/screenshots/ — see SHOTLIST.md)

- [ ] **iPhone 6.9":** `iphone-6.9/` (1-table, 2-inspect) — captured, 1320x2868
- [ ] **iPad 13":** `ipad-13/` (1-table, 2-inspect) — captured, 2064x2752
- [ ] **Mac:** `mac/` (1-table, 2-inspect) — captured, 1440x900

---

## 4b. In-App Purchase (FlatFile Pro)

Do this before submitting; the IAP must ship attached to the first version.

- [ ] **Monetization → In-App Purchases → +**, type **Non-Consumable**.
- [ ] **Reference Name:** FlatFile Pro
- [ ] **Product ID:** `aftrveil.FlatFile.pro` (must match the code exactly).
- [ ] **Price:** $9.99.
- [ ] **Localization (en-US):** Display Name "FlatFile Pro"; description from
      METADATA.md (In-App Purchase section).
- [ ] **Review screenshot:** attach a shot of the paywall (run the app and tap
      Inspect while locked, or reuse the inspect screenshot).
- [ ] **Availability:** all territories except the EU (match the app).
- [ ] **Attach the IAP to the version** on each platform's page ("In-App
      Purchases and Subscriptions" section) so App Review evaluates it.

---

## 5. Build, pricing, release

- [ ] **Build:** attach the processed iOS build and macOS build to each version.
- [ ] **Export compliance:** should not prompt (set in step 0). If asked, answer
      "No" to non-exempt encryption.
- [ ] **Pricing:** app is **Free** (Tier 0). Revenue comes from the $9.99 IAP
      above.
- [ ] **Availability:** all territories **except the EU** (remove every EU
      territory — no trader declaration for v1).
- [ ] **Release:** "Automatically release after review" is simplest.

---

## 6. Submit

- [ ] Hit **Add for Review / Submit** on each platform's version.
- [ ] First review usually lands in a day or two. Most first-app rejections are a
      missing URL or a privacy detail — all covered above.

---

## Notes and gotchas

- **Icon:** comes from the build automatically. The asset is a single
  1024x1024 PNG reused across sizes; iOS accepts a single-size app icon, and Mac
  downscales from it. If the Mac icon looks soft at small sizes, add dedicated
  Mac PNGs later — not a blocker for first submission.
- **One app, two versions:** iOS and macOS are separate version pages under the
  same app, sharing App Information and App Privacy but each needing its own
  screenshots and What's New.
- **No iCloud capability needed:** FlatFile uses the user's own Files storage,
  not an app iCloud container, so there is nothing to enable here.
