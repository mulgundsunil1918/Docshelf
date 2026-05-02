import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

/// Centralizes Android storage / notification permission handling so the
/// rest of the app can call one method and trust the result.
class PermissionService {
  static final PermissionService instance = PermissionService._();
  PermissionService._();

  int? _androidSdk;

  Future<int> _sdk() async {
    if (_androidSdk != null) return _androidSdk!;
    if (!Platform.isAndroid) return _androidSdk = 0;
    final info = await DeviceInfoPlugin().androidInfo;
    return _androidSdk = info.version.sdkInt;
  }

  /// Requests the right combination for the device's Android SDK level.
  ///
  /// - Android ≤ 10: WRITE_EXTERNAL_STORAGE
  /// - Android 11-12: MANAGE_EXTERNAL_STORAGE (full disk access)
  /// - Android 13+: READ_MEDIA_IMAGES / VIDEO / AUDIO + MANAGE_EXTERNAL_STORAGE
  ///
  /// Returns true if the app is allowed to read/write the public DocShelf
  /// folder.
  Future<bool> requestStoragePermission() async {
    if (!Platform.isAndroid) return true;
    final sdk = await _sdk();

    if (sdk >= 30) {
      final manage = await Permission.manageExternalStorage.status;
      if (manage.isGranted) return true;
      final result = await Permission.manageExternalStorage.request();
      return result.isGranted;
    }

    final storage = await Permission.storage.status;
    if (storage.isGranted) return true;
    final result = await Permission.storage.request();
    return result.isGranted;
  }

  Future<bool> hasStoragePermission() async {
    if (!Platform.isAndroid) return true;
    final sdk = await _sdk();
    if (sdk >= 30) {
      return (await Permission.manageExternalStorage.status).isGranted;
    }
    return (await Permission.storage.status).isGranted;
  }

  /// Android 13+ requires runtime permission to post notifications.
  Future<bool> requestNotificationPermission() async {
    if (!Platform.isAndroid) return true;
    final sdk = await _sdk();
    if (sdk < 33) return true;
    final status = await Permission.notification.status;
    if (status.isGranted) return true;
    final result = await Permission.notification.request();
    return result.isGranted;
  }

  Future<void> openSettings() async {
    await openAppSettings();
  }
}
