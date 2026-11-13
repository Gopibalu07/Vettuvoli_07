import 'dart:io';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';

import '../core/errors/app_exception.dart';

/// How aggressively background noise is removed.
enum NoiseReductionLevel {
  light(
    label: 'Light',
    description: 'Gentle clean-up. Keeps the most natural sound.',
    reductionDb: 10,
    noiseFloorDb: -35,
    gateThreshold: 0.01,
  ),
  standard(
    label: 'Standard',
    description: 'Balanced. Good for fans, hum and room noise.',
    reductionDb: 18,
    noiseFloorDb: -30,
    gateThreshold: 0.02,
  ),
  strong(
    label: 'Strong',
    description: 'Maximum clean-up for very noisy places. May sound processed.',
    reductionDb: 30,
    noiseFloorDb: -25,
    gateThreshold: 0.04,
  );

  const NoiseReductionLevel({
    required this.label,
    required this.description,
    required this.reductionDb,
    required this.noiseFloorDb,
    required this.gateThreshold,
  });

  final String label;
  final String description;

  /// afftdn `nr`: how many dB the noise is reduced by.
  final int reductionDb;

  /// afftdn `nf`: estimated noise floor in dB.
  final int noiseFloorDb;

  /// agate `threshold`: linear level below which the gate closes.
  final double gateThreshold;
}

/// Runs FFmpeg locally on the device. No network access is ever used.
class FfmpegService {
  /// Builds the audio filter chain (pure function, easy to unit test):
  ///
  /// 1. highpass  - removes rumble / wind / handling noise below 80 Hz
  /// 2. afftdn    - FFT-based broadband noise reduction (fans, hiss, AC hum)
  /// 3. agate     - gates the quiet gaps between words
  /// 4. lowpass   - removes ultrasonic hiss above 16 kHz
  /// 5. loudnorm  - normalises loudness to -16 LUFS (streaming standard)
  static String buildFilterChain(NoiseReductionLevel level) {
    return [
      'highpass=f=80',
      'afftdn=nr=${level.reductionDb}:nf=${level.noiseFloorDb}:tn=1',
      'agate=threshold=${level.gateThreshold}:ratio=2:attack=10:release=250',
      'lowpass=f=16000',
      'loudnorm=I=-16:TP=-1.5:LRA=11',
    ].join(',');
  }

  /// Cleans [inputPath] (any audio or video file) and writes an AAC .m4a file
  /// to [outputPath]. Returns [outputPath] on success.
  ///
  /// Throws [ProcessingCancelledException] if [cancel] was called, or
  /// [AppException] with a readable message on failure.
  Future<String> reduceNoise({
    required String inputPath,
    required String outputPath,
    NoiseReductionLevel level = NoiseReductionLevel.standard,
  }) async {
    if (!await File(inputPath).exists()) {
      throw const AppException('The original audio file could not be found.');
    }

    final args = <String>[
      '-y',
      '-i', inputPath,
      '-vn', // drop any video stream (imported video files)
      '-map', '0:a:0', // first audio stream only
      '-af', buildFilterChain(level),
      '-ar', '44100',
      '-c:a', 'aac',
      '-b:a', '192k',
      outputPath,
    ];

    final session = await FFmpegKit.executeWithArguments(args);
    final returnCode = await session.getReturnCode();

    if (ReturnCode.isSuccess(returnCode)) {
      final out = File(outputPath);
      if (await out.exists() && await out.length() > 0) return outputPath;
      throw const AppException('Processing finished but produced no audio.');
    }

    // Clean up a partial output file.
    final partial = File(outputPath);
    if (await partial.exists()) await partial.delete();

    if (ReturnCode.isCancel(returnCode)) {
      throw const ProcessingCancelledException();
    }

    final logs = (await session.getAllLogsAsString()) ?? '';
    if (logs.contains('matches no streams') ||
        logs.contains('does not contain any stream')) {
      throw const AppException('No audio track was found in this file.');
    }
    throw AppException(
      'Noise removal failed (code ${returnCode?.getValue()}).',
      logs.isEmpty ? null : logs.split('\n').takeLast(5).join('\n'),
    );
  }

  /// Stops any running FFmpeg session.
  Future<void> cancel() => FFmpegKit.cancel();

  /// Reads the media duration with ffprobe. Returns 0 if it can't be read.
  Future<int> probeDurationMs(String path) async {
    try {
      final session = await FFprobeKit.getMediaInformation(path);
      final info = session.getMediaInformation();
      final seconds = double.tryParse(info?.getDuration() ?? '');
      return seconds == null ? 0 : (seconds * 1000).round();
    } catch (_) {
      return 0;
    }
  }
}

extension _TakeLast<T> on Iterable<T> {
  Iterable<T> takeLast(int n) {
    final list = toList();
    return list.length <= n ? list : list.sublist(list.length - n);
  }
}
