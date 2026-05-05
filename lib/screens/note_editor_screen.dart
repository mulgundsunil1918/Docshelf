import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../models/category.dart';
import '../models/document.dart';
import '../services/category_service.dart';
import '../services/database_service.dart';
import '../services/document_notifier.dart';
import '../services/file_storage_service.dart';
import '../utils/app_colors.dart';
import '../utils/constants.dart';
import '../utils/friendly_error.dart';
import '../utils/note_format.dart';
import '../widgets/category_picker_widget.dart';

/// Edit ↔ Preview note editor.
///
/// **Why this design (and the history that got us here):**
///
/// 1. We tried `flutter_quill` 11.5 — silently rendered as a blank grey
///    rectangle on real devices. Killed it.
/// 2. We tried a custom `MarkdownTextController` that styled markdown
///    markers (`**`, `~~`, `<mark>…</mark>`) as faded text in-place. This
///    looked clever in screenshots but in real use, partially-typed
///    markers (e.g. you start typing `**foo` but never close it) showed
///    as raw asterisks mixed with styled text — users called it "messed
///    up". Killed that too.
/// 3. **Current approach:** plain `TextField` for editing (you see exactly
///    the markdown source you're typing — nothing surprising) + a Preview
///    toggle that swaps the body for a fully-rendered `Markdown` widget.
///    Same pattern as Notion / Bear / GitHub / Reddit. Predictable,
///    debuggable, no hidden state.
///
/// **Toolbar UX rule:** when the user clicks Bold / Italic / etc. with no
/// selection, we insert a placeholder ("bold text") inside the wrappers
/// AND select it, so the next keystroke replaces it. That avoids orphan
/// `**` `**` floating in the document — the original complaint.
class NoteEditorScreen extends StatefulWidget {
  const NoteEditorScreen({
    super.key,
    this.existingDoc,
    this.initialCategoryId,
  });

  final Document? existingDoc;
  final String? initialCategoryId;

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _bodyCtrl;
  late final FocusNode _bodyFocus;
  Category? _category;
  NoteMeta _meta = const NoteMeta();
  bool _saving = false;
  bool _bookmark = false;
  bool _preview = false;

  /// Format keys that are active at the current caret position. Used by
  /// the toolbar to render Bold / Italic / etc. as "pressed" so the user
  /// can SEE that they're inside a bold block — same affordance as Word
  /// or Notion. Recomputed on every text/selection change.
  Set<String> _activeFormats = const {};

  String _titleBaseline = '';
  String _bodyBaseline = '';
  String _categoryIdBaseline = '';
  int _bgBaseline = 0;
  bool _bookmarkBaseline = false;
  bool _baselineSet = false;

  bool get _isEditing => widget.existingDoc != null;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController();
    _bodyCtrl = TextEditingController();
    _bodyFocus = FocusNode();

    final doc = widget.existingDoc;
    if (doc != null) {
      _titleCtrl.text = doc.name;
      _bookmark = doc.isBookmarked;
      String raw = '';
      try {
        raw = File(doc.path).readAsStringSync();
      } catch (_) {/* unreadable — open empty */}
      final parsed = NoteFormat.parse(raw);
      _meta = parsed.meta;
      _bodyCtrl.text = parsed.body;
      _category = CategoryService.instance.getCategoryById(doc.categoryId);
    } else if (widget.initialCategoryId != null) {
      _category =
          CategoryService.instance.getCategoryById(widget.initialCategoryId!);
    }
    _category ??= CategoryService.instance
        .getCategoryById(AppConstants.unsortedCategoryId);

    _titleCtrl.addListener(_onChange);
    _bodyCtrl.addListener(_onChange);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _titleBaseline = _titleCtrl.text;
        _bodyBaseline = _bodyCtrl.text;
        _categoryIdBaseline = _category?.id ?? '';
        _bgBaseline = _meta.bg;
        _bookmarkBaseline = _bookmark;
        _baselineSet = true;
      });
    });
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    _bodyFocus.dispose();
    super.dispose();
  }

  void _onChange() {
    if (!mounted) return;
    final next = _computeActiveFormats();
    setState(() {
      _activeFormats = next;
    });
  }

  // ─── Active-format detection ──────────────────────────────────────
  /// Inspect the line and caret position and return which formats apply.
  /// Used to light up the toolbar buttons so the user has visual feedback
  /// that "Bold is on right now" — the missing piece they complained
  /// about. Cheap to compute (single line, simple substring scans).
  Set<String> _computeActiveFormats() {
    final sel = _bodyCtrl.selection;
    final text = _bodyCtrl.text;
    if (sel.start < 0) return const {};
    final caret = sel.start.clamp(0, text.length);

    // Carve out the line containing the caret.
    var lineStart = caret;
    while (lineStart > 0 && text[lineStart - 1] != '\n') {
      lineStart -= 1;
    }
    var lineEnd = caret;
    while (lineEnd < text.length && text[lineEnd] != '\n') {
      lineEnd += 1;
    }
    final line = text.substring(lineStart, lineEnd);
    final caretInLine = caret - lineStart;

    final active = <String>{};

    // Line-level prefixes — most specific wins.
    if (line.startsWith('### ')) {
      active.add('h3');
    } else if (line.startsWith('## ')) {
      active.add('h2');
    } else if (line.startsWith('# ')) {
      active.add('h1');
    }
    if (line.startsWith('- [ ] ') ||
        line.startsWith('- [x] ') ||
        line.startsWith('- [X] ')) {
      active.add('check');
    } else if (line.startsWith('- ') || line.startsWith('* ')) {
      active.add('bullet');
    }
    if (RegExp(r'^\d+\. ').hasMatch(line)) active.add('numbered');
    if (line.startsWith('> ')) active.add('quote');

    // Inline — caret strictly inside an OPEN…CLOSE pair on this line.
    bool inside(String left, String right) {
      var idx = 0;
      while (true) {
        final openAt = line.indexOf(left, idx);
        if (openAt < 0 || openAt >= caretInLine) return false;
        final closeAt = line.indexOf(right, openAt + left.length);
        if (closeAt < 0) return false;
        // Caret must be strictly between open and close.
        if (caretInLine > openAt + left.length - 1 &&
            caretInLine <= closeAt) {
          return true;
        }
        idx = closeAt + right.length;
      }
    }

    if (inside('**', '**')) active.add('bold');
    if (inside('~~', '~~')) active.add('strike');
    if (inside('`', '`')) active.add('code');
    if (inside('<mark>', '</mark>')) active.add('highlight');

    // Italic: single `*` not adjacent to another `*`. We strip the `**`
    // ranges first so they don't fool the single-`*` scan.
    final italicLine = line.replaceAllMapped(
      RegExp(r'\*\*[^*]*\*\*'),
      (m) => ' ' * m.group(0)!.length,
    );
    final italicRe =
        RegExp(r'(?<![\*\w])\*(?!\*)(.+?)(?<!\*)\*(?![\*\w])');
    for (final m in italicRe.allMatches(italicLine)) {
      if (caretInLine > m.start && caretInLine <= m.end - 1) {
        active.add('italic');
        break;
      }
    }

    return active;
  }

  bool get _dirty {
    if (!_baselineSet) return false;
    return _titleCtrl.text != _titleBaseline ||
        _bodyCtrl.text != _bodyBaseline ||
        (_category?.id ?? '') != _categoryIdBaseline ||
        _meta.bg != _bgBaseline ||
        _bookmark != _bookmarkBaseline;
  }

  bool get _canSave {
    if (_saving) return false;
    if (_titleCtrl.text.trim().isEmpty) return false;
    if (_bodyCtrl.text.trim().isEmpty) return false;
    if (_category == null) return false;
    return true;
  }

  // ─── Toolbar actions ────────────────────────────────────────────────
  /// Wrap the current selection with [left] / [right]. If there's no
  /// selection, insert [placeholder] between them and select that
  /// placeholder, so the next keystroke types over it. This is what
  /// avoids the "orphan `**` floating around" problem.
  void _wrapSelection(String left, String right, {required String placeholder}) {
    final sel = _bodyCtrl.selection;
    final text = _bodyCtrl.text;
    final hasSelection =
        sel.start >= 0 && sel.end >= 0 && sel.start != sel.end;

    if (!hasSelection) {
      // No selection — append wrappers + placeholder at caret (or end).
      final caret = sel.start < 0 ? text.length : sel.start;
      final before = text.substring(0, caret);
      final after = text.substring(caret);
      final inserted = '$left$placeholder$right';
      _bodyCtrl.text = '$before$inserted$after';
      _bodyCtrl.selection = TextSelection(
        baseOffset: before.length + left.length,
        extentOffset: before.length + left.length + placeholder.length,
      );
      _bodyFocus.requestFocus();
      return;
    }

    final selected = sel.textInside(text);
    final before = text.substring(0, sel.start);
    final after = text.substring(sel.end);
    _bodyCtrl.text = '$before$left$selected$right$after';
    _bodyCtrl.selection = TextSelection(
      baseOffset: before.length + left.length,
      extentOffset: before.length + left.length + selected.length,
    );
    _bodyFocus.requestFocus();
  }

  void _prefixCurrentLine(String prefix) {
    final sel = _bodyCtrl.selection;
    final text = _bodyCtrl.text;
    final caret = sel.start < 0 ? text.length : sel.start.clamp(0, text.length);
    // Find the start of the line containing the caret.
    var lineStart = caret;
    while (lineStart > 0 && text[lineStart - 1] != '\n') {
      lineStart -= 1;
    }
    // If the line already begins with this prefix, strip it (toggle).
    final lineRest = text.substring(lineStart);
    if (lineRest.startsWith(prefix)) {
      _bodyCtrl.text =
          '${text.substring(0, lineStart)}${lineRest.substring(prefix.length)}';
      final newCaret = (caret - prefix.length).clamp(lineStart, _bodyCtrl.text.length);
      _bodyCtrl.selection = TextSelection.collapsed(offset: newCaret);
    } else {
      _bodyCtrl.text =
          '${text.substring(0, lineStart)}$prefix${text.substring(lineStart)}';
      _bodyCtrl.selection = TextSelection.collapsed(
        offset: caret + prefix.length,
      );
    }
    _bodyFocus.requestFocus();
  }

  /// Bullet / numbered toggle. Strips any existing list prefix on the
  /// current line (bullet, numbered, checkbox) before applying [prefix],
  /// or removes [prefix] entirely if it's already there. This is what
  /// makes the toolbar "list" buttons act like a real list toggle —
  /// click again to leave the list, click another list type to switch.
  void _toggleListPrefix(String prefix) {
    final sel = _bodyCtrl.selection;
    final text = _bodyCtrl.text;
    final caret = sel.start < 0 ? text.length : sel.start.clamp(0, text.length);
    var lineStart = caret;
    while (lineStart > 0 && text[lineStart - 1] != '\n') {
      lineStart -= 1;
    }
    var lineEnd = caret;
    while (lineEnd < text.length && text[lineEnd] != '\n') {
      lineEnd += 1;
    }
    var line = text.substring(lineStart, lineEnd);

    // Strip ANY existing list-style prefix.
    int stripped = 0;
    final patterns = [
      RegExp(r'^- \[[ xX]\] '),
      RegExp(r'^- '),
      RegExp(r'^\* '),
      RegExp(r'^\d+\. '),
    ];
    for (final re in patterns) {
      final m = re.firstMatch(line);
      if (m != null) {
        stripped = m.end;
        line = line.substring(stripped);
        break;
      }
    }

    // If we stripped exactly the same prefix the user clicked, toggle off.
    final original = text.substring(lineStart, lineStart + stripped);
    final addPrefix = original == prefix ? '' : prefix;

    final newText =
        '${text.substring(0, lineStart)}$addPrefix$line${text.substring(lineEnd)}';
    final caretShift = addPrefix.length - stripped;
    _bodyCtrl.text = newText;
    _bodyCtrl.selection = TextSelection.collapsed(
      offset: (caret + caretShift).clamp(lineStart, _bodyCtrl.text.length),
    );
    _bodyFocus.requestFocus();
  }

  /// Checkbox toggle. Cycles a line between "no prefix" → `- [ ] ` →
  /// `- [x] ` → "no prefix". Strips any other list prefix on the way in.
  void _toggleCheckbox() {
    final sel = _bodyCtrl.selection;
    final text = _bodyCtrl.text;
    final caret = sel.start < 0 ? text.length : sel.start.clamp(0, text.length);
    var lineStart = caret;
    while (lineStart > 0 && text[lineStart - 1] != '\n') {
      lineStart -= 1;
    }
    var lineEnd = caret;
    while (lineEnd < text.length && text[lineEnd] != '\n') {
      lineEnd += 1;
    }
    var line = text.substring(lineStart, lineEnd);

    String add;
    int stripped;
    if (line.startsWith('- [ ] ')) {
      // unchecked → checked
      stripped = 6;
      line = line.substring(6);
      add = '- [x] ';
    } else if (line.startsWith('- [x] ') || line.startsWith('- [X] ')) {
      // checked → plain
      stripped = 6;
      line = line.substring(6);
      add = '';
    } else {
      // plain (or any other list) → unchecked
      stripped = 0;
      for (final re in [RegExp(r'^- '), RegExp(r'^\* '), RegExp(r'^\d+\. ')]) {
        final m = re.firstMatch(line);
        if (m != null) {
          stripped = m.end;
          line = line.substring(stripped);
          break;
        }
      }
      add = '- [ ] ';
    }

    final newText =
        '${text.substring(0, lineStart)}$add$line${text.substring(lineEnd)}';
    final caretShift = add.length - stripped;
    _bodyCtrl.text = newText;
    _bodyCtrl.selection = TextSelection.collapsed(
      offset: (caret + caretShift).clamp(lineStart, _bodyCtrl.text.length),
    );
    _bodyFocus.requestFocus();
  }

  void _insertAtCaret(String snippet) {
    final sel = _bodyCtrl.selection;
    final text = _bodyCtrl.text;
    final caret = sel.start < 0 ? text.length : sel.start;
    _bodyCtrl.text =
        '${text.substring(0, caret)}$snippet${text.substring(caret)}';
    _bodyCtrl.selection = TextSelection.collapsed(
      offset: caret + snippet.length,
    );
    _bodyFocus.requestFocus();
  }

  // ─── Save / discard ─────────────────────────────────────────────────
  Future<void> _save() async {
    if (!_canSave) return;
    setState(() => _saving = true);
    try {
      final body = NoteFormat.serialize(
        body: _bodyCtrl.text,
        meta: _meta,
      );
      if (_isEditing) {
        await _saveExisting(body);
      } else {
        await _saveNew(body);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(FriendlyError.from(e))),
      );
    }
  }

  Future<void> _saveNew(String body) async {
    var doc = await FileStorageService.instance.createNote(
      title: _titleCtrl.text.trim(),
      content: body,
      categoryId: _category!.id,
    );
    final id = await DatabaseService.instance.saveDocument(doc);
    doc = doc.copyWith(id: id, isBookmarked: _bookmark);
    if (_bookmark) {
      await DatabaseService.instance.toggleBookmark(doc.path, true);
    }
    DocumentNotifier.instance.notifyDocumentChanged();
    if (!mounted) return;
    Navigator.of(context).pop();
    final crumb = CategoryService.instance
        .getBreadcrumb(_category!.id)
        .map((c) => c.name)
        .join(' / ');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Note saved to $crumb ✓')),
    );
  }

  Future<void> _saveExisting(String body) async {
    final old = widget.existingDoc!;
    await File(old.path).writeAsString(body);
    final updated = old.copyWith(
      name: _titleCtrl.text.trim(),
      categoryId: _category!.id,
      isBookmarked: _bookmark,
    );
    await DatabaseService.instance.updateDocument(updated);
    DocumentNotifier.instance.notifyDocumentChanged();
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Note saved ✓')),
    );
  }

  Future<bool> _confirmDiscard() async {
    if (!_dirty) return true;
    final keep = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text(
          "You haven't saved this note. Discard your changes?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return keep == true;
  }

  Future<void> _pickCategory() async {
    final picked = await showModalBottomSheet<Category>(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scroll) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            children: [
              Text(
                'Save note in folder',
                style: GoogleFonts.nunito(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ChangeNotifierProvider.value(
                  value: CategoryService.instance,
                  child: CategoryPickerWidget(
                    selectedId: _category?.id,
                    scrollController: scroll,
                    onChanged: (c) => Navigator.of(context).pop(c),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (picked != null) setState(() => _category = picked);
  }

  // ─── Build ──────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = isDark ? AppColors.noteBgDark : AppColors.noteBgLight;
    final pageBg = _meta.bg == 0 ? colors.surface : palette[_meta.bg];

    final crumb = _category == null
        ? 'Choose folder'
        : CategoryService.instance
            .getBreadcrumb(_category!.id)
            .map((c) => c.name)
            .join(' / ');

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmDiscard() && mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: pageBg,
        appBar: AppBar(
          backgroundColor: pageBg,
          elevation: 0,
          title: Text(_isEditing ? 'Edit note' : 'New note'),
          actions: [
            // Edit ↔ Preview toggle
            IconButton(
              tooltip: _preview ? 'Back to editor' : 'Preview',
              onPressed: () => setState(() => _preview = !_preview),
              icon: Icon(
                _preview ? Icons.edit_outlined : Icons.visibility_outlined,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 10,
              ),
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                onPressed: _canSave ? _save : null,
                icon: _saving
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.white,
                        ),
                      )
                    : const Icon(Icons.check, size: 18),
                label: Text(
                  _saving ? 'Saving' : 'Save',
                  style: GoogleFonts.nunito(fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              // ─── Title ───────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Row(
                  children: [
                    Icon(
                      Icons.edit_note,
                      size: 26,
                      color: colors.onSurface.withValues(alpha: 0.5),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _titleCtrl,
                        maxLines: 1,
                        textCapitalization: TextCapitalization.sentences,
                        readOnly: _preview,
                        style: GoogleFonts.nunito(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          height: 1.2,
                          color: colors.onSurface,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Title',
                          hintStyle: GoogleFonts.nunito(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color:
                                colors.onSurface.withValues(alpha: 0.35),
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false,
                          contentPadding: EdgeInsets.zero,
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ─── Folder chip ─────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
                child: InkWell(
                  onTap: _pickCategory,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.30),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.folder_outlined,
                            size: 18, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            crumb,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.nunito(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        const Icon(Icons.unfold_more,
                            size: 16, color: AppColors.primary),
                      ],
                    ),
                  ),
                ),
              ),

              // ─── Toolbar (only in edit mode) ─────────────────────────
              if (!_preview)
                _MarkdownToolbar(
                  active: _activeFormats,
                  onBold: () => _wrapSelection('**', '**',
                      placeholder: 'bold text'),
                  onItalic: () => _wrapSelection('*', '*',
                      placeholder: 'italic text'),
                  onStrike: () => _wrapSelection('~~', '~~',
                      placeholder: 'strike'),
                  onHighlight: () => _wrapSelection('<mark>', '</mark>',
                      placeholder: 'highlight'),
                  onCode: () =>
                      _wrapSelection('`', '`', placeholder: 'code'),
                  onH1: () => _prefixCurrentLine('# '),
                  onH2: () => _prefixCurrentLine('## '),
                  onH3: () => _prefixCurrentLine('### '),
                  onBullet: () => _toggleListPrefix('- '),
                  onNumbered: () => _toggleListPrefix('1. '),
                  onCheck: () => _toggleCheckbox(),
                  onQuote: () => _prefixCurrentLine('> '),
                  onDivider: () => _insertAtCaret('\n\n---\n\n'),
                ),

              // ─── Inline colour palette ───────────────────────────────
              SizedBox(
                height: 56,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  itemCount: palette.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) => _BgSwatch(
                    index: i,
                    color: palette[i],
                    selected: i == _meta.bg,
                    onTap: () => setState(
                      () => _meta = _meta.copyWith(bg: i),
                    ),
                  ),
                ),
              ),

              const Divider(height: 1, thickness: 0.5),

              // ─── Body ────────────────────────────────────────────────
              Expanded(
                child: _preview
                    ? _buildPreview(colors)
                    : _buildEditor(colors),
              ),

              // ─── Footer ──────────────────────────────────────────────
              Container(
                color: colors.surface,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 6,
                ),
                child: Row(
                  children: [
                    InkWell(
                      onTap: () => setState(() => _bookmark = !_bookmark),
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 6,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _bookmark
                                  ? Icons.star
                                  : Icons.star_outline,
                              size: 20,
                              color: _bookmark
                                  ? AppColors.accent
                                  : colors.onSurface.withValues(alpha: 0.6),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _bookmark
                                  ? 'Bookmarked'
                                  : 'Bookmark this note',
                              style: GoogleFonts.nunito(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: _bookmark
                                    ? AppColors.accent
                                    : colors.onSurface
                                        .withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _preview ? 'Preview' : 'Editing',
                      style: GoogleFonts.nunito(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: colors.onSurface.withValues(alpha: 0.55),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '${_bodyCtrl.text.length} char${_bodyCtrl.text.length == 1 ? '' : 's'}',
                      style: GoogleFonts.nunito(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: colors.onSurface.withValues(alpha: 0.55),
                      ),
                    ),
                    if (_dirty) ...[
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Unsaved',
                          style: GoogleFonts.nunito(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: AppColors.warning,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Edit mode body ───────────────────────────────────────────────
  Widget _buildEditor(ColorScheme colors) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: TextField(
        controller: _bodyCtrl,
        focusNode: _bodyFocus,
        maxLines: null,
        expands: true,
        keyboardType: TextInputType.multiline,
        textCapitalization: TextCapitalization.sentences,
        textAlignVertical: TextAlignVertical.top,
        style: GoogleFonts.nunito(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          height: 1.55,
          color: colors.onSurface,
        ),
        decoration: InputDecoration(
          hintText:
              'Start typing your note…\n\n'
              'Tip: tap the eye icon at the top to preview.\n\n'
              'Quick markdown:\n'
              '• **bold**   • *italic*   • ~~strike~~\n'
              '• # heading  • - bullet  • > quote',
          hintStyle: GoogleFonts.nunito(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            height: 1.55,
            color: colors.onSurface.withValues(alpha: 0.40),
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          filled: false,
          contentPadding: EdgeInsets.zero,
          isDense: true,
        ),
      ),
    );
  }

  // ─── Preview mode body ────────────────────────────────────────────
  /// Renders the current `_bodyCtrl.text` using `flutter_markdown` —
  /// the SAME widget the read-only viewer uses, so what you see in
  /// preview is exactly what you'll see after saving.
  Widget _buildPreview(ColorScheme colors) {
    final text = _bodyCtrl.text.trim();
    if (text.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            "Nothing to preview yet — tap the pencil icon to go back to "
            "the editor and write something.",
            textAlign: TextAlign.center,
            style: GoogleFonts.nunito(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: colors.onSurface.withValues(alpha: 0.55),
            ),
          ),
        ),
      );
    }
    return Markdown(
      data: NoteFormat.renderable(_bodyCtrl.text),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      selectable: true,
      styleSheet: MarkdownStyleSheet(
        p: GoogleFonts.nunito(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          height: 1.55,
          color: colors.onSurface,
        ),
        h1: GoogleFonts.nunito(
          fontSize: 24,
          fontWeight: FontWeight.w900,
          color: colors.onSurface,
        ),
        h2: GoogleFonts.nunito(
          fontSize: 20,
          fontWeight: FontWeight.w900,
          color: colors.onSurface,
        ),
        h3: GoogleFonts.nunito(
          fontSize: 17,
          fontWeight: FontWeight.w900,
          color: colors.onSurface,
        ),
        strong: GoogleFonts.nunito(
          fontSize: 16,
          fontWeight: FontWeight.w900,
          color: colors.onSurface,
        ),
        em: GoogleFonts.nunito(
          fontSize: 16,
          fontStyle: FontStyle.italic,
          color: colors.onSurface,
        ),
        blockquote: GoogleFonts.nunito(
          fontSize: 16,
          fontStyle: FontStyle.italic,
          color: colors.onSurface.withValues(alpha: 0.7),
        ),
        blockquoteDecoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: AppColors.primary.withValues(alpha: 0.6),
              width: 4,
            ),
          ),
        ),
        blockquotePadding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
        code: GoogleFonts.firaCode(
          fontSize: 14,
          backgroundColor: colors.onSurface.withValues(alpha: 0.08),
        ),
        listBullet: GoogleFonts.nunito(
          fontSize: 16,
          color: colors.onSurface,
        ),
      ),
    );
  }
}

// ─── Toolbar widget ───────────────────────────────────────────────────
class _MarkdownToolbar extends StatelessWidget {
  const _MarkdownToolbar({
    required this.active,
    required this.onBold,
    required this.onItalic,
    required this.onStrike,
    required this.onHighlight,
    required this.onCode,
    required this.onH1,
    required this.onH2,
    required this.onH3,
    required this.onBullet,
    required this.onNumbered,
    required this.onCheck,
    required this.onQuote,
    required this.onDivider,
  });

  /// Format keys ('bold', 'italic', 'h1', 'bullet', etc.) currently in
  /// effect at the caret. Buttons whose key is in here render with the
  /// primary tint so the user SEES which formatting is on.
  final Set<String> active;
  final VoidCallback onBold;
  final VoidCallback onItalic;
  final VoidCallback onStrike;
  final VoidCallback onHighlight;
  final VoidCallback onCode;
  final VoidCallback onH1;
  final VoidCallback onH2;
  final VoidCallback onH3;
  final VoidCallback onBullet;
  final VoidCallback onNumbered;
  final VoidCallback onCheck;
  final VoidCallback onQuote;
  final VoidCallback onDivider;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      color: colors.surface,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            _ToolbarBtn(
                tooltip: 'Bold',
                onTap: onBold,
                isActive: active.contains('bold'),
                child: const Text('B',
                    style: TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w900))),
            _ToolbarBtn(
                tooltip: 'Italic',
                onTap: onItalic,
                isActive: active.contains('italic'),
                child: const Text('I',
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        fontStyle: FontStyle.italic))),
            _ToolbarBtn(
                tooltip: 'Strikethrough',
                onTap: onStrike,
                isActive: active.contains('strike'),
                child: const Text('S',
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        decoration: TextDecoration.lineThrough))),
            _ToolbarBtn(
                tooltip: 'Highlight',
                onTap: onHighlight,
                isActive: active.contains('highlight'),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 4, vertical: 2),
                  color: AppColors.accent.withValues(alpha: 0.55),
                  child: const Text('H',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w900)),
                )),
            _ToolbarBtn(
                tooltip: 'Inline code',
                onTap: onCode,
                isActive: active.contains('code'),
                child: const Icon(Icons.code, size: 20)),
            const _ToolbarDivider(),
            _ToolbarBtn(
                tooltip: 'Heading 1',
                onTap: onH1,
                isActive: active.contains('h1'),
                child: const Text('H1',
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w900))),
            _ToolbarBtn(
                tooltip: 'Heading 2',
                onTap: onH2,
                isActive: active.contains('h2'),
                child: const Text('H2',
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w900))),
            _ToolbarBtn(
                tooltip: 'Heading 3',
                onTap: onH3,
                isActive: active.contains('h3'),
                child: const Text('H3',
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w900))),
            const _ToolbarDivider(),
            _ToolbarBtn(
                tooltip: 'Bullet list',
                onTap: onBullet,
                isActive: active.contains('bullet'),
                child: const Icon(Icons.format_list_bulleted, size: 20)),
            _ToolbarBtn(
                tooltip: 'Numbered list',
                onTap: onNumbered,
                isActive: active.contains('numbered'),
                child: const Icon(Icons.format_list_numbered, size: 20)),
            _ToolbarBtn(
                tooltip: 'Checkbox list',
                onTap: onCheck,
                isActive: active.contains('check'),
                child: const Icon(Icons.check_box_outlined, size: 20)),
            _ToolbarBtn(
                tooltip: 'Quote',
                onTap: onQuote,
                isActive: active.contains('quote'),
                child: const Icon(Icons.format_quote, size: 20)),
            _ToolbarBtn(
                tooltip: 'Horizontal rule',
                onTap: onDivider,
                isActive: false,
                child: const Icon(Icons.horizontal_rule, size: 20)),
          ],
        ),
      ),
    );
  }
}

class _ToolbarBtn extends StatelessWidget {
  const _ToolbarBtn({
    required this.tooltip,
    required this.onTap,
    required this.child,
    this.isActive = false,
  });

  final String tooltip;
  final VoidCallback onTap;
  final Widget child;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final fg = isActive ? AppColors.primary : colors.onSurface;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 40,
          height: 40,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isActive
                ? AppColors.primary.withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: isActive
                ? Border.all(
                    color: AppColors.primary.withValues(alpha: 0.5),
                    width: 1.2,
                  )
                : null,
          ),
          child: IconTheme(
            data: IconThemeData(color: fg),
            child: DefaultTextStyle.merge(
              style: TextStyle(color: fg),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class _ToolbarDivider extends StatelessWidget {
  const _ToolbarDivider();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 24,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.15),
    );
  }
}

class _BgSwatch extends StatelessWidget {
  const _BgSwatch({
    required this.index,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final int index;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDefault = index == 0;
    final fill = isDefault ? Theme.of(context).colorScheme.surface : color;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: fill,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected
                ? AppColors.primary
                : Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.20),
            width: selected ? 2.5 : 1,
          ),
        ),
        child: isDefault
            ? Icon(
                Icons.format_color_reset,
                size: 16,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.55),
              )
            : (selected
                ? const Icon(Icons.check,
                    size: 16, color: AppColors.primary)
                : null),
      ),
    );
  }
}
