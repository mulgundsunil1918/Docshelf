import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/category.dart';
import '../models/document.dart';
import '../models/family_member.dart';
import '../services/category_service.dart';
import '../services/database_service.dart';
import '../services/document_notifier.dart';
import '../services/file_storage_service.dart';
import '../services/notification_service.dart';
import '../utils/app_colors.dart';
import '../utils/constants.dart';
import '../widgets/category_picker_widget.dart';
import '../widgets/expiry_date_picker.dart';
import '../widgets/family_picker_widget.dart';

class DocumentPropertiesScreen extends StatefulWidget {
  const DocumentPropertiesScreen({super.key, required this.doc});

  final Document doc;

  @override
  State<DocumentPropertiesScreen> createState() =>
      _DocumentPropertiesScreenState();
}

class _DocumentPropertiesScreenState extends State<DocumentPropertiesScreen> {
  late Document _doc;

  @override
  void initState() {
    super.initState();
    _doc = widget.doc;
  }

  Future<void> _rename() async {
    final ctrl = TextEditingController(text: _doc.name);
    final res = await showDialog<String?>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Rename'),
        content: TextField(controller: ctrl, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(ctrl.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (res == null || res.isEmpty || res == _doc.name) return;
    final updated = _doc.copyWith(name: res);
    await DatabaseService.instance.updateDocument(updated);
    setState(() => _doc = updated);
    DocumentNotifier.instance.notifyDocumentChanged();
  }

  Future<void> _changeOwner() async {
    final picked = await showModalBottomSheet<FamilyMember>(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Change owner',
                style: GoogleFonts.nunito(
                    fontSize: 16, fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            FamilyPickerWidget(
              selectedId: _doc.familyMemberId,
              onChanged: (m) => Navigator.of(context).pop(m),
            ),
          ],
        ),
      ),
    );
    if (picked == null || picked.id == _doc.familyMemberId) return;
    final updated = _doc.copyWith(familyMemberId: picked.id);
    await DatabaseService.instance.updateDocument(updated);
    setState(() => _doc = updated);
    DocumentNotifier.instance.notifyDocumentChanged();
  }

  Future<void> _changeCategory() async {
    final picked = await showModalBottomSheet<Category>(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: ChangeNotifierProvider.value(
            value: CategoryService.instance,
            child: CategoryPickerWidget(
              selectedId: _doc.categoryId,
              onChanged: (c) => Navigator.of(context).pop(c),
            ),
          ),
        ),
      ),
    );
    if (picked == null || picked.id == _doc.categoryId) return;
    final moved = await FileStorageService.instance.moveDocument(
      _doc,
      newCategoryId: picked.id,
    );
    await DatabaseService.instance.deleteDocument(_doc.path);
    final id = await DatabaseService.instance.saveDocument(moved);
    setState(() => _doc = moved.copyWith(id: id));
    DocumentNotifier.instance.notifyDocumentChanged();
  }

  Future<void> _editExpiry() async {
    DateTime? newDate = _doc.expiryDate;
    int newDays = _doc.reminderDays;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: StatefulBuilder(builder: (ctx, setSheet) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Expiry & reminder',
                  style: GoogleFonts.nunito(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                ExpiryDatePicker(
                  initialDate: newDate,
                  initialReminderDays: newDays,
                  onChanged: (d, r) {
                    setSheet(() {
                      newDate = d;
                      newDays = r;
                    });
                  },
                ),
                const SizedBox(height: 14),
                FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text('Save'),
                ),
              ],
            );
          }),
        );
      },
    );
    if (ok != true) return;
    final updated = _doc.copyWith(
      expiryDate: newDate,
      clearExpiryDate: newDate == null,
      reminderDays: newDays,
    );
    await DatabaseService.instance.updateDocument(updated);
    setState(() => _doc = updated);
    if (_doc.id != null) {
      if (newDate == null) {
        await NotificationService.instance.cancelReminder(_doc.id!);
      } else {
        await NotificationService.instance.scheduleExpiryReminder(_doc);
      }
    }
    DocumentNotifier.instance.notifyDocumentChanged();
  }

  Future<void> _editDescription() async {
    final ctrl = TextEditingController(text: _doc.description ?? '');
    final res = await showDialog<String?>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Description'),
        content: TextField(
          controller: ctrl,
          maxLines: 5,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(ctrl.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (res == null) return;
    final updated = _doc.copyWith(description: res);
    await DatabaseService.instance.updateDocument(updated);
    setState(() => _doc = updated);
    DocumentNotifier.instance.notifyDocumentChanged();
  }

  Future<void> _toggleBookmark() async {
    final next = !_doc.isBookmarked;
    await DatabaseService.instance.toggleBookmark(_doc.path, next);
    setState(() => _doc = _doc.copyWith(isBookmarked: next));
    DocumentNotifier.instance.notifyDocumentChanged();
  }

  void _copyPath() {
    Clipboard.setData(ClipboardData(text: _doc.path));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Path copied')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cats = CategoryService.instance;
    final crumb =
        cats.getBreadcrumb(_doc.categoryId).map((c) => c.name).join(' / ');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Properties'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(_doc),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Row(
            icon: Icons.text_fields,
            label: 'Name',
            value: _doc.name,
            onTap: _rename,
          ),
          _Row(
            icon: Icons.person_outline,
            label: 'Owner',
            value: _doc.familyMemberId,
            onTap: _changeOwner,
          ),
          _Row(
            icon: Icons.folder_outlined,
            label: 'Saved in',
            value: crumb.isEmpty ? '—' : crumb,
            onTap: _changeCategory,
          ),
          _Row(
            icon: Icons.event_outlined,
            label: 'Date saved',
            value: _doc.formattedDate,
          ),
          _Row(
            icon: Icons.timer_outlined,
            label: 'Expiry',
            value: _doc.expiryDate == null
                ? 'No expiry'
                : '${DateFormat('d MMM yyyy').format(_doc.expiryDate!)} · '
                    '${_doc.reminderDays} days reminder',
            onTap: _editExpiry,
          ),
          _Row(
            icon: Icons.sd_storage_outlined,
            label: 'Size',
            value: _doc.formattedSize,
          ),
          _Row(
            icon: Icons.label_outline,
            label: 'File type',
            value: _doc.fileType.name.toUpperCase(),
          ),
          SwitchListTile(
            value: _doc.isBookmarked,
            onChanged: (_) => _toggleBookmark(),
            title: const Text('Bookmarked'),
            secondary: const Icon(Icons.star_outline),
          ),
          _Row(
            icon: Icons.location_on_outlined,
            label: 'File location',
            value: _doc.path,
            onTap: _copyPath,
          ),
          _Row(
            icon: Icons.notes_outlined,
            label: 'Description',
            value: _doc.description?.isEmpty ?? true
                ? 'Tap to add'
                : _doc.description!,
            onTap: _editDescription,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => OpenFilex.open(_doc.path),
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Open'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => Share.shareXFiles(
                    [XFile(_doc.path)],
                    text: _doc.name,
                  ),
                  icon: const Icon(Icons.share),
                  label: const Text('Share'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _delete,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.danger,
              side: BorderSide(
                color: AppColors.danger.withValues(alpha: 0.4),
              ),
            ),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Delete document'),
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              '${AppConstants.appName} · ${_doc.formattedDate}',
              style: GoogleFonts.nunito(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.gray,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete this document?'),
        content: Text('"${_doc.name}" will be permanently removed.'),
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
    await FileStorageService.instance.deleteDocumentFromStorage(_doc.path);
    await DatabaseService.instance.deleteDocument(_doc.path);
    if (_doc.id != null) {
      await NotificationService.instance.cancelReminder(_doc.id!);
    }
    DocumentNotifier.instance.notifyDocumentChanged();
    if (!mounted) return;
    Navigator.of(context).pop();
    Navigator.of(context).pop();
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(
        label,
        style: GoogleFonts.nunito(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.0,
          color: AppColors.gray,
        ),
      ),
      subtitle: Text(
        value,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.nunito(
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
      trailing: onTap == null ? null : const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
