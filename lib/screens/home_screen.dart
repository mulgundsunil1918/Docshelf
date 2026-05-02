import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../data/default_categories.dart';
import '../models/document.dart';
import '../services/category_service.dart';
import '../services/database_service.dart';
import '../services/document_notifier.dart';
import '../services/file_storage_service.dart';
import '../services/onboarding_service.dart';
import '../services/profile_service.dart';
import '../utils/app_colors.dart';
import '../utils/constants.dart';
import '../widgets/coach_mark_overlay.dart';
import '../widgets/document_thumbnail.dart';
import '../widgets/save_document_sheet.dart';
import 'category_detail_screen.dart';
import 'device_file_search_screen.dart';
import 'document_viewer_screen.dart';
import 'expiring_soon_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late int _tipIndex;
  int _storageBytes = 0;
  final _importKey = GlobalKey();
  final _findKey = GlobalKey();
  final _categoriesKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    final day = DateTime.now().day;
    _tipIndex = day % AppConstants.homeTips.length;
    _refreshStorage();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowCoachMarks());
  }

  Future<void> _maybeShowCoachMarks() async {
    final seen = await OnboardingService.instance.hasSeenCoachMarks();
    if (seen || !mounted) return;
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    final steps = <CoachMark>[
      CoachMark(
        targetKey: _importKey,
        title: '📥 Add documents from anywhere',
        body:
            'Pick from device storage, or share into DocShelf from any app.',
      ),
      CoachMark(
        targetKey: _findKey,
        title: '🔍 Find what you already have',
        body:
            'Scan WhatsApp, Drive, Telegram, Downloads — files you already own.',
      ),
      CoachMark(
        targetKey: _categoriesKey,
        title: '🗂️ Your vault, organized the Indian way',
        body:
            'Identity, Finance, Health, Property — categories that match the documents you actually have.',
      ),
    ];
    OnboardingService.instance.markCoachMarksSeen();
    CoachMarkOverlay.show(context, steps: steps);
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

  Future<void> _importFile() async {
    final res = await FilePicker.platform.pickFiles(allowMultiple: false);
    if (res == null || res.files.isEmpty) return;
    final path = res.files.first.path;
    if (path == null) return;
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => SaveDocumentSheet(sourcePath: path),
    );
  }

  Future<void> _scanCamera() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    if (res == null || res.files.isEmpty) return;
    final path = res.files.first.path;
    if (path == null) return;
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => SaveDocumentSheet(sourcePath: path),
    );
  }

  void _findOnDevice() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const DeviceFileSearchScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<ProfileService, DocumentNotifier>(
      builder: (context, profile, _, __) {
        final activeSpace = profile.activeSpace;
        if (activeSpace == null) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Add a family member from the top to get started.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () async {
            await _refreshStorage();
            DocumentNotifier.instance.notifyDocumentChanged();
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              // ─── Greeting banner ───────────────────────────────────
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
                      '${_greeting()}, ${activeSpace.name} 👋',
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

              // ─── Hero action buttons ───────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: _HeroButton(
                      key: _importKey,
                      emoji: '📥',
                      label: 'Import',
                      onTap: _importFile,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _HeroButton(
                      emoji: '📷',
                      label: 'Scan',
                      onTap: _scanCamera,
                    ),
                  ),
                  const SizedBox(width: 10),
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
              const SizedBox(height: 20),

              // ─── Expiring soon strip ───────────────────────────────
              FutureBuilder<List<Document>>(
                future: DatabaseService.instance.getExpiringDocuments(
                  30,
                  spaceId: activeSpace.id,
                ),
                builder: (context, snap) {
                  final docs = snap.data ?? const <Document>[];
                  if (docs.isEmpty) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionHeader(
                        title: '⚠️ Expiring Soon',
                        action: 'See all',
                        onAction: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const ExpiringSoonScreen(),
                            ),
                          );
                        },
                      ),
                      SizedBox(
                        height: 92,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          itemCount: docs.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 10),
                          itemBuilder: (_, i) => _ExpiringCard(doc: docs[i]),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  );
                },
              ),

              // ─── Stats row ─────────────────────────────────────────
              FutureBuilder<List<Document>>(
                future: DatabaseService.instance.getAllDocuments(
                  spaceId: activeSpace.id,
                ),
                builder: (context, snap) {
                  final docs = snap.data ?? const <Document>[];
                  return Row(
                    children: [
                      Expanded(
                        child: _StatBox(
                          emoji: '📄',
                          value: '${docs.length}',
                          label: 'Documents',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _StatBox(
                          emoji: '👥',
                          value: '${profile.spaces.length}',
                          label: 'Spaces',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _StatBox(
                          emoji: '💾',
                          value: _formatBytes(_storageBytes),
                          label: 'Used',
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),

              // ─── Browse by category ────────────────────────────────
              _SectionHeader(key: _categoriesKey, title: 'Browse by Category'),
              SizedBox(
                height: 110,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: kDefaultCategories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (_, i) {
                    final c = kDefaultCategories[i];
                    return FutureBuilder<List<Document>>(
                      future: DatabaseService.instance.getDocumentsByCategories(
                        CategoryService.instance.getAllDescendantIds(c.id),
                        spaceId: activeSpace.id,
                      ),
                      builder: (context, snap) {
                        final count = (snap.data ?? const []).length;
                        return _CategoryCard(
                          emoji: c.emoji,
                          name: c.name,
                          count: count,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    CategoryDetailScreen(category: c),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),

              // ─── Recently added ────────────────────────────────────
              const _SectionHeader(title: 'Recently Added'),
              FutureBuilder<List<Document>>(
                future: DatabaseService.instance
                    .getAllDocuments(spaceId: activeSpace.id),
                builder: (context, snap) {
                  final all = snap.data ?? const <Document>[];
                  final recent = all.take(8).toList();
                  if (recent.isEmpty) {
                    return _EmptyHint(
                      emoji: '📂',
                      message:
                          'No documents yet. Tap Import to add your first one.',
                    );
                  }
                  return Column(
                    children: [
                      for (final d in recent)
                        _DocRow(
                          doc: d,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => DocumentViewerScreen(doc: d),
                              ),
                            );
                          },
                        ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 16),

              // ─── Bookmarked ────────────────────────────────────────
              FutureBuilder<List<Document>>(
                future: DatabaseService.instance
                    .getBookmarkedDocuments(spaceId: activeSpace.id),
                builder: (context, snap) {
                  final marks = snap.data ?? const <Document>[];
                  if (marks.isEmpty) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _SectionHeader(title: 'Bookmarked ⭐'),
                      SizedBox(
                        height: 92,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          itemCount: marks.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 10),
                          itemBuilder: (_, i) {
                            final d = marks[i];
                            return _BookmarkCard(
                              doc: d,
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
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Pieces ──────────────────────────────────────────────────────────
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
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.nunito(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    super.key,
    required this.title,
    this.action,
    this.onAction,
  });

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.nunito(
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          if (action != null)
            TextButton(onPressed: onAction, child: Text(action!)),
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({
    required this.emoji,
    required this.value,
    required this.label,
  });

  final String emoji;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color:
              Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(height: 4),
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
              color: Theme.of(context).textTheme.bodySmall?.color,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.emoji,
    required this.name,
    required this.count,
    required this.onTap,
  });

  final String emoji;
  final String name;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 130,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 28)),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: AppColors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '$count document${count == 1 ? '' : 's'}',
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
      ),
    );
  }
}

class _DocRow extends StatelessWidget {
  const _DocRow({required this.doc, required this.onTap});

  final Document doc;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            DocumentThumbnail(document: doc, size: 48),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    doc.name,
                    style: GoogleFonts.nunito(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${doc.formattedSize} · ${doc.formattedDate}',
                    style: GoogleFonts.nunito(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
                  ),
                ],
              ),
            ),
            if (doc.isBookmarked)
              const Icon(Icons.star, color: AppColors.accent, size: 18),
          ],
        ),
      ),
    );
  }
}

class _BookmarkCard extends StatelessWidget {
  const _BookmarkCard({required this.doc, required this.onTap});

  final Document doc;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 140,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.accent.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          children: [
            DocumentThumbnail(document: doc, size: 40),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                doc.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.nunito(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpiringCard extends StatelessWidget {
  const _ExpiringCard({required this.doc});

  final Document doc;

  Color _chipColor() {
    final d = doc.daysUntilExpiry;
    if (d == null) return AppColors.gray;
    if (d < 0) return AppColors.danger;
    if (d <= 7) return AppColors.danger;
    if (d <= 30) return AppColors.warning;
    return AppColors.success;
  }

  String _chipLabel() {
    final d = doc.daysUntilExpiry;
    if (d == null) return '';
    if (d < 0) return 'Expired ${-d}d ago';
    if (d == 0) return 'Expires today';
    return 'In ${d}d';
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => DocumentViewerScreen(doc: doc)),
        );
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 200,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _chipColor().withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          children: [
            DocumentThumbnail(document: doc, size: 48),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    doc.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _chipColor().withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _chipLabel(),
                      style: GoogleFonts.nunito(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: _chipColor(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.emoji, required this.message});

  final String emoji;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.nunito(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
