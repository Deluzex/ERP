import 'dart:typed_data';
import 'file_downloader_stub.dart'
    if (dart.library.html) 'file_downloader_web.dart' as platform_downloader;

class FileDownloader {
  static Future<void> downloadPdf(Uint8List bytes, String fileName) async {
    await platform_downloader.downloadPdfFile(bytes, fileName);
  }
}
