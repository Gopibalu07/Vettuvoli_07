import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/service_providers.dart';
import '../../../core/utils/format_utils.dart';
import '../providers/record_controller.dart';
import 'level_meter.dart';

/// Record from the microphone with pause / resume / stop / discard.
class RecordScreen extends ConsumerWidget {
  const RecordScreen({super.key});

  Future<bool> _confirmDiscard(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard recording?'),
        content: const Text('The audio recorded so far will be deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep recording'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _stop(BuildContext context, WidgetRef ref) async {
    final recording = await ref.read(recordControllerProvider.notifier).stop();
    if (recording != null && context.mounted) {
      // Replace this screen so "back" from the preview returns to the dashboard.
      context.pushReplacement('/preview/${recording.id}');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final state = ref.watch(recordControllerProvider);
    final controller = ref.read(recordControllerProvider.notifier);

    final isRecording = state.status == RecordStatus.recording;
    final isPaused = state.status == RecordStatus.paused;
    final isSaving = state.status == RecordStatus.saving;

    return PopScope(
      canPop: !state.isActive && !isSaving,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || isSaving) return;
        final discard = await _confirmDiscard(context);
        if (discard) {
          await controller.cancel();
          if (context.mounted) context.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Record Audio')),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Spacer(),
                Text(
                  formatDuration(state.elapsed),
                  style: theme.textTheme.displayLarge?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  switch (state.status) {
                    RecordStatus.idle => 'Tap the mic to start',
                    RecordStatus.recording => 'Recording…',
                    RecordStatus.paused => 'Paused',
                    RecordStatus.saving => 'Saving…',
                  },
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 32),
                LevelMeter(levels: state.levels),
                if (state.error != null) ...[
                  const SizedBox(height: 16),
                  _ErrorBanner(
                    message: state.error!,
                    onOpenSettings: () =>
                        ref.read(permissionServiceProvider).openSettings(),
                  ),
                ],
                const Spacer(),
                if (state.status == RecordStatus.idle)
                  _BigMicButton(
                    icon: Icons.mic,
                    color: scheme.primary,
                    iconColor: scheme.onPrimary,
                    onPressed: controller.start,
                  )
                else if (isSaving)
                  const CircularProgressIndicator()
                else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _RoundAction(
                        icon: Icons.delete_outline,
                        label: 'Discard',
                        onPressed: () async {
                          if (await _confirmDiscard(context)) {
                            await controller.cancel();
                            if (context.mounted) context.pop();
                          }
                        },
                      ),
                      _BigMicButton(
                        icon: isPaused ? Icons.mic : Icons.pause,
                        color: scheme.primary,
                        iconColor: scheme.onPrimary,
                        onPressed:
                            isRecording ? controller.pause : controller.resume,
                      ),
                      _RoundAction(
                        icon: Icons.stop_rounded,
                        label: 'Done',
                        filled: true,
                        onPressed: () => _stop(context, ref),
                      ),
                    ],
                  ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BigMicButton extends StatelessWidget {
  const _BigMicButton({
    required this.icon,
    required this.color,
    required this.iconColor,
    required this.onPressed,
  });

  final IconData icon;
  final Color color;
  final Color iconColor;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      shape: const CircleBorder(),
      elevation: 3,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox(
          width: 88,
          height: 88,
          child: Icon(icon, size: 40, color: iconColor),
        ),
      ),
    );
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.filled = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        filled
            ? IconButton.filled(
                onPressed: onPressed,
                iconSize: 32,
                icon: Icon(icon),
              )
            : IconButton.filledTonal(
                onPressed: onPressed,
                iconSize: 32,
                icon: Icon(icon),
              ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onOpenSettings});

  final String message;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isPermission = message.toLowerCase().contains('permission');
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: scheme.onErrorContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: scheme.onErrorContainer),
            ),
          ),
          if (isPermission)
            TextButton(
              onPressed: onOpenSettings,
              child: const Text('Settings'),
            ),
        ],
      ),
    );
  }
}
