import 'package:flutter/foundation.dart';

import '../models/space.dart';
import 'database_service.dart';
import 'onboarding_service.dart';

/// Holds the active Space + the full Space list. Persists the selected
/// Space across app launches.
class ProfileService extends ChangeNotifier {
  static final ProfileService instance = ProfileService._();
  ProfileService._();

  final List<Space> _spaces = [];
  Space? _active;

  List<Space> get spaces => List.unmodifiable(_spaces);
  Space? get activeSpace => _active;
  bool get hasSpaces => _spaces.isNotEmpty;

  Future<void> load() async {
    final list = await DatabaseService.instance.getAllSpaces();
    _spaces
      ..clear()
      ..addAll(list);
    final saved = await OnboardingService.instance.getActiveSpaceId();
    Space? matched;
    if (saved != null) {
      for (final s in _spaces) {
        if (s.id == saved) {
          matched = s;
          break;
        }
      }
    }
    _active = matched ?? (_spaces.isEmpty ? null : _spaces.first);
    if (_active != null && _active!.id != saved) {
      await OnboardingService.instance.setActiveSpaceId(_active!.id);
    }
    notifyListeners();
  }

  Future<void> setActiveSpace(String id) async {
    final s = _spaces.firstWhere(
      (s) => s.id == id,
      orElse: () => _spaces.first,
    );
    _active = s;
    await OnboardingService.instance.setActiveSpaceId(s.id);
    notifyListeners();
  }

  Future<Space> addSpace(Space s) async {
    await DatabaseService.instance.saveSpace(s);
    _spaces.add(s);
    if (_active == null) {
      _active = s;
      await OnboardingService.instance.setActiveSpaceId(s.id);
    }
    notifyListeners();
    return s;
  }

  Future<void> updateSpace(Space s) async {
    await DatabaseService.instance.saveSpace(s);
    final idx = _spaces.indexWhere((x) => x.id == s.id);
    if (idx >= 0) _spaces[idx] = s;
    if (_active?.id == s.id) _active = s;
    notifyListeners();
  }

  /// Permanently deletes a Space, all its docs, and its scoped custom
  /// categories.
  Future<void> deleteSpace(String id) async {
    await DatabaseService.instance.deleteSpace(id);
    _spaces.removeWhere((s) => s.id == id);
    if (_active?.id == id) {
      _active = _spaces.isEmpty ? null : _spaces.first;
      if (_active != null) {
        await OnboardingService.instance.setActiveSpaceId(_active!.id);
      }
    }
    notifyListeners();
  }
}
