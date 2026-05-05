import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/constants.dart';

/// Wraps Google's in-app review API with our own rate-limiting:
///
///   - Don't ask before the install is 3 days old (no premature begging).
///   - Don't ask more than once every 7 days.
///   - Google rate-limits the dialog server-side anyway, so the 7-day
///     ask is safe to call from `MainShell.initState` without the user
///     ever seeing it more than they should.
class ReviewService {
  static final ReviewService instance = ReviewService._();
  ReviewService._();

  final InAppReview _api = InAppReview.instance;

  static const _minInstallAge = Duration(days: 3);
  static const _minBetweenPrompts = Duration(days: 7);

  /// Records the install timestamp on first call. Returns the recorded
  /// timestamp (creating it if needed).
  Future<DateTime> _ensureInstalledAt(SharedPreferences prefs) async {
    final stored = prefs.getInt(AppConstants.prefInstalledAt);
    if (stored != null) {
      return DateTime.fromMillisecondsSinceEpoch(stored);
    }
    final now = DateTime.now();
    await prefs.setInt(AppConstants.prefInstalledAt, now.millisecondsSinceEpoch);
    return now;
  }

  /// Manual trigger from the Settings "Rate the app" tile. Always tries
  /// to launch — Google's server-side rate-limit decides whether to
  /// actually show the dialog.
  Future<void> requestExplicit() async {
    if (await _api.isAvailable()) {
      await _api.requestReview();
    } else {
      await _api.openStoreListing(appStoreId: AppConstants.packageId);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      AppConstants.prefLastReviewPromptAt,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// Auto-prompt entry point — call once from `MainShell.initState`.
  /// Silently returns without prompting if any gate fails.
  Future<void> maybePromptAutomatically() async {
    final prefs = await SharedPreferences.getInstance();
    final installedAt = await _ensureInstalledAt(prefs);
    final now = DateTime.now();

    if (now.difference(installedAt) < _minInstallAge) return;

    final lastMs = prefs.getInt(AppConstants.prefLastReviewPromptAt);
    if (lastMs != null) {
      final last = DateTime.fromMillisecondsSinceEpoch(lastMs);
      if (now.difference(last) < _minBetweenPrompts) return;
    }

    if (!await _api.isAvailable()) return;
    await _api.requestReview();
    await prefs.setInt(
      AppConstants.prefLastReviewPromptAt,
      now.millisecondsSinceEpoch,
    );
  }
}
