// Web-only PDF download handler
// This file is only compiled for web builds
import 'dart:html' as html;

/// Downloads a PDF directly in the browser by creating a blob and triggering download
Future<void> downloadPdfOnWeb(List<int> pdfBytes, String fileName) async {
  final blob = html.Blob([pdfBytes], 'application/pdf');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', fileName)
    ..click();
  html.Url.revokeObjectUrl(url);
}
