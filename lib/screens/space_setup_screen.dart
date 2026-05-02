import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/space.dart';
import '../services/onboarding_service.dart';
import '../services/profile_service.dart';
import '../utils/app_colors.dart';
import '../utils/constants.dart';
import 'main_shell.dart';

class SpaceSetupScreen extends StatefulWidget {
  const SpaceSetupScreen({super.key});

  @override
  State<SpaceSetupScreen> createState() => _SpaceSetupScreenState();
}

class _SpaceSetupScreenState extends State<SpaceSetupScreen> {
  final List<_DraftSpace> _drafts = [
    _DraftSpace(
      id: AppConstants.selfSpaceId,
      type: SpaceType.personal,
      avatar: '👤',
      isFirst: true,
    ),
  ];

  bool get _canContinue => _drafts.first.name.trim().isNotEmpty;

  void _addRow() {
    if (_drafts.length >= 7) return;
    setState(() {
      _drafts.add(
        _DraftSpace(
          id: 'space_${DateTime.now().millisecondsSinceEpoch}',
          type: SpaceType.work,
          avatar: '💼',
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
      final s = Space(
        id: d.id,
        name: d.name.trim().isEmpty ? d.type.label : d.name.trim(),
        type: d.type,
        avatar: d.avatar,
      );
      await profiles.addSpace(s);
    }
    await profiles.setActiveSpace(_drafts.first.id);
    await OnboardingService.instance.markSpaceSetupComplete();
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
        title: const Text('Set up your Spaces'),
        elevation: 0,
        backgroundColor: AppColors.light,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Text(
                'A Space is a top-level context — yourself, a family member, '
                'work, a side project, a class you teach. Add yourself first; '
                'add more anytime from Settings.',
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
                  return _SpaceRow(
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

class _DraftSpace {
  _DraftSpace({
    required this.id,
    required this.type,
    required this.avatar,
    this.isFirst = false,
  });

  final String id;
  String name = '';
  SpaceType type;
  String avatar;
  final bool isFirst;
}

class _SpaceRow extends StatelessWidget {
  const _SpaceRow({
    required this.draft,
    required this.isFirst,
    required this.onRemove,
    required this.onChanged,
  });

  final _DraftSpace draft;
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
      child: Row(
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
              child: Text(draft.avatar, style: const TextStyle(fontSize: 28)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: TextEditingController(text: draft.name)
                    ..selection =
                        TextSelection.collapsed(offset: draft.name.length),
                  onChanged: (v) {
                    draft.name = v;
                    onChanged();
                  },
                  decoration: InputDecoration(
                    hintText: isFirst
                        ? 'Your name (e.g. Sunil, or "Personal")'
                        : 'Space name (e.g. Wife, Work, Class 8-A)',
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButton<SpaceType>(
                  value: draft.type,
                  underline: const SizedBox.shrink(),
                  items: SpaceType.values
                      .map((r) => DropdownMenuItem(
                            value: r,
                            child: Text(r.label),
                          ))
                      .toList(),
                  onChanged: (r) {
                    if (r != null) {
                      draft.type = r;
                      onChanged();
                    }
                  },
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
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.add,
                color: enabled ? AppColors.primary : AppColors.gray),
            const SizedBox(width: 8),
            Text(
              enabled
                  ? 'Add another Space'
                  : 'Maximum 7 Spaces during setup',
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
                      child: Text(a, style: const TextStyle(fontSize: 26)),
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
