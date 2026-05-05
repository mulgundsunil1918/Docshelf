import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../utils/app_colors.dart';
import '../utils/constants.dart';

/// "Support the developer" call-to-action.
///
/// Used at the bottom of the home screen and inside the Settings screen.
/// Tap → friendly dialog explaining why → "Open support page" launches
/// the URL in the user's browser. Never auto-launches without an
/// explicit second tap.
class SupportDeveloperButton extends StatelessWidget {
  const SupportDeveloperButton({
    super.key,
    this.compact = false,
  });

  /// `true` for the Settings list-tile variant; `false` for the big
  /// home-screen card.
  final bool compact;

  static Future<void> showSupportDialog(BuildContext context) async {
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Support the developer ❤️'),
        content: SingleChildScrollView(
          child: Text(
            'DocShelf is free, has no ads, and never sees your data.\n\n'
            "If it's saved you a frantic search for an old document — even "
            "once — please consider chipping in.\n\n"
            'Your support keeps the lights on, the servers running, and '
            'keeps me motivated to ship updates. Even a chai\'s worth helps. ☕\n\n'
            'Tap below to open the support page in your browser.',
            style: GoogleFonts.nunito(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              height: 1.45,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Maybe later'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(ctx).pop(true),
            icon: const Icon(Icons.favorite, size: 16),
            label: const Text('Open support page'),
          ),
        ],
      ),
    );
    if (proceed != true) return;
    final uri = Uri.parse(AppConstants.supportDeveloperUrl);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open support page — try again later.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return ListTile(
        leading: const Icon(Icons.favorite_outline, color: AppColors.danger),
        title: Text(
          'Support the developer',
          style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
        ),
        subtitle: const Text(
          'Chip in to keep DocShelf free, ad-free, and updated',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => showSupportDialog(context),
      );
    }

    return InkWell(
      onTap: () => showSupportDialog(context),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.accent.withValues(alpha: 0.20),
              AppColors.accent.withValues(alpha: 0.08),
            ],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: AppColors.accent.withValues(alpha: 0.42),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppColors.accent,
                shape: BoxShape.circle,
              ),
              child: const Text('❤️', style: TextStyle(fontSize: 22)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Support the developer',
                    style: GoogleFonts.nunito(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'DocShelf is free, ad-free, and tracker-free. Your support keeps it that way.',
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.gray,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.accentDark),
          ],
        ),
      ),
    );
  }
}
