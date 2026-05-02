import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../models/category.dart';
import '../services/category_service.dart';
import '../utils/app_colors.dart';

/// Modal-friendly nested category picker.
///
/// Shows the entire tree as expandable rows; tapping any node selects it.
/// Useful inside [SaveDocumentSheet] and [AddNoteSheet].
class CategoryPickerWidget extends StatefulWidget {
  const CategoryPickerWidget({
    super.key,
    this.selectedId,
    required this.onChanged,
  });

  final String? selectedId;
  final ValueChanged<Category> onChanged;

  @override
  State<CategoryPickerWidget> createState() => _CategoryPickerWidgetState();
}

class _CategoryPickerWidgetState extends State<CategoryPickerWidget> {
  String _query = '';
  final _expanded = <String>{};

  @override
  Widget build(BuildContext context) {
    return Consumer<CategoryService>(
      builder: (context, cats, _) {
        final roots = cats.rootCategories;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final c in roots)
                    ..._renderNode(context, cats, c, 0),
                ],
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
  });

  final Category cat;
  final int depth;
  final bool selected;
  final bool canExpand;
  final bool expanded;
  final VoidCallback onTap;
  final VoidCallback onToggle;

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
                if (selected)
                  const Icon(Icons.check_circle,
                      size: 18, color: AppColors.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
