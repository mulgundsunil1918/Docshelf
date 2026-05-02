import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import '../models/family_member.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/document_notifier.dart';
import '../services/notification_service.dart';
import '../services/onboarding_service.dart';
import '../services/profile_service.dart';
import '../utils/app_colors.dart';
import '../widgets/save_document_sheet.dart';
import 'document_viewer_screen.dart';
import 'home_screen.dart';
import 'library_screen.dart';
import 'lock_screen.dart';
import 'manage_family_screen.dart';
import 'search_screen.dart';
import 'settings_screen.dart';

/// Bottom-nav shell with the persistent family-member switcher.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
  int _index = 0;
  DateTime? _lastBackgroundedAt;

  StreamSubscription<List<SharedMediaFile>>? _sharingSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _wireSharingIntent();
    NotificationService.instance.onNotificationTapped = _openDocFromNotification;
  }

  Future<void> _openDocFromNotification(int docId) async {
    final doc = await DatabaseService.instance.getDocumentById(docId);
    if (!mounted || doc == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => DocumentViewerScreen(doc: doc)),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sharingSub?.cancel();
    super.dispose();
  }

  // ─── Share intent ───────────────────────────────────────────────────
  void _wireSharingIntent() {
    if (!Platform.isAndroid && !Platform.isIOS) return;
    final inst = ReceiveSharingIntent.instance;
    _sharingSub = inst.getMediaStream().listen(_onSharedFiles);
    inst.getInitialMedia().then((files) {
      if (files.isNotEmpty) _onSharedFiles(files);
      inst.reset();
    });
  }

  Future<void> _onSharedFiles(List<SharedMediaFile> files) async {
    if (!mounted || files.isEmpty) return;
    for (final f in files) {
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => SaveDocumentSheet(sourcePath: f.path),
      );
    }
  }

  // ─── App-lifecycle (auto re-lock) ───────────────────────────────────
  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _lastBackgroundedAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed &&
        _lastBackgroundedAt != null) {
      final mins =
          await OnboardingService.instance.getAutoLockMinutes();
      if (mins < 0) return; // "Never"
      final elapsed =
          DateTime.now().difference(_lastBackgroundedAt!).inMinutes;
      _lastBackgroundedAt = null;
      if (elapsed >= mins && await AuthService.instance.isLockEnabled()) {
        if (!mounted) return;
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => LockScreen(
              onUnlocked: () => Navigator.of(context).pop(),
            ),
          ),
        );
      }
    }
  }

  // ─── Build ──────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const _FamilySwitcher(),
            const Divider(height: 1),
            Expanded(
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

class _FamilySwitcher extends StatelessWidget {
  const _FamilySwitcher();

  @override
  Widget build(BuildContext context) {
    return Consumer<ProfileService>(
      builder: (context, profile, _) {
        final members = profile.members;
        final active = profile.activeMember;
        return SizedBox(
          height: 80,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            scrollDirection: Axis.horizontal,
            children: [
              for (final m in members)
                _MemberChip(
                  member: m,
                  active: m.id == active?.id,
                  onTap: () => profile.setActiveMember(m.id),
                ),
              _AddMemberButton(),
            ],
          ),
        );
      },
    );
  }
}

class _MemberChip extends StatelessWidget {
  const _MemberChip({
    required this.member,
    required this.active,
    required this.onTap,
  });

  final FamilyMember member;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final size = active ? 56.0 : 44.0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: GestureDetector(
        onTap: () {
          onTap();
          DocumentNotifier.instance.notifyDocumentChanged();
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: size,
              height: size,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: active
                    ? AppColors.primary.withValues(alpha: 0.14)
                    : Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.06),
                border: Border.all(
                  color: active
                      ? AppColors.primary
                      : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Text(
                member.avatar,
                style: TextStyle(fontSize: active ? 26 : 22),
              ),
            ),
            const SizedBox(height: 2),
            SizedBox(
              width: 70,
              child: Text(
                member.name,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.nunito(
                  fontSize: 11,
                  fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                  color: active
                      ? AppColors.primary
                      : Theme.of(context).textTheme.bodySmall?.color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddMemberButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: GestureDetector(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ManageFamilyScreen()),
          );
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accent.withValues(alpha: 0.16),
                border: Border.all(
                  color: AppColors.accent.withValues(alpha: 0.4),
                  style: BorderStyle.solid,
                ),
              ),
              child: const Icon(Icons.add, color: AppColors.accentDark),
            ),
            const SizedBox(height: 2),
            SizedBox(
              width: 70,
              child: Text(
                'Add',
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accentDark,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
