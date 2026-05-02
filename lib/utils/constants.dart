/// App-wide constants for DocShelf.
///
/// Anything that might change between debug/release/play-listing lives here so
/// we never grep through the codebase for a hardcoded string.
class AppConstants {
  AppConstants._();

  // ─── Identity ───────────────────────────────────────────────────────
  static const String appName = 'DocShelf';
  static const String appTagline = 'Your Document Shelf';
  static const String packageId = 'com.docshelf.docshelf';

  // ─── Storage ────────────────────────────────────────────────────────
  /// Root folder created on the device's external storage.
  /// Final layout: /storage/emulated/0/DocShelf/<MemberName>/<Category>/<Subcategory>/
  static const String storageRoot = 'DocShelf';

  /// SQLite database filename (lives under app's private data dir).
  static const String dbFileName = 'docshelf.db';

  // ─── Default category ids ───────────────────────────────────────────
  /// Catch-all category when a document is moved out of a deleted category.
  static const String unsortedCategoryId = 'cat_other';

  // ─── Default profile ids ────────────────────────────────────────────
  static const String selfMemberId = 'self';

  // ─── Reminders ──────────────────────────────────────────────────────
  static const int defaultReminderDays = 30;
  static const List<int> reminderDayOptions = [7, 14, 30, 60, 90];

  // ─── Onboarding flag keys (SharedPreferences) ───────────────────────
  static const String prefHasSeenTutorial = 'has_seen_tutorial';
  static const String prefHasCompletedFamilySetup = 'has_completed_family_setup';
  static const String prefHasSeenCoachMarks = 'has_seen_coach_marks';
  static const String prefActiveMemberId = 'active_member_id';
  static const String prefThemeMode = 'theme_mode';
  static const String prefDefaultReminderDays = 'default_reminder_days';

  // ─── External links ─────────────────────────────────────────────────
  static const String supportEmail = 'mulgundsunil@gmail.com';
  static const String playStoreUrl =
      'https://play.google.com/store/apps/details?id=$packageId';
  static const String privacyPolicyUrl =
      'https://mulgundsunil1918.github.io/Docshelf/privacy.html';
  static const String termsUrl =
      'https://mulgundsunil1918.github.io/Docshelf/terms.html';
  static const String websiteUrl =
      'https://mulgundsunil1918.github.io/Docshelf/';

  // ─── Avatars (for family setup) ─────────────────────────────────────
  static const List<String> avatarOptions = [
    '👨', '👩', '🧑', '👨‍🦱', '👩‍🦰', '🧓', '👴', '👵',
    '👦', '👧', '🧒', '👶',
  ];

  // ─── Home screen tips (rotating by day-of-month) ────────────────────
  static const List<String> homeTips = [
    '📖 The best vault is the one you actually use.',
    '🔐 Your data never leaves this phone — that is the point.',
    '⏰ Set an expiry date on your passport — DocShelf will remind you.',
    '👨‍👩‍👧 Add your spouse and parents — every document, every member.',
    '📥 Long-press a WhatsApp PDF → Share → DocShelf → done.',
    '🗂️ Bookmark documents you grab often — they show up on Home.',
    '🚗 RC, PUC, insurance — keep all vehicle docs in one tap.',
    '🩺 Lab reports older than 2 years can usually be archived.',
    '🧾 Filing taxes? Bank statements live under Finance → Bank.',
    '🏠 Sale deeds in Property — never lose them in old folders again.',
    '🎓 Marksheets here means no more frantic searches before interviews.',
    '✈️ Visas expire — DocShelf reminds you 30 days before.',
    '🛡️ Health insurance card — Health → Insurance.',
    '🪪 Driving license renewal? Vehicle → License.',
    '💼 Keep payslips for the last 3 months — banks ask for them.',
    '📑 Tip: Notes work too — store quick reminders alongside docs.',
    '🔍 Use Search — it scans names, descriptions, and folders.',
    '👨‍👩‍👧 Switch family member at the top — instantly see their docs.',
    '📦 Unsorted category exists for that one weird document.',
    '🏥 Prescription history lives in Health → Prescriptions.',
    '⭐ Bookmark frequently used docs — Aadhaar, PAN, etc.',
    '🌙 Dark mode is in Settings → Appearance.',
    '💾 Files are stored in /DocShelf/ on your device — back up anytime.',
    '🧓 Parents documents in your hand — peace of mind.',
    '☕ Like DocShelf? Buy us a chai from the Settings screen.',
  ];
}
