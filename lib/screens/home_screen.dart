import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../models/document.dart';
import '../services/camera_scan_service.dart';
import '../services/category_service.dart';
import '../services/database_service.dart';
import '../services/document_notifier.dart';
import '../services/file_storage_service.dart';
import '../services/onboarding_service.dart';
import '../utils/app_colors.dart';
import '../utils/constants.dart';
import '../utils/document_share.dart';
import '../utils/friendly_error.dart';
import '../widgets/coach_mark_overlay.dart';
import '../widgets/document_thumbnail.dart';
import '../widgets/save_document_sheet.dart';
import '../widgets/support_developer_button.dart';
import 'batch_import_screen.dart';
import 'category_detail_screen.dart';
import 'device_file_search_screen.dart';
import 'document_viewer_screen.dart';
import 'expiring_soon_screen.dart';
import 'note_editor_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late int _tipIndex;
  int _storageBytes = 0;
  final _importKey = GlobalKey();
  final _scanKey = GlobalKey();
  final _findKey = GlobalKey();
  final _categoriesKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    final day = DateTime.now().day;
    _tipIndex = day % AppConstants.homeTips.length;
    _refreshStorage();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowCoachMarks());
    OnboardingService.instance.coachMarkReplaySignal.addListener(_onReplay);
  }

  @override
  void dispose() {
    OnboardingService.instance.coachMarkReplaySignal.removeListener(_onReplay);
    super.dispose();
  }

  void _onReplay() {
    if (!mounted) return;
    // Settings tapped "Replay walkthrough" — force the overlay to show
    // even if the seen flag is already cleared.
    Future<void>.delayed(
      const Duration(milliseconds: 300),
      _showCoachMarksNow,
    );
  }

  Future<void> _showCoachMarksNow() async {
    if (!mounted) return;
    final steps = <CoachMark>[
      CoachMark(
        targetKey: _importKey,
        title: '📥 Import any file',
        body:
            'Pick a single file, multiple files, or a whole folder — or share into DocShelf from any other app.',
      ),
      CoachMark(
        targetKey: _scanKey,
        title: '📷 Scan paper documents',
        body:
            'Auto-edge detection, perspective correction, multi-page → single PDF. All on-device — nothing leaves your phone.',
      ),
      CoachMark(
        targetKey: _findKey,
        title: '🔍 Find what you already have',
        body:
            'Scan WhatsApp, Drive, Telegram, Downloads — files you already own.',
      ),
      CoachMark(
        targetKey: _categoriesKey,
        title: '🗂️ Categories that match real life',
        body:
            'Identity, Finance, Work, Education, Health, Insurance, Quotations — 14 starter folders. Add your own anytime.',
      ),
    ];
    if (!mounted) return;
    CoachMarkOverlay.show(context, steps: steps);
  }

  Future<void> _maybeShowCoachMarks() async {
    final seen = await OnboardingService.instance.hasSeenCoachMarks();
    if (seen || !mounted) return;
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    OnboardingService.instance.markCoachMarksSeen();
    await _showCoachMarksNow();
  }

  Future<void> _refreshStorage() async {
    final size = await FileStorageService.instance.getTotalStorageUsed();
    if (!mounted) return;
    setState(() => _storageBytes = size);
  }

  String _formatBytes(int b) {
    if (b < 1024) return '$b B';
    if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)} KB';
    if (b < 1024 * 1024 * 1024) {
      return '${(b / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(b / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good Morning';
    if (h < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  /// Bottom-sheet picker offering three import modes.
  Future<void> _showImportSheet() async {
    final mode = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
              child: Text(
                'Import documents',
                style: GoogleFonts.nunito(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.insert_drive_file_outlined),
              title: const Text('Import a single file'),
              subtitle: const Text('Pick one PDF, image, doc, or note'),
              onTap: () => Navigator.of(context).pop('single'),
            ),
            ListTile(
              leading: const Icon(Icons.file_copy_outlined),
              title: const Text('Import multiple files'),
              subtitle: const Text('Pick several at once'),
              onTap: () => Navigator.of(context).pop('multi'),
            ),
            ListTile(
              leading: const Icon(Icons.folder_open_outlined),
              title: const Text('Import an entire folder'),
              subtitle: const Text('Recursively scan a folder & batch-import'),
              onTap: () => Navigator.of(context).pop('folder'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (mode == null || !mounted) return;
    switch (mode) {
      case 'single':
        await _importSingle();
      case 'multi':
      case 'folder':
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const BatchImportScreen()),
        );
    }
  }

  Future<void> _importSingle() async {
    final res = await FilePicker.platform.pickFiles(allowMultiple: false);
    if (res == null || res.files.isEmpty) return;
    final path = res.files.first.path;
    if (path == null || !mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => SaveDocumentSheet(sourcePath: path),
    );
  }

  Future<void> _scanCamera() async {
    String? scanned;
    try {
      scanned = await CameraScanService.instance.scanDocument();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(FriendlyError.from(e))),
      );
      return;
    }
    if (scanned == null || !mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => SaveDocumentSheet(sourcePath: scanned!),
    );
  }

  void _findOnDevice() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const DeviceFileSearchScreen()),
    );
  }

  Future<void> _newNote() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const NoteEditorScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DocumentNotifier>(
      builder: (context, _, __) {
        return RefreshIndicator(
          onRefresh: () async {
            await _refreshStorage();
            DocumentNotifier.instance.notifyDocumentChanged();
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              // ─── Greeting banner ─────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_greeting()} 👋',
                      style: GoogleFonts.nunito(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: AppColors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: () {
                        setState(() {
                          _tipIndex =
                              (_tipIndex + 1) % AppConstants.homeTips.length;
                        });
                      },
                      child: Text(
                        AppConstants.homeTips[_tipIndex],
                        style: GoogleFonts.nunito(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.white.withValues(alpha: 0.9),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ─── Hero action buttons ─────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: _HeroButton(
                      key: _importKey,
                      emoji: '📥',
                      label: 'Import',
                      onTap: _showImportSheet,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _HeroButton(
                      key: _scanKey,
                      emoji: '📷',
                      label: 'Scan',
                      onTap: _scanCamera,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _HeroButton(
                      emoji: '📝',
                      label: 'Note',
                      onTap: _newNote,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _HeroButton(
                      key: _findKey,
                      emoji: '🔍',
                      label: 'Find',
                      onTap: _findOnDevice,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // ─── Expiring soon strip ─────────────────────────────────
              FutureBuilder<List<Document>>(
                future:
                    DatabaseService.instance.getExpiringDocuments(30),
                builder: (context, snap) {
                  final docs = snap.data ?? const <Document>[];
                  if (docs.isEmpty) return const SizedBox.shrink();
                  return _ExpiringStrip(docs: docs);
                },
              ),

              const SizedBox(height: 18),

              // ─── Stats row ───────────────────────────────────────────
              FutureBuilder<List<Document>>(
                future: DatabaseService.instance.getAllDocuments(),
                builder: (context, snap) {
                  final docs = snap.data ?? const <Document>[];
                  return Row(
                    children: [
                      Expanded(
                        child: _StatTile(
                          icon: '📄',
                          value: '${docs.length}',
                          label: 'Documents',
                          onTap: () =>
                              OnboardingService.instance.requestActiveTab(2),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _StatTile(
                          icon: '💾',
                          value: _formatBytes(_storageBytes),
                          label: 'Used',
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 22),

              // ─── Browse by category ──────────────────────────────────
              Padding(
                key: _categoriesKey,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  'Browse by category',
                  style: GoogleFonts.nunito(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 110,
                child: Consumer<CategoryService>(
                  builder: (context, cats, _) {
                    final roots = cats.rootCategories;
                    return ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: roots.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (_, i) => _CategoryTile(cat: roots[i]),
                    );
                  },
                ),
              ),
              const SizedBox(height: 22),

              // ─── Recently added ──────────────────────────────────────
              FutureBuilder<List<Document>>(
                future: DatabaseService.instance.getAllDocuments(),
                builder: (context, snap) {
                  final docs = (snap.data ?? const <Document>[]).take(8).toList();
                  if (docs.isEmpty) return _EmptyHomeHint(onImport: _showImportSheet);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Recently added',
                        style: GoogleFonts.nunito(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ...docs.map((d) => _DocRow(doc: d)),
                    ],
                  );
                },
              ),

              const SizedBox(height: 22),

              // ─── Bookmarked ──────────────────────────────────────────
              FutureBuilder<List<Document>>(
                future: DatabaseService.instance.getBookmarkedDocuments(),
                builder: (context, snap) {
                  final docs = snap.data ?? const <Document>[];
                  if (docs.isEmpty) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bookmarked',
                        style: GoogleFonts.nunito(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 84,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: docs.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 10),
                          itemBuilder: (_, i) => _BookmarkChip(doc: docs[i]),
                        ),
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 28),

              // ─── Support the developer (bottom of home) ──────────────
              const SupportDeveloperButton(),
            ],
          ),
        );
      },
    );
  }
}

// ─── Sub-widgets ─────────────────────────────────────────────────────
class _HeroButton extends StatelessWidget {
  const _HeroButton({
    super.key,
    required this.emoji,
    required this.label,
    required this.onTap,
  });

  final String emoji;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.25),
          ),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 26)),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.nunito(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.value,
    required this.label,
    this.onTap,
  });

  final String icon;
  final String value;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color:
              Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: GoogleFonts.nunito(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  label,
                  style: GoogleFonts.nunito(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.gray,
                  ),
                ),
              ],
            ),
          ),
          if (onTap != null)
            const Icon(Icons.chevron_right, size: 18, color: AppColors.gray),
        ],
      ),
    );
    if (onTap == null) return content;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: content,
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.cat});
  final dynamic cat;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => CategoryDetailScreen(category: cat),
          ),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: FutureBuilder<int>(
        future: DatabaseService.instance.countDocumentsInCategory(cat.id as String),
        builder: (context, snap) {
          final count = snap.data ?? 0;
          return Container(
            width: 130,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  cat.emoji as String,
                  style: const TextStyle(fontSize: 28),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cat.name as String,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.nunito(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: AppColors.white,
                      ),
                    ),
                    Text(
                      '$count file${count == 1 ? '' : 's'}',
                      style: GoogleFonts.nunito(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.white.withValues(alpha: 0.78),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DocRow extends StatelessWidget {
  const _DocRow({required this.doc});
  final Document doc;

  @override
  Widget build(BuildContext context) {
    final crumb = CategoryService.instance
        .getBreadcrumb(doc.categoryId)
        .map((c) => c.name)
        .join(' / ');
    return ListTile(
      leading: DocumentThumbnail(document: doc, size: 44),
      contentPadding: EdgeInsets.zero,
      title: Text(
        doc.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
      ),
      subtitle: Text(
        crumb,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.nunito(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.gray,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (doc.isBookmarked)
            const Padding(
              padding: EdgeInsets.only(right: 4),
              child: Icon(Icons.bookmark,
                  color: AppColors.accent, size: 18),
            ),
          IconButton(
            tooltip: 'Share',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.ios_share, size: 20),
            onPressed: () => shareDocument(context, doc),
          ),
        ],
      ),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => DocumentViewerScreen(doc: doc)),
        );
      },
    );
  }
}

class _BookmarkChip extends StatelessWidget {
  const _BookmarkChip({required this.doc});
  final Document doc;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => DocumentViewerScreen(doc: doc)),
      ),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 200,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.accent.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            DocumentThumbnail(document: doc, size: 44),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    doc.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
                  ),
                  Text(
                    doc.formattedDate,
                    style: GoogleFonts.nunito(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.gray,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Share',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.ios_share, size: 20),
              onPressed: () => shareDocument(context, doc),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpiringStrip extends StatelessWidget {
  const _ExpiringStrip({required this.docs});
  final List<Document> docs;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '⚠️ Expiring soon',
              style: GoogleFonts.nunito(
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ExpiringSoonScreen(),
                  ),
                );
              },
              child: const Text('See all'),
            ),
          ],
        ),
        SizedBox(
          height: 80,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              final d = docs[i];
              final days = d.daysUntilExpiry ?? 0;
              return InkWell(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => DocumentViewerScreen(doc: d),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: 220,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const Text('⏰', style: TextStyle(fontSize: 22)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              d.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.nunito(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              days < 0
                                  ? 'Expired ${-days}d ago'
                                  : 'In $days days',
                              style: GoogleFonts.nunito(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.warning,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _EmptyHomeHint extends StatelessWidget {
  const _EmptyHomeHint({required this.onImport});
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Nothing here yet 📭',
            style: GoogleFonts.nunito(
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "Tap Import above, or share any file from another app into DocShelf.",
            style: GoogleFonts.nunito(
              fontWeight: FontWeight.w500,
              color: AppColors.gray,
            ),
          ),
        ],
      ),
    );
  }
}
