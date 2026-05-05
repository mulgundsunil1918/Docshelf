import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/document.dart';
import '../utils/constants.dart';
import 'database_service.dart';

/// Manages the on-disk DocShelf vault under
/// `/storage/emulated/0/DocShelf/<Cat1>/<Cat2>/...` so users can browse
/// the same folders from any file manager.
class FileStorageService {
  static final FileStorageService instance = FileStorageService._();
  FileStorageService._();

  // ─── Paths ──────────────────────────────────────────────────────────
  Future<String> get rootDir async {
    if (Platform.isAndroid) {
      // Top-level visible folder. Requires MANAGE_EXTERNAL_STORAGE on
      // Android 11+; users grant this once via Settings.
      final external =
          Directory('/storage/emulated/0/${AppConstants.storageRoot}');
      if (!external.existsSync()) {
        try {
          external.createSync(recursive: true);
        } catch (_) {/* fall through to app-private fallback below */}
      }
      if (external.existsSync()) return external.path;
    }
    final docs = await getApplicationDocumentsDirectory();
    final fallback = Directory(p.join(docs.path, AppConstants.storageRoot));
    if (!fallback.existsSync()) fallback.createSync(recursive: true);
    return fallback.path;
  }

  String sanitizeName(String s) {
    final t = s.trim();
    if (t.isEmpty) return 'Untitled';
    return t.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
  }

  Future<List<String>> _categoryPathSegments(String categoryId) async {
    return DatabaseService.instance.getCategoryPathNames(categoryId);
  }

  /// Builds an absolute folder path for the given category.
  Future<String> ensureCategoryDir({required String categoryId}) async {
    final root = await rootDir;
    final segs = await _categoryPathSegments(categoryId);
    final cleaned = segs.map(sanitizeName).toList();
    final full = p.joinAll([root, ...cleaned]);
    final dir = Directory(full);
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return full;
  }

  // ─── Storing files ──────────────────────────────────────────────────
  Future<Document> storeDocument({
    required String sourcePath,
    required String categoryId,
    String? customName,
    DateTime? expiryDate,
    int reminderDays = 30,
    String? description,
    bool isBookmarked = false,
  }) async {
    final src = File(sourcePath);
    if (!src.existsSync()) {
      throw FileSystemException('Source missing', sourcePath);
    }
    final originalName = customName?.trim().isNotEmpty == true
        ? customName!.trim()
        : p.basename(sourcePath);
    final name = sanitizeName(originalName);
    final dir = await ensureCategoryDir(categoryId: categoryId);
    final destPath = _uniqueDest(p.join(dir, name));
    final dest = await src.copy(destPath);
    final size = dest.lengthSync();
    final ext = p.extension(destPath);
    return Document(
      name: p.basenameWithoutExtension(destPath),
      path: dest.path,
      categoryId: categoryId,
      fileType: Document.typeFromExtension(ext),
      sizeBytes: size,
      savedAt: DateTime.now(),
      expiryDate: expiryDate,
      reminderDays: reminderDays,
      description: description,
      isBookmarked: isBookmarked,
    );
  }

  Future<Document> createNote({
    required String title,
    required String content,
    required String categoryId,
  }) async {
    final dir = await ensureCategoryDir(categoryId: categoryId);
    final fileName =
        '${sanitizeName(title.isEmpty ? 'Untitled note' : title)}.txt';
    final destPath = _uniqueDest(p.join(dir, fileName));
    final f = await File(destPath).writeAsString(content);
    final size = f.lengthSync();
    return Document(
      name: p.basenameWithoutExtension(destPath),
      path: f.path,
      categoryId: categoryId,
      fileType: DocFileType.note,
      sizeBytes: size,
      savedAt: DateTime.now(),
      isNote: true,
    );
  }

  Future<Document> moveDocument(
    Document doc, {
    required String newCategoryId,
  }) async {
    final destDir = await ensureCategoryDir(categoryId: newCategoryId);
    final fileName = p.basename(doc.path);
    final destPath = _uniqueDest(p.join(destDir, fileName));
    final src = File(doc.path);
    if (!src.existsSync()) {
      throw FileSystemException('File missing', doc.path);
    }
    final moved = await src.rename(destPath).catchError((_) async {
      final copied = await src.copy(destPath);
      await src.delete();
      return copied;
    });
    return doc.copyWith(
      path: moved.path,
      categoryId: newCategoryId,
    );
  }

  Future<bool> deleteDocumentFromStorage(String filePath) async {
    final f = File(filePath);
    if (!f.existsSync()) return true;
    try {
      await f.delete();
    } catch (_) {
      return false;
    }
    return !f.existsSync();
  }

  Future<void> deleteCategoryDir({required String categoryId}) async {
    final root = await rootDir;
    final segs = await _categoryPathSegments(categoryId);
    if (segs.isEmpty) return;
    final cleaned = segs.map(sanitizeName).toList();
    final full = p.joinAll([root, ...cleaned]);
    final dir = Directory(full);
    if (dir.existsSync()) {
      try {
        dir.deleteSync(recursive: true);
      } catch (_) {/* swallow — DB row will still be removed */}
    }
  }

  // ─── Utility ────────────────────────────────────────────────────────
  String _uniqueDest(String desired) {
    final f = File(desired);
    if (!f.existsSync()) return desired;
    final dir = p.dirname(desired);
    final stem = p.basenameWithoutExtension(desired);
    final ext = p.extension(desired);
    var i = 2;
    while (true) {
      final candidate = p.join(dir, '$stem ($i)$ext');
      if (!File(candidate).existsSync()) return candidate;
      i += 1;
    }
  }

  Future<int> getTotalStorageUsed() async {
    final root = await rootDir;
    final dir = Directory(root);
    if (!dir.existsSync()) return 0;
    var total = 0;
    try {
      await for (final entity in dir.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          try {
            total += await entity.length();
          } catch (_) {}
        }
      }
    } catch (_) {}
    return total;
  }

  bool fileExists(String path) => File(path).existsSync();
}
