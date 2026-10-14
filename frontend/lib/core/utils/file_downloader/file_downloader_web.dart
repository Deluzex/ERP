// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';

Future<void> downloadPdfFile(Uint8List bytes, String fileName) async {
  final mimeType = fileName.endsWith('.csv')
      ? 'text/csv'
      : (fileName.endsWith('.txt') ? 'text/plain' : 'application/pdf');
  final blob = html.Blob([bytes], mimeType);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', fileName)
    ..click();
  html.Url.revokeObjectUrl(url);
}
