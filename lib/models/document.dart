import 'dart:io';

import 'package:intl/intl.dart';

/// File-type bucket for [Document]. Drives icons, viewer routing, and the
/// type filter chips on the search screen.
enum DocFileType {
  pdf,
  image,
  video,
  audio,
  document,
  note,
  other;

  String get storageKey => name;

  static DocFileType fromKey(String? key) {
    if (key == null) return DocFileType.other;
    return DocFileType.values.firstWhere(
      (t) => t.name == key,
      orElse: () => DocFileType.other,
    );
  }
}

/// A single document record stored in the `documents` SQLite table.
///
/// Filesystem path is canonical — the same row is keyed by [path] (UNIQUE)
/// so moves are deletes-and-reinserts at the storage layer but updates at
/// the DB layer when only metadata changes.
class Document {
  const Document({
    this.id,
    required this.name,
    required this.path,
    required this.categoryId,
    required this.fileType,
    required this.sizeBytes,
    required this.savedAt,
    this.expiryDate,
    this.reminderDays = 30,
    this.description,
    this.isBookmarked = false,
    this.isNote = false,
  });

  final int? id;
  final String name;
  final String path;
  final String categoryId;
  final DocFileType fileType;
  final int sizeBytes;
  final DateTime savedAt;
  final DateTime? expiryDate;
  final int reminderDays;
  final String? description;
  final bool isBookmarked;
  final bool isNote;

  // ─── Computed ───────────────────────────────────────────────────────
  String get formattedSize {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    if (sizeBytes < 1024 * 1024 * 1024) {
      return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(sizeBytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  String get formattedDate => DateFormat('d MMMM yyyy').format(savedAt);

  String get formattedExpiryDate =>
      expiryDate == null ? '' : DateFormat('d MMM yyyy').format(expiryDate!);

  String get fileTypeIcon {
    switch (fileType) {
      case DocFileType.pdf:
        return '📄';
      case DocFileType.image:
        return '🖼️';
      case DocFileType.video:
        return '🎥';
      case DocFileType.audio:
        return '🎵';
      case DocFileType.document:
        return '📃';
      case DocFileType.note:
        return '📝';
      case DocFileType.other:
        return '📎';
    }
  }

  bool get isExpired =>
      expiryDate != null && expiryDate!.isBefore(DateTime.now());

  bool get isExpiringSoon {
    if (expiryDate == null || isExpired) return false;
    final days = daysUntilExpiry;
    if (days == null) return false;
    return days <= reminderDays;
  }

  int? get daysUntilExpiry {
    if (expiryDate == null) return null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final exp = DateTime(
      expiryDate!.year,
      expiryDate!.month,
      expiryDate!.day,
    );
    return exp.difference(today).inDays;
  }

  String get extension {
    final i = path.lastIndexOf('.');
    if (i < 0 || i == path.length - 1) return '';
    return path.substring(i + 1).toLowerCase();
  }

  bool get fileExistsOnDisk => File(path).existsSync();

  // ─── Static helpers ─────────────────────────────────────────────────
  static DocFileType typeFromExtension(String ext, {bool isNote = false}) {
    final e = ext.toLowerCase().replaceAll('.', '');
    if (isNote && e == 'txt') return DocFileType.note;
    switch (e) {
      case 'pdf':
        return DocFileType.pdf;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'webp':
      case 'heic':
      case 'gif':
      case 'bmp':
        return DocFileType.image;
      case 'mp4':
      case 'mov':
      case 'webm':
      case 'avi':
      case 'mkv':
      case '3gp':
        return DocFileType.video;
      case 'mp3':
      case 'wav':
      case 'm4a':
      case 'aac':
      case 'ogg':
        return DocFileType.audio;
      case 'doc':
      case 'docx':
      case 'odt':
      case 'rtf':
      case 'txt':
        return DocFileType.document;
      default:
        return DocFileType.other;
    }
  }

  Document copyWith({
    int? id,
    String? name,
    String? path,
    String? categoryId,
    DocFileType? fileType,
    int? sizeBytes,
    DateTime? savedAt,
    DateTime? expiryDate,
    bool clearExpiryDate = false,
    int? reminderDays,
    String? description,
    bool? isBookmarked,
    bool? isNote,
  }) {
    return Document(
      id: id ?? this.id,
      name: name ?? this.name,
      path: path ?? this.path,
      categoryId: categoryId ?? this.categoryId,
      fileType: fileType ?? this.fileType,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      savedAt: savedAt ?? this.savedAt,
      expiryDate: clearExpiryDate ? null : (expiryDate ?? this.expiryDate),
      reminderDays: reminderDays ?? this.reminderDays,
      description: description ?? this.description,
      isBookmarked: isBookmarked ?? this.isBookmarked,
      isNote: isNote ?? this.isNote,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'path': path,
        'categoryId': categoryId,
        'fileType': fileType.storageKey,
        'sizeBytes': sizeBytes,
        'savedAt': savedAt.millisecondsSinceEpoch,
        'expiryDate': expiryDate?.millisecondsSinceEpoch,
        'reminderDays': reminderDays,
        'description': description,
        'isBookmarked': isBookmarked ? 1 : 0,
        'isNote': isNote ? 1 : 0,
      };

  factory Document.fromMap(Map<String, dynamic> map) {
    return Document(
      id: map['id'] as int?,
      name: map['name'] as String? ?? '',
      path: map['path'] as String? ?? '',
      categoryId: map['categoryId'] as String? ?? '',
      fileType: DocFileType.fromKey(map['fileType'] as String?),
      sizeBytes: (map['sizeBytes'] as int?) ?? 0,
      savedAt: DateTime.fromMillisecondsSinceEpoch(
        (map['savedAt'] as int?) ?? 0,
      ),
      expiryDate: map['expiryDate'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(map['expiryDate'] as int),
      reminderDays: (map['reminderDays'] as int?) ?? 30,
      description: map['description'] as String?,
      isBookmarked: ((map['isBookmarked'] as int?) ?? 0) == 1,
      isNote: ((map['isNote'] as int?) ?? 0) == 1,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Document && other.path == path);

  @override
  int get hashCode => path.hashCode;

  @override
  String toString() =>
      'Document(id: $id, name: $name, path: $path, '
      'cat: $categoryId, type: ${fileType.name})';
}
