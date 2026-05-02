import 'package:flutter/foundation.dart' hide Category;

import '../data/default_categories.dart';
import '../models/category.dart';
import 'database_service.dart';

/// Holds DocShelf's category tree (defaults + user-created custom nodes)
/// and notifies listeners on any mutation.
class CategoryService extends ChangeNotifier {
  static final CategoryService instance = CategoryService._();
  CategoryService._();

  final List<Category> _custom = [];
  bool _loaded = false;

  // ─── Load ───────────────────────────────────────────────────────────
  Future<void> load() async {
    final custom = await DatabaseService.instance.getCustomCategories();
    _custom
      ..clear()
      ..addAll(custom);
    _loaded = true;
    notifyListeners();
  }

  bool get isLoaded => _loaded;

  // ─── Reads ──────────────────────────────────────────────────────────
  List<Category> get rootCategories {
    final defaults = kDefaultCategories;
    final customRoots = _custom.where((c) => c.parentId == null).toList();
    return [...defaults, ...customRoots];
  }

  /// Flat list of every category (root + nested) — useful for fast id lookups.
  List<Category> get flatCategories {
    final out = <Category>[];
    out.addAll(flattenDefaults());
    out.addAll(_custom);
    return out;
  }

  List<Category> get allCategories => flatCategories;

  Category? getCategoryById(String id) {
    for (final c in flatCategories) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// Children (one level deep) for a given parent id. Combines built-in and
  /// custom subcategories. Pass null to get top-level roots.
  List<Category> getChildren(String? parentId) {
    if (parentId == null) return rootCategories;
    final defaults = flattenDefaults().where((c) => c.parentId == parentId);
    final custom = _custom.where((c) => c.parentId == parentId);
    return [...defaults, ...custom];
  }

  /// Breadcrumb root → leaf for the given category id (inclusive).
  List<Category> getBreadcrumb(String categoryId) {
    final byId = {for (final c in flatCategories) c.id: c};
    final crumbs = <Category>[];
    String? cur = categoryId;
    final guard = <String>{};
    while (cur != null && !guard.contains(cur)) {
      guard.add(cur);
      final cat = byId[cur];
      if (cat == null) break;
      crumbs.insert(0, cat);
      cur = cat.parentId;
    }
    return crumbs;
  }

  /// Returns the given id and every descendant id (recursive).
  List<String> getAllDescendantIds(String categoryId) {
    final result = <String>[categoryId];
    final stack = <String>[categoryId];
    while (stack.isNotEmpty) {
      final cur = stack.removeLast();
      for (final c in flatCategories) {
        if (c.parentId == cur) {
          result.add(c.id);
          stack.add(c.id);
        }
      }
    }
    return result;
  }

  // ─── Mutations ──────────────────────────────────────────────────────
  Future<Category> addCategory({
    required String name,
    required String emoji,
    String? parentId,
    String? ownerMemberId,
  }) async {
    final id = 'custom_${DateTime.now().millisecondsSinceEpoch}';
    final parent = parentId == null ? null : getCategoryById(parentId);
    final depth = parent == null ? 0 : parent.depth + 1;
    final cat = Category(
      id: id,
      name: name.trim(),
      emoji: emoji,
      parentId: parentId,
      depth: depth,
      isCustom: true,
      ownerMemberId: ownerMemberId,
    );
    await DatabaseService.instance.saveCustomCategory(cat);
    _custom.add(cat);
    notifyListeners();
    return cat;
  }

  Future<void> updateCategory(
    String id, {
    String? newName,
    String? newEmoji,
  }) async {
    await DatabaseService.instance
        .updateCustomCategory(id, newName: newName, newEmoji: newEmoji);
    final idx = _custom.indexWhere((c) => c.id == id);
    if (idx >= 0) {
      _custom[idx] = _custom[idx].copyWith(
        name: newName ?? _custom[idx].name,
        emoji: newEmoji ?? _custom[idx].emoji,
      );
      notifyListeners();
    }
  }

  Future<void> deleteCategory(
    String id, {
    bool moveDocsToOther = false,
  }) async {
    final ids = getAllDescendantIds(id);
    await DatabaseService.instance.deleteCategoryAndChildren(
      id,
      ids,
      moveDocsToOther: moveDocsToOther,
    );
    _custom.removeWhere((c) => ids.contains(c.id));
    notifyListeners();
  }
}
