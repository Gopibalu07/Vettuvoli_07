
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/constants/app_constants.dart';
import '../core/errors/app_exception.dart';

class FileStorageService {
  Future<Directory> _subDir(String name) async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, name));

    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    return dir;
  }

  Future<String> newRecordingPath() async {
    final dir = await _subDir(AppConstants.recordingsDir);
    final stamp = DateTime.now().millisecondsSinceEpoch;
    return p.join(dir.path, 'rec_$stamp.wav');
  }

  Future<String> newProcessedPath(String recordingId) async {
    final dir = await _subDir(AppConstants.processedDir);
    final stamp = DateTime.now().millisecondsSinceEpoch;

    return p.join(dir.path, '${recordingId}_clean_$stamp.m4a');
  }

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
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // Best effort deletion.
    }
  }

  Future<({String path, String name})?> pickMediaFile() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: [
        ...AppConstants.audioExtensions,
        ...AppConstants.videoExtensions,
      ],
    );

    if (file == null) return null;

    final String? path = file.path;

    if (path == null) return null;

    return (
      path: path,
      name: p.basenameWithoutExtension(file.name),
    );
  }

  Future<String?> saveToDevice(
    String sourcePath,
    String fileName,
  ) async {
    final bytes = await File(sourcePath).readAsBytes();

    final result = await FilePicker.saveFile(
      dialogTitle: 'Save cleaned audio',
      fileName: fileName,
      bytes: bytes,
    );

    return result?.toString();
  }
}
