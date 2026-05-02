import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../data/default_categories.dart';
import '../models/category.dart';
import '../models/document.dart';
import '../models/space.dart';
import '../utils/constants.dart';

/// SQLite wrapper for DocShelf.
///
/// Three tables: `documents`, `custom_categories`, `spaces`. Default
/// categories (the built-in roots) live in code, not the DB.
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
            spaceId TEXT NOT NULL,
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
          'CREATE INDEX idx_documents_space ON documents(spaceId)',
        );
        await db.execute(
          'CREATE INDEX idx_documents_expiry ON documents(expiryDate)',
        );
        await db.execute('''
          CREATE TABLE custom_categories (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            parentId TEXT,
            emoji TEXT NOT NULL DEFAULT '📁',
            ownerSpaceId TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE spaces (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            type TEXT NOT NULL,
            avatar TEXT NOT NULL,
            description TEXT,
            createdAt INTEGER NOT NULL
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

  Future<List<Document>> getAllDocuments({String? spaceId}) async {
    final db = await database;
    final rows = await db.query(
      'documents',
      where: spaceId == null ? null : 'spaceId = ?',
      whereArgs: spaceId == null ? null : [spaceId],
      orderBy: 'savedAt DESC',
    );
    return rows.map(Document.fromMap).toList(growable: false);
  }

  Future<List<Document>> getDocumentsByCategory(
    String categoryId, {
    String? spaceId,
  }) async {
    final db = await database;
    final where = StringBuffer('categoryId = ?');
    final args = <Object?>[categoryId];
    if (spaceId != null) {
      where.write(' AND spaceId = ?');
      args.add(spaceId);
    }
    final rows = await db.query(
      'documents',
      where: where.toString(),
      whereArgs: args,
      orderBy: 'savedAt DESC',
    );
    return rows.map(Document.fromMap).toList(growable: false);
  }

  Future<List<Document>> getDocumentsBySpace(String spaceId) =>
      getAllDocuments(spaceId: spaceId);

  Future<List<Document>> getDocumentsByCategories(
    List<String> categoryIds, {
    String? spaceId,
  }) async {
    if (categoryIds.isEmpty) return const [];
    final db = await database;
    final placeholders = List.filled(categoryIds.length, '?').join(',');
    final where = StringBuffer('categoryId IN ($placeholders)');
    final args = <Object?>[...categoryIds];
    if (spaceId != null) {
      where.write(' AND spaceId = ?');
      args.add(spaceId);
    }
    final rows = await db.query(
      'documents',
      where: where.toString(),
      whereArgs: args,
      orderBy: 'savedAt DESC',
    );
    return rows.map(Document.fromMap).toList(growable: false);
  }

  Future<List<Document>> getBookmarkedDocuments({String? spaceId}) async {
    final db = await database;
    final where = StringBuffer('isBookmarked = 1');
    final args = <Object?>[];
    if (spaceId != null) {
      where.write(' AND spaceId = ?');
      args.add(spaceId);
    }
    final rows = await db.query(
      'documents',
      where: where.toString(),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'savedAt DESC',
    );
    return rows.map(Document.fromMap).toList(growable: false);
  }

  Future<List<Document>> getExpiringDocuments(
    int withinDays, {
    String? spaceId,
  }) async {
    final db = await database;
    final cutoff = DateTime.now()
        .add(Duration(days: withinDays))
        .millisecondsSinceEpoch;
    final where = StringBuffer('expiryDate IS NOT NULL AND expiryDate <= ?');
    final args = <Object?>[cutoff];
    if (spaceId != null) {
      where.write(' AND spaceId = ?');
      args.add(spaceId);
    }
    final rows = await db.query(
      'documents',
      where: where.toString(),
      whereArgs: args,
      orderBy: 'expiryDate ASC',
    );
    return rows.map(Document.fromMap).toList(growable: false);
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

  Future<int> deleteDocumentsBySpace(String spaceId) async {
    final db = await database;
    return db.delete(
      'documents',
      where: 'spaceId = ?',
      whereArgs: [spaceId],
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
    String? newSpaceId,
  }) async {
    final db = await database;
    final patch = <String, Object?>{'categoryId': newCategoryId};
    if (newPath != null) patch['path'] = newPath;
    if (newSpaceId != null) patch['spaceId'] = newSpaceId;
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

  Future<List<Category>> getCustomCategories({String? spaceId}) async {
    final db = await database;
    final rows = await db.query('custom_categories');
    final all = rows.map((r) => Category.fromMap(r)).toList();
    if (spaceId == null) return all;
    return all
        .where((c) => c.ownerSpaceId == null || c.ownerSpaceId == spaceId)
        .toList();
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

  // ─── Spaces ─────────────────────────────────────────────────────────
  Future<void> saveSpace(Space s) async {
    final db = await database;
    await db.insert(
      'spaces',
      s.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Space>> getAllSpaces() async {
    final db = await database;
    final rows = await db.query('spaces', orderBy: 'createdAt ASC');
    return rows.map(Space.fromMap).toList(growable: false);
  }

  Future<Space?> getSpaceById(String id) async {
    final db = await database;
    final rows = await db.query(
      'spaces',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Space.fromMap(rows.first);
  }

  Future<void> deleteSpace(String id) async {
    final db = await database;
    final batch = db.batch();
    batch.delete('documents', where: 'spaceId = ?', whereArgs: [id]);
    batch.delete('custom_categories',
        where: 'ownerSpaceId = ?', whereArgs: [id]);
    batch.delete('spaces', where: 'id = ?', whereArgs: [id]);
    await batch.commit(noResult: true);
  }
}
