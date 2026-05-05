import 'dart:convert';

/// On-disk format for DocShelf notes.
///
///   ┌──────────────────────────────────────────────────────────────┐
///   │ {"v":2,"bg":2}              ← line 1: JSON metadata header  │
///   │ ---                         ← separator                      │
///   │ # Heading                                                    │
///   │ Some **bold** and *italic* text and a <mark>highlight</mark> │
///   │ - bullet 1                                                   │
///   │ - bullet 2                                                   │
///   └──────────────────────────────────────────────────────────────┘
///
/// Body is plain Markdown — readable as-is in any text editor, on any
/// file manager, on any Android version. No proprietary delta format.
///
/// Backward compatibility:
///   - **No header** → the entire file is treated as plain Markdown.
///     Promoted to the new header-prefixed format on first save.
///   - **v=1 (old Quill Delta JSON)** → the parser walks the Delta op
///     list and concatenates each `insert` string. The user keeps their
///     text content; rich attributes (bold/italic) are lost on this
///     one-time migration. Promoted to v=2 on first save.
class NoteFormat {
  NoteFormat._();

  static const int currentVersion = 2;
  static const String _separator = '---';

  /// Parse a stored note into ([metadata], [body]).
  /// Always succeeds; defaults to empty body + default meta on errors.
  static ParsedNote parse(String raw) {
    final newlineIdx = raw.indexOf('\n');
    if (newlineIdx > 0 && newlineIdx < 1024) {
      final firstLine = raw.substring(0, newlineIdx).trim();
      final rest = raw.substring(newlineIdx + 1);
      final sepIdx = rest.indexOf('\n');
      if (sepIdx >= 0 && rest.substring(0, sepIdx).trim() == _separator) {
        try {
          final meta = jsonDecode(firstLine);
          if (meta is Map<String, dynamic>) {
            final body = rest.substring(sepIdx + 1);
            final noteMeta = NoteMeta.fromJson(meta);
            // v=1 was Quill Delta JSON. Recover plain text from the
            // delta op list — `insert` strings concatenated.
            if (noteMeta.version <= 1) {
              return ParsedNote(
                meta: noteMeta.copyWith(version: currentVersion),
                body: _quillDeltaToPlain(body),
              );
            }
            return ParsedNote(meta: noteMeta, body: body);
          }
        } catch (_) {/* fall through to plain-text path */}
      }
    }
    // No header at all — treat the whole file as Markdown body.
    return ParsedNote(meta: const NoteMeta(), body: raw);
  }

  /// Build the on-disk string for [body] + [meta]. Always writes the
  /// current format version.
  static String serialize({
    required String body,
    required NoteMeta meta,
  }) {
    final header = jsonEncode(
      meta.copyWith(version: currentVersion).toJson(),
    );
    return '$header\n$_separator\n$body';
  }

  /// Walks a Quill Delta JSON string and joins each `insert` op's
  /// string content. Used only for one-time migration of v=1 notes.
  static String _quillDeltaToPlain(String deltaJson) {
    try {
      final list = jsonDecode(deltaJson);
      if (list is! List) return deltaJson;
      final buf = StringBuffer();
      for (final op in list) {
        if (op is Map && op['insert'] is String) {
          buf.write(op['insert'] as String);
        }
      }
      return buf.toString();
    } catch (_) {
      return deltaJson;
    }
  }

  /// Convert task-list syntax (`- [ ] foo`, `- [x] foo`) into a form that
  /// `flutter_markdown` will render as a normal list with a leading
  /// checkbox glyph. flutter_markdown 0.7.x has no built-in task-list
  /// renderer, so we transform on the way OUT: source stays GitHub-
  /// compatible, the on-screen output gets a real ☐ / ☑ at the front
  /// of the line.
  ///
  /// Source (on disk)         → Rendered
  /// -----------------------    --------------------
  /// `- [ ] buy milk`         → `- ☐ buy milk`
  /// `- [x] call doctor`      → `- ☑ call doctor`  (also strikethrough)
  static String renderable(String body) {
    return body.split('\n').map((line) {
      if (line.startsWith('- [ ] ')) {
        return '- ☐ ${line.substring(6)}';
      }
      if (line.startsWith('- [x] ') || line.startsWith('- [X] ')) {
        // Strike the text so checked items look done.
        return '- ☑ ~~${line.substring(6)}~~';
      }
      return line;
    }).join('\n');
  }

  /// Returns a short plain-text preview suitable for list subtitles.
  /// Strips the metadata header and most Markdown markers so the file
  /// list never leaks raw JSON or syntax noise.
  static String preview(String raw, {int maxChars = 80}) {
    final body = parse(raw).body;
    final stripped = body
        .replaceAll(RegExp(r'^#+\s*', multiLine: true), '')
        .replaceAll(RegExp(r'\*\*([^*]+)\*\*'), r'$1')
        .replaceAll(RegExp(r'\*([^*]+)\*'), r'$1')
        .replaceAll(RegExp(r'<mark>([^<]+)</mark>'), r'$1')
        .replaceAll(RegExp(r'^\s*[-*>]\s+', multiLine: true), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (stripped.length <= maxChars) return stripped;
    return '${stripped.substring(0, maxChars)}…';
  }
}

class NoteMeta {
  const NoteMeta({this.bg = 0, this.version = NoteFormat.currentVersion});

  /// Index into [AppColors.noteBgLight] / [AppColors.noteBgDark].
  /// 0 = no tint (theme surface).
  final int bg;
  final int version;

  Map<String, dynamic> toJson() => {'v': version, 'bg': bg};

  factory NoteMeta.fromJson(Map<String, dynamic> j) {
    return NoteMeta(
      bg: (j['bg'] as int?) ?? 0,
      version: (j['v'] as int?) ?? 1,
    );
  }

  NoteMeta copyWith({int? bg, int? version}) =>
      NoteMeta(bg: bg ?? this.bg, version: version ?? this.version);
}

class ParsedNote {
  ParsedNote({required this.meta, required this.body});
  final NoteMeta meta;

  /// Plain Markdown body — what `flutter_markdown` renders, what the
  /// editor TextField shows / mutates, what gets serialized back.
  final String body;
}
