import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/family_member.dart';
import '../services/onboarding_service.dart';
import '../services/profile_service.dart';
import '../utils/app_colors.dart';
import '../utils/constants.dart';
import 'main_shell.dart';

class FamilySetupScreen extends StatefulWidget {
  const FamilySetupScreen({super.key});

  @override
  State<FamilySetupScreen> createState() => _FamilySetupScreenState();
}

class _FamilySetupScreenState extends State<FamilySetupScreen> {
  final List<_DraftMember> _drafts = [
    _DraftMember(
      id: AppConstants.selfMemberId,
      relation: FamilyRelation.self,
      avatar: '👨',
      isSelfRow: true,
    ),
  ];

  bool get _canContinue =>
      _drafts.first.name.trim().isNotEmpty;

  void _addRow() {
    if (_drafts.length >= 7) return;
    setState(() {
      _drafts.add(
        _DraftMember(
          id: 'member_${DateTime.now().millisecondsSinceEpoch}',
          relation: FamilyRelation.spouse,
          avatar: '👩',
        ),
      );
    });
  }

  void _removeRow(int idx) {
    if (idx == 0) return;
    setState(() => _drafts.removeAt(idx));
  }

  Future<void> _save() async {
    final profiles = ProfileService.instance;
    for (final d in _drafts) {
      final m = FamilyMember(
        id: d.id,
        name: d.name.trim().isEmpty
            ? d.relation.label
            : d.name.trim(),
        relation: d.relation,
        avatar: d.avatar,
      );
      await profiles.addMember(m);
    }
    await profiles.setActiveMember(_drafts.first.id);
    await OnboardingService.instance.markFamilySetupComplete();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const MainShell()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.light,
      appBar: AppBar(
        title: const Text("Who's in your family?"),
        elevation: 0,
        backgroundColor: AppColors.light,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Text(
                'Add yourself first. You can add spouse, kids, parents anytime from Settings.',
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.gray,
                ),
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                itemCount: _drafts.length + 1,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, idx) {
                  if (idx == _drafts.length) {
                    return _AddRowButton(
                      enabled: _drafts.length < 7,
                      onTap: _addRow,
                    );
                  }
                  return _MemberRow(
                    draft: _drafts[idx],
                    isFirst: idx == 0,
                    onRemove: () => _removeRow(idx),
                    onChanged: () => setState(() {}),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _canContinue ? _save : null,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: Text('Continue →'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DraftMember {
  _DraftMember({
    required this.id,
    required this.relation,
    required this.avatar,
    this.isSelfRow = false,
  });

  final String id;
  String name = '';
  FamilyRelation relation;
  String avatar;
  final bool isSelfRow;
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({
    required this.draft,
    required this.isFirst,
    required this.onRemove,
    required this.onChanged,
  });

  final _DraftMember draft;
  final bool isFirst;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gray.withValues(alpha: 0.15)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () async {
                  final picked = await showModalBottomSheet<String>(
                    context: context,
                    builder: (_) => _AvatarPicker(current: draft.avatar),
                  );
                  if (picked != null) {
                    draft.avatar = picked;
                    onChanged();
                  }
                },
                child: Container(
                  width: 56,
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.4),
                      width: 2,
                    ),
                  ),
                  child: Text(draft.avatar,
                      style: const TextStyle(fontSize: 28)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: TextEditingController(text: draft.name)
                        ..selection = TextSelection.collapsed(
                            offset: draft.name.length),
                      onChanged: (v) {
                        draft.name = v;
                        onChanged();
                      },
                      decoration: InputDecoration(
                        hintText: isFirst
                            ? 'Your name (e.g. Sunil)'
                            : '${draft.relation.label} name',
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (!isFirst)
                      DropdownButton<FamilyRelation>(
                        value: draft.relation,
                        underline: const SizedBox.shrink(),
                        items: FamilyRelation.values
                            .where((r) => r != FamilyRelation.self)
                            .map(
                              (r) => DropdownMenuItem(
                                value: r,
                                child: Text(r.label),
                              ),
                            )
                            .toList(),
                        onChanged: (r) {
                          if (r != null) {
                            draft.relation = r;
                            onChanged();
                          }
                        },
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color:
                                AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Self · required',
                            style: GoogleFonts.nunito(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (!isFirst)
                IconButton(
                  icon: const Icon(Icons.close),
                  color: AppColors.danger,
                  onPressed: onRemove,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AddRowButton extends StatelessWidget {
  const _AddRowButton({required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
        decoration: BoxDecoration(
          color: enabled
              ? AppColors.primary.withValues(alpha: 0.06)
              : AppColors.gray.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: enabled
                ? AppColors.primary.withValues(alpha: 0.4)
                : AppColors.gray.withValues(alpha: 0.3),
            style: BorderStyle.solid,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.add,
              color: enabled ? AppColors.primary : AppColors.gray,
            ),
            const SizedBox(width: 8),
            Text(
              enabled
                  ? 'Add another family member'
                  : 'Maximum 7 members during setup',
              style: GoogleFonts.nunito(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: enabled ? AppColors.primary : AppColors.gray,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AvatarPicker extends StatelessWidget {
  const _AvatarPicker({required this.current});
  final String current;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pick an avatar',
              style: GoogleFonts.nunito(
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final a in AppConstants.avatarOptions)
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(a),
                    child: Container(
                      width: 56,
                      height: 56,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: a == current
                            ? AppColors.primary.withValues(alpha: 0.18)
                            : AppColors.gray.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: a == current
                              ? AppColors.primary
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child:
                          Text(a, style: const TextStyle(fontSize: 26)),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
