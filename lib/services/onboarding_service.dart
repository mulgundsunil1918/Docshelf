import 'package:flutter/foundation.dart';
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

  // ─── Cross-screen signals ───────────────────────────────────────────
  /// Bumped when the user taps "Replay walkthrough" in Settings. The
  /// HomeScreen subscribes and triggers the coach-mark overlay.
  final ValueNotifier<int> coachMarkReplaySignal = ValueNotifier<int>(0);
  void requestCoachMarkReplay() => coachMarkReplaySignal.value++;

  /// Used by Settings to switch the bottom-nav tab without a Navigator hack.
  /// MainShell listens and updates its `_index`. -1 means "no request".
  final ValueNotifier<int> activeTabRequest = ValueNotifier<int>(-1);
  void requestActiveTab(int index) {
    activeTabRequest.value = index;
  }

  // ─── Tutorial / first-run gates ─────────────────────────────────────
  Future<bool> hasSeenTutorial() async =>
      (await _p()).getBool(AppConstants.prefHasSeenTutorial) ?? false;
  Future<void> markTutorialSeen() async =>
      (await _p()).setBool(AppConstants.prefHasSeenTutorial, true);
  Future<void> resetTutorial() async =>
      (await _p()).setBool(AppConstants.prefHasSeenTutorial, false);

  Future<bool> hasSeenCoachMarks() async =>
      (await _p()).getBool(AppConstants.prefHasSeenCoachMarks) ?? false;
  Future<void> markCoachMarksSeen() async =>
      (await _p()).setBool(AppConstants.prefHasSeenCoachMarks, true);
  Future<void> resetCoachMarks() async =>
      (await _p()).setBool(AppConstants.prefHasSeenCoachMarks, false);

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

  // ─── Hidden default categories ──────────────────────────────────────
  /// IDs of built-in folders the user has "deleted" (we hide them
  /// rather than touch the read-only default tree). See [CategoryService].
  Future<Set<String>> getHiddenDefaultCategories() async {
    final list =
        (await _p()).getStringList(AppConstants.prefHiddenDefaultCategories);
    return (list ?? const <String>[]).toSet();
  }

  Future<void> setHiddenDefaultCategories(Set<String> ids) async {
    await (await _p()).setStringList(
      AppConstants.prefHiddenDefaultCategories,
      ids.toList(),
    );
  }
}
