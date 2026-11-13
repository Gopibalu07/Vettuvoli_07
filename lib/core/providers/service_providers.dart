import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/app_database.dart';
import '../../data/repositories/recording_repository.dart';
import '../../services/audio_recorder_service.dart';
import '../../services/ffmpeg_service.dart';
import '../../services/file_storage_service.dart';
import '../../services/permission_service.dart';
import '../../services/share_service.dart';

// Every service is exposed through a provider so tests can override it.

final appDatabaseProvider = Provider<AppDatabase>((ref) => AppDatabase());

final recordingRepositoryProvider = Provider<RecordingRepository>(
  (ref) => RecordingRepository(ref.watch(appDatabaseProvider)),
);

final permissionServiceProvider =
    Provider<PermissionService>((ref) => PermissionService());

final fileStorageServiceProvider =
    Provider<FileStorageService>((ref) => FileStorageService());

final ffmpegServiceProvider =
    Provider<FfmpegService>((ref) => FfmpegService());

final shareServiceProvider = Provider<ShareService>((ref) => ShareService());

/// Auto-disposed: the microphone is released when the record screen closes.
final audioRecorderServiceProvider =
    Provider.autoDispose<AudioRecorderService>((ref) {
  final service = AudioRecorderService();
  ref.onDispose(service.dispose);
  return service;
});
