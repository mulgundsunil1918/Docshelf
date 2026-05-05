import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../utils/app_colors.dart';

/// Static FAQ screen — 14 hand-written items, no DB / network reads.
/// Works offline, costs nothing, opens instantly.
class FaqScreen extends StatelessWidget {
  const FaqScreen({super.key});

  static const _faqs = <_FaqItem>[
    _FaqItem(
      'Where are my files actually saved?',
      'In a folder called DocShelf at the top of your phone storage — '
          '`/storage/emulated/0/DocShelf/`. You can browse it with any '
          'file manager. If you uninstall DocShelf, the files survive.',
    ),
    _FaqItem(
      'Does DocShelf upload my documents anywhere?',
      'No. DocShelf has no server, no account, no cloud sync. Everything '
          'stays on this phone. The only network calls the app makes are '
          'when you tap a link (e.g. Privacy Policy) or rate the app.',
    ),
    _FaqItem(
      'How do I import a file?',
      'Tap "Import" on Home — choose single file, multiple files, or an '
          'entire folder. Or, from any other app (WhatsApp, Drive, Gmail, '
          'Files, etc.), use that app\'s Share button and pick DocShelf.',
    ),
    _FaqItem(
      'How does scan-with-camera work?',
      'Tap "Scan" on Home. The native document scanner opens — point at a '
          'paper, it auto-detects edges and corrects perspective. Multi-page '
          'scans become a single PDF. All processing is on-device.',
    ),
    _FaqItem(
      'How do expiry reminders work?',
      'When saving any document you can toggle "This document has an expiry '
          'date." DocShelf opens your phone\'s native calendar app with the '
          'reminder pre-filled — your normal calendar handles the alert.',
    ),
    _FaqItem(
      'Can I add my own folders?',
      'Yes. In Library, tap the + icon to add a new top-level folder. '
          'Inside any folder, the 3-dot menu has "Add subfolder."',
    ),
    _FaqItem(
      'Can I rename or move files?',
      'Open the file → ⋮ menu → Properties → Name (rename) or Saved In '
          '(move to a different folder).',
    ),
    _FaqItem(
      'How do I find a specific document?',
      'Tap the Search tab and type any part of the name, description, or '
          'folder path. Use the filter chips to narrow by file type.',
    ),
    _FaqItem(
      'My files folder isn\'t showing up in my file manager',
      'On Android 11 and above DocShelf needs "All files access" to write '
          'to the visible /DocShelf/ folder. Open Settings → Apps → DocShelf '
          '→ Permissions and grant it. If you decline, files go to a '
          'private app folder instead.',
    ),
    _FaqItem(
      'I forgot to mark something as bookmarked',
      'Open the file → tap the bookmark icon in the top bar. It will '
          'appear in the Bookmarked strip on Home.',
    ),
    _FaqItem(
      'Why are my documents not appearing on my new phone after restore?',
      'By design — DocShelf opts out of Android backup so your tutorial / '
          'coach marks reset cleanly on a new install. The actual files in '
          '/DocShelf/ on your phone storage transfer via Smart Switch / '
          'Files-by-Google like any normal folder. Re-tag them via Find on '
          'device.',
    ),
    _FaqItem(
      'Can I share a document?',
      'Open the file → ⋮ → Share. The standard Android share sheet opens '
          'so you can send it via WhatsApp / Email / etc.',
    ),
    _FaqItem(
      'How do I uninstall DocShelf without losing files?',
      'Just uninstall — the /DocShelf/ folder stays on your phone storage. '
          'On reinstall, tap "Find on device" to re-scan it.',
    ),
    _FaqItem(
      'How can I support development?',
      'Bottom of the Home screen, or Settings → Support. DocShelf is free '
          'and ad-free; chipping in keeps it that way.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Help & FAQs')),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: _faqs.length,
        separatorBuilder: (_, __) => const SizedBox(height: 6),
        itemBuilder: (_, i) => _FaqTile(item: _faqs[i]),
      ),
    );
  }
}

class _FaqItem {
  const _FaqItem(this.q, this.a);
  final String q;
  final String a;
}

class _FaqTile extends StatelessWidget {
  const _FaqTile({required this.item});
  final _FaqItem item;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        title: Text(
          item.q,
          style: GoogleFonts.nunito(
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedAlignment: Alignment.centerLeft,
        children: [
          Text(
            item.a,
            style: GoogleFonts.nunito(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              height: 1.5,
              color: AppColors.gray,
            ),
          ),
        ],
      ),
    );
  }
}
