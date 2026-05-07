# DocShelf 🗂️

> **Files organized · Offline** — a privacy-first document vault for everyone.

DocShelf is one offline vault for any important document you care about — contracts, passports, marksheets, payslips, NDAs, homework, car quotations, insurance policies, warranty cards, lease agreements, anything. Organize into **Spaces** you define (yourself, family, work, study, side project, a class you teach), tag with categories, set expiry reminders that hand off to your phone calendar.

- **Local-first.** Files stay on your device. No accounts, no upload, no tracking.
- **Spaces.** A Space is a top-level context — yourself, a family member, work, a project, a class. Each Space has its own folder tree.
- **14 starter categories.** Identity, Finance, Work, Education, Health, Insurance, Property, Vehicle, Bills, Receipts &amp; Warranties, Quotations, Travel, Family, Other. Add your own subfolders / categories anytime.
- **Calendar reminders.** Toggle expiry on a file → DocShelf opens your phone calendar with the event pre-filled. The OS handles delivery (survives reboots and battery savers).
- **Import from anywhere.** Long-press a WhatsApp / Drive / Gmail PDF → Share → DocShelf. Or scan device folders for files you already have.

Built with Flutter for Android (iOS later).

🌐 Marketing site &amp; docs: <https://mulgundsunil1918.github.io/Docshelf/>

---

## Stack

- Flutter 3.29+ / Dart 3.11+
- State: Provider
- Storage: SQLite (`sqflite`) + filesystem at `/storage/emulated/0/DocShelf/`
- File handling: `file_picker`, `share_plus`, `receive_sharing_intent`, `open_filex`
- Viewers: `pdfx`, `video_player` + `chewie`
- Reminders: `add_2_calendar` (system calendar hand-off — no local notification scheduling, no permissions, no battery-saver issues)
- Theme: Material 3, Indigo `#3D5AFE` + Amber `#FFB300`, Nunito (`google_fonts`)

---

## Getting started

```bash
cd Docshelf
flutter pub get
flutter run
```

Requires `minSdk 23` (Android 6.0+). Verified `flutter analyze`: **0 issues**.

---

## Project layout

```
lib/
├── main.dart
├── data/
│   └── default_categories.dart   # 14 root categories + subs
├── models/                       # Document, Category, Space
├── services/                     # DB, file storage, calendar, profile, etc.
├── screens/                      # ~16 screens (splash → settings)
├── widgets/                      # Pickers, sheets, thumbnails, coach marks
└── utils/                        # Colors, theme, constants
```

Full feature checklist + design rationale live in the prompts that built the project.

---

## Building a release APK / AAB

### One-time keystore setup (do this *before* your first Play upload)

```bash
# 1. Generate the upload keystore — do NOT reuse another app's keystore.
keytool -genkey -v \
  -keystore android/app/docshelf-upload.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias docshelf

# 2. Back the .jks file up to a separate place (1Password, encrypted USB,
#    second cloud account). Losing it means losing the ability to publish
#    updates ever again — there's no recovery.

# 3. Create android/key.properties (NOT repo root — gradle reads from
#    android/). Already in .gitignore. storeFile is RELATIVE to
#    android/app/, so write the bare filename, not "app/<file>".
cat > android/key.properties <<'EOF'
storePassword=<store-password>
keyPassword=<key-password>
keyAlias=docshelf
storeFile=docshelf-upload.jks
EOF

# 4. Sanity check the SHA-256 fingerprint (you'll need this to enrol in
#    Play App Signing inside Play Console).
keytool -list -v -keystore android/app/docshelf-upload.jks -alias docshelf
```

`android/app/build.gradle.kts` reads `android/key.properties` for the
release buildType and falls back to debug signing if the file is
absent — so the project builds locally even without secrets present
(CI-friendly).

**Verify before uploading to Play Console** — debug-signed AABs are
rejected. After every release build run:

```bash
unzip -p build/app/outputs/bundle/release/app-release.aab \
  META-INF/DOCSHELF.RSA | keytool -printcert | grep Owner
# Expected:  Owner: CN=DocShelf, OU=DocShelf, O=DocShelf, L=N/A, ST=N/A, C=IN
# REJECTED:  Owner: CN=Android Debug, ...
```

### Build commands

```bash
flutter build appbundle --release   # for Play Store (preferred)
flutter build apk --release         # for sideload testing
```

### Pre-flight checklist before every Play Console upload

- [ ] Bumped `version: x.y.z+N` in `pubspec.yaml`. **Every uploaded
      `versionCode` is permanently consumed by Play, even on rejection
      — bump on every retry.**
- [ ] Set `targetSdk` to whatever Play currently mandates (35 as of 2026).
- [ ] Privacy policy URL is reachable: <https://mulgundsunil1918.github.io/Docshelf/privacy.html>
- [ ] Release-build tested on a real device (not just emulator).
- [ ] Confirmed `key.properties` is not staged: `git status --ignored`.
- [ ] Enrolled in **Play App Signing** the first time — Google holds the
      real signing key, your `.jks` becomes a rotatable upload key.

---

## Privacy & data discipline

DocShelf does not have a server. There is no account, no telemetry, no
cloud sync, no in-app purchases, no ads. Files live in
`/storage/emulated/0/DocShelf/<Category>/…` on your device. The
`/DocShelf/` folder survives uninstalls so users keep their files.

The only way someone reaches your DocShelf folder is by holding your
unlocked phone — which means the only meaningful security boundary is
your phone's own lock screen. We don't pretend to add a second one on top.

**`allowBackup="false"` + custom `dataExtractionRules.xml`** opt the app
out of Google Auto Backup *and* Samsung Smart Switch — so a reinstall
on the same Google account doesn't silently restore old SharedPrefs and
the user-facing tutorial / coach marks re-show cleanly. The actual
files in `/DocShelf/` on shared storage transfer normally and survive.

`SharedPreferences` keys are version-stamped (`_v1` suffix) so a future
UX change can force the tutorial / coach marks to re-show even if a
backup ever did restore the old values.

---

## License

MIT © 2026 Sunil Mulgund · [mulgundsunil@gmail.com](mailto:mulgundsunil@gmail.com) · *Built in India, made for the world ❤️*
