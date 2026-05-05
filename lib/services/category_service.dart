import 'package:flutter/foundation.dart' hide Category;

import '../data/default_categories.dart';
import '../models/category.dart';
import '../utils/constants.dart';
import 'database_service.dart';
import 'onboarding_service.dart';

/// Holds DocShelf's category tree (defaults + user-created custom nodes)
/// and notifies listeners on any mutation.
///
/// Default categories are read-only code (`kDefaultCategories`). Users
/// can still "delete" them — we record their IDs in
/// `_hiddenDefaults` (persisted via [OnboardingService]) and filter them
/// out of every reader. The actual document files in those folders move
/// to Other / Unsorted before the hide takes effect, so nothing is lost.
class CategoryService extends ChangeNotifier {
  static final CategoryService instance = CategoryService._();
  CategoryService._();

  final List<Category> _custom = [];
  final Set<String> _hiddenDefaults = <String>{};
  bool _loaded = false;

  // ─── Load ───────────────────────────────────────────────────────────
  Future<void> load() async {
    final custom = await DatabaseService.instance.getCustomCategories();
    _custom
      ..clear()
      ..addAll(custom);
    final hidden =
        await OnboardingService.instance.getHiddenDefaultCategories();
    _hiddenDefaults
      ..clear()
      ..addAll(hidden);
    _loaded = true;
    notifyListeners();
  }

  bool get isLoaded => _loaded;
  Set<String> get hiddenDefaults => Set.unmodifiable(_hiddenDefaults);
  bool get hasHiddenDefaults => _hiddenDefaults.isNotEmpty;

  // ─── Reads ──────────────────────────────────────────────────────────
  /// True if [id] is a built-in default (lives in `kDefaultCategories`)
  /// rather than a user-created custom category.
  bool isDefault(String id) =>
      flattenDefaults().any((c) => c.id == id);

  bool _isHidden(String id) => _hiddenDefaults.contains(id);

  List<Category> get rootCategories {
    final defaults =
        kDefaultCategories.where((c) => !_isHidden(c.id)).toList();
    final customRoots = _custom.where((c) => c.parentId == null).toList();
    return [...defaults, ...customRoots];
  }

  /// Flat list of every category (root + nested) — useful for fast id lookups.
  List<Category> get flatCategories {
    final out = <Category>[];
    out.addAll(flattenDefaults().where((c) => !_isHidden(c.id)));
    out.addAll(_custom);
    return out;
  }

  List<Category> get allCategories => flatCategories;

  Category? getCategoryById(String id) {
    if (_isHidden(id)) return null;
    for (final c in flatCategories) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// Children (one level deep) for a given parent id. Combines built-in and
  /// custom subcategories. Pass null to get top-level roots.
  List<Category> getChildren(String? parentId) {
    if (parentId == null) return rootCategories;
    if (_isHidden(parentId)) return const [];
    final defaults = flattenDefaults()
        .where((c) => c.parentId == parentId && !_isHidden(c.id));
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
  ///
  /// Walks the FULL tree (including hidden defaults) — needed because
  /// when the user deletes a default we still need to find its children
  /// to mark them hidden too.
  List<String> getAllDescendantIds(String categoryId) {
    final result = <String>[categoryId];
    final stack = <String>[categoryId];
    final fullTree = <Category>[
      ...flattenDefaults(),
      ..._custom,
    ];
    while (stack.isNotEmpty) {
      final cur = stack.removeLast();
      for (final c in fullTree) {
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

  /// Deletes a category. Behaviour depends on whether it's custom or
  /// default:
  ///   - custom  → row removed from DB; docs either deleted or moved.
  ///   - default → ID added to `_hiddenDefaults` and persisted; docs
  ///               always moved to Other / Unsorted (we can't rip the
  ///               default tree out of code, only hide it).
  ///
  /// `Other / Unsorted` (`cat_other`) cannot be deleted — it's the
  /// catch-all destination for moved docs.
  Future<void> deleteCategory(
    String id, {
    bool moveDocsToOther = true,
  }) async {
    if (id == AppConstants.unsortedCategoryId) {
      throw StateError(
        'Other / Unsorted cannot be deleted — it is the catch-all '
        'where deleted folders\' documents land.',
      );
    }

    final ids = getAllDescendantIds(id);

    // Defaults always move docs (we can't truly delete the folder, so
    // refusing to move would leak unreachable docs).
    final touchesDefault =
        ids.any((cid) => isDefault(cid));
    final shouldMove = touchesDefault ? true : moveDocsToOther;

    await DatabaseService.instance.deleteCategoryAndChildren(
      id,
      ids,
      moveDocsToOther: shouldMove,
    );

    // Custom rows: drop from in-memory cache.
    _custom.removeWhere((c) => ids.contains(c.id));

    // Default IDs in this subtree: mark hidden.
    final newlyHidden =
        ids.where((cid) => isDefault(cid)).toSet();
    if (newlyHidden.isNotEmpty) {
      _hiddenDefaults.addAll(newlyHidden);
      await OnboardingService.instance
          .setHiddenDefaultCategories(_hiddenDefaults);
    }

    notifyListeners();
  }

  /// "Restore default folders" — clears every hidden-default flag so
  /// the built-in tree comes back in full. Documents that had been
  /// moved to Other / Unsorted stay where they were (we can't know
  /// which ones came from where).
  Future<void> restoreAllDefaults() async {
    if (_hiddenDefaults.isEmpty) return;
    _hiddenDefaults.clear();
    await OnboardingService.instance.setHiddenDefaultCategories({});
    notifyListeners();
  }
}
