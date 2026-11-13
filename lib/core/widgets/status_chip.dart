import 'package:flutter/material.dart';

import '../../data/models/recording.dart';

/// Small coloured label showing a recording's processing status.
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status});

  final ProcessingStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final (String label, Color bg, Color fg) = switch (status) {
      ProcessingStatus.pending => (
          'Not cleaned',
          scheme.surfaceContainerHighest,
          scheme.onSurfaceVariant,
        ),
      ProcessingStatus.processing => (
          'Cleaning…',
          scheme.tertiaryContainer,
          scheme.onTertiaryContainer,
        ),
      ProcessingStatus.done => (
          'Cleaned',
          scheme.primaryContainer,
          scheme.onPrimaryContainer,
        ),
      ProcessingStatus.failed => (
          'Failed',
          scheme.errorContainer,
          scheme.onErrorContainer,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: fg),
      ),
    );
  }
}
