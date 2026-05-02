import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../models/family_member.dart';
import '../services/database_service.dart';
import '../services/document_notifier.dart';
import '../services/profile_service.dart';
import '../utils/app_colors.dart';
import '../utils/constants.dart';

class ManageFamilyScreen extends StatelessWidget {
  const ManageFamilyScreen({super.key});

  Future<void> _add(BuildContext context) async {
    final res = await _editSheet(context);
    if (res == null) return;
    final id = 'member_${DateTime.now().millisecondsSinceEpoch}';
    await ProfileService.instance.addMember(
      FamilyMember(
        id: id,
        name: res.name,
        relation: res.relation,
        avatar: res.avatar,
        dateOfBirth: res.dob,
      ),
    );
  }

  Future<void> _edit(BuildContext context, FamilyMember m) async {
    final res = await _editSheet(context, initial: m);
    if (res == null) return;
    await ProfileService.instance.updateMember(
      m.copyWith(
        name: res.name,
        relation: res.relation,
        avatar: res.avatar,
        dateOfBirth: res.dob,
        clearDateOfBirth: res.dob == null,
      ),
    );
  }

  Future<void> _delete(BuildContext context, FamilyMember m) async {
    final docs = await DatabaseService.instance.getDocumentsByMember(m.id);
    if (!context.mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Delete ${m.name}?'),
        content: Text(
          'This will permanently remove ${m.name} and ${docs.length} of their document${docs.length == 1 ? '' : 's'}. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ProfileService.instance.deleteMember(m.id);
    DocumentNotifier.instance.notifyDocumentChanged();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ProfileService>(
      builder: (context, profile, _) {
        final members = profile.members;
        return Scaffold(
          appBar: AppBar(title: const Text('Family members')),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _add(context),
            icon: const Icon(Icons.person_add),
            label: const Text('Add member'),
          ),
          body: members.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      'No family members yet. Tap Add to begin.',
                      style: GoogleFonts.nunito(fontWeight: FontWeight.w700),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView.separated(
                  itemCount: members.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final m = members[i];
                    return Dismissible(
                      key: ValueKey(m.id),
                      direction: m.relation == FamilyRelation.self &&
                              members.length == 1
                          ? DismissDirection.none
                          : DismissDirection.endToStart,
                      confirmDismiss: (_) async {
                        await _delete(context, m);
                        return false;
                      },
                      background: Container(
                        color: AppColors.danger,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        child: const Icon(Icons.delete, color: AppColors.white),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              AppColors.primary.withValues(alpha: 0.16),
                          child: Text(m.avatar,
                              style: const TextStyle(fontSize: 22)),
                        ),
                        title: Text(
                          m.name,
                          style: GoogleFonts.nunito(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        subtitle: Text(m.relation.label),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _edit(context, m),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}

class _DraftEdit {
  _DraftEdit({
    required this.name,
    required this.relation,
    required this.avatar,
    this.dob,
  });

  final String name;
  final FamilyRelation relation;
  final String avatar;
  final DateTime? dob;
}

Future<_DraftEdit?> _editSheet(
  BuildContext context, {
  FamilyMember? initial,
}) async {
  final nameCtrl = TextEditingController(text: initial?.name ?? '');
  var relation = initial?.relation ?? FamilyRelation.spouse;
  var avatar = initial?.avatar ?? '👤';
  DateTime? dob = initial?.dateOfBirth;

  return showModalBottomSheet<_DraftEdit>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) {
      return Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: StatefulBuilder(builder: (ctx, setSheet) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                initial == null ? 'Add member' : 'Edit member',
                style: GoogleFonts.nunito(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  GestureDetector(
                    onTap: () async {
                      final picked = await showModalBottomSheet<String>(
                        context: ctx,
                        builder: (_) => SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                            child: Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                for (final a in AppConstants.avatarOptions)
                                  GestureDetector(
                                    onTap: () => Navigator.of(ctx).pop(a),
                                    child: Container(
                                      width: 50,
                                      height: 50,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: AppColors.primary
                                            .withValues(alpha: 0.10),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Text(a,
                                          style:
                                              const TextStyle(fontSize: 26)),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                      if (picked != null) setSheet(() => avatar = picked);
                    },
                    child: Container(
                      width: 56,
                      height: 56,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.16),
                        shape: BoxShape.circle,
                      ),
                      child:
                          Text(avatar, style: const TextStyle(fontSize: 26)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(hintText: 'Name'),
                      autofocus: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<FamilyRelation>(
                initialValue: relation,
                items: FamilyRelation.values
                    .map(
                      (r) => DropdownMenuItem(
                        value: r,
                        child: Text(r.label),
                      ),
                    )
                    .toList(),
                onChanged: (r) {
                  if (r != null) setSheet(() => relation = r);
                },
                decoration: const InputDecoration(labelText: 'Relation'),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: dob ?? DateTime(2000, 1, 1),
                    firstDate: DateTime(1920),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) setSheet(() => dob = picked);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 14),
                  decoration: BoxDecoration(
                    color: Theme.of(ctx).colorScheme.surface,
                    border: Border.all(
                      color: Theme.of(ctx)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.12),
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.cake_outlined),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          dob == null
                              ? 'Date of birth (optional)'
                              : '${dob!.day}/${dob!.month}/${dob!.year}',
                        ),
                      ),
                      if (dob != null)
                        IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () => setSheet(() => dob = null),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    final n = nameCtrl.text.trim();
                    if (n.isEmpty) return;
                    Navigator.of(ctx).pop(
                      _DraftEdit(
                        name: n,
                        relation: relation,
                        avatar: avatar,
                        dob: dob,
                      ),
                    );
                  },
                  child: const Text('Save'),
                ),
              ),
            ],
          );
        }),
      );
    },
  );
}
