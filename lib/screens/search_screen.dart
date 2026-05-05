import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../models/document.dart';
import '../services/category_service.dart';
import '../services/database_service.dart';
import '../services/document_notifier.dart';

import '../utils/app_colors.dart';
import '../utils/document_share.dart';
import '../widgets/document_thumbnail.dart';
import 'document_viewer_screen.dart';

enum _Filter { all, pdf, image, note, video, document }

extension on _Filter {
  String get label {
    switch (this) {
      case _Filter.all:
        return 'All';
      case _Filter.pdf:
        return 'PDFs';
      case _Filter.image:
        return 'Images';
      case _Filter.note:
        return 'Notes';
      case _Filter.video:
        return 'Videos';
      case _Filter.document:
        return 'Docs';
    }
  }

  bool matches(Document d) {
    switch (this) {
      case _Filter.all:
        return true;
      case _Filter.pdf:
        return d.fileType == DocFileType.pdf;
      case _Filter.image:
        return d.fileType == DocFileType.image;
      case _Filter.note:
        return d.isNote || d.fileType == DocFileType.note;
      case _Filter.video:
        return d.fileType == DocFileType.video;
      case _Filter.document:
        return d.fileType == DocFileType.document;
    }
  }
}

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  String _query = '';
  _Filter _filter = _Filter.all;

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  bool _matchesQuery(Document d, String q, List<String> breadcrumb) {
    if (q.isEmpty) return true;
    final hay = [
      d.name,
      d.description ?? '',
      ...breadcrumb,
    ].join(' ').toLowerCase();
    return hay.contains(q);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<DocumentNotifier, CategoryService>(
      builder: (context, _, cats, __) {
        return Scaffold(
          appBar: AppBar(
            title: TextField(
              controller: _ctrl,
              focusNode: _focus,
              autofocus: false,
              decoration: const InputDecoration(
                hintText: 'Search documents…',
                prefixIcon: Icon(Icons.search),
                border: InputBorder.none,
                filled: false,
              ),
              onChanged: (v) => setState(() => _query = v.toLowerCase().trim()),
            ),
            actions: [
              if (_query.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    _ctrl.clear();
                    setState(() => _query = '');
                  },
                ),
            ],
          ),
          body: Column(
            children: [
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
              Expanded(
                child: FutureBuilder<List<Document>>(
                  future: DatabaseService.instance.getAllDocuments(),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final all = snap.data ?? const <Document>[];
                    final filtered = <Document>[];
                    for (final d in all) {
                      if (!_filter.matches(d)) continue;
                      final breadcrumb = cats
                          .getBreadcrumb(d.categoryId)
                          .map((c) => c.name)
                          .toList();
                      if (!_matchesQuery(d, _query, breadcrumb)) continue;
                      filtered.add(d);
                    }
                    if (filtered.isEmpty) {
                      if (_query.isEmpty && _filter == _Filter.all) {
                        return _StartHint();
                      }
                      return _NoMatch(query: _query);
                    }
                    return ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final d = filtered[i];
                        final crumb = cats
                            .getBreadcrumb(d.categoryId)
                            .map((c) => c.name)
                            .join(' / ');
                        return ListTile(
                          leading: DocumentThumbnail(document: d, size: 44),
                          title: Text(
                            d.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.nunito(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          subtitle: Text(
                            crumb,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.nunito(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          trailing: IconButton(
                            tooltip: 'Share',
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.ios_share, size: 20),
                            onPressed: () => shareDocument(context, d),
                          ),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    DocumentViewerScreen(doc: d),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StartHint extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('📭', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 12),
            Text(
              'No documents yet',
              style: GoogleFonts.nunito(
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Tap Import on Home to add files. Once you do, all your documents will appear here.',
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoMatch extends StatelessWidget {
  const _NoMatch({required this.query});
  final String query;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          query.isEmpty
              ? 'No documents match this filter.'
              : "No documents match '$query'.",
          textAlign: TextAlign.center,
          style: GoogleFonts.nunito(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.gray,
          ),
        ),
      ),
    );
  }
}
