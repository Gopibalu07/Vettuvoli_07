import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/providers/service_providers.dart';
import '../../../data/models/recording.dart';
import '../../../services/ffmpeg_service.dart';
import '../../dashboard/providers/recordings_provider.dart';

final processingControllerProvider =
    NotifierProvider<ProcessingController, ProcessingState>(
  ProcessingController.new,
);

class ProcessingState {
  const ProcessingState({this.activeId});

  /// Id of the recording currently being cleaned (null when idle).
  final String? activeId;

  bool get busy => activeId != null;
}

/// Orchestrates: register audio -> clean it with FFmpeg -> save the result.
///
/// Lives for the whole app session, so processing keeps running if the user
/// leaves the preview screen.
class ProcessingController extends Notifier<ProcessingState> {
  static const Uuid _uuid = Uuid();

  @override
  ProcessingState build() => const ProcessingState();

  /// Registers an audio file that already lives in app storage.
  Future<Recording> ingest({
    required String path,
    required RecordingSource source,
    required String name,
  }) async {
    final durationMs =
        await ref.read(ffmpegServiceProvider).probeDurationMs(path);
    final recording = Recording(
      id: _uuid.v4(),
      name: name,
      originalPath: path,
      durationMs: durationMs,
      createdAt: DateTime.now(),
      source: source,
    );
    await ref.read(recordingRepositoryProvider).insert(recording);
    await ref.read(recordingsProvider.notifier).refresh();
    return recording;
  }

  /// Lets the user pick an audio/video file and registers a copy of it.
  /// Returns null if the user cancelled the picker.
  Future<Recording?> importFile() async {
    final storage = ref.read(fileStorageServiceProvider);
    final picked = await storage.pickMediaFile();
    if (picked == null) return null;
    final copiedPath = await storage.copyIntoApp(picked.path);
    return ingest(
      path: copiedPath,
      source: RecordingSource.imported,
      name: picked.name,
    );
  }

  /// Removes background noise from [recording] and updates its database row.
  Future<void> process(
    Recording recording, {
    NoiseReductionLevel level = NoiseReductionLevel.standard,
  }) async {
    if (state.busy) return;

    final repo = ref.read(recordingRepositoryProvider);
    final storage = ref.read(fileStorageServiceProvider);
    final ffmpeg = ref.read(ffmpegServiceProvider);
    final list = ref.read(recordingsProvider.notifier);

    state = ProcessingState(activeId: recording.id);

    var current = recording.copyWith(
      status: ProcessingStatus.processing,
      clearError: true,
    );
    await repo.update(current);
    await list.refresh();

    try {
      final outputPath = await storage.newProcessedPath(recording.id);
      await ffmpeg.reduceNoise(
        inputPath: recording.originalPath,
        outputPath: outputPath,
        level: level,
      );
      // Success: drop the previous cleaned file, if any.
      await storage.deleteIfExists(recording.processedPath);
      current = current.copyWith(
        status: ProcessingStatus.done,
        processedPath: outputPath,
      );
    } on ProcessingCancelledException {
      current = current.copyWith(
        status: recording.hasProcessed
            ? ProcessingStatus.done
            : ProcessingStatus.pending,
      );
    } on AppException catch (e) {
      current = current.copyWith(
        status: ProcessingStatus.failed,
        errorMessage: e.message,
      );
    } catch (e) {
      current = current.copyWith(
        status: ProcessingStatus.failed,
        errorMessage: 'Unexpected error: $e',
      );
    }

    await repo.update(current);
    await list.refresh();
    state = const ProcessingState();
  }

  /// Cancels the running FFmpeg job (if any).
  Future<void> cancel() => ref.read(ffmpegServiceProvider).cancel();
}
