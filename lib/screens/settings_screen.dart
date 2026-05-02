import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../main.dart';
import '../services/file_storage_service.dart';
import '../services/onboarding_service.dart';
import '../services/profile_service.dart';
import '../utils/app_colors.dart';
import '../utils/constants.dart';
import 'about_screen.dart';
import 'manage_family_screen.dart';
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
    final activeMember = context.watch<ProfileService>().activeMember;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 32),
        children: [
          // ─── Family ─────────────────────────────────────────────────
          _Section(title: '👨‍👩‍👧  Family', children: [
            ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.primary.withValues(alpha: 0.16),
                child: Text(activeMember?.avatar ?? '👤',
                    style: const TextStyle(fontSize: 22)),
              ),
              title: Text(activeMember?.name ?? '—'),
              subtitle: Text(activeMember?.relation.label ?? 'Active member'),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ManageFamilyScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.group_outlined),
              title: const Text('Manage family members'),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ManageFamilyScreen()),
                );
              },
            ),
          ]),

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
              onTap: () async {
                await OnboardingService.instance.resetCoachMarks();
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Coach marks will replay on Home.'),
                  ),
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

          // ─── Feedback ───────────────────────────────────────────────
          _Section(title: '💬  Feedback', children: [
            ListTile(
              leading: const Icon(Icons.email_outlined),
              title: const Text('Send feedback'),
              onTap: () => launchUrl(
                Uri.parse(
                    'mailto:${AppConstants.supportEmail}?subject=DocShelf%20feedback'),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.bug_report_outlined),
              title: const Text('Report a bug'),
              onTap: () => launchUrl(
                Uri.parse(
                    'mailto:${AppConstants.supportEmail}?subject=DocShelf%20bug%20report'),
              ),
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
              onTap: () => launchUrl(Uri.parse(AppConstants.playStoreUrl)),
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
            child: Column(
              children: [
                Text(
                  'Built in India, made for the world ❤️',
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.gray,
                  ),
                ),
              ],
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

  void _showHowToImport() {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('How to import'),
        content: const SingleChildScrollView(
          child: Text(
            '1) Tap "Import" on Home, pick any file.\n\n'
            '2) From WhatsApp/Gmail/Drive: tap a file → Share → DocShelf.\n\n'
            '3) Tap "Find on device" to scan WhatsApp/Telegram/Downloads for stuff you already have.\n\n'
            '4) Bulk-import a whole folder via the Library "+" → batch import.',
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
