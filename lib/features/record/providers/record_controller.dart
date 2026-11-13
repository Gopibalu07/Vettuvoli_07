import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/providers/service_providers.dart';
import '../../../data/models/recording.dart';
import '../../../services/audio_recorder_service.dart';
import '../../processing/providers/processing_controller.dart';

final recordControllerProvider =
    NotifierProvider.autoDispose<RecordController, RecordState>(
  RecordController.new,
);

enum RecordStatus { idle, recording, paused, saving }

class RecordState {
  const RecordState({
    this.status = RecordStatus.idle,
    this.elapsed = Duration.zero,
    this.levels = const <double>[],
    this.error,
  });

  final RecordStatus status;
  final Duration elapsed;

  /// Recent input levels (0..1) for the live level meter.
  final List<double> levels;
  final String? error;

  bool get isActive =>
      status == RecordStatus.recording || status == RecordStatus.paused;

  RecordState copyWith({
    RecordStatus? status,
    Duration? elapsed,
    List<double>? levels,
    String? error,
    bool clearError = false,
  }) {
    return RecordState(
      status: status ?? this.status,
      elapsed: elapsed ?? this.elapsed,
      levels: levels ?? this.levels,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class RecordController extends AutoDisposeNotifier<RecordState> {
  static const int _maxLevels = 48;

  late AudioRecorderService _recorder;
  Timer? _ticker;
  StreamSubscription<double>? _levelSub;
  String? _path;
  Duration _accumulated = Duration.zero;
  DateTime? _resumedAt;
  bool _micOpen = false;

  @override
  RecordState build() {
    _recorder = ref.watch(audioRecorderServiceProvider);
    ref.onDispose(() {
      _ticker?.cancel();
      _levelSub?.cancel();
      // Leaving the screen mid-recording discards the partial file.
      if (_micOpen) {
        _recorder.cancel().catchError((Object _) {});
      }
    });
    return const RecordState();
  }

  Duration _currentElapsed() {
    final resumedAt = _resumedAt;
    if (resumedAt == null) return _accumulated;
    return _accumulated + DateTime.now().difference(resumedAt);
  }

  Future<void> start() async {
    if (state.status != RecordStatus.idle) return;

    final granted = await ref.read(permissionServiceProvider).ensureMicrophone();
    if (!granted) {
      state = state.copyWith(
        error: 'Microphone permission is needed to record. '
            'You can enable it in your phone settings.',
      );
      return;
    }

    try {
      _path = await ref.read(fileStorageServiceProvider).newRecordingPath();
      await _recorder.start(_path!);
      _micOpen = true;
      _accumulated = Duration.zero;
      _resumedAt = DateTime.now();

      _levelSub = _recorder.amplitudeStream().listen(_onLevel);
      _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) {
        if (state.status == RecordStatus.recording) {
          state = state.copyWith(elapsed: _currentElapsed());
        }
      });

      state = const RecordState(status: RecordStatus.recording);
    } catch (e) {
      _micOpen = false;
      state = state.copyWith(error: 'Could not start recording: $e');
    }
  }

  void _onLevel(double level) {
    if (state.status != RecordStatus.recording) return;
    final next = [...state.levels, level];
    if (next.length > _maxLevels) next.removeRange(0, next.length - _maxLevels);
    state = state.copyWith(levels: next);
  }

  Future<void> pause() async {
    if (state.status != RecordStatus.recording) return;
    await _recorder.pause();
    _accumulated = _currentElapsed();
    _resumedAt = null;
    state = state.copyWith(status: RecordStatus.paused, elapsed: _accumulated);
  }

  Future<void> resume() async {
    if (state.status != RecordStatus.paused) return;
    await _recorder.resume();
    _resumedAt = DateTime.now();
    state = state.copyWith(status: RecordStatus.recording);
  }

  /// Stops, saves and registers the recording. Returns it, or null if the
  /// recording was too short or saving failed (see [RecordState.error]).
  Future<Recording?> stop() async {
    if (!state.isActive) return null;

    final total = _currentElapsed();
    state = state.copyWith(status: RecordStatus.saving);
    _ticker?.cancel();
    await _levelSub?.cancel();

    try {
      final savedPath = await _recorder.stop();
      _micOpen = false;

      if (savedPath == null) {
        throw StateError('No audio was captured.');
      }

      if (total < AppConstants.minRecordingLength) {
        await ref.read(fileStorageServiceProvider).deleteIfExists(savedPath);
        state = const RecordState(error: 'Recording was too short. Try again.');
        return null;
      }

      final name =
          'Recording ${DateFormat('d MMM, h:mm a').format(DateTime.now())}';
      final recording =
          await ref.read(processingControllerProvider.notifier).ingest(
                path: savedPath,
                source: RecordingSource.recorded,
                name: name,
              );
      state = const RecordState();
      return recording;
    } catch (e) {
      _micOpen = false;
      state = RecordState(error: 'Could not save the recording: $e');
      return null;
    }
  }

  /// Stops and throws the recording away.
  Future<void> cancel() async {
    _ticker?.cancel();
    await _levelSub?.cancel();
    if (_micOpen) {
      await _recorder.cancel();
      _micOpen = false;
    }
    state = const RecordState();
  }
}
