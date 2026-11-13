import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/constants/app_constants.dart';
import '../core/errors/app_exception.dart';

/// Everything that touches the file system or the system file pickers.
class FileStorageService {
  Future<Directory> _subDir(String name) async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, name));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// A fresh path for a new microphone recording (.wav).
  Future<String> newRecordingPath() async {
    final dir = await _subDir(AppConstants.recordingsDir);
    final stamp = DateTime.now().millisecondsSinceEpoch;
    return p.join(dir.path, 'rec_$stamp.wav');
  }

  /// A unique path for a cleaned file (.m4a). A timestamp makes every run unique
  /// so the player never serves a stale cached file after "Clean again".
  Future<String> newProcessedPath(String recordingId) async {
    final dir = await _subDir(AppConstants.processedDir);
    final stamp = DateTime.now().millisecondsSinceEpoch;
    return p.join(dir.path, '${recordingId}_clean_$stamp.m4a');
  }

  /// Copies an imported file into app storage so it stays available even if the
  /// original is moved or deleted. Returns the new path.
  Future<String> copyIntoApp(String sourcePath) async {
    final source = File(sourcePath);
    if (!await source.exists()) {
      throw const AppException('The selected file could not be read.');
    }
    final dir = await _subDir(AppConstants.recordingsDir);
    final ext = p.extension(sourcePath);
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final target = p.join(dir.path, 'import_$stamp$ext');
    await source.copy(target);
    return target;
  }

  Future<void> deleteIfExists(String? path) async {
    if (path == null) return;
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {
      // Best effort: a leftover file must never crash the app.
    }
  }

  /// Opens the system picker for an audio or video file.
  /// Returns null if the user cancelled.
  Future<({String path, String name})?> pickMediaFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: [
        ...AppConstants.audioExtensions,
        ...AppConstants.videoExtensions,
      ],
      allowMultiple: false,
    );
    final file = result?.files.single;
    final path = file?.path;
    if (file == null || path == null) return null;
    return (path: path, name: p.basenameWithoutExtension(file.name));
  }

  /// Lets the user choose where to save [sourcePath] (system "Save as" dialog).
  /// Returns the saved location, or null if cancelled.
  Future<String?> saveToDevice(String sourcePath, String fileName) async {
    final bytes = await File(sourcePath).readAsBytes();
    return FilePicker.platform.saveFile(
      dialogTitle: 'Save cleaned audio',
      fileName: fileName,
      bytes: bytes, // required on Android and iOS
    );
  }
}
