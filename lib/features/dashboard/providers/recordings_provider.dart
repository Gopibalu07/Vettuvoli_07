import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/service_providers.dart';
import '../../../data/models/recording.dart';

/// The list of all recordings shown on the dashboard.
final recordingsProvider =
    AsyncNotifierProvider<RecordingsNotifier, List<Recording>>(
  RecordingsNotifier.new,
);

/// One recording by id (null if it was deleted). Derived from the list so the
/// preview screen updates automatically while processing runs.
final recordingByIdProvider = Provider.family<Recording?, String>((ref, id) {
  final list = ref.watch(recordingsProvider).valueOrNull ?? const <Recording>[];
  for (final r in list) {
    if (r.id == id) return r;
  }
  return null;
});

class RecordingsNotifier extends AsyncNotifier<List<Recording>> {
  @override
  Future<List<Recording>> build() {
    return ref.watch(recordingRepositoryProvider).getAll();
  }

  /// Reloads from the database without flashing a loading spinner.
  Future<void> refresh() async {
    state = await AsyncValue.guard(
      () => ref.read(recordingRepositoryProvider).getAll(),
    );
  }

  Future<void> rename(Recording recording, String newName) async {
    final name = newName.trim();
    if (name.isEmpty || name == recording.name) return;
    await ref
        .read(recordingRepositoryProvider)
        .update(recording.copyWith(name: name));
    await refresh();
  }

  /// Deletes the database row and both audio files.
  Future<void> delete(Recording recording) async {
    final storage = ref.read(fileStorageServiceProvider);
    await storage.deleteIfExists(recording.originalPath);
    await storage.deleteIfExists(recording.processedPath);
    await ref.read(recordingRepositoryProvider).delete(recording.id);
    await refresh();
  }
}
