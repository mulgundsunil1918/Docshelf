import 'dart:io';

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
    if (msg.toLowerCase().contains('camera')) {
      return 'Camera unavailable. Make sure another app isn\'t using it.';
    }

    // Default: don't leak the raw exception text.
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
