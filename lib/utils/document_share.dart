import 'dart:io';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../models/document.dart';
import 'friendly_error.dart';

/// Shares [doc] via the native share sheet.
///
/// Pass the [BuildContext] of the share button so iOS can anchor the
/// share-sheet popover to the correct position (required on iOS — passing
/// a zero rect causes PlatformException sharePositionOrigin).
Future<void> shareDocument(BuildContext context, Document doc) async {
  try {
    final file = File(doc.path);
    if (!file.existsSync()) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("That file has been moved or deleted.")),
      );
      return;
    }

    // Derive the anchor rect from the tapped widget so iOS knows where
    // to draw the share-sheet popover arrow.
    final box = context.findRenderObject() as RenderBox?;
    final origin = box == null
        ? null
        : box.localToGlobal(Offset.zero) & box.size;

    await Share.shareXFiles(
      [XFile(doc.path)],
      subject: doc.name,
      sharePositionOrigin: origin,
    );
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(FriendlyError.from(e))),
    );
  }
}
