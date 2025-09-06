// Web-specific utilities
import 'dart:html' as html;

void downloadFile(List<int> bytes, String filename) {
  final blob = html.Blob([bytes]);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();
  
  // Clean up the blob URL
  html.Url.revokeObjectUrl(url);
}