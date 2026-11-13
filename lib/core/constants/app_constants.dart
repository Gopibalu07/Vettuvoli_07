/// App-wide constants.
class AppConstants {
  AppConstants._();

  // Database
  static const String dbName = 'vettuvoli.db';
  static const int dbVersion = 1;
  static const String recordingsTable = 'recordings';

  // Recording quality: 48 kHz mono 16-bit PCM WAV (lossless, best for denoising).
  static const int recordSampleRate = 48000;
  static const int recordChannels = 1;

  // Folder names inside the app documents directory.
  static const String recordingsDir = 'recordings';
  static const String processedDir = 'processed';

  // Import filters.
  static const List<String> audioExtensions = [
    'mp3',
    'wav',
    'm4a',
    'aac',
    'ogg',
    'flac',
    'opus',
  ];
  static const List<String> videoExtensions = [
    'mp4',
    'mov',
    'mkv',
    'webm',
    '3gp',
  ];

  /// Recordings shorter than this are discarded as accidental taps.
  static const Duration minRecordingLength = Duration(seconds: 1);
}
