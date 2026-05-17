import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../data/default_categories.dart';
import '../models/category.dart';
import '../models/document.dart';
import '../utils/constants.dart';

/// SQLite wrapper for DocShelf.
///
/// Two tables: `documents` and `custom_categories`. Default categories
/// (the built-in roots) live in code, not the DB.
class DatabaseService {
  static final DatabaseService instance = DatabaseService._();
  DatabaseService._();

  Database? _db;

  Future<Database> get database async {
    return _db ??= await _open();
  }

  Future<Database> _open() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, AppConstants.dbFileName);
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE documents (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            path TEXT NOT NULL UNIQUE,
            categoryId TEXT NOT NULL,
            fileType TEXT NOT NULL,
            sizeBytes INTEGER NOT NULL,
            savedAt INTEGER NOT NULL,
            expiryDate INTEGER,
            reminderDays INTEGER NOT NULL DEFAULT 30,
            description TEXT,
            isBookmarked INTEGER NOT NULL DEFAULT 0,
            isNote INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute(
          'CREATE INDEX idx_documents_category ON documents(categoryId)',
        );
        await db.execute(
          'CREATE INDEX idx_documents_expiry ON documents(expiryDate)',
        );
        await db.execute('''
          CREATE TABLE custom_categories (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            parentId TEXT,
            emoji TEXT NOT NULL DEFAULT '📁'
          )
        ''');
      },
    );
  }

  Future<void> close() async {
    final db = _db;
    if (db != null) {
      await db.close();
      _db = null;
    }
  }

  // ─── Documents ──────────────────────────────────────────────────────
  Future<int> saveDocument(Document doc) async {
    final db = await database;
    return db.insert(
      'documents',
      doc.toMap()..remove('id'),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> updateDocument(Document doc) async {
    final db = await database;
    return db.update(
      'documents',
      doc.toMap()..remove('id'),
      where: 'path = ?',
      whereArgs: [doc.path],
    );
  }

  /// Fixes a stale iOS container-UUID path in-place.
  /// Called by FileStorageService.resolvedPath() after a successful remap.
  Future<void> updateDocumentPath(int id, String newPath) async {
    final db = await database;
    await db.update(
      'documents',
      {'path': newPath},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Document>> getAllDocuments() async {
    final db = await database;
    final rows = await db.query('documents', orderBy: 'savedAt DESC');
    return rows.map(Document.fromMap).toList(growable: false);
  }

  Future<List<Document>> getDocumentsByCategory(String categoryId) async {
    final db = await database;
    final rows = await db.query(
      'documents',
      where: 'categoryId = ?',
      whereArgs: [categoryId],
      orderBy: 'savedAt DESC',
    );
    return rows.map(Document.fromMap).toList(growable: false);
  }

  Future<List<Document>> getDocumentsByCategories(
    List<String> categoryIds,
  ) async {
    if (categoryIds.isEmpty) return const [];
    final db = await database;
    final placeholders = List.filled(categoryIds.length, '?').join(',');
    final rows = await db.query(
      'documents',
      where: 'categoryId IN ($placeholders)',
      whereArgs: categoryIds,
      orderBy: 'savedAt DESC',
    );
    return rows.map(Document.fromMap).toList(growable: false);
  }

  Future<List<Document>> getBookmarkedDocuments() async {
    final db = await database;
    final rows = await db.query(
      'documents',
      where: 'isBookmarked = 1',
      orderBy: 'savedAt DESC',
    );
    return rows.map(Document.fromMap).toList(growable: false);
  }

  Future<List<Document>> getExpiringDocuments(int withinDays) async {
    final db = await database;
    final cutoff = DateTime.now()
        .add(Duration(days: withinDays))
        .millisecondsSinceEpoch;
    final rows = await db.query(
      'documents',
      where: 'expiryDate IS NOT NULL AND expiryDate <= ?',
      whereArgs: [cutoff],
      orderBy: 'expiryDate ASC',
    );
    return rows.map(Document.fromMap).toList(growable: false);
  }

  Future<int> countDocumentsInCategory(String categoryId) async {
    final db = await database;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM documents WHERE categoryId = ?',
      [categoryId],
    );
    return (rows.first['c'] as int?) ?? 0;
  }

  Future<int> countDocumentsInCategories(List<String> categoryIds) async {
    if (categoryIds.isEmpty) return 0;
    final db = await database;
    final placeholders = List.filled(categoryIds.length, '?').join(',');
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM documents WHERE categoryId IN ($placeholders)',
      categoryIds,
    );
    return (rows.first['c'] as int?) ?? 0;
  }

  Future<Document?> getDocumentById(int id) async {
    final db = await database;
    final rows = await db.query(
      'documents',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Document.fromMap(rows.first);
  }

  Future<Document?> getDocumentByPath(String path) async {
    final db = await database;
    final rows = await db.query(
      'documents',
      where: 'path = ?',
      whereArgs: [path],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Document.fromMap(rows.first);
  }

  Future<int> deleteDocument(String path) async {
    final db = await database;
    return db.delete(
      'documents',
      where: 'path = ?',
      whereArgs: [path],
    );
  }

  Future<int> deleteDocumentsByCategories(List<String> ids) async {
    if (ids.isEmpty) return 0;
    final db = await database;
    final placeholders = List.filled(ids.length, '?').join(',');
    return db.delete(
      'documents',
      where: 'categoryId IN ($placeholders)',
      whereArgs: ids,
    );
  }

  Future<void> toggleBookmark(String path, bool bookmarked) async {
    final db = await database;
    await db.update(
      'documents',
      {'isBookmarked': bookmarked ? 1 : 0},
      where: 'path = ?',
      whereArgs: [path],
    );
  }

  Future<void> moveDocument(
    String oldPath, {
    required String newCategoryId,
    String? newPath,
  }) async {
    final db = await database;
    final patch = <String, Object?>{'categoryId': newCategoryId};
    if (newPath != null) patch['path'] = newPath;
    await db.update(
      'documents',
      patch,
      where: 'path = ?',
      whereArgs: [oldPath],
    );
  }

  // ─── Custom categories ──────────────────────────────────────────────
  Future<void> saveCustomCategory(Category cat) async {
    final db = await database;
    await db.insert(
      'custom_categories',
      cat.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Category>> getCustomCategories() async {
    final db = await database;
    final rows = await db.query('custom_categories');
    return rows.map((r) => Category.fromMap(r)).toList();
  }

  Future<void> updateCustomCategory(
    String id, {
    String? newName,
    String? newEmoji,
  }) async {
    final db = await database;
    final patch = <String, Object?>{};
    if (newName != null) patch['name'] = newName;
    if (newEmoji != null) patch['emoji'] = newEmoji;
    if (patch.isEmpty) return;
    await db.update(
      'custom_categories',
      patch,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteCategoryAndChildren(
    String id,
    List<String> allIds, {
    bool moveDocsToOther = false,
  }) async {
    final db = await database;
    final batch = db.batch();
    if (moveDocsToOther) {
      final placeholders = List.filled(allIds.length, '?').join(',');
      batch.update(
        'documents',
        {'categoryId': AppConstants.unsortedCategoryId},
        where: 'categoryId IN ($placeholders)',
        whereArgs: allIds,
      );
    } else {
      final placeholders = List.filled(allIds.length, '?').join(',');
      batch.delete(
        'documents',
        where: 'categoryId IN ($placeholders)',
        whereArgs: allIds,
      );
    }
    final placeholders = List.filled(allIds.length, '?').join(',');
    batch.delete(
      'custom_categories',
      where: 'id IN ($placeholders)',
      whereArgs: allIds,
    );
    await batch.commit(noResult: true);
  }

  Future<Category?> getCategoryById(
    String id, {
    Iterable<Category>? defaults,
  }) async {
    final defaultsList = defaults ?? flattenDefaults();
    for (final c in defaultsList) {
      if (c.id == id) return c;
    }
    final db = await database;
    final rows = await db.query(
      'custom_categories',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Category.fromMap(rows.first);
  }

  Future<List<String>> getCategoryPathNames(String categoryId) async {
    final names = <String>[];
    final allDefaults = flattenDefaults();
    final defaultsById = {for (final c in allDefaults) c.id: c};
    final db = await database;
    final customRows = await db.query('custom_categories');
    final customById = {
      for (final r in customRows) r['id'] as String: Category.fromMap(r),
    };

    String? cur = categoryId;
    final guard = <String>{};
    while (cur != null && !guard.contains(cur)) {
      guard.add(cur);
      final cat = defaultsById[cur] ?? customById[cur];
      if (cat == null) break;
      names.insert(0, cat.name);
      cur = cat.parentId;
    }
    return names;
  }
}
