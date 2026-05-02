import 'package:flutter/foundation.dart';

import '../models/family_member.dart';
import 'database_service.dart';
import 'onboarding_service.dart';

/// Holds the active family member + the full member list. Persists the
/// selected member across app launches.
class ProfileService extends ChangeNotifier {
  static final ProfileService instance = ProfileService._();
  ProfileService._();

  final List<FamilyMember> _members = [];
  FamilyMember? _active;

  List<FamilyMember> get members => List.unmodifiable(_members);
  FamilyMember? get activeMember => _active;
  bool get hasMembers => _members.isNotEmpty;

  Future<void> load() async {
    final list = await DatabaseService.instance.getAllFamilyMembers();
    _members
      ..clear()
      ..addAll(list);
    final saved = await OnboardingService.instance.getActiveMemberId();
    FamilyMember? matched;
    if (saved != null) {
      for (final m in _members) {
        if (m.id == saved) {
          matched = m;
          break;
        }
      }
    }
    _active = matched ?? (_members.isEmpty ? null : _members.first);
    if (_active != null && _active!.id != saved) {
      await OnboardingService.instance.setActiveMemberId(_active!.id);
    }
    notifyListeners();
  }

  Future<void> setActiveMember(String id) async {
    final m = _members.firstWhere(
      (m) => m.id == id,
      orElse: () => _members.first,
    );
    _active = m;
    await OnboardingService.instance.setActiveMemberId(m.id);
    notifyListeners();
  }

  Future<FamilyMember> addMember(FamilyMember m) async {
    await DatabaseService.instance.saveFamilyMember(m);
    _members.add(m);
    if (_active == null) {
      _active = m;
      await OnboardingService.instance.setActiveMemberId(m.id);
    }
    notifyListeners();
    return m;
  }

  Future<void> updateMember(FamilyMember m) async {
    await DatabaseService.instance.saveFamilyMember(m);
    final idx = _members.indexWhere((x) => x.id == m.id);
    if (idx >= 0) _members[idx] = m;
    if (_active?.id == m.id) _active = m;
    notifyListeners();
  }

  /// Permanently deletes a family member, all their docs, and their
  /// member-scoped custom categories.
  Future<void> deleteMember(String id) async {
    await DatabaseService.instance.deleteFamilyMember(id);
    _members.removeWhere((m) => m.id == id);
    if (_active?.id == id) {
      _active = _members.isEmpty ? null : _members.first;
      if (_active != null) {
        await OnboardingService.instance.setActiveMemberId(_active!.id);
      }
    }
    notifyListeners();
  }
}
