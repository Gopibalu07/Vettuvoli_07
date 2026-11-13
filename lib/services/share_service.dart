import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

/// Opens the system share sheet (WhatsApp, Instagram, Telegram, Drive, ...).
class ShareService {
  Future<void> shareAudio(String path, {String? text}) async {
    await Share.shareXFiles(
      [XFile(path, mimeType: _mimeFor(path))],
      text: text,
    );
  }

  String _mimeFor(String path) {
    switch (p.extension(path).toLowerCase()) {
      case '.m4a':
      case '.aac':
        return 'audio/mp4';
      case '.wav':
        return 'audio/wav';
      case '.mp3':
        return 'audio/mpeg';
      default:
        return 'audio/*';
    }
  }
}
