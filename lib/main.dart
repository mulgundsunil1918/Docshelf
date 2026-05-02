import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:timezone/data/latest.dart' as tz;

import 'screens/splash_screen.dart';
import 'services/category_service.dart';
import 'services/document_notifier.dart';
import 'services/notification_service.dart';
import 'services/onboarding_service.dart';
import 'services/profile_service.dart';
import 'utils/app_theme.dart';
import 'utils/constants.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Desktop platforms (testing) need sqflite FFI; mobile uses native sqflite.
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  tz.initializeTimeZones();

  // Bootstrap critical singletons before first frame.
  await CategoryService.instance.load();
  await ProfileService.instance.load();
  await NotificationService.instance.init();
  // Re-register expiry reminders (covers reinstall/reboot).
  unawaited(NotificationService.instance.rescheduleAllReminders());

  final themeMode = await OnboardingService.instance.getThemeMode();

  runApp(DocShelfApp(initialThemeMode: themeMode));
}

class DocShelfApp extends StatelessWidget {
  const DocShelfApp({super.key, required this.initialThemeMode});

  final String initialThemeMode;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: CategoryService.instance),
        ChangeNotifierProvider.value(value: ProfileService.instance),
        ChangeNotifierProvider.value(value: DocumentNotifier.instance),
        ChangeNotifierProvider(
          create: (_) => ThemeNotifier(initialThemeMode),
        ),
      ],
      child: Consumer<ThemeNotifier>(
        builder: (context, theme, _) {
          return MaterialApp(
            title: AppConstants.appName,
            debugShowCheckedModeBanner: false,
            themeMode: theme.mode,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            home: const SplashScreen(),
          );
        },
      ),
    );
  }
}

/// Persists and broadcasts the user's theme choice. Three values:
/// `system` (default), `light`, `dark`.
class ThemeNotifier extends ChangeNotifier {
  ThemeNotifier(String initial) : _key = initial;

  String _key;

  String get key => _key;

  ThemeMode get mode {
    switch (_key) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  Future<void> setKey(String key) async {
    if (_key == key) return;
    _key = key;
    await OnboardingService.instance.setThemeMode(key);
    notifyListeners();
  }
}
