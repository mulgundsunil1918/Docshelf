import 'package:flutter/foundation.dart';

/// Lightweight pub/sub for document changes.
///
/// Any screen that displays a list of documents listens to this. Whenever
/// a document is saved, deleted, moved, bookmarked, or has its expiry
/// updated, call [notifyDocumentChanged]. Listeners then refetch from
/// `DatabaseService` — no shared in-memory state to keep in sync.
class DocumentNotifier extends ChangeNotifier {
  static final DocumentNotifier instance = DocumentNotifier._();
  DocumentNotifier._();

  int _revision = 0;
  int get revision => _revision;

  void notifyDocumentChanged() {
    _revision++;
    notifyListeners();
  }
}
