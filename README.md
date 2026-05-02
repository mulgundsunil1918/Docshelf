# DocShelf 🗂️

> **Your Document Shelf** — a privacy-first document vault for Indian households.

DocShelf is the single offline vault for every important family document — Aadhaar, PAN, ITR, sale deed, RC, marksheets, insurance, prescriptions — organized by who owns it (Self / Spouse / Kids / Parents) and what type it is. Biometric lock, expiry reminders, no cloud, no ads.

- **Local-first.** Files stay on your device. No accounts, no upload, no tracking.
- **Family profiles.** Each member gets their own document tree.
- **Expiry reminders.** Set an expiry date — DocShelf notifies you 30 days before.
- **Bank-grade lock.** Biometric or PIN, with auto-relock after backgrounding.

Built with Flutter for Android (iOS later).

---

## Stack

- Flutter 3.29+ / Dart 3.11+
- State: Provider
- Storage: SQLite (`sqflite`) + filesystem at `/storage/emulated/0/DocShelf/`
- File handling: `file_picker`, `share_plus`, `receive_sharing_intent`, `open_filex`
- Viewers: `pdfx`, `video_player` + `chewie`
- Auth: `local_auth` + SHA-256 PIN hash via `crypto`
- Reminders: `flutter_local_notifications` + `timezone`
- Theme: Material 3, Indigo `#3D5AFE` + Amber `#FFB300`, Nunito (`google_fonts`)

---

## Getting started

```bash
git clone https://github.com/mulgundsunil1918/Docshelf.git
cd Docshelf
flutter pub get
flutter run
```

Requires `minSdk 23` (Android 6.0+). Verified Flutter analyze: **0 issues**.

---

## Project layout

```
lib/
├── main.dart
├── data/
│   └── default_categories.dart   # 11 root categories + subs
├── models/                       # Document, Category, FamilyMember
├── services/                     # DB, file storage, auth, notifications, etc.
├── screens/                      # 17 screens (splash → settings)
├── widgets/                      # Pickers, sheets, thumbnails, coach marks
└── utils/                        # Colors, theme, constants
```

Full feature checklist lives in the original spec — every category, every screen, every reminder option is documented in the prompts that built it.

---

## Building a release APK

1. Generate a fresh keystore (do **not** reuse another app's):

   ```bash
   keytool -genkey -v -keystore android/app/docshelf-release.jks \
     -keyalg RSA -keysize 2048 -validity 10000 -alias docshelf
   ```

2. Create `key.properties` at the repo root (gitignored):

   ```properties
   storePassword=<your-store-password>
   keyPassword=<your-key-password>
   keyAlias=docshelf
   storeFile=app/docshelf-release.jks
   ```

3. Build:

   ```bash
   flutter build appbundle --release   # for Play Store
   # or
   flutter build apk --release         # for sideload testing
   ```

The release config in [`android/app/build.gradle.kts`](android/app/build.gradle.kts) auto-falls-back to debug signing if `key.properties` is absent, so the project builds out of the box.

---

## Privacy

DocShelf does not have a server. There is no account, no telemetry, no cloud sync in v1. Files live in `/storage/emulated/0/DocShelf/<MemberName>/<Category>/...` on your device. You can back them up via your usual phone backup; nothing is sent anywhere by the app.

---

## License

MIT © 2026 Sunil Mulgund · [mulgundsunil@gmail.com](mailto:mulgundsunil@gmail.com)
