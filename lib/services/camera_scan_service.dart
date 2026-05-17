import 'dart:io';
import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

/// Wraps `cunning_document_scanner` (Google ML Kit Document Scanner on
/// Android, VisionKit on iOS).
///
/// What you get for free, all on-device, all offline:
///   - live edge detection in the camera viewfinder
///   - perspective correction (auto-rectifies skewed photos)
///   - light/B&W/colour enhance presets (the "Adobe Scan look")
///   - multi-page support — capture several pages in one session
///
/// We then stitch multi-page captures into a single PDF using the `pdf`
/// package, so the user ends up with one document, not N image files.
class CameraScanService {
  static final CameraScanService instance = CameraScanService._();
  CameraScanService._();

  /// Launch the native scanner UI. Returns the path of a single output
  /// file the rest of the app can save:
  ///   - 1 page captured  → returns the path of the JPG directly
  ///   - N pages captured → returns the path of a stitched PDF
  /// Returns null if the user cancelled.
  /// Throws [PlatformException] with code 'camera_permission_denied' if
  /// the user has denied camera access, or if the scanner is unavailable.
  Future<String?> scanDocument({int maxPages = 10}) async {
    // On iOS, VNDocumentCameraViewController requires camera permission.
    // Request it before launching so we can give a clear error if denied,
    // rather than letting VisionKit fail silently or crash.
    if (Platform.isIOS) {
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        throw PlatformException(
          code: 'camera_permission_denied',
          message: 'Camera access denied. Enable it in Settings → DocShelf.',
        );
      }
    }

    final pages = await CunningDocumentScanner.getPictures(
      noOfPages: maxPages,
      isGalleryImportAllowed: false,
    );
    if (pages == null || pages.isEmpty) return null;

    if (pages.length == 1) return pages.first;

    return _stitchToPdf(pages);
  }

  /// Combines a list of JPG paths into a single PDF in the app's temp
  /// directory. The caller is expected to copy the PDF into DocShelf's
  /// vault via `FileStorageService.storeDocument`, after which the temp
  /// PDF can be discarded.
  Future<String> _stitchToPdf(List<String> imagePaths) async {
    final doc = pw.Document();
    for (final pathStr in imagePaths) {
      final bytes = await File(pathStr).readAsBytes();
      final image = pw.MemoryImage(bytes);
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (_) => pw.Center(
            child: pw.Image(image, fit: pw.BoxFit.contain),
          ),
        ),
      );
    }
    final tmp = await getTemporaryDirectory();
    final fname =
        'Scan-${DateTime.now().millisecondsSinceEpoch}.pdf';
    final out = File(p.join(tmp.path, fname));
    final Uint8List pdfBytes = await doc.save();
    await out.writeAsBytes(pdfBytes);
    return out.path;
  }
}
