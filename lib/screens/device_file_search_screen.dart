import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path/path.dart' as p;

import '../models/document.dart';
import '../utils/app_colors.dart';
import '../widgets/save_document_sheet.dart';

class DeviceFileSearchScreen extends StatefulWidget {
  const DeviceFileSearchScreen({super.key});

  @override
  State<DeviceFileSearchScreen> createState() =>
      _DeviceFileSearchScreenState();
}

class _DeviceFileSearchScreenState extends State<DeviceFileSearchScreen> {
  static const _searchRoots = [
    '/storage/emulated/0/WhatsApp/Media/WhatsApp Documents',
    '/storage/emulated/0/WhatsApp/Media/WhatsApp Images',
    '/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Documents',
    '/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Images',
    '/storage/emulated/0/Telegram/Telegram Documents',
    '/storage/emulated/0/Download',
    '/storage/emulated/0/Downloads',
    '/storage/emulated/0/DCIM',
    '/storage/emulated/0/Pictures',
    '/storage/emulated/0/Documents',
    '/storage/emulated/0/Bluetooth',
    '/storage/emulated/0/WeChat',
    '/storage/emulated/0/Android/data/com.google.android.gm/cache',
  ];

  bool _scanning = true;
  final _results = <_DeviceFile>[];
  _Filter _filter = _Filter.all;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _scan();
  }

  Future<void> _scan() async {
    final found = <_DeviceFile>[];
    for (final root in _searchRoots) {
      final dir = Directory(root);
      if (!dir.existsSync()) continue;
      try {
        await for (final e in dir.list(recursive: true, followLinks: false)) {
          if (e is File) {
            final ext = p.extension(e.path).replaceFirst('.', '').toLowerCase();
            if (ext.isEmpty) continue;
            final type = Document.typeFromExtension(ext);
            if (type == DocFileType.other) continue;
            found.add(_DeviceFile(
              path: e.path,
              name: p.basename(e.path),
              size: e.lengthSync(),
              type: type,
            ));
          }
        }
      } catch (_) {/* unreadable subtree, skip */}
    }
    found.sort((a, b) => a.name.compareTo(b.name));
    if (!mounted) return;
    setState(() {
      _results
        ..clear()
        ..addAll(found);
      _scanning = false;
    });
  }

  Iterable<_DeviceFile> get _filtered => _results.where((f) {
        if (!_filter.matches(f.type)) return false;
        if (_query.isNotEmpty &&
            !f.name.toLowerCase().contains(_query.toLowerCase())) {
          return false;
        }
        return true;
      });

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered.toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Find on device'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(110),
          child: Column(
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Filter by name…',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (v) => setState(() => _query = v.trim()),
                ),
              ),
              SizedBox(
                height: 48,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    for (final f in _Filter.values)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ChoiceChip(
                          label: Text(f.label),
                          selected: f == _filter,
                          onSelected: (v) {
                            if (v) setState(() => _filter = f);
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: _scanning
          ? const Center(child: CircularProgressIndicator())
          : filtered.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      'No matching files found.\nTry the Import button on Home for any file path.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.nunito(fontWeight: FontWeight.w700),
                    ),
                  ),
                )
              : ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final f = filtered[i];
                    return ListTile(
                      leading: Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(_emoji(f.type),
                            style: const TextStyle(fontSize: 20)),
                      ),
                      title: Text(
                        f.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
                      ),
                      subtitle: Text(
                        '${_fmt(f.size)} · ${f.path}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.nunito(fontSize: 11),
                      ),
                      onTap: () {
                        showModalBottomSheet<void>(
                          context: context,
                          isScrollControlled: true,
                          builder: (_) =>
                              SaveDocumentSheet(sourcePath: f.path),
                        );
                      },
                    );
                  },
                ),
    );
  }

  String _emoji(DocFileType t) {
    switch (t) {
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

  String _fmt(int b) {
    if (b < 1024) return '$b B';
    if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)} KB';
    return '${(b / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class _DeviceFile {
  _DeviceFile({
    required this.path,
    required this.name,
    required this.size,
    required this.type,
  });

  final String path;
  final String name;
  final int size;
  final DocFileType type;
}

enum _Filter { all, pdf, image, document, video }

extension on _Filter {
  String get label {
    switch (this) {
      case _Filter.all:
        return 'All';
      case _Filter.pdf:
        return 'PDFs';
      case _Filter.image:
        return 'Images';
      case _Filter.document:
        return 'Docs';
      case _Filter.video:
        return 'Videos';
    }
  }

  bool matches(DocFileType type) {
    switch (this) {
      case _Filter.all:
        return true;
      case _Filter.pdf:
        return type == DocFileType.pdf;
      case _Filter.image:
        return type == DocFileType.image;
      case _Filter.document:
        return type == DocFileType.document || type == DocFileType.note;
      case _Filter.video:
        return type == DocFileType.video;
    }
  }
}
