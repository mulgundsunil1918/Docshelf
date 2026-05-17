import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
  int _index = 0;

  StreamSubscription<List<SharedMediaFile>>? _sharingSub;

  // iOS method channel — bypasses receive_sharing_intent's cold-start
  // scene-delegate timing issue (eventSink fires before Dart listener
  // is registered; initialMedia is never set via the scene path).
  static const _intentChannel = MethodChannel('docshelf/share_intent');

  // Guard: prevent showing the save sheet twice if both the plugin
  // stream and our channel fire for the same share event.
  bool _handlingShare = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
    WidgetsBinding.instance.removeObserver(this);
    OnboardingService.instance.activeTabRequest.removeListener(_onTabRequest);
    _sharingSub?.cancel();
    super.dispose();
  }

  // ─── Lifecycle observer ─────────────────────────────────────────────
  // Catches iOS cold-start shares that the plugin stream misses because
  // the scene delegate fires the eventSink before Dart is listening.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && Platform.isIOS) {
      _checkIosPendingShare();
    }
  }

  // ─── Share intent ───────────────────────────────────────────────────
  // Two delivery paths:
  //
  //  Android  → receive_sharing_intent stream (getMediaStream) + getInitialMedia
  //  iOS warm → receive_sharing_intent stream fires when app is already open
  //  iOS cold → scene delegate fires eventSink before Dart listener exists
  //             so we bypass the plugin and read directly from the shared
  //             app-group UserDefaults via the 'docshelf/share_intent' channel
  //
  void _wireSharingIntent() {
    if (!Platform.isAndroid && !Platform.isIOS) return;

    final inst = ReceiveSharingIntent.instance;

    // Android + iOS warm-start: stream fires while app is running.
    _sharingSub = inst.getMediaStream().listen((files) {
      inst.reset(); // reset before processing so double-fire is harmless
      _onSharedFiles(files);
    });

    if (Platform.isAndroid) {
      // Android cold-start via getInitialMedia.
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final files = await inst.getInitialMedia();
        inst.reset();
        if (files.isNotEmpty && mounted) {
          await Future<void>.delayed(const Duration(milliseconds: 200));
          if (mounted) await _onSharedFiles(files);
        }
      });
    } else {
      // iOS: check the native channel on first frame (handles cold-start)
      // AND on every app-resume (handles extension → manual app open).
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 300));
        if (mounted) await _checkIosPendingShare();
      });
    }
  }

  /// Reads the raw app-group UserDefaults via native channel, bypassing
  /// receive_sharing_intent's cold-start scene-delegate timing issue.
  Future<void> _checkIosPendingShare() async {
    if (_handlingShare) return;
    try {
      final raw = await _intentChannel.invokeMethod<List<dynamic>>('getAndClear');
      final paths = (raw ?? [])
          .cast<String>()
          .map((p) => p.startsWith('file://') ? p.substring(7) : p)
          .where((p) => p.trim().isNotEmpty)
          .toList(growable: false);
      if (paths.isEmpty || !mounted) return;
      await _onSharedPaths(paths);
    } on PlatformException {
      // channel not available on Android or if something went wrong — ignore
    }
  }

  Future<void> _onSharedFiles(List<SharedMediaFile> files) async {
    if (files.isEmpty) return;
    final paths = files
        .map((f) => f.path.startsWith('file://')
            ? f.path.substring(7)
            : f.path)
        .where((p) => p.trim().isNotEmpty)
        .toList(growable: false);
    await _onSharedPaths(paths);
  }

  Future<void> _onSharedPaths(List<String> paths) async {
    if (!mounted || paths.isEmpty || _handlingShare) return;
    _handlingShare = true;
    try {
      if (paths.length == 1) {
        await showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          builder: (_) => SaveDocumentSheet(sourcePath: paths.first),
        );
      } else {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => BatchImportScreen(preloadedPaths: paths),
          ),
        );
      }
    } finally {
      _handlingShare = false;
    }
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
