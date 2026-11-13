import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../data/models/recording.dart';
import '../../processing/providers/processing_controller.dart';
import '../providers/recordings_provider.dart';
import 'recording_tile.dart';

/// Home screen: Record / Import buttons and the list of recordings.
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool _importing = false;

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _import() async {
    setState(() => _importing = true);
    try {
      final recording =
          await ref.read(processingControllerProvider.notifier).importFile();
      if (recording != null && mounted) {
        context.push('/preview/${recording.id}');
      }
    } on AppException catch (e) {
      _snack(e.message);
    } catch (e) {
      _snack('Import failed: $e');
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _rename(Recording recording) async {
    final controller = TextEditingController(text: recording.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename recording'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          onSubmitted: (value) => Navigator.of(context).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (newName == null) return;
    await ref.read(recordingsProvider.notifier).rename(recording, newName);
  }

  Future<void> _delete(Recording recording) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete recording?'),
        content: Text(
          '"${recording.name}" and its cleaned version will be removed from '
          'this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(recordingsProvider.notifier).delete(recording);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final recordings = ref.watch(recordingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'VettuVoli',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Studio-quality audio,\nentirely on your phone.',
                  style: theme.textTheme.headlineSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  'Works offline. Your audio never leaves your device.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _importing ? null : () => context.push('/record'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 64),
                    textStyle: theme.textTheme.titleMedium,
                  ),
                  icon: const Icon(Icons.mic, size: 28),
                  label: const Text('Record Audio'),
                ),
                const SizedBox(height: 12),
                FilledButton.tonalIcon(
                  onPressed: _importing ? null : _import,
                  icon: _importing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.upload_file),
                  label: const Text('Import File'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Text('Your recordings', style: theme.textTheme.titleMedium),
          ),
          Expanded(
            child: recordings.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => EmptyState(
                icon: Icons.error_outline,
                title: 'Could not load recordings',
                message: '$error',
              ),
              data: (items) {
                if (items.isEmpty) {
                  return const EmptyState(
                    icon: Icons.graphic_eq,
                    title: 'No recordings yet',
                    message:
                        'Record something or import an audio or video file to '
                        'remove its background noise.',
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final recording = items[index];
                    return RecordingTile(
                      recording: recording,
                      onTap: () => context.push('/preview/${recording.id}'),
                      onMenuAction: (action) {
                        switch (action) {
                          case RecordingMenuAction.rename:
                            _rename(recording);
                          case RecordingMenuAction.delete:
                            _delete(recording);
                        }
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
