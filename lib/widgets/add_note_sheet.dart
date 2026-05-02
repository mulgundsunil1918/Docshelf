import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../models/category.dart';
import '../models/space.dart';
import '../services/category_service.dart';
import '../services/database_service.dart';
import '../services/document_notifier.dart';
import '../services/file_storage_service.dart';
import '../services/profile_service.dart';
import '../utils/app_colors.dart';
import 'category_picker_widget.dart';
import 'space_picker_widget.dart';

class AddNoteSheet extends StatefulWidget {
  const AddNoteSheet({super.key, this.initialCategoryId});

  final String? initialCategoryId;

  @override
  State<AddNoteSheet> createState() => _AddNoteSheetState();
}

class _AddNoteSheetState extends State<AddNoteSheet> {
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  Category? _category;
  Space? _space;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _space = ProfileService.instance.activeSpace;
    if (widget.initialCategoryId != null) {
      _category =
          CategoryService.instance.getCategoryById(widget.initialCategoryId!);
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  bool get _canSave =>
      _titleCtrl.text.trim().isNotEmpty &&
      _bodyCtrl.text.trim().isNotEmpty &&
      _category != null &&
      _space != null &&
      !_saving;

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() => _saving = true);
    try {
      var doc = await FileStorageService.instance.createNote(
        title: _titleCtrl.text.trim(),
        content: _bodyCtrl.text,
        categoryId: _category!.id,
        space: _space!,
      );
      final id = await DatabaseService.instance.saveDocument(doc);
      doc = doc.copyWith(id: id);
      DocumentNotifier.instance.notifyDocumentChanged();
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Note saved ✓')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    }
  }

  Future<void> _pickCategory() async {
    final picked = await showModalBottomSheet<Category>(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: ChangeNotifierProvider.value(
            value: CategoryService.instance,
            child: CategoryPickerWidget(
              selectedId: _category?.id,
              onChanged: (c) => Navigator.of(context).pop(c),
            ),
          ),
        ),
      ),
    );
    if (picked != null) setState(() => _category = picked);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (_, scroll) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Text(
                      '📝 New note',
                      style: GoogleFonts.nunito(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scroll,
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                  children: [
                    TextField(
                      controller: _titleCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Title (e.g. Maid contact, Locker code)',
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _bodyCtrl,
                      maxLines: 8,
                      decoration: const InputDecoration(
                        hintText: 'Type your note here…',
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 14),
                    SpacePickerWidget(
                      selectedId: _space?.id,
                      onChanged: (s) => setState(() => _space = s),
                    ),
                    const SizedBox(height: 14),
                    InkWell(
                      onTap: _pickCategory,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.12),
                          ),
                        ),
                        child: Row(
                          children: [
                            Text(_category?.emoji ?? '📁',
                                style: const TextStyle(fontSize: 22)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _category == null
                                    ? 'Choose a folder…'
                                    : CategoryService.instance
                                        .getBreadcrumb(_category!.id)
                                        .map((c) => c.name)
                                        .join(' / '),
                                style: GoogleFonts.nunito(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const Icon(Icons.chevron_right),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton(
                      onPressed: _canSave ? _save : null,
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.white,
                              ),
                            )
                          : const Text('Save note'),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
