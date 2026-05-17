import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../main.dart';
import '../services/category_service.dart';
import '../services/document_notifier.dart';
import '../services/file_storage_service.dart';
import '../services/onboarding_service.dart';
import '../services/review_service.dart';
import '../utils/app_colors.dart';
import '../utils/constants.dart';
import '../widgets/support_developer_button.dart';
import 'about_screen.dart';
import 'faq_screen.dart';
import 'tutorial_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _defaultReminder = 30;
  String _version = '0.1.0';
  int _storageBytes = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final ob = OnboardingService.instance;
    final reminder = await ob.getDefaultReminderDays();
    final info = await PackageInfo.fromPlatform();
    final size = await FileStorageService.instance.getTotalStorageUsed();
    if (!mounted) return;
    setState(() {
      _defaultReminder = reminder;
      _version = '${info.version}+${info.buildNumber}';
      _storageBytes = size;
    });
  }

  String _fmt(int b) {
    if (b < 1024) return '$b B';
    if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)} KB';
    if (b < 1024 * 1024 * 1024) {
      return '${(b / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(b / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeNotifier>();
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 32),
        children: [
          // ─── Reminders ──────────────────────────────────────────────
          _Section(title: '⏰  Reminders', children: [
            ListTile(
              leading: const Icon(Icons.event_outlined),
              title: const Text('How reminders work'),
              subtitle: const Text(
                'When you set an expiry date on a file, DocShelf adds an event to your phone calendar — your normal calendar app handles the alert.',
              ),
              isThreeLine: true,
            ),
            ListTile(
              leading: const Icon(Icons.notifications_active_outlined),
              title: const Text('Default reminder lead-time'),
              subtitle: Text('$_defaultReminder days before expiry'),
              onTap: _pickReminder,
            ),
          ]),

          // ─── Appearance ─────────────────────────────────────────────
          _Section(title: '🎨  Appearance', children: [
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'system', label: Text('System')),
                  ButtonSegment(value: 'light', label: Text('Light')),
                  ButtonSegment(value: 'dark', label: Text('Dark')),
                ],
                selected: {theme.key},
                onSelectionChanged: (s) => theme.setKey(s.first),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.replay_outlined),
              title: const Text('Replay walkthrough'),
              subtitle: const Text(
                'Tap to switch to Home and re-show the coach marks.',
              ),
              onTap: _replayWalkthrough,
            ),
          ]),

          // ─── Folders ────────────────────────────────────────────────
          _Section(title: '🗂️  Folders', children: [
            Consumer<CategoryService>(
              builder: (context, cats, _) {
                final hiddenCount = cats.hiddenDefaults.length;
                return ListTile(
                  leading: const Icon(Icons.restore_outlined),
                  title: const Text('Restore default folders'),
                  subtitle: Text(
                    hiddenCount == 0
                        ? "Bring back any built-in folders you've deleted."
                        : "$hiddenCount built-in folder${hiddenCount == 1 ? '' : 's'} currently hidden — tap to restore.",
                  ),
                  enabled: hiddenCount > 0,
                  onTap: hiddenCount == 0 ? null : _restoreDefaults,
                );
              },
            ),
          ]),

          // ─── Help ───────────────────────────────────────────────────
          _Section(title: '📚  Help', children: [
            ListTile(
              leading: const Icon(Icons.school_outlined),
              title: const Text('View tutorial'),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const TutorialScreen(fromSettings: true),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.help_outline),
              title: const Text('Help & FAQs'),
              subtitle: const Text('14 quick answers, all offline'),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const FaqScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.import_export_outlined),
              title: const Text('How to import'),
              onTap: _showHowToImport,
            ),
          ]),

          // ─── About ──────────────────────────────────────────────────
          _Section(title: 'ℹ️  About', children: [
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('About DocShelf'),
              subtitle: Text('v$_version'),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AboutScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.privacy_tip_outlined),
              title: const Text('Privacy policy'),
              onTap: () =>
                  launchUrl(Uri.parse(AppConstants.privacyPolicyUrl)),
            ),
            ListTile(
              leading: const Icon(Icons.gavel_outlined),
              title: const Text('Terms of use'),
              onTap: () => launchUrl(Uri.parse(AppConstants.termsUrl)),
            ),
          ]),

          // ─── Support ────────────────────────────────────────────────
          _Section(title: '❤️  Support', children: const [
            SupportDeveloperButton(compact: true),
          ]),

          // ─── Feedback ───────────────────────────────────────────────
          _Section(title: '💬  Feedback', children: [
            ListTile(
              leading: const Icon(Icons.email_outlined),
              title: const Text('Send feedback'),
              onTap: () => _mailto('DocShelf feedback'),
            ),
            ListTile(
              leading: const Icon(Icons.lightbulb_outline),
              title: const Text('Suggest a feature'),
              onTap: () => _mailto('DocShelf — feature request'),
            ),
            ListTile(
              leading: const Icon(Icons.bug_report_outlined),
              title: const Text('Report a bug'),
              onTap: _reportBug,
            ),
            ListTile(
              leading: const Icon(Icons.share_outlined),
              title: const Text('Share with friends'),
              onTap: () => Share.share(
                'DocShelf — every important document in one offline vault. ${AppConstants.playStoreUrl}',
              ),
            ),
            ListTile(
              leading: const Icon(Icons.star_outline),
              title: const Text('Rate the app'),
              onTap: () => ReviewService.instance.requestExplicit(),
            ),
          ]),

          // ─── Storage ────────────────────────────────────────────────
          _Section(title: '📊  Storage', children: [
            ListTile(
              leading: const Icon(Icons.sd_storage_outlined),
              title: const Text('DocShelf storage used'),
              subtitle: Text(_fmt(_storageBytes)),
            ),
          ]),

          const SizedBox(height: 16),
          Center(
            child: Text(
              'Built in India, made for the world ❤️',
              style: GoogleFonts.nunito(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.gray,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickReminder() async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final d in AppConstants.reminderDayOptions)
              ListTile(
                title: Text('$d days before'),
                trailing: d == _defaultReminder
                    ? const Icon(Icons.check, color: AppColors.primary)
                    : null,
                onTap: () => Navigator.of(context).pop(d),
              ),
          ],
        ),
      ),
    );
    if (picked != null) {
      await OnboardingService.instance.setDefaultReminderDays(picked);
      setState(() => _defaultReminder = picked);
    }
  }

  /// Brings back any built-in folders the user has hidden via Library →
  /// Edit → Delete. Documents that had moved to Other / Unsorted stay
  /// where they are — we can't trace which ones came from where.
  Future<void> _restoreDefaults() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Restore default folders?'),
        content: const Text(
          'All built-in folders will reappear in your Library. '
          'Documents currently in Other / Unsorted stay there — DocShelf '
          'cannot tell which ones came from which folder.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await CategoryService.instance.restoreAllDefaults();
    DocumentNotifier.instance.notifyDocumentChanged();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Default folders restored ✓')),
    );
  }

  /// Resets the coach-marks-seen flag, switches to the Home tab, and
  /// fires the replay signal so HomeScreen actually re-shows the overlay.
  Future<void> _replayWalkthrough() async {
    await OnboardingService.instance.resetCoachMarks();
    OnboardingService.instance.requestCoachMarkReplay();
    OnboardingService.instance.requestActiveTab(0);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Walkthrough restarting on Home…')),
    );
  }

  /// Builds a `mailto:` URI with subject + body properly query-encoded
  /// via `Uri.encodeQueryComponent` (Uri's default encoder converts
  /// spaces to '+', which some mail clients fail to round-trip).
  Uri _buildMailto({required String subject, String? body}) {
    final params = <String>['subject=${Uri.encodeQueryComponent(subject)}'];
    if (body != null) {
      params.add('body=${Uri.encodeQueryComponent(body)}');
    }
    return Uri.parse(
      'mailto:${AppConstants.supportEmail}?${params.join('&')}',
    );
  }

  Future<void> _mailto(String subject) async {
    await launchUrl(
      _buildMailto(subject: subject),
      mode: LaunchMode.externalApplication,
    );
  }

  /// Bug-report mailto with version + platform pre-filled in the body
  /// — saves a back-and-forth with the user later.
  Future<void> _reportBug() async {
    final platformLine = Platform.isAndroid
        ? 'Android ${Platform.operatingSystemVersion}'
        : 'iOS ${Platform.operatingSystemVersion}';
    final body = '''
[Describe the bug here]


───── Auto-included ─────
App version: $_version
Platform: $platformLine
''';
    await launchUrl(
      _buildMailto(subject: 'DocShelf — bug report', body: body),
      mode: LaunchMode.externalApplication,
    );
  }

  void _showHowToImport() {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('How to import'),
        content: const SingleChildScrollView(
          child: Text(
            '1) Tap "Import" on Home — pick a single file, multiple files, or an entire folder.\n\n'
            '2) From WhatsApp/Gmail/Drive: tap a file → Share → DocShelf.\n\n'
            '3) Tap "Find" to scan WhatsApp/Telegram/Downloads/Documents for files you already have.\n\n'
            '4) Tap "Scan" to capture a paper document with your camera — auto-cropped and enhanced like a scanner.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
              child: Text(
                title,
                style: GoogleFonts.nunito(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                  color: AppColors.gray,
                ),
              ),
            ),
            ...children,
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }
}
