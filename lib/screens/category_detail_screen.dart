import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../models/category.dart';
import '../models/document.dart';
import '../services/category_service.dart';
import '../services/database_service.dart';
import '../services/document_notifier.dart';
import '../services/file_storage_service.dart';
import '../services/profile_service.dart';
import '../utils/app_colors.dart';
import '../widgets/add_note_sheet.dart';
import '../widgets/document_thumbnail.dart';
import '../widgets/save_document_sheet.dart';
import 'document_viewer_screen.dart';

class CategoryDetailScreen extends StatefulWidget {
  const CategoryDetailScreen({super.key, required this.category});

  final Category category;

  @override
  State<CategoryDetailScreen> createState() => _CategoryDetailScreenState();
}

class _CategoryDetailScreenState extends State<CategoryDetailScreen> {
  Future<void> _importFile() async {
    final res = await FilePicker.platform.pickFiles();
    if (res == null || res.files.isEmpty) return;
    final path = res.files.first.path;
    if (path == null || !mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => SaveDocumentSheet(
        sourcePath: path,
        initialCategoryId: widget.category.id,
      ),
    );
  }

  Future<void> _addNote() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => AddNoteSheet(initialCategoryId: widget.category.id),
    );
  }

  Future<void> _addSub() async {
    final ctrl = TextEditingController();
    final ok = await showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'New subfolder under "${widget.category.name}"',
              style: GoogleFonts.nunito(
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              decoration: const InputDecoration(hintText: 'Folder name'),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
                child: const Text('Create'),
              ),
            ),
          ],
        ),
      ),
    );
    if (ok == null || ok.isEmpty) return;
    await CategoryService.instance.addCategory(
      name: ok,
      emoji: '📁',
      parentId: widget.category.id,
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Consumer3<ProfileService, DocumentNotifier, CategoryService>(
      builder: (context, profile, _, cats, __) {
        final activeId = profile.activeSpace?.id;
        final breadcrumb = cats.getBreadcrumb(widget.category.id);
        final breadcrumbText = breadcrumb.map((c) => c.name).join(' / ');
        final children = cats.getChildren(widget.category.id);
        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(widget.category.emoji,
                        style: const TextStyle(fontSize: 22)),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        widget.category.name,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.nunito(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  breadcrumbText,
                  style: GoogleFonts.nunito(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                ),
              ],
            ),
            actions: [
              PopupMenuButton<String>(
                onSelected: (v) async {
                  switch (v) {
                    case 'sub':
                      _addSub();
                      break;
                    case 'rename':
                      // Defer to library edit mode for now.
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              'Rename from Library → Edit (top-right pencil).'),
                        ),
                      );
                      break;
                    case 'delete':
                      if (!widget.category.isCustom) return;
                      await CategoryService.instance
                          .deleteCategory(widget.category.id, moveDocsToOther: true);
                      if (mounted) Navigator.of(context).pop();
                      DocumentNotifier.instance.notifyDocumentChanged();
                      break;
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'sub', child: Text('Add subfolder')),
                  const PopupMenuItem(value: 'rename', child: Text('Rename')),
                  if (widget.category.isCustom)
                    const PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ],
          ),
          body: Column(
            children: [
              if (children.isNotEmpty)
                SizedBox(
                  height: 90,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    itemCount: children.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (_, i) => _SubChip(
                      cat: children[i],
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                CategoryDetailScreen(category: children[i]),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              Expanded(
                child: FutureBuilder<List<Document>>(
                  future: DatabaseService.instance.getDocumentsByCategory(
                    widget.category.id,
                    spaceId: activeId,
                  ),
                  builder: (context, snap) {
                    final docs = snap.data ?? const <Document>[];
                    if (docs.isEmpty) {
                      return _Empty(onTap: _importFile);
                    }
                    return ListView.separated(
                      padding:
                          const EdgeInsets.fromLTRB(12, 4, 12, 80),
                      itemCount: docs.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, indent: 60),
                      itemBuilder: (_, i) => _DocTile(doc: docs[i]),
                    );
                  },
                ),
              ),
            ],
          ),
          floatingActionButton: _FabSpeedDial(
            onImport: _importFile,
            onNote: _addNote,
            onSubfolder: _addSub,
          ),
        );
      },
    );
  }
}

class _SubChip extends StatelessWidget {
  const _SubChip({required this.cat, required this.onTap});

  final Category cat;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 130,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Text(cat.emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                cat.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.nunito(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DocTile extends StatelessWidget {
  const _DocTile({required this.doc});

  final Document doc;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: DocumentThumbnail(document: doc, size: 44),
      title: Text(
        doc.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
      ),
      subtitle: Text(
        '${doc.formattedSize} · ${doc.formattedDate}',
        style: GoogleFonts.nunito(fontSize: 11, fontWeight: FontWeight.w600),
      ),
      trailing: doc.isBookmarked
          ? const Icon(Icons.star, color: AppColors.accent, size: 18)
          : null,
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => DocumentViewerScreen(doc: doc)),
        );
      },
      onLongPress: () => _showDocMenu(context, doc),
    );
  }

  Future<void> _showDocMenu(BuildContext context, Document doc) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.visibility_outlined),
                title: const Text('Open'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => DocumentViewerScreen(doc: doc),
                    ),
                  );
                },
              ),
              ListTile(
                leading: Icon(
                  doc.isBookmarked
                      ? Icons.star
                      : Icons.star_outline,
                  color: AppColors.accent,
                ),
                title: Text(
                    doc.isBookmarked ? 'Remove bookmark' : 'Bookmark'),
                onTap: () async {
                  await DatabaseService.instance
                      .toggleBookmark(doc.path, !doc.isBookmarked);
                  DocumentNotifier.instance.notifyDocumentChanged();
                  if (ctx.mounted) Navigator.of(ctx).pop();
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline,
                    color: AppColors.danger),
                title: const Text(
                  'Delete',
                  style: TextStyle(color: AppColors.danger),
                ),
                onTap: () async {
                  await FileStorageService.instance
                      .deleteDocumentFromStorage(doc.path);
                  await DatabaseService.instance.deleteDocument(doc.path);
                  DocumentNotifier.instance.notifyDocumentChanged();
                  if (ctx.mounted) Navigator.of(ctx).pop();
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('📁', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 12),
            Text(
              'No documents here yet.',
              style: GoogleFonts.nunito(
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Tap + to add your first one.',
              style: GoogleFonts.nunito(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onTap,
              icon: const Icon(Icons.add),
              label: const Text('Import a document'),
            ),
          ],
        ),
      ),
    );
  }
}

class _FabSpeedDial extends StatefulWidget {
  const _FabSpeedDial({
    required this.onImport,
    required this.onNote,
    required this.onSubfolder,
  });

  final VoidCallback onImport;
  final VoidCallback onNote;
  final VoidCallback onSubfolder;

  @override
  State<_FabSpeedDial> createState() => _FabSpeedDialState();
}

class _FabSpeedDialState extends State<_FabSpeedDial> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (_open) ...[
          _MiniFab(
            label: 'New subfolder',
            icon: Icons.create_new_folder_outlined,
            onTap: () {
              setState(() => _open = false);
              widget.onSubfolder();
            },
          ),
          const SizedBox(height: 10),
          _MiniFab(
            label: 'Add note',
            icon: Icons.edit_note,
            onTap: () {
              setState(() => _open = false);
              widget.onNote();
            },
          ),
          const SizedBox(height: 10),
          _MiniFab(
            label: 'Import file',
            icon: Icons.file_download_outlined,
            onTap: () {
              setState(() => _open = false);
              widget.onImport();
            },
          ),
          const SizedBox(height: 10),
        ],
        FloatingActionButton(
          onPressed: () => setState(() => _open = !_open),
          child: Icon(_open ? Icons.close : Icons.add),
        ),
      ],
    );
  }
}

class _MiniFab extends StatelessWidget {
  const _MiniFab({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.dark,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: GoogleFonts.nunito(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.white,
            ),
          ),
        ),
        const SizedBox(width: 8),
        FloatingActionButton.small(
          heroTag: label,
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.white,
          onPressed: onTap,
          child: Icon(icon),
        ),
      ],
    );
  }
}
