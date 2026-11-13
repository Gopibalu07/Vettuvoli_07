import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';

/// Wraps just_audio. One instance plays either the "before" or "after" file;
/// the preview screen swaps the source while keeping the playback position.
class AudioPlayerService {
  final AudioPlayer _player = AudioPlayer();
  bool _sessionConfigured = false;

  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;

  /// True only while audio is actually playing (false once it has finished).
  Stream<bool> get isPlayingStream => _player.playerStateStream.map(_isPlaying);

  bool get isPlaying => _isPlaying(_player.playerState);

  static bool _isPlaying(PlayerState s) =>
      s.playing && s.processingState != ProcessingState.completed;

  /// Loads a local file. Returns its duration when known.
  Future<Duration?> load(
    String path, {
    Duration initialPosition = Duration.zero,
  }) async {
    if (!_sessionConfigured) {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
      _sessionConfigured = true;
    }
    return _player.setFilePath(path, initialPosition: initialPosition);
  }

  Future<void> togglePlay() async {
    final state = _player.playerState;
    if (state.processingState == ProcessingState.completed) {
      await _player.seek(Duration.zero);
      unawaited(_player.play());
    } else if (state.playing) {
      await _player.pause();
    } else {
      unawaited(_player.play());
    }
  }

  void play() => unawaited(_player.play());

  Future<void> pause() => _player.pause();

  Future<void> seek(Duration position) => _player.seek(position);

  Duration get position => _player.position;

  Future<void> dispose() => _player.dispose();
}
