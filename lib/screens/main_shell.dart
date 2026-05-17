import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import '../services/onboarding_service.dart';
import '../services/permission_service.dart';
import '../services/review_service.dart';
import '../widgets/save_document_sheet.dart';
import 'batch_import_screen.dart';
import 'home_screen.dart';
import 'library_screen.dart';
import 'search_screen.dart';
import 'settings_screen.dart';

/// Bottom-nav shell with 4 tabs. Receives share-intents and prompts for
/// the top-level storage permission on first launch.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  StreamSubscription<List<SharedMediaFile>>? _sharingSub;

  @override
  void initState() {
    super.initState();
    _wireSharingIntent();
    OnboardingService.instance.activeTabRequest.addListener(_onTabRequest);
    // Request top-level storage access so files land in the visible
    // /storage/emulated/0/DocShelf/ folder, not the app's private dir.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final granted =
          await PermissionService.instance.requestStoragePermission();
      if (!granted && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            duration: Duration(seconds: 6),
            content: Text(
              'Files will be stored privately. Enable "All files access" '
              'in Settings to make /DocShelf/ visible in your file manager.',
            ),
          ),
        );
      }
      // Auto-prompt for in-app review once the install is 3+ days old
      // and at most every 7 days. Google rate-limits server-side too.
      unawaited(ReviewService.instance.maybePromptAutomatically());
    });
  }

  void _onTabRequest() {
    final i = OnboardingService.instance.activeTabRequest.value;
    if (i < 0 || i > 3) return;
    if (!mounted) return;
    setState(() => _index = i);
  }

  @override
  void dispose() {
    OnboardingService.instance.activeTabRequest.removeListener(_onTabRequest);
    _sharingSub?.cancel();
    super.dispose();
  }

  // ─── Share intent ───────────────────────────────────────────────────
  // Wires up two delivery paths:
  //   - getMediaStream()   — warm starts (app already running when share
  //                          fires)
  //   - getInitialMedia()  — cold starts (share triggered the launch)
  //
  // For the cold-start path we DEFER processing to a post-frame callback
  // so the Navigator + Scaffold are mounted before we try to push a
  // route or show a modal sheet. Without this, on first launch the
  // share-handler tries to push before the widget tree is ready and the
  // modal silently dismisses → user sees the app open with no save flow,
  // exactly the bug.
  void _wireSharingIntent() {
    if (!Platform.isAndroid && !Platform.isIOS) return;
    final inst = ReceiveSharingIntent.instance;
    _sharingSub = inst.getMediaStream().listen(_onSharedFiles);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final files = await inst.getInitialMedia();
      if (files.isNotEmpty) {
        // Tiny delay lets the splash → main-shell transition complete
        // on slower devices before the route push fires.
        await Future<void>.delayed(const Duration(milliseconds: 200));
        if (mounted) await _onSharedFiles(files);
      }
      // Always reset — even if we skipped processing due to unmount — so
      // the next cold start doesn't replay the same intent.
      inst.reset();
    });
  }

  Future<void> _onSharedFiles(List<SharedMediaFile> files) async {
    if (!mounted || files.isEmpty) return;
    final paths = files
        .map((f) => f.path)
        .where((p) => p.trim().isNotEmpty)
        .toList(growable: false);
    if (paths.isEmpty) return;

    if (paths.length == 1) {
      // Single share → quick save sheet.
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => SaveDocumentSheet(sourcePath: paths.first),
      );
      return;
    }

    // Multi-file share (e.g. user picked 3 PDFs in WhatsApp → Share →
    // DocShelf). One-folder-fits-all UX: open the batch import screen
    // pre-loaded with every shared path so the user picks ONE folder
    // and saves them all at once instead of N sequential sheets.
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BatchImportScreen(preloadedPaths: paths),
      ),
    );
  }

  // ─── Build ──────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: _index,
          children: const [
            HomeScreen(),
            LibraryScreen(),
            SearchScreen(),
            SettingsScreen(),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.folder_outlined),
            selectedIcon: Icon(Icons.folder_rounded),
            label: 'Library',
          ),
          NavigationDestination(
            icon: Icon(Icons.search_outlined),
            selectedIcon: Icon(Icons.search_rounded),
            label: 'Search',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
