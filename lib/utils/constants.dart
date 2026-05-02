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

  // ─── Default Space ids ──────────────────────────────────────────────
  static const String selfSpaceId = 'self';

  // ─── Reminders ──────────────────────────────────────────────────────
  static const int defaultReminderDays = 30;
  static const List<int> reminderDayOptions = [7, 14, 30, 60, 90];

  // ─── Onboarding flag keys (SharedPreferences) ───────────────────────
  static const String prefHasSeenTutorial = 'has_seen_tutorial';
  static const String prefHasCompletedSpaceSetup = 'has_completed_space_setup';
  static const String prefHasSeenCoachMarks = 'has_seen_coach_marks';
  static const String prefActiveSpaceId = 'active_space_id';
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

  // ─── Avatars (people + contexts — DocShelf is universal) ───────────
  static const List<String> avatarOptions = [
    '👤', '👨', '👩', '🧑', '👨‍🦱', '👩‍🦰', '🧓', '👴', '👵', '👦', '👧',
    '🧒', '👶', '💼', '🎓', '🏠', '🏢', '📚', '💻', '✏️', '🛠️', '🏥',
    '🚀', '🎨', '⭐',
  ];

  // ─── Home screen tips (rotating by day-of-month) ────────────────────
  /// Universal — covers personal, work, study, finance, vehicle, project,
  /// teaching, freelance. Whatever the user has in their life, there's a
  /// tip for it.
  static const List<String> homeTips = [
    '📖 The best vault is the one you actually use.',
    '🛡️ Your data never leaves this phone — that is the point.',
    '⏰ Set an expiry date on a contract or passport — DocShelf reminds you via your phone calendar.',
    '🗂️ Spaces let you keep work, study, family, and projects separate — switch with one tap.',
    '📥 Long-press any file in WhatsApp / Drive / Gmail → Share → DocShelf → done.',
    '⭐ Bookmark documents you grab often — they show up on Home.',
    '🚗 Vehicle docs (RC, insurance, PUC) and quotes for new cars all in one place.',
    '🩺 Old lab reports? Drop them in Health and forget about them — searchable forever.',
    '🧾 Tax season is calmer when bank statements + ITR are tagged and dated.',
    '🏠 Sale deeds, rent agreements, property tax — never lose them in old email threads.',
    '🎓 Students: keep assignments, marksheets, and project reports per semester.',
    '✏️ Teachers: lesson plans, syllabi, and student records in one Space per class.',
    '✈️ Visas, tickets, hotel bookings — all expire-trackable.',
    '💼 Offer letters, NDAs, payslips, performance reviews — your career file in one folder tree.',
    '🔍 Search scans names, descriptions, AND folder paths — find anything fast.',
    '🚗 Got a car quotation? Drop it in Quotations & Estimates — compare them later side-by-side.',
    '📦 Unsorted is fine — DocShelf doesn\'t force you to categorize on day one.',
    '🛡️ Insurance policies: life, motor, home, term — all in their own folder.',
    '🌙 Dark mode is in Settings → Appearance.',
    '💾 Files are stored in /DocShelf/ on your device — back up via your phone\'s normal backup.',
    '🛒 Receipts, warranty cards, manuals — Receipts & Warranties has you covered.',
    '🧑‍💻 Software people: keep license keys, tax invoices for SaaS, and contracts neatly tagged.',
    '🏥 Health Insurance card — Health → Insurance, expires reminded.',
    '☕ Like DocShelf? Buy us a chai from Settings — keeps it free for everyone.',
    '🌍 DocShelf works fully offline — no account, no cloud, no tracking.',
  ];
}
