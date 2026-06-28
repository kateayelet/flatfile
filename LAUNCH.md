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

## Two decisions to make

### 1. Pricing decision
The issue calls for "one-time ~$9.99 with a genuinely useful free tier." A free
tier on a paid app means free download plus a one-time in-app unlock, which needs
StoreKit code that is **not built**. Two paths:

- **Recommended for launch:** ship **paid up front at $9.99**, no IAP. Zero extra
  code, fastest to the store. Add a free tier in a fast-follow update if you want
  it.
- **Freemium:** free download with a $9.99 unlock. More polished funnel, but
  needs a StoreKit purchase flow, a "what's free vs paid" line drawn in the app,
  and receipt handling. File this as its own issue if you choose it.

The metadata and checklist are written for the paid-up-front path; switching to
free is a one-field change in App Store Connect plus the IAP work.

### 2. EU trader status
Required before EU distribution (Digital Services Act). Declare individual/trader
in App Store Connect under App Information, or exclude the EU from availability.

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
