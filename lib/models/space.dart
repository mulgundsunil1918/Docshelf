import 'package:flutter/foundation.dart';

/// Type of a [Space] — answers "what is this context for?"
///
/// A Space can be a person (Self, Wife, Kid, Dad), a context (Work, Side
/// Project, Class 8-A), or just "Other." The avatar emoji is what users
/// recognize visually; the type is mostly metadata for grouping.
enum SpaceType {
  personal,
  family,
  work,
  study,
  project,
  client,
  other;

  String get storageKey => name;

  String get label {
    switch (this) {
      case SpaceType.personal:
        return 'Personal';
      case SpaceType.family:
        return 'Family';
      case SpaceType.work:
        return 'Work';
      case SpaceType.study:
        return 'Study';
      case SpaceType.project:
        return 'Project';
      case SpaceType.client:
        return 'Client';
      case SpaceType.other:
        return 'Other';
    }
  }

  static SpaceType fromKey(String? key) {
    if (key == null) return SpaceType.other;
    return SpaceType.values.firstWhere(
      (r) => r.name == key,
      orElse: () => SpaceType.other,
    );
  }
}

/// A "Space" is a top-level context inside DocShelf — could be a person
/// (Self, Wife, Mom), a work bucket (Office, Side Project), a study
/// bucket (Class 8-A, my own coursework), or anything the user wants
/// to keep separate. Each Space has its own folder tree on disk.
@immutable
class Space {
  Space({
    required this.id,
    required this.name,
    required this.type,
    required this.avatar,
    this.description,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;
  final String name;
  final SpaceType type;
  final String avatar;
  final String? description;
  final DateTime createdAt;

  /// Folder-safe version of [name] for the on-disk path.
  String get safeName {
    final t = name.trim();
    if (t.isEmpty) return id;
    return t.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
  }

  Space copyWith({
    String? id,
    String? name,
    SpaceType? type,
    String? avatar,
    String? description,
    bool clearDescription = false,
    DateTime? createdAt,
  }) {
    return Space(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      avatar: avatar ?? this.avatar,
      description:
          clearDescription ? null : (description ?? this.description),
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'type': type.storageKey,
        'avatar': avatar,
        'description': description,
        'createdAt': createdAt.millisecondsSinceEpoch,
      };

  factory Space.fromMap(Map<String, dynamic> map) {
    return Space(
      id: map['id'] as String,
      name: (map['name'] as String?) ?? '',
      type: SpaceType.fromKey(map['type'] as String?),
      avatar: (map['avatar'] as String?) ?? '👤',
      description: map['description'] as String?,
      createdAt: map['createdAt'] == null
          ? DateTime.now()
          : DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Space && other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Space(id: $id, name: $name, type: ${type.name})';
}
