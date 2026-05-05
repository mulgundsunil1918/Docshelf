import 'dart:io';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../models/document.dart';
import 'friendly_error.dart';

/// Shares [doc] through the native Android share sheet so the user can
/// pick whichever app they want (WhatsApp, Gmail, Drive, Bluetooth…).
///
/// Used by the inline share IconButton on every file-row widget. All
/// errors are routed through `FriendlyError` so we never expose raw
/// platform-channel exceptions in a SnackBar.
Future<void> shareDocument(BuildContext context, Document doc) async {
  try {
    final file = File(doc.path);
    if (!file.existsSync()) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("That file has been moved or deleted."),
        ),
      );
      return;
    }
    await Share.shareXFiles(
      [XFile(doc.path)],
      subject: doc.name,
    );
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(FriendlyError.from(e))),
    );
  }
}
