import 'package:flutter/foundation.dart' hide Category;

/// A node in DocShelf's category tree.
///
/// Defaults are seeded from `lib/data/default_categories.dart` (in code, not
/// the database). User-created categories live in `custom_categories` and
/// have ids prefixed `custom_<timestamp>`.
@immutable
class Category {
  const Category({
    required this.id,
    required this.name,
    required this.emoji,
    this.parentId,
    this.depth = 0,
    this.children = const [],
    this.isCustom = false,
    this.ownerMemberId,
  });

  final String id;
  final String name;
  final String emoji;
  final String? parentId;
  final int depth;
  final List<Category> children;
  final bool isCustom;

  /// Null = shared across every family member (default for built-ins).
  /// Non-null = visible only to that member.
  final String? ownerMemberId;

  bool get hasChildren => children.isNotEmpty;
  bool get isRoot => parentId == null;

  Category copyWith({
    String? id,
    String? name,
    String? emoji,
    String? parentId,
    int? depth,
    List<Category>? children,
    bool? isCustom,
    String? ownerMemberId,
    bool clearOwnerMemberId = false,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      emoji: emoji ?? this.emoji,
      parentId: parentId ?? this.parentId,
      depth: depth ?? this.depth,
      children: children ?? this.children,
      isCustom: isCustom ?? this.isCustom,
      ownerMemberId:
          clearOwnerMemberId ? null : (ownerMemberId ?? this.ownerMemberId),
    );
  }

  // ─── Serialization (custom only) ────────────────────────────────────
  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'parentId': parentId,
        'emoji': emoji,
        'ownerMemberId': ownerMemberId,
      };

  factory Category.fromMap(Map<String, dynamic> map, {int depth = 0}) {
    return Category(
      id: map['id'] as String,
      name: (map['name'] as String?) ?? '',
      emoji: (map['emoji'] as String?) ?? '📁',
      parentId: map['parentId'] as String?,
      depth: depth,
      isCustom: true,
      ownerMemberId: map['ownerMemberId'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Category && other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'Category(id: $id, name: $name, parent: $parentId, depth: $depth, '
      'custom: $isCustom, owner: $ownerMemberId)';
}
