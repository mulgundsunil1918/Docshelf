import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../models/category.dart';
import '../services/calendar_service.dart';
import '../services/category_service.dart';
import '../services/database_service.dart';
import '../services/document_notifier.dart';
import '../services/file_storage_service.dart';
import '../services/onboarding_service.dart';
import '../utils/app_colors.dart';
import '../utils/constants.dart';
import '../utils/friendly_error.dart';
import 'category_picker_widget.dart';
import 'expiry_date_picker.dart';

class SaveDocumentSheet extends StatefulWidget {
  const SaveDocumentSheet({
    super.key,
    required this.sourcePath,
    this.initialCategoryId,
  });

  final String sourcePath;
  final String? initialCategoryId;

  @override
  State<SaveDocumentSheet> createState() => _SaveDocumentSheetState();
}

class _SaveDocumentSheetState extends State<SaveDocumentSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  Category? _category;
  DateTime? _expiry;
  int _reminderDays = 30;
  bool _bookmark = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final base = p.basenameWithoutExtension(widget.sourcePath);
    _nameCtrl = TextEditingController(text: base);
    _descCtrl = TextEditingController();
    if (widget.initialCategoryId != null) {
      _category =
          CategoryService.instance.getCategoryById(widget.initialCategoryId!);
    }
    // Default to "Other / Unsorted" so the Save button isn't grey on
    // first open — user can change the category before saving.
    _category ??=
        CategoryService.instance.getCategoryById(AppConstants.unsortedCategoryId);
    _loadDefaultReminder();
  }

  Future<void> _loadDefaultReminder() async {
    final d = await OnboardingService.instance.getDefaultReminderDays();
    if (mounted) setState(() => _reminderDays = d);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  bool get _canSave =>
      _nameCtrl.text.trim().isNotEmpty && _category != null && !_saving;

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() => _saving = true);
    try {
      final ext = p.extension(widget.sourcePath);
      final customName = _nameCtrl.text.trim().isEmpty
          ? null
          : '${_nameCtrl.text.trim()}$ext';
      var doc = await FileStorageService.instance.storeDocument(
        sourcePath: widget.sourcePath,
        categoryId: _category!.id,
        customName: customName,
        expiryDate: _expiry,
        reminderDays: _reminderDays,
        description:
            _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        isBookmarked: _bookmark,
      );
      final id = await DatabaseService.instance.saveDocument(doc);
      doc = doc.copyWith(id: id);
      if (_expiry != null) {
        // Hand off the reminder to the system calendar app — the user
        // confirms once and it lives in their normal notification flow.
        await CalendarService.instance.addExpiryReminder(doc);
      }
      DocumentNotifier.instance.notifyDocumentChanged();
      if (!mounted) return;
      final crumb = CategoryService.instance
          .getBreadcrumb(_category!.id)
          .map((c) => c.name)
          .join(' / ');
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved to $crumb ✓')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(FriendlyError.from(e))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
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
                      'Save document',
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
                    _PreviewTile(path: widget.sourcePath),
                    const SizedBox(height: 14),
                    _FieldLabel('Name'),
                    TextField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Document name',
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 14),
                    _FieldLabel('Category'),
                    InkWell(
                      onTap: _pickCategory,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
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
                            if (_category != null) ...[
                              Text(
                                _category!.emoji,
                                style: const TextStyle(fontSize: 22),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  CategoryService.instance
                                      .getBreadcrumb(_category!.id)
                                      .map((c) => c.name)
                                      .join(' / '),
                                  style: GoogleFonts.nunito(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ] else
                              Expanded(
                                child: Text(
                                  'Choose a category…',
                                  style: GoogleFonts.nunito(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.gray,
                                  ),
                                ),
                              ),
                            const Icon(Icons.chevron_right),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    ExpiryDatePicker(
                      initialDate: _expiry,
                      initialReminderDays: _reminderDays,
                      onChanged: (d, r) {
                        setState(() {
                          _expiry = d;
                          _reminderDays = r;
                        });
                      },
                    ),
                    const SizedBox(height: 14),
                    _FieldLabel('Description (optional)'),
                    TextField(
                      controller: _descCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText: 'Notes about this document…',
                      ),
                    ),
                    const SizedBox(height: 14),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Bookmark for quick access ⭐',
                        style: GoogleFonts.nunito(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      value: _bookmark,
                      onChanged: (v) => setState(() => _bookmark = v),
                    ),
                    SizedBox(height: size.height * 0.02),
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
                          : Text(
                              'Save Document',
                              style: GoogleFonts.nunito(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
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

  Future<void> _pickCategory() async {
    final picked = await showModalBottomSheet<Category>(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scroll) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            children: [
              Text(
                'Choose a folder',
                style: GoogleFonts.nunito(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ChangeNotifierProvider.value(
                  value: CategoryService.instance,
                  child: CategoryPickerWidget(
                    selectedId: _category?.id,
                    scrollController: scroll,
                    onChanged: (c) => Navigator.of(context).pop(c),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (picked != null) setState(() => _category = picked);
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, top: 2),
      child: Text(
        label.toUpperCase(),
        style: GoogleFonts.nunito(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.0,
          color: AppColors.gray,
        ),
      ),
    );
  }
}

class _PreviewTile extends StatelessWidget {
  const _PreviewTile({required this.path});
  final String path;

  @override
  Widget build(BuildContext context) {
    final ext = p.extension(path).replaceFirst('.', '').toLowerCase();
    final size = File(path).existsSync() ? File(path).lengthSync() : 0;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              _emoji(ext),
              style: const TextStyle(fontSize: 22),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.basename(path),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${ext.toUpperCase()} · ${_fmt(size)}',
                  style: GoogleFonts.nunito(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.gray,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _emoji(String ext) {
    if (ext == 'pdf') return '📄';
    if (['jpg', 'jpeg', 'png', 'webp', 'heic'].contains(ext)) return '🖼️';
    if (['mp4', 'mov', 'webm', 'avi'].contains(ext)) return '🎥';
    if (['mp3', 'wav', 'm4a'].contains(ext)) return '🎵';
    if (['doc', 'docx', 'odt', 'rtf'].contains(ext)) return '📃';
    if (ext == 'txt') return '📝';
    return '📎';
  }

  String _fmt(int b) {
    if (b < 1024) return '$b B';
    if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)} KB';
    return '${(b / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
