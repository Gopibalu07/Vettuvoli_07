import 'package:intl/intl.dart';

/// Formats a duration as `m:ss` or `h:mm:ss`.
String formatDuration(Duration d) {
  final totalSeconds = d.inSeconds < 0 ? 0 : d.inSeconds;
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;
  final ss = seconds.toString().padLeft(2, '0');
  if (hours > 0) {
    return '$hours:${minutes.toString().padLeft(2, '0')}:$ss';
  }
  return '$minutes:$ss';
}

/// Formats a date like "Nov 13, 2026, 4:24 PM".
String formatDateTime(DateTime date) => DateFormat.yMMMd().add_jm().format(date);

/// Removes characters that are unsafe in file names.
String sanitizeFileName(String name) {
  final cleaned = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
  return cleaned.isEmpty ? 'audio' : cleaned;
}
