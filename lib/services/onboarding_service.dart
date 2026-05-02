import 'package:shared_preferences/shared_preferences.dart';

import '../utils/constants.dart';

/// Thin wrapper around `SharedPreferences` for first-launch flags + a few
/// small persisted preferences.
class OnboardingService {
  static final OnboardingService instance = OnboardingService._();
  OnboardingService._();

  SharedPreferences? _prefs;

  Future<SharedPreferences> _p() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  // ─── Tutorial / first-run gates ─────────────────────────────────────
  Future<bool> hasSeenTutorial() async =>
      (await _p()).getBool(AppConstants.prefHasSeenTutorial) ?? false;
  Future<void> markTutorialSeen() async =>
      (await _p()).setBool(AppConstants.prefHasSeenTutorial, true);
  Future<void> resetTutorial() async =>
      (await _p()).setBool(AppConstants.prefHasSeenTutorial, false);

  Future<bool> hasCompletedSpaceSetup() async =>
      (await _p()).getBool(AppConstants.prefHasCompletedSpaceSetup) ?? false;
  Future<void> markSpaceSetupComplete() async =>
      (await _p()).setBool(AppConstants.prefHasCompletedSpaceSetup, true);

  Future<bool> hasSeenCoachMarks() async =>
      (await _p()).getBool(AppConstants.prefHasSeenCoachMarks) ?? false;
  Future<void> markCoachMarksSeen() async =>
      (await _p()).setBool(AppConstants.prefHasSeenCoachMarks, true);
  Future<void> resetCoachMarks() async =>
      (await _p()).setBool(AppConstants.prefHasSeenCoachMarks, false);

  // ─── Active Space ───────────────────────────────────────────────────
  Future<String?> getActiveSpaceId() async =>
      (await _p()).getString(AppConstants.prefActiveSpaceId);
  Future<void> setActiveSpaceId(String id) async =>
      (await _p()).setString(AppConstants.prefActiveSpaceId, id);

  // ─── Theme mode ─────────────────────────────────────────────────────
  /// 'system' | 'light' | 'dark'
  Future<String> getThemeMode() async =>
      (await _p()).getString(AppConstants.prefThemeMode) ?? 'system';
  Future<void> setThemeMode(String mode) async =>
      (await _p()).setString(AppConstants.prefThemeMode, mode);

  // ─── Reminder default ───────────────────────────────────────────────
  Future<int> getDefaultReminderDays() async =>
      (await _p()).getInt(AppConstants.prefDefaultReminderDays) ??
      AppConstants.defaultReminderDays;
  Future<void> setDefaultReminderDays(int days) async =>
      (await _p()).setInt(AppConstants.prefDefaultReminderDays, days);
}
