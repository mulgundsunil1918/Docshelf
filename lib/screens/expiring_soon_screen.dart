import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/document.dart';
import '../services/category_service.dart';
import '../services/database_service.dart';
import '../services/document_notifier.dart';
import '../services/notification_service.dart';
import '../services/profile_service.dart';
import '../utils/app_colors.dart';
import '../widgets/document_thumbnail.dart';
import 'document_viewer_screen.dart';

enum _Bucket { all, expired, week, month, ninety }

extension on _Bucket {
  String get label {
    switch (this) {
      case _Bucket.all:
        return 'All';
      case _Bucket.expired:
        return 'Expired';
      case _Bucket.week:
        return 'This week';
      case _Bucket.month:
        return 'This month';
      case _Bucket.ninety:
        return 'Next 90d';
    }
  }

  bool matches(Document d) {
    final days = d.daysUntilExpiry;
    if (days == null) return false;
    switch (this) {
      case _Bucket.all:
        return true;
      case _Bucket.expired:
        return days < 0;
      case _Bucket.week:
        return days >= 0 && days <= 7;
      case _Bucket.month:
        return days >= 0 && days <= 30;
      case _Bucket.ninety:
        return days >= 0 && days <= 90;
    }
  }
}

class ExpiringSoonScreen extends StatefulWidget {
  const ExpiringSoonScreen({super.key});

  @override
  State<ExpiringSoonScreen> createState() => _ExpiringSoonScreenState();
}

class _ExpiringSoonScreenState extends State<ExpiringSoonScreen> {
  _Bucket _bucket = _Bucket.all;

  Color _chipColor(int? days) {
    if (days == null) return AppColors.gray;
    if (days < 0) return AppColors.danger;
    if (days <= 7) return AppColors.danger;
    if (days <= 30) return AppColors.warning;
    return AppColors.success;
  }

  String _chipLabel(int? days) {
    if (days == null) return '';
    if (days < 0) return 'Expired ${-days}d ago';
    if (days == 0) return 'Expires today';
    return 'In $days days';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<ProfileService, DocumentNotifier>(
      builder: (context, profile, _, __) {
        final activeId = profile.activeMember?.id;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Expiring soon'),
          ),
          body: Column(
            children: [
              SizedBox(
                height: 56,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    for (final b in _Bucket.values)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ChoiceChip(
                          label: Text(b.label),
                          selected: _bucket == b,
                          onSelected: (v) {
                            if (v) setState(() => _bucket = b);
                          },
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: FutureBuilder<List<Document>>(
                  future: DatabaseService.instance
                      .getExpiringDocuments(365 * 30, memberId: activeId),
                  builder: (context, snap) {
                    final all = snap.data ?? const <Document>[];
                    final filtered =
                        all.where(_bucket.matches).toList(growable: false);
                    if (filtered.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'No documents in this bucket.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.nunito(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      );
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, indent: 60),
                      itemBuilder: (_, i) {
                        final d = filtered[i];
                        final crumb = CategoryService.instance
                            .getBreadcrumb(d.categoryId)
                            .map((c) => c.name)
                            .join(' / ');
                        return ListTile(
                          leading: DocumentThumbnail(document: d, size: 44),
                          title: Text(
                            d.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                                GoogleFonts.nunito(fontWeight: FontWeight.w800),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Expires ${DateFormat('d MMM yyyy').format(d.expiryDate!)}',
                                style: GoogleFonts.nunito(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                crumb,
                                style: GoogleFonts.nunito(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.gray,
                                ),
                              ),
                            ],
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _chipColor(d.daysUntilExpiry)
                                  .withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _chipLabel(d.daysUntilExpiry),
                              style: GoogleFonts.nunito(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: _chipColor(d.daysUntilExpiry),
                              ),
                            ),
                          ),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => DocumentViewerScreen(doc: d),
                              ),
                            );
                          },
                          onLongPress: () => _showActionSheet(context, d),
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

  Future<void> _showActionSheet(BuildContext ctx, Document d) async {
    await showModalBottomSheet<void>(
      context: ctx,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.event_repeat),
              title: const Text('Renew (extend by 1 year)'),
              onTap: () async {
                final newDate = (d.expiryDate ?? DateTime.now())
                    .add(const Duration(days: 365));
                final updated = d.copyWith(expiryDate: newDate);
                await DatabaseService.instance.updateDocument(updated);
                if (updated.id != null) {
                  await NotificationService.instance
                      .scheduleExpiryReminder(updated);
                }
                DocumentNotifier.instance.notifyDocumentChanged();
                if (sheet.mounted) Navigator.of(sheet).pop();
              },
            ),
            ListTile(
              leading: const Icon(Icons.event_busy_outlined),
              title: const Text('Mark as renewed (clear expiry)'),
              onTap: () async {
                final updated = d.copyWith(clearExpiryDate: true);
                await DatabaseService.instance.updateDocument(updated);
                if (updated.id != null) {
                  await NotificationService.instance
                      .cancelReminder(updated.id!);
                }
                DocumentNotifier.instance.notifyDocumentChanged();
                if (sheet.mounted) Navigator.of(sheet).pop();
              },
            ),
          ],
        ),
      ),
    );
  }
}
