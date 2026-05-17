import 'dart:io';

import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:open_filex/open_filex.dart';
import 'package:pdfx/pdfx.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

import '../models/document.dart';
import '../services/database_service.dart';
import '../services/document_notifier.dart';
import '../services/file_storage_service.dart';
import '../utils/app_colors.dart';
import '../utils/note_format.dart';
import 'document_properties_screen.dart';
import 'note_editor_screen.dart';

class DocumentViewerScreen extends StatefulWidget {
  const DocumentViewerScreen({super.key, required this.doc});

  final Document doc;

  @override
  State<DocumentViewerScreen> createState() => _DocumentViewerScreenState();
}

class _DocumentViewerScreenState extends State<DocumentViewerScreen> {
  late Document _doc;

  @override
  void initState() {
    super.initState();
    _doc = widget.doc;
  }

  Future<void> _toggleBookmark() async {
    final next = !_doc.isBookmarked;
    await DatabaseService.instance.toggleBookmark(_doc.path, next);
    setState(() => _doc = _doc.copyWith(isBookmarked: next));
    DocumentNotifier.instance.notifyDocumentChanged();
  }

  Future<void> _share(BuildContext btnCtx) async {
    // iOS requires sharePositionOrigin to be a non-zero rect within the
    // source view's coordinate space — required even on iPhone in iOS 26+.
    final box = btnCtx.findRenderObject() as RenderBox?;
    final origin = box == null
        ? null
        : box.localToGlobal(Offset.zero) & box.size;
    await Share.shareXFiles(
      [XFile(_doc.path)],
      text: _doc.name,
      sharePositionOrigin: origin,
    );
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete this document?'),
        content: Text('"${_doc.name}" will be permanently removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await FileStorageService.instance.deleteDocumentFromStorage(_doc.path);
    await DatabaseService.instance.deleteDocument(_doc.path);
    DocumentNotifier.instance.notifyDocumentChanged();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _properties() async {
    final updated = await Navigator.of(context).push<Document?>(
      MaterialPageRoute(
        builder: (_) => DocumentPropertiesScreen(doc: _doc),
      ),
    );
    if (updated != null && mounted) setState(() => _doc = updated);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _doc.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: Icon(
              _doc.isBookmarked ? Icons.star : Icons.star_outline,
              color: AppColors.accent,
            ),
            onPressed: _toggleBookmark,
          ),
          Builder(
            builder: (menuCtx) => PopupMenuButton<String>(
              onSelected: (v) {
                switch (v) {
                  case 'props':
                    _properties();
                    break;
                  case 'share':
                    _share(menuCtx);
                    break;
                  case 'delete':
                    _delete();
                    break;
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'props', child: Text('Properties')),
                const PopupMenuItem(value: 'share', child: Text('Share')),
                const PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
          ),
        ],
      ),
      body: _Viewer(doc: _doc),
    );
  }
}

class _Viewer extends StatefulWidget {
  const _Viewer({required this.doc});
  final Document doc;

  @override
  State<_Viewer> createState() => _ViewerState();
}

class _ViewerState extends State<_Viewer> {
  String? _resolvedPath;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  Future<void> _resolve() async {
    // Remaps stale iOS container-UUID paths after reinstall.
    final path = await FileStorageService.instance.resolvedPath(widget.doc);
    if (mounted) setState(() => _resolvedPath = path);
  }

  @override
  Widget build(BuildContext context) {
    final path = _resolvedPath;
    if (path == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (!File(path).existsSync()) {
      return _MissingFile(path: path);
    }
    switch (widget.doc.fileType) {
      case DocFileType.pdf:
        return _PdfViewer(path: path);
      case DocFileType.image:
        return _ImageViewer(path: path);
      case DocFileType.video:
        return _VideoViewer(path: path);
      case DocFileType.note:
        return _NoteViewer(doc: widget.doc);
      case DocFileType.audio:
      case DocFileType.document:
      case DocFileType.other:
        return _ExternalOpener(doc: widget.doc);
    }
  }
}

class _MissingFile extends StatelessWidget {
  const _MissingFile({required this.path});
  final String path;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🚫', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 12),
            Text(
              'File not found on device',
              style: GoogleFonts.nunito(
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              path,
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.gray,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PdfViewer extends StatefulWidget {
  const _PdfViewer({required this.path});
  final String path;

  @override
  State<_PdfViewer> createState() => _PdfViewerState();
}

class _PdfViewerState extends State<_PdfViewer> {
  late PdfController _controller;

  @override
  void initState() {
    super.initState();
    _controller = PdfController(
      document: PdfDocument.openFile(widget.path),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PdfView(
      controller: _controller,
      scrollDirection: Axis.vertical,
      pageSnapping: false,
    );
  }
}

class _ImageViewer extends StatelessWidget {
  const _ImageViewer({required this.path});
  final String path;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: InteractiveViewer(
        minScale: 1,
        maxScale: 5,
        child: Center(child: Image.file(File(path))),
      ),
    );
  }
}

class _VideoViewer extends StatefulWidget {
  const _VideoViewer({required this.path});
  final String path;

  @override
  State<_VideoViewer> createState() => _VideoViewerState();
}

class _VideoViewerState extends State<_VideoViewer> {
  VideoPlayerController? _video;
  ChewieController? _chewie;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final v = VideoPlayerController.file(File(widget.path));
    await v.initialize();
    final c = ChewieController(
      videoPlayerController: v,
      autoPlay: true,
      looping: false,
      aspectRatio: v.value.aspectRatio,
    );
    if (!mounted) {
      v.dispose();
      c.dispose();
      return;
    }
    setState(() {
      _video = v;
      _chewie = c;
    });
  }

  @override
  void dispose() {
    _chewie?.dispose();
    _video?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_chewie == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return Chewie(controller: _chewie!);
  }
}

/// Read-only note view inside the document viewer. The "Edit" button
/// pushes the full-screen [NoteEditorScreen] — keeping a single canonical
/// edit path means fewer save/discard bugs.
///
/// On return from the editor we reload the file off disk so the viewer
/// reflects any changes the editor wrote.
class _NoteViewer extends StatefulWidget {
  const _NoteViewer({required this.doc});
  final Document doc;

  @override
  State<_NoteViewer> createState() => _NoteViewerState();
}

class _NoteViewerState extends State<_NoteViewer> {
  String _markdown = '';
  NoteMeta _meta = const NoteMeta();
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    String raw = '';
    try {
      raw = File(widget.doc.path).readAsStringSync();
    } catch (_) {/* unreadable */}
    final parsed = NoteFormat.parse(raw);
    if (!mounted) return;
    setState(() {
      _markdown = parsed.body;
      _meta = parsed.meta;
      _loaded = true;
    });
  }

  String get _plain => _markdown
      .replaceAll(RegExp(r'^#+\s*', multiLine: true), '')
      .replaceAll(RegExp(r'\*\*([^*]+)\*\*'), r'$1')
      .replaceAll(RegExp(r'\*([^*]+)\*'), r'$1')
      .replaceAll(RegExp(r'<mark>([^<]+)</mark>'), r'$1')
      .replaceAll(RegExp(r'^\s*[-*>]\s+', multiLine: true), '');

  Future<void> _openEditor() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NoteEditorScreen(existingDoc: widget.doc),
      ),
    );
    if (mounted) _reload();
  }

  int get _wordCount {
    final t = _plain.trim();
    if (t.isEmpty) return 0;
    return t.split(RegExp(r'\s+')).length;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = isDark ? AppColors.noteBgDark : AppColors.noteBgLight;
    final pageBg = _meta.bg == 0 ? colors.surface : palette[_meta.bg];

    return Container(
      color: pageBg,
      child: Column(
        children: [
          // ─── Toolbar row ───────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            color: colors.surface.withValues(alpha: 0.85),
            child: Row(
              children: [
                Icon(
                  Icons.notes,
                  size: 18,
                  color: colors.onSurface.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 8),
                Text(
                  'Reading',
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: colors.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                const Spacer(),
                FilledButton.tonalIcon(
                  onPressed: _openEditor,
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('Edit'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // ─── Markdown body (read-only) ─────────────────────────────
          Expanded(
            child: !_loaded
                ? const Center(child: CircularProgressIndicator())
                : _markdown.trim().isEmpty
                    ? Center(
                        child: Text(
                          '(empty note — tap Edit to write something)',
                          style: GoogleFonts.nunito(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: colors.onSurface
                                .withValues(alpha: 0.45),
                          ),
                        ),
                      )
                    : Markdown(
                        data: NoteFormat.renderable(_markdown),
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                        selectable: true,
                        styleSheet: MarkdownStyleSheet(
                          p: GoogleFonts.nunito(
                            fontSize: 15,
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
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: colors.onSurface,
                          ),
                          em: GoogleFonts.nunito(
                            fontSize: 15,
                            fontStyle: FontStyle.italic,
                            color: colors.onSurface,
                          ),
                          blockquote: GoogleFonts.nunito(
                            fontSize: 15,
                            fontStyle: FontStyle.italic,
                            color: colors.onSurface
                                .withValues(alpha: 0.7),
                          ),
                          blockquoteDecoration: BoxDecoration(
                            border: Border(
                              left: BorderSide(
                                color: AppColors.primary
                                    .withValues(alpha: 0.6),
                                width: 4,
                              ),
                            ),
                          ),
                          blockquotePadding:
                              const EdgeInsets.fromLTRB(12, 4, 4, 4),
                          code: GoogleFonts.firaCode(
                            fontSize: 13,
                            backgroundColor: colors.onSurface
                                .withValues(alpha: 0.08),
                          ),
                          listBullet: GoogleFonts.nunito(
                            fontSize: 15,
                            color: colors.onSurface,
                          ),
                        ),
                      ),
          ),

          // ─── Footer ────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: colors.surface.withValues(alpha: 0.85),
            child: Row(
              children: [
                Text(
                  '$_wordCount word${_wordCount == 1 ? '' : 's'}',
                  style: GoogleFonts.nunito(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: colors.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${_plain.length} char${_plain.length == 1 ? '' : 's'}',
                  style: GoogleFonts.nunito(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: colors.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExternalOpener extends StatelessWidget {
  const _ExternalOpener({required this.doc});
  final Document doc;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              doc.fileTypeIcon,
              style: const TextStyle(fontSize: 64),
            ),
            const SizedBox(height: 12),
            Text(
              doc.name,
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => OpenFilex.open(doc.path),
              icon: const Icon(Icons.open_in_new),
              label: const Text('Open in another app'),
            ),
          ],
        ),
      ),
    );
  }
}
