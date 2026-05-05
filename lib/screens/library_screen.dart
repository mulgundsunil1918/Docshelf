import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../models/category.dart';
import '../services/category_service.dart';
import '../services/database_service.dart';
import '../services/document_notifier.dart';

import '../utils/app_colors.dart';
import '../utils/constants.dart';
import '../widgets/emoji_picker_button.dart';
import 'category_detail_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  bool _grid = true;
  bool _editMode = false;
  final _expanded = <String>{};

  Future<void> _addRoot() async {
    final res = await _editCategorySheet(context);
    if (res == null) return;
    await CategoryService.instance.addCategory(
      name: res.name,
      emoji: res.emoji,
    );
  }

  Future<void> _renameCategory(Category c) async {
    final res =
        await _editCategorySheet(context, initialName: c.name, initialEmoji: c.emoji);
    if (res == null) return;
    await CategoryService.instance.updateCategory(
      c.id,
      newName: res.name,
      newEmoji: res.emoji,
    );
  }

  Future<void> _addSub(Category parent) async {
    final res = await _editCategorySheet(context);
    if (res == null) return;
    await CategoryService.instance.addCategory(
      name: res.name,
      emoji: res.emoji,
      parentId: parent.id,
    );
    setState(() => _expanded.add(parent.id));
  }

  Future<void> _deleteCategory(Category c) async {
    if (c.id == AppConstants.unsortedCategoryId) {
      // Block on the catch-all — there's nowhere for its docs to go.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Other / Unsorted can't be deleted — it's the catch-all "
            "where deleted folders' documents land.",
          ),
        ),
      );
      return;
    }
    final isDefault = !c.isCustom;
    final descendantCount =
        CategoryService.instance.getAllDescendantIds(c.id).length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Delete "${c.name}"?'),
        content: Text(
          isDefault
              ? 'Documents inside (and inside any subfolders) will move '
                  'to Other / Unsorted. The folder will be hidden — you '
                  'can bring it back from Settings → Restore default '
                  'folders.'
              : 'Documents inside will move to Other / Unsorted. The '
                  'folder${descendantCount > 1 ? ' and its $descendantCount subfolders' : ''} '
                  'will be deleted permanently.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style:
                FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(isDefault ? 'Hide folder' : 'Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await CategoryService.instance
        .deleteCategory(c.id, moveDocsToOther: true);
    DocumentNotifier.instance.notifyDocumentChanged();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<CategoryService, DocumentNotifier>(
      builder: (context, cats, _, __) {
        final roots = cats.rootCategories;
        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            title: const Text('My Library'),
            actions: [
              IconButton(
                icon: Icon(_grid ? Icons.list : Icons.grid_view),
                onPressed: () => setState(() => _grid = !_grid),
                tooltip: _grid ? 'List view' : 'Grid view',
              ),
              IconButton(
                icon: Icon(_editMode ? Icons.done : Icons.edit_outlined),
                onPressed: () => setState(() => _editMode = !_editMode),
                tooltip: _editMode ? 'Done' : 'Edit',
              ),
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: _addRoot,
              ),
            ],
          ),
          body: _grid
              ? _GridView(
                  roots: roots,
                  editMode: _editMode,
                  onRename: _renameCategory,
                  onAddSub: _addSub,
                  onDelete: _deleteCategory,
                )
              : _ListView(
                  roots: roots,
                  expanded: _expanded,
                  onToggle: (id) => setState(() {
                    if (_expanded.contains(id)) {
                      _expanded.remove(id);
                    } else {
                      _expanded.add(id);
                    }
                  }),
                  editMode: _editMode,
                  onRename: _renameCategory,
                  onAddSub: _addSub,
                  onDelete: _deleteCategory,
                ),
        );
      },
    );
  }
}

class _GridView extends StatelessWidget {
  const _GridView({
    required this.roots,
    required this.editMode,
    required this.onRename,
    required this.onAddSub,
    required this.onDelete,
  });

  final List<Category> roots;
  final bool editMode;
  final ValueChanged<Category> onRename;
  final ValueChanged<Category> onAddSub;
  final ValueChanged<Category> onDelete;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.05,
      ),
      itemCount: roots.length,
      itemBuilder: (_, i) {
        final c = roots[i];
        return _CategoryGridCard(
          cat: c,
          editMode: editMode,
          onRename: onRename,
          onAddSub: onAddSub,
          onDelete: onDelete,
        );
      },
    );
  }
}

class _CategoryGridCard extends StatelessWidget {
  const _CategoryGridCard({
    required this.cat,
    required this.editMode,
    required this.onRename,
    required this.onAddSub,
    required this.onDelete,
  });

  final Category cat;
  final bool editMode;
  final ValueChanged<Category> onRename;
  final ValueChanged<Category> onAddSub;
  final ValueChanged<Category> onDelete;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => CategoryDetailScreen(category: cat),
          ),
        );
      },
      onLongPress: () => onRename(cat),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(cat.emoji, style: const TextStyle(fontSize: 36)),
                if (editMode)
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert,
                        color: AppColors.white),
                    onSelected: (v) {
                      switch (v) {
                        case 'rename':
                          onRename(cat);
                          break;
                        case 'sub':
                          onAddSub(cat);
                          break;
                        case 'delete':
                          onDelete(cat);
                          break;
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'rename', child: Text('Rename')),
                      const PopupMenuItem(
                          value: 'sub', child: Text('Add subfolder')),
                      if (cat.id != AppConstants.unsortedCategoryId)
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text(
                            'Delete',
                            style: TextStyle(color: AppColors.danger),
                          ),
                        ),
                    ],
                  ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cat.name,
                  style: GoogleFonts.nunito(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: AppColors.white,
                  ),
                ),
                FutureBuilder<int>(
                  future: DatabaseService.instance.countDocumentsInCategories(
                    CategoryService.instance.getAllDescendantIds(cat.id),
                  ),
                  builder: (context, snap) {
                    final n = snap.data ?? 0;
                    return Text(
                      '$n document${n == 1 ? '' : 's'}',
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.white.withValues(alpha: 0.78),
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ListView extends StatelessWidget {
  const _ListView({
    required this.roots,
    required this.expanded,
    required this.onToggle,
    required this.editMode,
    required this.onRename,
    required this.onAddSub,
    required this.onDelete,
  });

  final List<Category> roots;
  final Set<String> expanded;
  final ValueChanged<String> onToggle;
  final bool editMode;
  final ValueChanged<Category> onRename;
  final ValueChanged<Category> onAddSub;
  final ValueChanged<Category> onDelete;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      children: [
        for (final c in roots) ..._renderNode(context, c, 0),
      ],
    );
  }

  List<Widget> _renderNode(BuildContext context, Category c, int depth) {
    final isOpen = expanded.contains(c.id);
    final children = CategoryService.instance.getChildren(c.id);
    return [
      Padding(
        padding: EdgeInsets.only(left: 12.0 + depth * 16.0, right: 8),
        child: ListTile(
          leading:
              Text(c.emoji, style: const TextStyle(fontSize: 22)),
          title: Text(
            c.name,
            style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
          ),
          trailing: editMode
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.add, size: 20),
                      tooltip: 'Add subfolder',
                      onPressed: () => onAddSub(c),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      tooltip: 'Rename',
                      onPressed: () => onRename(c),
                    ),
                    if (c.id != AppConstants.unsortedCategoryId)
                      IconButton(
                        icon: const Icon(Icons.delete_outline,
                            size: 20, color: AppColors.danger),
                        tooltip: 'Delete',
                        onPressed: () => onDelete(c),
                      ),
                  ],
                )
              : (children.isNotEmpty
                  ? Icon(isOpen ? Icons.expand_less : Icons.expand_more)
                  : const Icon(Icons.chevron_right)),
          onTap: () {
            if (children.isNotEmpty && !editMode) {
              onToggle(c.id);
            } else {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => CategoryDetailScreen(category: c),
                ),
              );
            }
          },
        ),
      ),
      if (isOpen)
        for (final child in children) ..._renderNode(context, child, depth + 1),
    ];
  }
}

class _CategoryEdit {
  const _CategoryEdit({required this.name, required this.emoji});
  final String name;
  final String emoji;
}

Future<_CategoryEdit?> _editCategorySheet(
  BuildContext context, {
  String initialName = '',
  String initialEmoji = '📁',
}) async {
  final ctrl = TextEditingController(text: initialName);
  String emoji = initialEmoji;
  return showModalBottomSheet<_CategoryEdit>(
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
                initialName.isEmpty ? 'New folder' : 'Rename folder',
                style: GoogleFonts.nunito(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  EmojiPickerButton(
                    current: emoji,
                    onChanged: (v) => setSheet(() => emoji = v),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: ctrl,
                      decoration: const InputDecoration(hintText: 'Folder name'),
                      autofocus: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    final name = ctrl.text.trim();
                    if (name.isEmpty) return;
                    Navigator.of(ctx).pop(
                      _CategoryEdit(name: name, emoji: emoji),
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
