import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../models/space.dart';
import '../services/database_service.dart';
import '../services/document_notifier.dart';
import '../services/profile_service.dart';
import '../utils/app_colors.dart';
import '../utils/constants.dart';

class ManageSpacesScreen extends StatelessWidget {
  const ManageSpacesScreen({super.key});

  Future<void> _add(BuildContext context) async {
    final res = await _editSheet(context);
    if (res == null) return;
    final id = 'space_${DateTime.now().millisecondsSinceEpoch}';
    await ProfileService.instance.addSpace(
      Space(
        id: id,
        name: res.name,
        type: res.type,
        avatar: res.avatar,
        description: res.description,
      ),
    );
  }

  Future<void> _edit(BuildContext context, Space s) async {
    final res = await _editSheet(context, initial: s);
    if (res == null) return;
    await ProfileService.instance.updateSpace(
      s.copyWith(
        name: res.name,
        type: res.type,
        avatar: res.avatar,
        description: res.description,
        clearDescription: res.description == null,
      ),
    );
  }

  Future<void> _delete(BuildContext context, Space s) async {
    final docs = await DatabaseService.instance.getDocumentsBySpace(s.id);
    if (!context.mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Delete ${s.name}?'),
        content: Text(
          'This will permanently remove ${s.name} and ${docs.length} of its document${docs.length == 1 ? '' : 's'}. This cannot be undone.',
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
    await ProfileService.instance.deleteSpace(s.id);
    DocumentNotifier.instance.notifyDocumentChanged();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ProfileService>(
      builder: (context, profile, _) {
        final spaces = profile.spaces;
        return Scaffold(
          appBar: AppBar(title: const Text('Spaces')),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _add(context),
            icon: const Icon(Icons.add),
            label: const Text('Add Space'),
          ),
          body: spaces.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      'No Spaces yet. Tap Add to begin.',
                      style: GoogleFonts.nunito(fontWeight: FontWeight.w700),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView.separated(
                  itemCount: spaces.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final s = spaces[i];
                    return Dismissible(
                      key: ValueKey(s.id),
                      direction: spaces.length == 1
                          ? DismissDirection.none
                          : DismissDirection.endToStart,
                      confirmDismiss: (_) async {
                        await _delete(context, s);
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
                          child: Text(s.avatar,
                              style: const TextStyle(fontSize: 22)),
                        ),
                        title: Text(
                          s.name,
                          style: GoogleFonts.nunito(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        subtitle: Text(s.type.label),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _edit(context, s),
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
    required this.type,
    required this.avatar,
    this.description,
  });

  final String name;
  final SpaceType type;
  final String avatar;
  final String? description;
}

Future<_DraftEdit?> _editSheet(
  BuildContext context, {
  Space? initial,
}) async {
  final nameCtrl = TextEditingController(text: initial?.name ?? '');
  final descCtrl = TextEditingController(text: initial?.description ?? '');
  var type = initial?.type ?? SpaceType.work;
  var avatar = initial?.avatar ?? '👤';

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
                initial == null ? 'Add Space' : 'Edit Space',
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
                      decoration:
                          const InputDecoration(hintText: 'Space name'),
                      autofocus: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<SpaceType>(
                initialValue: type,
                items: SpaceType.values
                    .map(
                      (r) => DropdownMenuItem(
                        value: r,
                        child: Text(r.label),
                      ),
                    )
                    .toList(),
                onChanged: (r) {
                  if (r != null) setSheet(() => type = r);
                },
                decoration: const InputDecoration(labelText: 'Type'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  hintText: 'e.g. "All my freelance contracts"',
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    final n = nameCtrl.text.trim();
                    if (n.isEmpty) return;
                    final d = descCtrl.text.trim();
                    Navigator.of(ctx).pop(
                      _DraftEdit(
                        name: n,
                        type: type,
                        avatar: avatar,
                        description: d.isEmpty ? null : d,
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
