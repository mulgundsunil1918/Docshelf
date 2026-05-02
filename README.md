# DocShelf 🗂️

> **Your Document Shelf** — a privacy-first document vault for everyone.

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
git clone https://github.com/mulgundsunil1918/Docshelf.git
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

DocShelf does not have a server. There is no account, no telemetry, no cloud sync, no in-app purchases, no ads. Files live in `/storage/emulated/0/DocShelf/<SpaceName>/<Category>/…` on your device. Backups are via your usual phone backup — DocShelf itself never transmits anything.

The only way someone reaches your DocShelf folder is by holding your unlocked phone — which means the only meaningful security boundary is your phone's own lock screen. We don't pretend to add a second one on top.

---

## License

MIT © 2026 Sunil Mulgund · [mulgundsunil@gmail.com](mailto:mulgundsunil@gmail.com) · *Built in India, made for the world ❤️*
