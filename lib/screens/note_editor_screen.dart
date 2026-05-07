import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
// `Document` is exported by both our model and super_editor — hide it
// from the editor package so DocShelf's Document model wins everywhere
// in this file (we don't need super_editor's abstract Document directly).
import 'package:super_editor/super_editor.dart' hide Document;
import 'package:super_editor_markdown/super_editor_markdown.dart';

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

/// **Premium WYSIWYG note editor.**
///
/// Why super_editor: previous attempts went through flutter_quill (silently
/// rendered as a blank grey rectangle on real devices), then a markdown
/// `TextField` with a custom controller (markers leaked when patterns were
/// incomplete). Both failed the doctors-on-rounds litmus test: "I want to
/// type, not see formatting symbols."
///
/// super_editor renders the document as actual styled text — `**bold**`
/// becomes a bold span, `# heading` becomes a 28pt heading. The on-disk
/// format stays markdown so notes remain readable in any text editor and
/// open cleanly across DocShelf versions; we round-trip via
/// `super_editor_markdown` only at load/save boundaries.
///
/// **UX principles enforced here:**
/// 1. Never expose markdown syntax to the user. Markers exist only on disk.
/// 2. Single accent colour ([AppColors.primary]) used sparingly — the rest
///    is calm neutrals. Selection / active states use 12-15% tinted fills.
/// 3. Toolbar is keyboard-anchored (no toolbar floating mid-screen) and
///    shows only the six most-used actions; everything else lives behind
///    a "More" sheet.
/// 4. Title field is visually distinct from body text — large, w800, with
///    a soft underline on focus.
/// 5. Autosave runs 1.5s after the last keystroke (separate from the
///    explicit Save button) so closing the screen never loses work.
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
  // ─── Title ──────────────────────────────────────────────────────────
  late final TextEditingController _titleCtrl;

  // ─── Body (super_editor) ────────────────────────────────────────────
  late MutableDocument _doc;
  late MutableDocumentComposer _composer;
  late Editor _editor;
  final _scrollController = ScrollController();

  // ─── Note metadata ──────────────────────────────────────────────────
  Category? _category;
  NoteMeta _meta = const NoteMeta();
  bool _bookmark = false;
  bool _saving = false;
  Timer? _autosaveTimer;

  // ─── Active formatting state (drives toolbar pressed-look) ──────────
  /// Recomputed every time the document or selection changes. Toolbar
  /// buttons read from this set so the user can SEE that, e.g., the
  /// caret is currently inside a bold run.
  Set<String> _activeFormats = const {};

  // ─── Dirty tracking ─────────────────────────────────────────────────
  String _titleBaseline = '';
  String _markdownBaseline = '';
  String _categoryIdBaseline = '';
  int _bgBaseline = 0;
  bool _bookmarkBaseline = false;
  bool _baselineSet = false;

  bool get _isEditing => widget.existingDoc != null;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController()..addListener(_onTitleChanged);

    // ── Load existing note (or start a fresh blank document).
    String initialMarkdown = '';
    final doc = widget.existingDoc;
    if (doc != null) {
      _titleCtrl.text = doc.name;
      _bookmark = doc.isBookmarked;
      try {
        final parsed = NoteFormat.parse(File(doc.path).readAsStringSync());
        _meta = parsed.meta;
        initialMarkdown = parsed.body;
      } catch (_) {/* unreadable — open blank */}
      _category = CategoryService.instance.getCategoryById(doc.categoryId);
    } else if (widget.initialCategoryId != null) {
      _category =
          CategoryService.instance.getCategoryById(widget.initialCategoryId!);
    }
    _category ??= CategoryService.instance
        .getCategoryById(AppConstants.unsortedCategoryId);

    // ── Build the document model.
    _doc = initialMarkdown.trim().isEmpty
        ? MutableDocument(nodes: [
            ParagraphNode(
              id: Editor.createNodeId(),
              text: AttributedText(),
            ),
          ])
        : deserializeMarkdownToDocument(initialMarkdown);
    _composer = MutableDocumentComposer();
    _editor = createDefaultDocumentEditor(
      document: _doc,
      composer: _composer,
    );

    // ── Listen for any change → autosave + active-format recompute.
    _doc.addListener(_onDocumentChanged);
    _composer.selectionNotifier.addListener(_onSelectionChanged);

    // Establish baseline once the first frame settles so dirty=false.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _titleBaseline = _titleCtrl.text;
        _markdownBaseline = serializeDocumentToMarkdown(_doc);
        _categoryIdBaseline = _category?.id ?? '';
        _bgBaseline = _meta.bg;
        _bookmarkBaseline = _bookmark;
        _baselineSet = true;
      });
    });
  }

  @override
  void dispose() {
    _autosaveTimer?.cancel();
    _doc.removeListener(_onDocumentChanged);
    _composer.selectionNotifier.removeListener(_onSelectionChanged);
    _titleCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ─── Listeners ──────────────────────────────────────────────────────
  void _onTitleChanged() {
    _scheduleAutosave();
    if (mounted) setState(() {});
  }

  void _onDocumentChanged(_) {
    _scheduleAutosave();
    if (mounted) setState(() => _activeFormats = _computeActiveFormats());
  }

  void _onSelectionChanged() {
    if (mounted) setState(() => _activeFormats = _computeActiveFormats());
  }

  /// Save 1.5s after the last keystroke. Cheaper than save-on-every-key,
  /// guarantees no lost work if the user backgrounds the app.
  void _scheduleAutosave() {
    _autosaveTimer?.cancel();
    if (!_isEditing) return; // new notes save on first explicit Save tap
    _autosaveTimer = Timer(const Duration(milliseconds: 1500), _autosave);
  }

  Future<void> _autosave() async {
    if (!_isEditing || !_canSave) return;
    try {
      final body = NoteFormat.serialize(
        body: serializeDocumentToMarkdown(_doc),
        meta: _meta,
      );
      await File(widget.existingDoc!.path).writeAsString(body);
      // Don't pop, don't snackbar — silent autosave. Update baselines so
      // we stop showing "Unsaved" while the user keeps typing.
      if (!mounted) return;
      setState(() {
        _titleBaseline = _titleCtrl.text;
        _markdownBaseline = serializeDocumentToMarkdown(_doc);
        _categoryIdBaseline = _category?.id ?? '';
        _bgBaseline = _meta.bg;
        _bookmarkBaseline = _bookmark;
      });
    } catch (_) {/* silent — explicit Save still works */}
  }

  // ─── Active formatting detection ────────────────────────────────────
  /// Walks the current selection and builds a set of human-readable
  /// keys ('bold', 'italic', 'h1', 'bullet', 'task', 'quote', 'highlight')
  /// describing which attributions cover the caret. Used to highlight
  /// toolbar buttons.
  Set<String> _computeActiveFormats() {
    final selection = _composer.selection;
    if (selection == null) return const {};

    final active = <String>{};

    // Block-level: read the type of the node containing the caret.
    final node = _doc.getNodeById(selection.extent.nodeId);
    if (node is ParagraphNode) {
      final blockType = node.metadata['blockType'];
      if (blockType == header1Attribution) active.add('h1');
      if (blockType == header2Attribution) active.add('h2');
      if (blockType == header3Attribution) active.add('h3');
      if (blockType == blockquoteAttribution) active.add('quote');
    } else if (node is ListItemNode) {
      active.add(node.type == ListItemType.ordered ? 'numbered' : 'bullet');
    } else if (node is TaskNode) {
      active.add('task');
    }

    // Inline: ask the composer whether the caret currently typing-applies
    // these attributions. composer.preferences keeps the style for "what
    // the next keystroke will be", which is exactly what we want to show.
    final preferred = _composer.preferences.currentAttributions;
    if (preferred.contains(boldAttribution)) active.add('bold');
    if (preferred.contains(italicsAttribution)) active.add('italic');
    if (preferred.contains(strikethroughAttribution)) active.add('strike');
    if (preferred.contains(underlineAttribution)) active.add('underline');
    if (preferred.contains(codeAttribution)) active.add('code');
    if (preferred.any((a) => a is BackgroundColorAttribution)) {
      active.add('highlight');
    }

    return active;
  }

  // ─── Toolbar actions ────────────────────────────────────────────────
  void _toggleInline(Attribution attribution) {
    final selection = _composer.selection;
    if (selection == null) return;
    if (selection.isCollapsed) {
      // No range — flip the "next keystroke" preference instead.
      _composer.preferences.toggleStyle(attribution);
      setState(() => _activeFormats = _computeActiveFormats());
      return;
    }
    _editor.execute([
      ToggleTextAttributionsRequest(
        documentRange: selection,
        attributions: {attribution},
      ),
    ]);
  }

  void _toggleHighlight() {
    // We pin highlight to a single warm amber so it always reads in dark
    // mode AND light mode. Toggle by checking if the current attribution
    // set already has any BackgroundColorAttribution.
    const highlight = BackgroundColorAttribution(Color(0xFFFFF3B0));
    final selection = _composer.selection;
    if (selection == null) return;
    if (selection.isCollapsed) {
      final prefs = _composer.preferences.currentAttributions;
      final existing = prefs.whereType<BackgroundColorAttribution>().firstOrNull;
      if (existing != null) {
        _composer.preferences.removeStyle(existing);
      } else {
        _composer.preferences.addStyle(highlight);
      }
      setState(() => _activeFormats = _computeActiveFormats());
      return;
    }
    _editor.execute([
      ToggleTextAttributionsRequest(
        documentRange: selection,
        attributions: {highlight},
      ),
    ]);
  }

  /// Cycle the current paragraph through h1 → h2 → h3 → paragraph.
  /// One toolbar button covers all three so the toolbar stays compact.
  void _cycleHeading() {
    final selection = _composer.selection;
    if (selection == null) return;
    final node = _doc.getNodeById(selection.extent.nodeId);
    if (node is! ParagraphNode) return;
    final current = node.metadata['blockType'];
    Attribution? next;
    if (current == header1Attribution) {
      next = header2Attribution;
    } else if (current == header2Attribution) {
      next = header3Attribution;
    } else if (current == header3Attribution) {
      next = null; // back to paragraph
    } else {
      next = header1Attribution;
    }
    _editor.execute([
      ChangeParagraphBlockTypeRequest(nodeId: node.id, blockType: next),
    ]);
  }

  void _toggleBlockquote() {
    final selection = _composer.selection;
    if (selection == null) return;
    final node = _doc.getNodeById(selection.extent.nodeId);
    if (node is! ParagraphNode) return;
    final current = node.metadata['blockType'];
    final next = current == blockquoteAttribution ? null : blockquoteAttribution;
    _editor.execute([
      ChangeParagraphBlockTypeRequest(nodeId: node.id, blockType: next),
    ]);
  }

  void _toggleList(ListItemType type) {
    final selection = _composer.selection;
    if (selection == null) return;
    final node = _doc.getNodeById(selection.extent.nodeId);
    if (node is ListItemNode) {
      if (node.type == type) {
        // Same kind tapped again → leave the list.
        _editor.execute([ConvertListItemToParagraphRequest(nodeId: node.id)]);
      } else {
        // Switch ordered ↔ unordered.
        _editor.execute([
          ChangeListItemTypeRequest(nodeId: node.id, newType: type),
        ]);
      }
      return;
    }
    if (node is ParagraphNode) {
      _editor.execute([
        ConvertParagraphToListItemRequest(nodeId: node.id, type: type),
      ]);
    }
  }

  void _toggleTask() {
    final selection = _composer.selection;
    if (selection == null) return;
    final node = _doc.getNodeById(selection.extent.nodeId);
    if (node is TaskNode) {
      _editor.execute([ConvertTaskToParagraphRequest(nodeId: node.id)]);
    } else if (node is ParagraphNode) {
      _editor.execute([
        ConvertParagraphToTaskRequest(nodeId: node.id),
      ]);
    }
  }

  // ─── Save / discard ─────────────────────────────────────────────────
  bool get _dirty {
    if (!_baselineSet) return false;
    final markdown = serializeDocumentToMarkdown(_doc);
    return _titleCtrl.text != _titleBaseline ||
        markdown != _markdownBaseline ||
        (_category?.id ?? '') != _categoryIdBaseline ||
        _meta.bg != _bgBaseline ||
        _bookmark != _bookmarkBaseline;
  }

  bool get _canSave {
    if (_saving) return false;
    if (_titleCtrl.text.trim().isEmpty) return false;
    if (serializeDocumentToMarkdown(_doc).trim().isEmpty) return false;
    if (_category == null) return false;
    return true;
  }

  Future<void> _save() async {
    if (!_canSave) return;
    HapticFeedback.lightImpact();
    setState(() => _saving = true);
    try {
      final body = NoteFormat.serialize(
        body: serializeDocumentToMarkdown(_doc),
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
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scroll) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Save note in folder',
                style: GoogleFonts.nunito(
                  fontSize: 17,
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
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final palette = isDark ? AppColors.noteBgDark : AppColors.noteBgLight;
    final pageBg = _meta.bg == 0 ? colors.surface : palette[_meta.bg];

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
        appBar: _buildAppBar(colors),
        body: SafeArea(
          child: Column(
            children: [
              _buildTitleField(colors),
              _buildFolderChip(),
              Expanded(child: _buildEditor(colors, isDark)),
              _buildBottomToolbar(colors, isDark),
            ],
          ),
        ),
      ),
    );
  }

  // ─── App bar ────────────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar(ColorScheme colors) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      titleSpacing: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
        onPressed: () async {
          if (await _confirmDiscard() && mounted) {
            Navigator.of(context).pop();
          }
        },
      ),
      title: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        child: _dirty
            ? Row(
                key: const ValueKey('dirty'),
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AppColors.warning,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isEditing ? 'Unsaved changes' : 'Draft',
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: colors.onSurface.withValues(alpha: 0.65),
                    ),
                  ),
                ],
              )
            : Text(
                _isEditing ? 'Saved' : 'New note',
                key: const ValueKey('clean'),
                style: GoogleFonts.nunito(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: colors.onSurface.withValues(alpha: 0.55),
                ),
              ),
      ),
      actions: [
        IconButton(
          tooltip: _bookmark ? 'Unbookmark' : 'Bookmark',
          onPressed: () {
            HapticFeedback.selectionClick();
            setState(() => _bookmark = !_bookmark);
          },
          icon: Icon(
            _bookmark ? Icons.star_rounded : Icons.star_border_rounded,
            color: _bookmark ? AppColors.accent : null,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 12, 8),
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: _canSave ? _save : null,
            child: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.white,
                    ),
                  )
                : Text(
                    'Save',
                    style: GoogleFonts.nunito(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.2,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  // ─── Title field ────────────────────────────────────────────────────
  Widget _buildTitleField(ColorScheme colors) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      child: TextField(
        controller: _titleCtrl,
        maxLines: 2,
        minLines: 1,
        textCapitalization: TextCapitalization.sentences,
        cursorColor: AppColors.primary,
        cursorWidth: 2,
        style: GoogleFonts.nunito(
          fontSize: 28,
          fontWeight: FontWeight.w900,
          height: 1.2,
          color: colors.onSurface,
          letterSpacing: -0.4,
        ),
        decoration: InputDecoration(
          hintText: 'Untitled',
          hintStyle: GoogleFonts.nunito(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            height: 1.2,
            color: colors.onSurface.withValues(alpha: 0.22),
            letterSpacing: -0.4,
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );
  }

  // ─── Folder chip ────────────────────────────────────────────────────
  Widget _buildFolderChip() {
    final crumb = _category == null
        ? 'Choose folder'
        : CategoryService.instance
            .getBreadcrumb(_category!.id)
            .map((c) => c.name)
            .join(' › ');
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 6),
      child: GestureDetector(
        onTap: _pickCategory,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.folder_rounded,
                size: 14,
                color: AppColors.primary,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  crumb,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                    letterSpacing: 0.1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Editor (super_editor) ──────────────────────────────────────────
  Widget _buildEditor(ColorScheme colors, bool isDark) {
    return SuperEditor(
      editor: _editor,
      scrollController: _scrollController,
      stylesheet: _premiumStylesheet(colors, isDark),
      componentBuilders: [
        TaskComponentBuilder(_editor),
        ...defaultComponentBuilders,
      ],
      selectionStyle: SelectionStyles(
        selectionColor: AppColors.primary.withValues(alpha: 0.22),
      ),
      // Re-build the default overlay chain rather than replacing it with
      // a single desktop caret. `DefaultCaretOverlayBuilder` is desktop-
      // only (`displayOnAllPlatforms: false` by default) — passing only
      // it would erase the Android/iOS handle layers that paint the
      // *blinking caret on touch devices*. Result: no visible cursor
      // while typing on a phone. The list below mirrors super_editor's
      // `defaultSuperEditorDocumentOverlayBuilders` but with the indigo
      // brand colour wired into the per-platform handle builders.
      documentOverlayBuilders: [
        const SuperEditorIosToolbarFocalPointDocumentLayerBuilder(),
        const SuperEditorIosHandlesDocumentLayerBuilder(
          handleColor: AppColors.primary,
        ),
        const SuperEditorAndroidToolbarFocalPointDocumentLayerBuilder(),
        const SuperEditorAndroidHandlesDocumentLayerBuilder(
          caretColor: AppColors.primary,
        ),
        // Desktop fallback (mouse/web) — Android & iOS branches return
        // EmptyBox here because of platform guards inside the builder.
        const DefaultCaretOverlayBuilder(
          caretStyle: CaretStyle(width: 2, color: AppColors.primary),
        ),
      ],
    );
  }

  // ─── Premium document stylesheet ────────────────────────────────────
  /// Tuned for medical / professional note-taking:
  ///   - 17pt body, 1.6 line-height — long passages stay legible
  ///   - 30 / 24 / 19 pt headers — distinct hierarchy without shouting
  ///   - 32px horizontal page padding so text doesn't kiss the edge
  ///   - Blockquote uses a left border in the primary tint, not bold grey
  Stylesheet _premiumStylesheet(ColorScheme colors, bool isDark) {
    final body = GoogleFonts.nunito(
      fontSize: 17,
      fontWeight: FontWeight.w500,
      height: 1.6,
      color: colors.onSurface,
      letterSpacing: 0.05,
    );
    return Stylesheet(
      rules: [
        StyleRule(
          BlockSelector.all,
          (doc, node) => {
            Styles.maxWidth: 720.0,
            Styles.padding:
                const CascadingPadding.symmetric(horizontal: 24, vertical: 0),
            Styles.textStyle: body,
          },
        ),
        StyleRule(
          const BlockSelector('header1'),
          (doc, node) => {
            Styles.padding: const CascadingPadding.only(top: 24, bottom: 4),
            Styles.textStyle: GoogleFonts.nunito(
              fontSize: 30,
              fontWeight: FontWeight.w900,
              height: 1.25,
              color: colors.onSurface,
              letterSpacing: -0.3,
            ),
          },
        ),
        StyleRule(
          const BlockSelector('header2'),
          (doc, node) => {
            Styles.padding: const CascadingPadding.only(top: 20, bottom: 2),
            Styles.textStyle: GoogleFonts.nunito(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              height: 1.25,
              color: colors.onSurface,
              letterSpacing: -0.2,
            ),
          },
        ),
        StyleRule(
          const BlockSelector('header3'),
          (doc, node) => {
            Styles.padding: const CascadingPadding.only(top: 16, bottom: 2),
            Styles.textStyle: GoogleFonts.nunito(
              fontSize: 19,
              fontWeight: FontWeight.w900,
              height: 1.3,
              color: colors.onSurface,
            ),
          },
        ),
        StyleRule(
          const BlockSelector('paragraph'),
          (doc, node) => {
            Styles.padding: const CascadingPadding.only(top: 10),
          },
        ),
        StyleRule(
          const BlockSelector('paragraph').after('header1'),
          (doc, node) => {
            Styles.padding: const CascadingPadding.only(top: 4),
          },
        ),
        StyleRule(
          const BlockSelector('paragraph').after('header2'),
          (doc, node) => {
            Styles.padding: const CascadingPadding.only(top: 4),
          },
        ),
        StyleRule(
          const BlockSelector('paragraph').after('header3'),
          (doc, node) => {
            Styles.padding: const CascadingPadding.only(top: 4),
          },
        ),
        StyleRule(
          const BlockSelector('listItem'),
          (doc, node) => {
            Styles.padding: const CascadingPadding.only(top: 6),
          },
        ),
        StyleRule(
          const BlockSelector('blockquote'),
          (doc, node) => {
            Styles.padding: const CascadingPadding.only(top: 10),
            Styles.textStyle: GoogleFonts.nunito(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              fontStyle: FontStyle.italic,
              height: 1.55,
              color: colors.onSurface.withValues(alpha: 0.78),
            ),
          },
        ),
        StyleRule(
          BlockSelector.all.last(),
          (doc, node) => {
            Styles.padding: const CascadingPadding.only(bottom: 96),
          },
        ),
      ],
      inlineTextStyler: defaultInlineTextStyler,
      inlineWidgetBuilders: defaultInlineWidgetBuilderChain,
    );
  }

  // ─── Bottom toolbar (keyboard-anchored) ─────────────────────────────
  /// Six primary actions visible — Bold, Italic, Highlight, Heading,
  /// Bullet, Checklist. Everything else lives behind the "More" button
  /// to keep the toolbar calm. The toolbar is rendered as the last item
  /// in the column so MediaQuery padding (keyboard) pushes it up
  /// naturally.
  Widget _buildBottomToolbar(ColorScheme colors, bool isDark) {
    final tbBg = isDark
        ? const Color(0xFF1A1B22).withValues(alpha: 0.96)
        : Colors.white.withValues(alpha: 0.97);
    return Container(
      decoration: BoxDecoration(
        color: tbBg,
        border: Border(
          top: BorderSide(
            color: colors.onSurface.withValues(alpha: 0.06),
            width: 0.5,
          ),
        ),
      ),
      padding: EdgeInsets.only(
        left: 4,
        right: 4,
        top: 6,
        bottom: 6 + MediaQuery.of(context).viewPadding.bottom * 0.4,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _ToolbarBtn(
              icon: Icons.format_bold_rounded,
              tooltip: 'Bold',
              isActive: _activeFormats.contains('bold'),
              onTap: () => _toggleInline(boldAttribution),
            ),
            _ToolbarBtn(
              icon: Icons.format_italic_rounded,
              tooltip: 'Italic',
              isActive: _activeFormats.contains('italic'),
              onTap: () => _toggleInline(italicsAttribution),
            ),
            _ToolbarBtn(
              icon: Icons.highlight_rounded,
              tooltip: 'Highlight',
              isActive: _activeFormats.contains('highlight'),
              onTap: _toggleHighlight,
            ),
            const _ToolbarDivider(),
            _ToolbarBtn(
              icon: Icons.title_rounded,
              tooltip: 'Heading',
              isActive: _activeFormats.contains('h1') ||
                  _activeFormats.contains('h2') ||
                  _activeFormats.contains('h3'),
              onTap: _cycleHeading,
            ),
            _ToolbarBtn(
              icon: Icons.format_list_bulleted_rounded,
              tooltip: 'Bullet list',
              isActive: _activeFormats.contains('bullet'),
              onTap: () => _toggleList(ListItemType.unordered),
            ),
            _ToolbarBtn(
              icon: Icons.check_box_outlined,
              tooltip: 'Checklist',
              isActive: _activeFormats.contains('task'),
              onTap: _toggleTask,
            ),
            const _ToolbarDivider(),
            _ToolbarBtn(
              icon: Icons.more_horiz_rounded,
              tooltip: 'More',
              isActive: false,
              onTap: _openMoreSheet,
            ),
          ],
        ),
      ),
    );
  }

  // ─── More-actions sheet ─────────────────────────────────────────────
  Future<void> _openMoreSheet() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = isDark ? AppColors.noteBgDark : AppColors.noteBgLight;
    HapticFeedback.selectionClick();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheet) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'More formatting',
                    style: GoogleFonts.nunito(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _MoreTile(
                      icon: Icons.format_underline_rounded,
                      label: 'Underline',
                      active: _activeFormats.contains('underline'),
                      onTap: () {
                        Navigator.of(sheet).pop();
                        _toggleInline(underlineAttribution);
                      },
                    ),
                    _MoreTile(
                      icon: Icons.strikethrough_s_rounded,
                      label: 'Strike',
                      active: _activeFormats.contains('strike'),
                      onTap: () {
                        Navigator.of(sheet).pop();
                        _toggleInline(strikethroughAttribution);
                      },
                    ),
                    _MoreTile(
                      icon: Icons.code_rounded,
                      label: 'Code',
                      active: _activeFormats.contains('code'),
                      onTap: () {
                        Navigator.of(sheet).pop();
                        _toggleInline(codeAttribution);
                      },
                    ),
                    _MoreTile(
                      icon: Icons.format_quote_rounded,
                      label: 'Quote',
                      active: _activeFormats.contains('quote'),
                      onTap: () {
                        Navigator.of(sheet).pop();
                        _toggleBlockquote();
                      },
                    ),
                    _MoreTile(
                      icon: Icons.format_list_numbered_rounded,
                      label: 'Numbered',
                      active: _activeFormats.contains('numbered'),
                      onTap: () {
                        Navigator.of(sheet).pop();
                        _toggleList(ListItemType.ordered);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Page colour',
                    style: GoogleFonts.nunito(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 48,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: palette.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, i) => _BgSwatch(
                      index: i,
                      color: palette[i],
                      selected: i == _meta.bg,
                      onTap: () {
                        setState(() => _meta = _meta.copyWith(bg: i));
                        Navigator.of(sheet).pop();
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─── Toolbar atoms ─────────────────────────────────────────────────────
/// 44×44 hit area, 8px radius, primary tint when active. Animation is
/// kept fast (120ms) — we want satisfying, not theatrical.
class _ToolbarBtn extends StatelessWidget {
  const _ToolbarBtn({
    required this.icon,
    required this.tooltip,
    required this.isActive,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 44,
          height: 44,
          margin: const EdgeInsets.symmetric(horizontal: 1),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isActive
                ? AppColors.primary.withValues(alpha: 0.14)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            size: 22,
            color: isActive
                ? AppColors.primary
                : colors.onSurface.withValues(alpha: 0.78),
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
      height: 22,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.10),
    );
  }
}

class _MoreTile extends StatelessWidget {
  const _MoreTile({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 92,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: active
              ? AppColors.primary.withValues(alpha: 0.14)
              : colors.onSurface.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active
                ? AppColors.primary.withValues(alpha: 0.4)
                : Colors.transparent,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 22,
              color: active ? AppColors.primary : colors.onSurface,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: GoogleFonts.nunito(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: active ? AppColors.primary : colors.onSurface,
              ),
            ),
          ],
        ),
      ),
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
        width: 44,
        height: 44,
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
                    .withValues(alpha: 0.2),
            width: selected ? 2.5 : 1,
          ),
        ),
        child: isDefault
            ? Icon(
                Icons.format_color_reset_rounded,
                size: 18,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.55),
              )
            : (selected
                ? const Icon(
                    Icons.check_rounded,
                    size: 18,
                    color: AppColors.primary,
                  )
                : null),
      ),
    );
  }
}
