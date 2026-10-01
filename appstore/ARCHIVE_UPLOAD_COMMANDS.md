# FlatFile — Archive + TestFlight upload (paste-ready)

Team: `SMQ3T59TFL` · Bundle: `aftrveil.FlatFile` · Scheme: `FlatFile`
Checkout: `~/11-flatfile-app` (live). `~/06-flatfile-app` is nested dump only.

## Blockers found 2026-10-01 (PT)

### Done locally this session
- iOS archive **SUCCEEDED** → `/tmp/flatfile-archives/FlatFile-iOS.xcarchive`
- iOS export **SUCCEEDED** → `/tmp/flatfile-exports/iOS/FlatFile.ipa`
- Mac archive **SUCCEEDED** → `/tmp/flatfile-archives/FlatFile-Mac.xcarchive`
- Mac export: see log `/tmp/flatfile-archives/mac-export.log` (re-run §3 if needed)

### Upload blocked — no ASC API / notary credentials
Upload to App Store Connect / TestFlight **cannot finish from CLI** until Kate provides one of:

1. **App Store Connect API key** (preferred)
   - Place `AuthKey_<KEY_ID>.p8` in `~/.appstoreconnect/private_keys/`
   - Export: `APP_STORE_CONNECT_API_KEY_ID`, `APP_STORE_CONNECT_ISSUER_ID`
   - None of: `~/.appstoreconnect/private_keys`, `~/AuthKey*.p8`, ASC env vars
2. **Or** `xcrun notarytool store-credentials` / altool Apple ID + app-specific password
   - No Keychain profile `AC_PASSWORD` present (`notarytool` / `security` both miss it)
3. **Transporter.app** — not installed under `/Applications`

Ambient Apple ID auth (if any) is **not** usable for unattended upload — do not rely on it; use an API key.

IAP creation in ASC UI is a **Kate gate** (interactive login). Product id (paste-ready):

```
aftrveil.FlatFile.pro
```

Non-consumable, $9.99, name FlatFile Pro — see `LAUNCH.md` / `SUBMISSION_CHECKLIST.md`.

## 1) Archive iOS (Any iOS Device)

```bash
cd ~/11-flatfile-app
mkdir -p /tmp/flatfile-archives /tmp/flatfile-exports

xcodebuild archive \
  -project FlatFile.xcodeproj \
  -scheme FlatFile \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath /tmp/flatfile-archives/FlatFile-iOS.xcarchive \
  DEVELOPMENT_TEAM=SMQ3T59TFL \
  PRODUCT_BUNDLE_IDENTIFIER=aftrveil.FlatFile \
  -allowProvisioningUpdates
```

## 2) Archive Mac (Any Mac)

```bash
cd ~/11-flatfile-app

xcodebuild archive \
  -project FlatFile.xcodeproj \
  -scheme FlatFile \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -archivePath /tmp/flatfile-archives/FlatFile-Mac.xcarchive \
  DEVELOPMENT_TEAM=SMQ3T59TFL \
  PRODUCT_BUNDLE_IDENTIFIER=aftrveil.FlatFile \
  -allowProvisioningUpdates
```

## 3) Export for App Store Connect

Write ExportOptions once:

```bash
cat > /tmp/flatfile-archives/ExportOptions-appstore.plist <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>method</key>
	<string>app-store-connect</string>
	<key>teamID</key>
	<string>SMQ3T59TFL</string>
	<key>destination</key>
	<string>export</string>
	<key>signingStyle</key>
	<string>automatic</string>
	<key>uploadSymbols</key>
	<true/>
</dict>
</plist>
PLIST
```

```bash
xcodebuild -exportArchive \
  -archivePath /tmp/flatfile-archives/FlatFile-iOS.xcarchive \
  -exportPath /tmp/flatfile-exports/iOS \
  -exportOptionsPlist /tmp/flatfile-archives/ExportOptions-appstore.plist \
  -allowProvisioningUpdates

xcodebuild -exportArchive \
  -archivePath /tmp/flatfile-archives/FlatFile-Mac.xcarchive \
  -exportPath /tmp/flatfile-exports/Mac \
  -exportOptionsPlist /tmp/flatfile-archives/ExportOptions-appstore.plist \
  -allowProvisioningUpdates
```

## 4) Upload (after API key or Apple ID creds)

### ASC API key

```bash
# iOS IPA
xcrun altool --upload-app \
  --type ios \
  --file /tmp/flatfile-exports/iOS/FlatFile.ipa \
  --apiKey "$APP_STORE_CONNECT_API_KEY_ID" \
  --apiIssuer "$APP_STORE_CONNECT_ISSUER_ID"

# Mac (pkg or app from export)
xcrun altool --upload-app \
  --type macos \
  --file /tmp/flatfile-exports/Mac/FlatFile.pkg \
  --apiKey "$APP_STORE_CONNECT_API_KEY_ID" \
  --apiIssuer "$APP_STORE_CONNECT_ISSUER_ID"
```

Or open archives in Xcode Organizer → Distribute App → App Store Connect.

### Mac notarization (if distributing outside ASC)

```bash
xcrun notarytool submit /tmp/flatfile-exports/Mac/FlatFile.zip \
  --keychain-profile AC_PASSWORD --wait
```

## 5) Or: Xcode Organizer (interactive)

1. Open `FlatFile.xcodeproj` on the About-fix branch / main after merge
2. Product → Archive (iOS destination, then My Mac / Any Mac)
3. Organizer → Distribute → App Store Connect → Upload
