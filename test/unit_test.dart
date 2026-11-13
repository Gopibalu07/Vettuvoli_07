import 'package:flutter_test/flutter_test.dart';
import 'package:vettuvoli/core/utils/format_utils.dart';
import 'package:vettuvoli/data/models/recording.dart';
import 'package:vettuvoli/services/ffmpeg_service.dart';

void main() {
  group('FfmpegService.buildFilterChain', () {
    test('contains every stage in order', () {
      final chain = FfmpegService.buildFilterChain(NoiseReductionLevel.standard);
      final stages = chain.split(',');
      expect(stages.length, 5);
      expect(stages[0], startsWith('highpass'));
      expect(stages[1], startsWith('afftdn'));
      expect(stages[2], startsWith('agate'));
      expect(stages[3], startsWith('lowpass'));
      expect(stages[4], startsWith('loudnorm'));
    });

    test('stronger levels reduce more noise', () {
      expect(
        NoiseReductionLevel.strong.reductionDb,
        greaterThan(NoiseReductionLevel.light.reductionDb),
      );
      expect(
        FfmpegService.buildFilterChain(NoiseReductionLevel.strong),
        contains('nr=30'),
      );
    });
  });

  group('Recording', () {
    final recording = Recording(
      id: 'abc',
      name: 'Test',
      originalPath: '/a/b.wav',
      durationMs: 4200,
      createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
      source: RecordingSource.imported,
      status: ProcessingStatus.done,
      processedPath: '/a/b_clean.m4a',
    );

    test('survives a toMap / fromMap round trip', () {
      expect(Recording.fromMap(recording.toMap()), recording);
    });

    test('copyWith(clearError) removes the error', () {
      final failed = recording.copyWith(
        status: ProcessingStatus.failed,
        errorMessage: 'boom',
      );
      expect(failed.errorMessage, 'boom');
      expect(failed.copyWith(clearError: true).errorMessage, isNull);
    });
  });

  group('format utils', () {
    test('formatDuration', () {
      expect(formatDuration(const Duration(seconds: 5)), '0:05');
      expect(formatDuration(const Duration(minutes: 2, seconds: 3)), '2:03');
      expect(formatDuration(const Duration(hours: 1, minutes: 1)), '1:01:00');
    });

    test('sanitizeFileName', () {
      expect(sanitizeFileName('a/b:c'), 'a_b_c');
      expect(sanitizeFileName('   '), 'audio');
    });
  });
}
