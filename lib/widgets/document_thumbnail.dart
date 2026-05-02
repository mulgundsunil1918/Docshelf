import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdfx/pdfx.dart';

import '../models/document.dart';
import '../utils/app_colors.dart';

/// Renders a small preview tile for any [Document]: PDF first page,
/// the image itself, or a colored fallback chip with a type emoji.
class DocumentThumbnail extends StatefulWidget {
  const DocumentThumbnail({
    super.key,
    required this.document,
    this.size = 56,
  });

  final Document document;
  final double size;

  @override
  State<DocumentThumbnail> createState() => _DocumentThumbnailState();
}

class _DocumentThumbnailState extends State<DocumentThumbnail> {
  static final Map<String, Uint8List> _cache = {};

  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    _maybeLoadPdfPreview();
  }

  Future<void> _maybeLoadPdfPreview() async {
    if (widget.document.fileType != DocFileType.pdf) return;
    final cached = _cache[widget.document.path];
    if (cached != null) {
      setState(() => _bytes = cached);
      return;
    }
    try {
      final pdf = await PdfDocument.openFile(widget.document.path);
      final page = await pdf.getPage(1);
      final image = await page.render(
        width: widget.size * 2.5,
        height: widget.size * 2.5,
        format: PdfPageImageFormat.png,
      );
      await page.close();
      await pdf.close();
      if (image == null) return;
      _cache[widget.document.path] = image.bytes;
      if (mounted) setState(() => _bytes = image.bytes);
    } catch (_) {/* fall through to fallback */}
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(8);
    final clip = ClipRRect(
      borderRadius: radius,
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: _content(),
      ),
    );
    return clip;
  }

  Widget _content() {
    final d = widget.document;
    if (d.fileType == DocFileType.image && File(d.path).existsSync()) {
      return Image.file(File(d.path), fit: BoxFit.cover);
    }
    if (d.fileType == DocFileType.pdf && _bytes != null) {
      return Image.memory(_bytes!, fit: BoxFit.cover);
    }
    return _Fallback(type: d.fileType);
  }
}

class _Fallback extends StatelessWidget {
  const _Fallback({required this.type});

  final DocFileType type;

  Color _bg() {
    switch (type) {
      case DocFileType.pdf:
        return AppColors.danger;
      case DocFileType.note:
        return AppColors.accent;
      case DocFileType.document:
        return AppColors.primary;
      case DocFileType.audio:
        return Colors.purple;
      case DocFileType.video:
        return Colors.pinkAccent;
      case DocFileType.image:
        return Colors.teal;
      case DocFileType.other:
        return AppColors.gray;
    }
  }

  String _emoji() {
    switch (type) {
      case DocFileType.pdf:
        return '📄';
      case DocFileType.note:
        return '📝';
      case DocFileType.document:
        return '📃';
      case DocFileType.audio:
        return '🎵';
      case DocFileType.video:
        return '🎥';
      case DocFileType.image:
        return '🖼️';
      case DocFileType.other:
        return '📎';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _bg().withValues(alpha: 0.18),
      alignment: Alignment.center,
      child: Text(
        _emoji(),
        style: GoogleFonts.nunito(fontSize: 22),
      ),
    );
  }
}
