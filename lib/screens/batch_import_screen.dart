import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../models/category.dart';
import '../services/category_service.dart';
import '../services/database_service.dart';
import '../services/document_notifier.dart';
import '../services/file_storage_service.dart';
import '../utils/app_colors.dart';
import '../utils/constants.dart';
import '../widgets/category_picker_widget.dart';

class BatchImportScreen extends StatefulWidget {
  const BatchImportScreen({super.key, this.preloadedPaths = const []});

  /// File paths supplied by the share-intent flow (or any caller that
  /// already has paths). When non-empty, the screen opens with these
  /// files pre-checked so the user can pick ONE folder + import them
  /// all at once instead of going through N sequential save sheets.
  final List<String> preloadedPaths;

  @override
  State<BatchImportScreen> createState() => _BatchImportScreenState();
}

class _BatchImportScreenState extends State<BatchImportScreen> {
  final _files = <_PendingFile>[];
  Category? _category;
  bool _importing = false;
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    _category =
        CategoryService.instance.getCategoryById(AppConstants.unsortedCategoryId);
    // Pre-load any paths passed in by the share-intent handler.
    for (final p in widget.preloadedPaths) {
      if (p.trim().isEmpty) continue;
      if (_files.any((x) => x.path == p)) continue;
      _files.add(_PendingFile(path: p));
    }
  }

  Future<void> _pickFiles() async {
    final res = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (res == null) return;
    setState(() {
      for (final f in res.files) {
        if (f.path == null) continue;
        if (_files.any((x) => x.path == f.path)) continue;
        _files.add(_PendingFile(path: f.path!));
      }
    });
  }

  Future<void> _pickFolder() async {
    final dir = await FilePicker.platform.getDirectoryPath();
    if (dir == null) return;
    final root = Directory(dir);
    if (!root.existsSync()) return;
    final all = <_PendingFile>[];
    await for (final e in root.list(recursive: true, followLinks: false)) {
      if (e is File) all.add(_PendingFile(path: e.path));
    }
    if (!mounted) return;
    setState(() {
      for (final f in all) {
        if (_files.any((x) => x.path == f.path)) continue;
        _files.add(f);
      }
    });
  }

  Future<void> _import() async {
    if (_category == null) return;
    final selected = _files.where((f) => f.selected).toList();
    if (selected.isEmpty) return;
    setState(() {
      _importing = true;
      _progress = 0;
    });
    for (var i = 0; i < selected.length; i++) {
      final f = selected[i];
      try {
        var doc = await FileStorageService.instance.storeDocument(
          sourcePath: f.path,
          categoryId: _category!.id,
        );
        final id = await DatabaseService.instance.saveDocument(doc);
        doc = doc.copyWith(id: id);
      } catch (_) {/* skip individual failures */}
      if (!mounted) return;
      setState(() => _progress = (i + 1) / selected.length);
    }
    DocumentNotifier.instance.notifyDocumentChanged();
    if (!mounted) return;
    setState(() => _importing = false);
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Imported ${selected.length} files ✓')),
    );
  }

  Future<void> _pickCategory() async {
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
    final selected = _files.where((f) => f.selected).length;
    return Scaffold(
      appBar: AppBar(title: const Text('Batch import')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickFiles,
                    icon: const Icon(Icons.file_copy_outlined),
                    label: const Text('Files'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickFolder,
                    icon: const Icon(Icons.folder_open),
                    label: const Text('Folder'),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: InkWell(
              onTap: _pickCategory,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(12),
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
                            ? 'Choose target folder…'
                            : CategoryService.instance
                                .getBreadcrumb(_category!.id)
                                .map((c) => c.name)
                                .join(' / '),
                        style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
                      ),
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: _files.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('📂', style: TextStyle(fontSize: 56)),
                          const SizedBox(height: 12),
                          Text(
                            'Pick files or a folder to begin.',
                            style: GoogleFonts.nunito(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'You can mix files from anywhere; we\'ll batch them in.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.nunito(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppColors.gray,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: _files.length,
                    itemBuilder: (_, i) {
                      final f = _files[i];
                      return CheckboxListTile(
                        value: f.selected,
                        title: Text(
                          p.basename(f.path),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          f.path,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.nunito(
                            fontSize: 11,
                            color: AppColors.gray,
                          ),
                        ),
                        onChanged: (v) =>
                            setState(() => f.selected = v ?? false),
                      );
                    },
                  ),
          ),
          if (_importing)
            Padding(
              padding: const EdgeInsets.all(16),
              child: LinearProgressIndicator(value: _progress),
            ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  onPressed: (_category != null &&
                          selected > 0 &&
                          !_importing)
                      ? _import
                      : null,
                  child: Text(
                    _importing
                        ? 'Importing… ${(_progress * 100).round()}%'
                        : 'Import $selected file${selected == 1 ? '' : 's'}',
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PendingFile {
  _PendingFile({required this.path});
  final String path;
  bool selected = true;
}
