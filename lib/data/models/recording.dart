import 'package:equatable/equatable.dart';

/// Lifecycle of the noise-removal step for one recording.
enum ProcessingStatus { pending, processing, done, failed }

/// Where the audio came from.
enum RecordingSource { recorded, imported }

/// Metadata for one recording. The audio itself lives on disk; this row only
/// stores the paths and display information.
class Recording extends Equatable {
  const Recording({
    required this.id,
    required this.name,
    required this.originalPath,
    required this.durationMs,
    required this.createdAt,
    required this.source,
    this.processedPath,
    this.status = ProcessingStatus.pending,
    this.errorMessage,
  });

  final String id;
  final String name;
  final String originalPath;
  final String? processedPath;
  final int durationMs;
  final DateTime createdAt;
  final ProcessingStatus status;
  final RecordingSource source;
  final String? errorMessage;

  Duration get duration => Duration(milliseconds: durationMs);
  bool get hasProcessed => processedPath != null;

  Recording copyWith({
    String? name,
    String? processedPath,
    int? durationMs,
    ProcessingStatus? status,
    String? errorMessage,
    bool clearError = false,
  }) {
    return Recording(
      id: id,
      name: name ?? this.name,
      originalPath: originalPath,
      processedPath: processedPath ?? this.processedPath,
      durationMs: durationMs ?? this.durationMs,
      createdAt: createdAt,
      source: source,
      status: status ?? this.status,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'original_path': originalPath,
        'processed_path': processedPath,
        'duration_ms': durationMs,
        'created_at': createdAt.millisecondsSinceEpoch,
        'status': status.name,
        'source': source.name,
        'error_message': errorMessage,
      };

  factory Recording.fromMap(Map<String, Object?> map) {
    return Recording(
      id: map['id'] as String,
      name: map['name'] as String,
      originalPath: map['original_path'] as String,
      processedPath: map['processed_path'] as String?,
      durationMs: (map['duration_ms'] as num).toInt(),
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (map['created_at'] as num).toInt(),
      ),
      status: ProcessingStatus.values.firstWhere(
        (s) => s.name == map['status'],
        orElse: () => ProcessingStatus.pending,
      ),
      source: RecordingSource.values.firstWhere(
        (s) => s.name == map['source'],
        orElse: () => RecordingSource.recorded,
      ),
      errorMessage: map['error_message'] as String?,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        originalPath,
        processedPath,
        durationMs,
        createdAt,
        status,
        source,
        errorMessage,
      ];
}
