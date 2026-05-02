import 'package:flutter/foundation.dart';

enum FamilyRelation {
  self,
  spouse,
  kid,
  parent,
  sibling,
  other;

  String get storageKey => name;

  String get label {
    switch (this) {
      case FamilyRelation.self:
        return 'Self';
      case FamilyRelation.spouse:
        return 'Spouse';
      case FamilyRelation.kid:
        return 'Kid';
      case FamilyRelation.parent:
        return 'Parent';
      case FamilyRelation.sibling:
        return 'Sibling';
      case FamilyRelation.other:
        return 'Other';
    }
  }

  static FamilyRelation fromKey(String? key) {
    if (key == null) return FamilyRelation.other;
    return FamilyRelation.values.firstWhere(
      (r) => r.name == key,
      orElse: () => FamilyRelation.other,
    );
  }
}

@immutable
class FamilyMember {
  FamilyMember({
    required this.id,
    required this.name,
    required this.relation,
    required this.avatar,
    this.dateOfBirth,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;
  final String name;
  final FamilyRelation relation;
  final String avatar;
  final DateTime? dateOfBirth;
  final DateTime createdAt;

  /// Folder-safe version of [name] used to build storage paths.
  String get safeName {
    final t = name.trim();
    if (t.isEmpty) return id;
    return t.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
  }

  FamilyMember copyWith({
    String? id,
    String? name,
    FamilyRelation? relation,
    String? avatar,
    DateTime? dateOfBirth,
    bool clearDateOfBirth = false,
    DateTime? createdAt,
  }) {
    return FamilyMember(
      id: id ?? this.id,
      name: name ?? this.name,
      relation: relation ?? this.relation,
      avatar: avatar ?? this.avatar,
      dateOfBirth:
          clearDateOfBirth ? null : (dateOfBirth ?? this.dateOfBirth),
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'relation': relation.storageKey,
        'avatar': avatar,
        'dateOfBirth': dateOfBirth?.millisecondsSinceEpoch,
        'createdAt': createdAt.millisecondsSinceEpoch,
      };

  factory FamilyMember.fromMap(Map<String, dynamic> map) {
    return FamilyMember(
      id: map['id'] as String,
      name: (map['name'] as String?) ?? '',
      relation: FamilyRelation.fromKey(map['relation'] as String?),
      avatar: (map['avatar'] as String?) ?? '👤',
      dateOfBirth: map['dateOfBirth'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(map['dateOfBirth'] as int),
      createdAt: map['createdAt'] == null
          ? DateTime.now()
          : DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is FamilyMember && other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'FamilyMember(id: $id, name: $name, relation: ${relation.name})';
}
