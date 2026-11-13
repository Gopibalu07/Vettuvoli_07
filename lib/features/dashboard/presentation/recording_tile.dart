import 'package:flutter/material.dart';

import '../../../core/utils/format_utils.dart';
import '../../../core/widgets/status_chip.dart';
import '../../../data/models/recording.dart';

enum RecordingMenuAction { rename, delete }

/// One row in the dashboard list.
class RecordingTile extends StatelessWidget {
  const RecordingTile({
    super.key,
    required this.recording,
    required this.onTap,
    required this.onMenuAction,
  });

  final Recording recording;
  final VoidCallback onTap;
  final ValueChanged<RecordingMenuAction> onMenuAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isImported = recording.source == RecordingSource.imported;

    return Card(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: scheme.primaryContainer,
                foregroundColor: scheme.onPrimaryContainer,
                child: Icon(isImported ? Icons.folder_open : Icons.mic),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recording.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${formatDateTime(recording.createdAt)}  ·  '
                      '${formatDuration(recording.duration)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    StatusChip(status: recording.status),
                  ],
                ),
              ),
              PopupMenuButton<RecordingMenuAction>(
                onSelected: onMenuAction,
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: RecordingMenuAction.rename,
                    child: Text('Rename'),
                  ),
                  PopupMenuItem(
                    value: RecordingMenuAction.delete,
                    child: Text('Delete'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
