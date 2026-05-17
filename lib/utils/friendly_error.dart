import 'dart:io';

import 'package:flutter/services.dart';

/// Maps raw exceptions to user-readable messages.
///
/// Rule: never let `[firebase/...]`, `FileSystemException: errno = 13`,
/// or other engine vomit reach a snackbar. Wrap every `catch (e)` site
/// with this util:
///
///     ScaffoldMessenger.of(context).showSnackBar(
///       SnackBar(content: Text(FriendlyError.from(e))),
///     );
class FriendlyError {
  FriendlyError._();

  /// Returns a short, plain-English explanation of [error].
  static String from(Object error, {String fallback = 'Something went wrong.'}) {
    if (error is FileSystemException) {
      return _fileSystemMessage(error);
    }
    if (error is PlatformException) {
      return _platformMessage(error, fallback);
    }
    if (error is FormatException) {
      return "We couldn't read that file's name or path.";
    }
    if (error is StateError) {
      return 'The app got into an unexpected state. Try again.';
    }
    if (error is TypeError) {
      return 'Internal error — please report this if it keeps happening.';
    }

    final msg = error.toString();

    // Common substrings — strip noise and translate.
    if (msg.contains('PERMISSION_DENIED') || msg.toLowerCase().contains('permission denied')) {
      return 'Permission denied. Please grant storage access in Settings.';
    }
    if (msg.contains('ENOSPC')) {
      return "Your phone is out of storage. Free up some space and try again.";
    }
    if (msg.contains('EACCES') || msg.contains('errno = 13')) {
      return 'DocShelf cannot access that location. Check storage permission in Settings.';
    }
    if (msg.contains('ENOENT') || msg.toLowerCase().contains('no such file')) {
      return "That file no longer exists on your phone.";
    }
    if (msg.toLowerCase().contains('user canceled') ||
        msg.toLowerCase().contains('user cancelled')) {
      return 'Cancelled.';
    }
    // Default: don't leak the raw exception text.
    return fallback;
  }

  static String _platformMessage(PlatformException e, String fallback) {
    final code = e.code.toLowerCase();
    final msg = (e.message ?? '').toLowerCase();
    if (code.contains('camera_permission') ||
        msg.contains('permission') && (code.contains('camera') || msg.contains('camera'))) {
      return 'Camera access denied. Enable it in Settings → DocShelf.';
    }
    if (code.contains('camera') || msg.contains('camera') ||
        msg.contains('scanner') || msg.contains('not supported') ||
        msg.contains('scanning is not available') ||
        msg.contains('document scan')) {
      return 'Document scanner is not available on this device.';
    }
    if (code.contains('permission') || msg.contains('permission denied')) {
      return 'Permission denied. Please enable access in Settings → DocShelf.';
    }
    return fallback;
  }

  static String _fileSystemMessage(FileSystemException e) {
    final code = e.osError?.errorCode ?? 0;
    switch (code) {
      case 2: // ENOENT
        return "That file no longer exists on your phone.";
      case 13: // EACCES
        return 'DocShelf cannot access that location. Check storage permission in Settings.';
      case 17: // EEXIST
        return 'A file with that name already exists.';
      case 28: // ENOSPC
        return "Your phone is out of storage. Free up some space and try again.";
      case 30: // EROFS
        return 'That location is read-only.';
      default:
        return 'A file system error stopped this action.';
    }
  }
}
