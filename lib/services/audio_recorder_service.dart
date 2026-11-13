import 'package:record/record.dart';

import '../core/constants/app_constants.dart';

/// Records from the device microphone to an uncompressed WAV file.
///
/// Platform processing (auto gain, echo cancel, noise suppress) is switched
/// off on purpose: we want the raw signal so our own FFmpeg pipeline can do the
/// noise removal with full control.
class AudioRecorderService {
  final AudioRecorder _recorder = AudioRecorder();

  /// Starts recording to [path]. The caller must have mic permission.
  Future<void> start(String path) {
    return _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: AppConstants.recordSampleRate,
        numChannels: AppConstants.recordChannels,
        autoGain: false,
        echoCancel: false,
        noiseSuppress: false,
      ),
      path: path,
    );
  }

  Future<void> pause() => _recorder.pause();

  Future<void> resume() => _recorder.resume();

  /// Stops recording and returns the saved file path (null if nothing saved).
  Future<String?> stop() => _recorder.stop();

  /// Stops recording and deletes the partial file.
  Future<void> cancel() => _recorder.cancel();

  Future<bool> isRecording() => _recorder.isRecording();

  /// Live input level, normalised to 0.0 (silence) .. 1.0 (loud).
  Stream<double> amplitudeStream({
    Duration interval = const Duration(milliseconds: 80),
  }) {
    return _recorder.onAmplitudeChanged(interval).map((amp) {
      // `current` is in dBFS (about -160..0). Treat -60 dB and below as silence.
      final normalised = (amp.current + 60) / 60;
      return normalised.clamp(0.0, 1.0).toDouble();
    });
  }

  Future<void> dispose() => _recorder.dispose();
}
