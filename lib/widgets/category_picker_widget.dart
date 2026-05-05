import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../models/category.dart';
import '../services/category_service.dart';
import '../utils/app_colors.dart';
import 'emoji_picker_button.dart';

/// Modal-friendly nested category picker.
///
/// Shows the entire tree as expandable rows; tapping any node selects it.
/// Used inside [SaveDocumentSheet], [AddNoteSheet], etc.
///
/// Includes an inline **"Create new folder"** CTA at the top so users
/// don't have to leave the save flow to make a new folder. Tapping it
/// opens a small inline form (emoji + name + optional parent), and on
/// save the freshly-created [Category] is auto-selected via
/// `widget.onChanged`.
///
/// IMPORTANT: this widget claims its full bounded height (the search field
/// is fixed-height and the list takes the rest via `Expanded`). Callers
/// MUST place it inside a parent with a finite height — typically
/// `Expanded` inside a Column inside a `DraggableScrollableSheet`. Wrapping
/// it in a `SingleChildScrollView` will collapse the inner list and
/// disable scrolling.
class CategoryPickerWidget extends StatefulWidget {
  const CategoryPickerWidget({
    super.key,
    this.selectedId,
    required this.onChanged,
    this.scrollController,
  });

  final String? selectedId;
  final ValueChanged<Category> onChanged;

  /// Optional controller — pass the `DraggableScrollableSheet`'s controller
  /// so dragging the bottom sheet down also drags the list.
  final ScrollController? scrollController;

  @override
  State<CategoryPickerWidget> createState() => _CategoryPickerWidgetState();
}

class _CategoryPickerWidgetState extends State<CategoryPickerWidget> {
  String _query = '';
  final _expanded = <String>{};

  Future<void> _createNewFolder({Category? parent}) async {
    final created = await showModalBottomSheet<Category>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: _NewFolderSheet(parent: parent),
      ),
    );
    if (created != null) {
      // Make sure the parent is auto-expanded so the new folder is visible.
      if (parent != null) _expanded.add(parent.id);
      widget.onChanged(created);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CategoryService>(
      builder: (context, cats, _) {
        final roots = cats.rootCategories;
        final rows = <Widget>[];
        for (final c in roots) {
          rows.addAll(_renderNode(context, cats, c, 0));
        }
        return Column(
          children: [
            // ─── Create-new CTA ─────────────────────────────────────
            // Tapping this is the inline equivalent of "Library → +".
            // Lets users create a brand-new top-level folder without
            // leaving the save sheet — half the point of "fully
            // customisable."
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 4, 0, 8),
              child: InkWell(
                onTap: () => _createNewFolder(),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.32),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.create_new_folder_outlined,
                            color: AppColors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Create a new folder',
                              style: GoogleFonts.nunito(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                color: AppColors.primary,
                              ),
                            ),
                            Text(
                              'Or pick from your existing ones below.',
                              style: GoogleFonts.nunito(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary
                                    .withValues(alpha: 0.75),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right,
                          color: AppColors.primary),
                    ],
                  ),
                ),
              ),
            ),

            // ─── Search field ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
              child: TextField(
                decoration: const InputDecoration(
                  hintText: 'Search folders…',
                  prefixIcon: Icon(Icons.search, size: 20),
                ),
                onChanged: (v) =>
                    setState(() => _query = v.trim().toLowerCase()),
              ),
            ),

            // ─── Tree ─────────────────────────────────────────────────
            Expanded(
              child: rows.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          _query.isEmpty
                              ? 'No folders yet — tap "Create a new folder" above.'
                              : "No folders match '$_query'.",
                          style: GoogleFonts.nunito(
                            fontWeight: FontWeight.w700,
                            color: AppColors.gray,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: widget.scrollController,
                      // Always-on physics so a bounded-height container
                      // can still drag-scroll even if total content is
                      // short — matters when the modal is tall.
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: rows.length,
                      itemBuilder: (_, i) => rows[i],
                    ),
            ),
          ],
        );
      },
    );
  }

  bool _matchesQuery(Category c) {
    if (_query.isEmpty) return true;
    return c.name.toLowerCase().contains(_query);
  }

  List<Widget> _renderNode(
    BuildContext context,
    CategoryService cats,
    Category c,
    int depth,
  ) {
    final children = cats.getChildren(c.id);
    final isOpen = _expanded.contains(c.id) || _query.isNotEmpty;

    final selfMatch = _matchesQuery(c);
    final childMatchExists =
        children.any((ch) => ch.name.toLowerCase().contains(_query));

    if (!selfMatch && !childMatchExists) return const [];

    return [
      _Row(
        cat: c,
        depth: depth,
        selected: c.id == widget.selectedId,
        canExpand: children.isNotEmpty,
        expanded: isOpen,
        onTap: () => widget.onChanged(c),
        onToggle: () {
          setState(() {
            if (_expanded.contains(c.id)) {
              _expanded.remove(c.id);
            } else {
              _expanded.add(c.id);
            }
          });
        },
        onAddSub: () => _createNewFolder(parent: c),
      ),
      if (isOpen)
        for (final child in children) ..._renderNode(context, cats, child, depth + 1),
    ];
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.cat,
    required this.depth,
    required this.selected,
    required this.canExpand,
    required this.expanded,
    required this.onTap,
    required this.onToggle,
    required this.onAddSub,
  });

  final Category cat;
  final int depth;
  final bool selected;
  final bool canExpand;
  final bool expanded;
  final VoidCallback onTap;
  final VoidCallback onToggle;
  final VoidCallback onAddSub;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: depth * 16.0),
      child: Material(
        color: selected
            ? AppColors.primary.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            child: Row(
              children: [
                if (canExpand)
                  IconButton(
                    icon: Icon(
                      expanded ? Icons.expand_less : Icons.expand_more,
                      size: 20,
                    ),
                    onPressed: onToggle,
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  )
                else
                  const SizedBox(width: 28),
                const SizedBox(width: 4),
                Text(cat.emoji, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    cat.name,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.nunito(
                      fontSize: 14,
                      fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                      color: selected ? AppColors.primary : null,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Add subfolder under "${cat.name}"',
                  icon: Icon(Icons.create_new_folder_outlined,
                      size: 18,
                      color: AppColors.primary.withValues(alpha: 0.85)),
                  onPressed: onAddSub,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                      minWidth: 32, minHeight: 32),
                ),
                if (selected)
                  const Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Icon(Icons.check_circle,
                        size: 18, color: AppColors.primary),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Inline new-folder sheet ───────────────────────────────────────
class _NewFolderSheet extends StatefulWidget {
  const _NewFolderSheet({this.parent});
  final Category? parent;

  @override
  State<_NewFolderSheet> createState() => _NewFolderSheetState();
}

class _NewFolderSheetState extends State<_NewFolderSheet> {
  final _ctrl = TextEditingController();
  String _emoji = '📁';
  bool _saving = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _ctrl.text.trim();
    if (name.isEmpty || _saving) return;
    setState(() => _saving = true);
    final cat = await CategoryService.instance.addCategory(
      name: name,
      emoji: _emoji,
      parentId: widget.parent?.id,
    );
    if (!mounted) return;
    Navigator.of(context).pop(cat);
  }

  @override
  Widget build(BuildContext context) {
    final parent = widget.parent;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          parent == null
              ? 'New folder'
              : 'New subfolder under "${parent.name}"',
          style: GoogleFonts.nunito(
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          parent == null
              ? "It'll appear at the top of your library."
              : 'It will live inside this folder.',
          style: GoogleFonts.nunito(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.gray,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            EmojiPickerButton(
              current: _emoji,
              onChanged: (v) => setState(() => _emoji = v),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _ctrl,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  hintText: 'Folder name',
                ),
                onSubmitted: (_) => _save(),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed:
                (_ctrl.text.trim().isEmpty || _saving) ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check, size: 18),
            label: Text(parent == null ? 'Create folder' : 'Create subfolder'),
          ),
        ),
      ],
    );
  }
}
