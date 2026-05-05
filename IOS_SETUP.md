# DocShelf — iOS / App Store Setup Guide

End-to-end checklist for shipping DocShelf to TestFlight + the App
Store via Codemagic. Cross-references back to the audit you ran.

---

## 1. Build & config — at a glance

| Item | Value |
|---|---|
| Bundle id | `com.docshelf.myapp` (matches Android) |
| Display name | DocShelf |
| iOS deployment target | 13.0 |
| Xcode | latest (Codemagic auto) |
| Cocoapods | default channel |
| Privacy manifest | `ios/Runner/PrivacyInfo.xcprivacy` ✓ |
| App Sandbox | yes — Files-app visible (`UIFileSharingEnabled` + `LSSupportsOpeningDocumentsInPlace`) |
| iPad support | yes (universal — DocShelf is portrait-locked but works on iPad) |

All of the above are already wired in `ios/Runner/Info.plist`,
`ios/Podfile`, `ios/Runner.xcodeproj/project.pbxproj`. **Don't edit by
hand on macOS** — open `ios/Runner.xcworkspace` after `pod install`,
let Xcode resolve, then close.

---

## 2. Permissions — what we declare and why

Apple rejects vague permission strings. Each entry below is:
1. Action-oriented ("only when you tap…")
2. Explicit about what we **don't** do (no upload, no scanning of unrelated content)
3. Tied to a real user-facing feature

| Key | Purpose |
|---|---|
| `NSCameraUsageDescription` | Document scanner (cunning_document_scanner — on-device ML Kit / VisionKit) |
| `NSPhotoLibraryUsageDescription` | File picker → import existing photos |
| `NSPhotoLibraryAddUsageDescription` | Optional save-back when user exports |
| `NSMicrophoneUsageDescription` | Reserved for audio notes (not yet shipped — string warns reviewers about why mic access is requested only on tap) |
| `NSCalendarsUsageDescription` | Expiry reminders (`add_2_calendar`) |
| `NSDocumentsFolderUsageDescription` | The vault itself (`/DocShelf/` under the app's sandbox) |
| `NSFaceIDUsageDescription` | Reserved for an optional app-lock; not active in v0.2 |

### Restricted on iOS

| Feature | Status on iOS |
|---|---|
| Cross-app folder scanning ("Find on Device" → WhatsApp / Drive folders) | **Disabled.** iOS sandboxes every app; we cannot read others' folders. The screen now shows a hint pointing users to Files.app + Share. |
| `MANAGE_EXTERNAL_STORAGE` equivalent | N/A. Files live under `/var/mobile/.../Documents/DocShelf/` and are visible in Files.app via `UIFileSharingEnabled`. |
| Background `flutter_local_notifications` | Removed earlier; we use `add_2_calendar` (no permission needed beyond Calendars). |

---

## 3. Privacy Manifest

Apple required this from May 2024. We declare:

- `NSPrivacyTracking = false` — no IDFA, no analytics
- `NSPrivacyCollectedDataTypes = []` — we collect nothing
- `NSPrivacyAccessedAPITypes`:
  - `FileTimestamp` (reason `C617.1` — populating "Date saved")
  - `UserDefaults` (reason `CA92.1` — onboarding flags / theme prefs)
  - `DiskSpace` (reason `E174.1` — formatting "1.4 MB" labels)
  - `SystemBootTime` (reason `35F9.1` — Flutter / shared_preferences internal)

If you add a network SDK later (Sentry, Firebase, Mixpanel), append
matching declarations to `PrivacyInfo.xcprivacy` AND update the App
Store Privacy questionnaire.

---

## 4. Codemagic flow

`codemagic.yaml` at the repo root defines two workflows:

### `ios-release`
- Trigger: git tag matching `v*` (e.g. `git tag v0.2.0+12 && git push origin v0.2.0+12`)
- Signs via App Store Connect API integration (set up in Codemagic UI under **Integrations → App Store Connect → API key**)
- Builds `flutter build ipa`, uploads to TestFlight under the **Internal** beta group
- `submit_to_app_store: false` until you've manually verified the first TestFlight build, then flip it on

### `android-release`
- Same trigger pattern
- Uses your `docshelf_keystore` upload key (upload `android/app/docshelf-upload.jks` + password from `.secrets/UPLOAD_KEYSTORE_PASSWORD.txt` to Codemagic → **Code-signing identities → Android keystores**)
- Pushes AAB to Play Internal track as a **draft** (so you can promote manually)

### Codemagic one-time setup
1. Connect the GitHub repo at app.codemagic.io.
2. **Integrations → App Store Connect**: upload an API key (Issuer ID, Key ID, .p8 file). Name it `codemagic-app-store-connect`.
3. **Code-signing identities → iOS**: enable automatic signing for `com.docshelf.myapp`.
4. **Code-signing identities → Android**: upload `docshelf-upload.jks` with alias `docshelf` + the password.
5. **Environment variables**:
   - `GCLOUD_SERVICE_ACCOUNT_CREDENTIALS` (Play Console service account JSON, secured)
   - `APP_STORE_APPLE_ID` (numeric, after creating the app in App Store Connect)
6. Push a tag → Codemagic picks it up → IPA + AAB both build.

---

## 5. App Store Connect listing — ready-to-paste copy

### App Name (max 30 chars)
```
DocShelf — Document Vault
```

### Subtitle (max 30 chars)
```
Files organized · Offline
```

### Promotional Text (max 170 chars, can change without resubmit)
```
Scan paper, import from anywhere, file into 14 ready-made folders, write rich notes, calendar reminders for what expires. Local-first. No accounts, ever.
```

### Description (max 4000 chars)
```
DocShelf — every important document of your life, in one offline vault on your phone.

⚡ The chaos: passports in Mail, contracts in Drive, marksheets in WhatsApp, car quotations on someone's USB stick. The fix: one private, offline vault that scans, organises, searches, and reminds — without uploading a thing.

▸ ON-DEVICE DOCUMENT SCANNER
Tap Scan, point at any paper document, and the camera auto-detects edges, fixes perspective, and enhances contrast. Multi-page captures stitch into a single PDF automatically. All processing on-device — no images leave your phone.

▸ IMPORT FROM ANYWHERE
Pick a single file, multiple files, or share into DocShelf from any other app — Files, Mail, Messages, Drive. The native iOS share sheet works everywhere.

▸ 14 STARTER FOLDERS
Identity, Finance, Work, Education, Health, Insurance & Policies, Property, Vehicle, Bills, Receipts & Warranties, Quotations & Estimates, Travel, Family, Other. Add your own subfolders or whole new categories anytime. Delete defaults you don't need — DocShelf is fully customisable.

▸ RICH-TEXT NOTES BUILT IN
Bold, italic, underline, strike, highlight, headings, bullet & numbered lists, checkboxes, quote blocks. Pick a sticky-note background colour. Notes save alongside your documents in the same folder tree.

▸ CALENDAR REMINDERS FOR WHAT EXPIRES
Toggle "expiry date" on a passport, insurance, lease, license — DocShelf adds an event to your iPhone calendar. The OS handles the alert. Survives reboots, low-power mode, everything.

▸ SEARCH THAT ACTUALLY FINDS
Search across file names, your descriptions, AND folder paths. Filter by file type. Find any document in seconds.

KEY FEATURES
• Fully offline — no account, no cloud, no tracking, no ads
• On-device document scanner (VisionKit / ML Kit)
• Single, multi, or share-from-any-app import
• 14 starter folders + unlimited subfolders + delete-anything
• Rich-text note editor with markdown
• Calendar-based expiry reminders
• Bookmarks, descriptions, expiry dates on every file
• Material 3 design with intentional dark mode
• Files visible in the Files app — yours to keep
• Files survive reinstall — your data is yours
• Open-source on GitHub

▸ WHO IT'S FOR
DocShelf is built for anyone with documents:
• Households juggling IDs, sale deeds, marksheets, bills
• Professionals tracking contracts, NDAs, payslips, performance reviews
• Students & teachers managing assignments, marksheets, lesson plans
• Anyone comparing car quotations, repair estimates, vendor bids
• Anyone tired of cloud subscription apps reading their data

▸ PRIVATE BY DESIGN
DocShelf has no server. There is no telemetry, no analytics, no cloud sync, no in-app purchases, no ads, no accounts. Files live on your iPhone only. Privacy policy at https://mulgundsunil1918.github.io/Docshelf/privacy.html — read it, the source code is open on GitHub.

▸ FREE
DocShelf is free. Optional "Buy me a chai" support tile if you'd like to chip in — keeps it that way.

DocShelf. Files organized · Offline.
```

### Keywords (100 chars, comma-separated, no spaces around commas)
```
document scanner,offline,vault,pdf,organizer,paperless,scan,storage,private,manager,files,reminder
```

### Support URL
```
https://mulgundsunil1918.github.io/Docshelf/
```

### Marketing URL (optional)
```
https://mulgundsunil1918.github.io/Docshelf/
```

### Privacy Policy URL (REQUIRED)
```
https://mulgundsunil1918.github.io/Docshelf/privacy.html
```

### Category
- **Primary**: Productivity
- **Secondary**: Utilities

(Avoid Medical / Finance / Business — Apple holds those to additional review and DocShelf isn't industry-specific.)

### Age Rating
4+ (no questionable content, no violence, no user-generated public content)

### App Privacy questionnaire (App Store Connect → App Privacy)
Answer every section as **"Data Not Collected."** When asked "Do you use third-party SDKs that collect data?" — **No** (we use no analytics, no ad SDKs, no Firebase).

---

## 6. Screenshot strategy (5 screenshots — iPhone 6.9″, required)

App Store accepts the same image set across screen sizes — you only
need to upload one set at the largest required size: **iPhone 6.9″
(1290 × 2796)**.

### Screenshot order (carousel reads left → right)

| # | Title | Subtitle | UI shown |
|---|---|---|---|
| 1 | "Every important document, in one offline vault" | "Files organized · Offline" | Hero — DocShelf wordmark + 3 stacked-paper icons (the existing `phone-1-intro.png` from the Play asset pack, just resized for iPhone 6.9″) |
| 2 | "Scan paper documents" | "Auto-edge detection. Perspective fixed. Multi-page → one PDF." | Camera scanner viewfinder mock with amber corner brackets — `phone-3-scan.png` from the asset pack |
| 3 | "Import from anywhere" | "Single file. Multiple files. Or an entire folder. Or share-to from any app." | Import sheet open over Home — `phone-4-import.png` |
| 4 | "14 folders, fully customisable" | "Identity · Finance · Work · Education · Insurance · Receipts · …" | Library 2-col grid with emojis — `phone-5-categories.png` |
| 5 | "Rich-text notes built in" | "Bold · italic · highlight · headings · lists — all on-device" | Note editor with formatted text + colour palette — `phone-6-notes.png` |

### Generation
Re-run the existing pipeline with the iPhone aspect ratio:

```bash
PYTHONIOENCODING=utf-8 python tools/play_assets.py
# Then resize the phone-*.png variants to 1290×2796 with a
# letterboxed deep-navy frame. Add an `iphone-N.png` set to
# play-assets/.
```

(If you want me to add the iPhone-size emitter to `play_assets.py`,
say "ship iphone screenshots" and I'll extend the script.)

---

## 7. Common rejection traps — and how this build avoids each

| Apple-rejection reason | How we prevent it |
|---|---|
| Vague permission strings | Every `NS*UsageDescription` names the user-facing feature + promises what we don't do (above) |
| Camera/mic permission requested upfront | `cunning_document_scanner` only requests Camera at the moment the user taps Scan |
| Missing privacy manifest | `PrivacyInfo.xcprivacy` shipped with required-reason API codes |
| Missing privacy policy URL | Hosted at `mulgundsunil1918.github.io/Docshelf/privacy.html` (with CAMERA disclosure) |
| Wrong Data Privacy answers vs actual SDK behaviour | Zero analytics SDKs; "Data Not Collected" is honest |
| Crash on launch | Plain Flutter + offline only; no Firebase init that could fail; ATS default suffices |
| Demo / placeholder content | All copy is real (no "Lorem ipsum") |
| Misleading metadata | Description matches reality, no "for medical professionals only" or other niche claims |
| In-app purchase strings without IAP | None declared. The "Buy me a chai" tile opens an external UPI link via Safari — Apple discourages but allows it for non-digital-goods donations. If review pushes back, replace with a "Visit our site" button. |
| Sign-in screen with no Apple Sign-In | DocShelf has **no sign-in screen**. Apple's Sign-In with Apple requirement only applies if you offer 3rd-party sign-in. We don't. |
| Background modes claimed but not used | We declare none. Don't enable Background Fetch / Remote Notifications in Xcode. |
| Cross-app folder scanning (would be flagged) | `Platform.isIOS` guard now shows a "use Files / Share" hint instead of attempting to scan |

---

## 8. Pre-flight before tagging

```bash
# In repo root, on a Mac (or Codemagic build env):
cd ios
pod install --repo-update
cd ..
flutter clean
flutter pub get
flutter analyze lib            # must show "No issues found!"
flutter build ipa --release    # must succeed
```

If any pod fails to resolve, the most common fix is:
```bash
cd ios
rm -rf Pods Podfile.lock
pod install --repo-update
```

If Xcode complains about missing simulator architecture during local
testing, that's the `EXCLUDED_ARCHS[sdk=iphonesimulator*] = arm64`
line in our `Podfile`'s `post_install` — already set.

---

## 9. Tag → ship

```bash
# Bump pubspec to next version (e.g. 0.3.0+13)
git add pubspec.yaml
git commit -m "Bump to v0.3.0+13"
git tag v0.3.0+13
git push origin main --tags
```

Codemagic picks up the tag, runs both workflows in parallel:
- iOS → IPA → TestFlight Internal group → email when ready to test
- Android → AAB → Play Internal track (draft) → email when uploaded

Test on TestFlight, promote to App Store from the App Store Connect
UI when satisfied.

---

## 10. Error-handling (when Codemagic fails)

| Symptom | Most-likely cause | Fix |
|---|---|---|
| `pod install` errors with "CocoaPods could not find compatible versions for pod X" | Stale Podfile.lock | Delete `ios/Podfile.lock`, re-run |
| `xcodebuild` fails with "No profiles for 'com.docshelf.myapp' were found" | App Store Connect API integration not set up correctly | In Codemagic → Integrations → re-add the API key with full access |
| `xcodebuild` fails with "Bitcode is no longer accepted" | Old plugin still has bitcode flag | Already disabled in our `Podfile` post_install (`ENABLE_BITCODE = NO`) |
| `flutter build ipa` fails with "ld: symbol(s) not found for arch arm64" | Pod missing arm64 slice | Already excluded in Podfile (`EXCLUDED_ARCHS[sdk=iphonesimulator*] = arm64`) |
| `permission_handler` warning about unused permission | Macro mismatch | Adjust the `PERMISSION_*` macro list in `ios/Podfile`'s post_install |
| App Store rejects with "missing usage description for X" | New plugin added that requires it | Add corresponding `NSXUsageDescription` to `Info.plist` |
| App Store rejects with "missing privacy manifest declarations" | New SDK accesses required-reason API | Add the matching entry to `ios/Runner/PrivacyInfo.xcprivacy` |

Send the failing log; I'll diagnose root cause + fix.
