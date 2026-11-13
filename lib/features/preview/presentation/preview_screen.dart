import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/service_providers.dart';
import '../../../core/utils/format_utils.dart';
import '../../../core/widgets/status_chip.dart';
import '../../../data/models/recording.dart';
import '../../../services/audio_player_service.dart';
import '../../../services/ffmpeg_service.dart';
import '../../dashboard/providers/recordings_provider.dart';
import '../../processing/providers/processing_controller.dart';

/// Clean a recording, compare Before / After, then share or save it.
class PreviewScreen extends ConsumerStatefulWidget {
  const PreviewScreen({super.key, required this.recordingId});

  final String recordingId;

  @override
  ConsumerState<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends ConsumerState<PreviewScreen> {
  final AudioPlayerService _player = AudioPlayerService();
  final List<StreamSubscription<dynamic>> _subs = [];

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _playing = false;
  bool _showProcessed = false;
  String? _loadedPath;
  String? _playerError;
  NoiseReductionLevel _level = NoiseReductionLevel.standard;

  @override
  void initState() {
    super.initState();

    _subs.add(_player.positionStream.listen((p) {
      if (mounted) setState(() => _position = p);
    }));
    _subs.add(_player.durationStream.listen((d) {
      if (mounted && d != null) setState(() => _duration = d);
    }));
    _subs.add(_player.isPlayingStream.listen((v) {
      if (mounted) setState(() => _playing = v);
    }));

    final recording = ref.read(recordingByIdProvider(widget.recordingId));
    if (recording != null) {
      _showProcessed = recording.hasProcessed;
      unawaited(_syncSource(recording));
    }
  }

  @override
  void dispose() {
    for (final sub in _subs) {
      sub.cancel();
    }
    _player.dispose();
    super.dispose();
  }

  /// Loads the right file (original or cleaned) into the player, keeping the
  /// current position and play/pause state so A/B switching is seamless.
  Future<void> _syncSource(Recording recording) async {
    final path = (_showProcessed && recording.processedPath != null)
        ? recording.processedPath!
        : recording.originalPath;
    if (path == _loadedPath) return;

    final wasPlaying = _player.isPlaying;
    final resumeAt = _loadedPath == null ? Duration.zero : _player.position;

    try {
      _loadedPath = path;
      final duration = await _player.load(path, initialPosition: resumeAt);
      if (!mounted) return;
      setState(() {
        _playerError = null;
        if (duration != null) _duration = duration;
      });
      if (wasPlaying) _player.play();
    } catch (_) {
      _loadedPath = null;
      if (mounted) setState(() => _playerError = 'Could not play this file.');
    }
  }

  void _setShowProcessed(bool value) {
    final recording = ref.read(recordingByIdProvider(widget.recordingId));
    if (recording == null) return;
    setState(() => _showProcessed = value);
    unawaited(_syncSource(recording));
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _share(Recording recording) async {
    final path = recording.processedPath;
    if (path == null) return;
    try {
      await ref.read(shareServiceProvider).shareAudio(
            path,
            text: 'Cleaned with VettuVoli',
          );
    } catch (e) {
      _snack('Could not share: $e');
    }
  }

  Future<void> _saveToDevice(Recording recording) async {
    final path = recording.processedPath;
    if (path == null) return;
    try {
      final saved = await ref
          .read(fileStorageServiceProvider)
          .saveToDevice(path, '${sanitizeFileName(recording.name)}_clean.m4a');
      if (saved != null) _snack('Saved to your device.');
    } catch (e) {
      _snack('Could not save: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final recording = ref.watch(recordingByIdProvider(widget.recordingId));
    final processing = ref.watch(processingControllerProvider);

    // When cleaning finishes, jump straight to the cleaned version.
    ref.listen<Recording?>(recordingByIdProvider(widget.recordingId),
        (previous, next) {
      if (next == null) return;
      if (next.processedPath != null &&
          previous?.processedPath != next.processedPath) {
        setState(() => _showProcessed = true);
        unawaited(_syncSource(next));
      }
    });

    if (recording == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Recording not found.')),
      );
    }

    final isBusy = recording.status == ProcessingStatus.processing ||
        processing.activeId == recording.id;
    final hasProcessed = recording.hasProcessed;

    return Scaffold(
      appBar: AppBar(title: const Text('Preview')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: [
          // Header
          Text(recording.name, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 6),
          Row(
            children: [
              StatusChip(status: recording.status),
              const SizedBox(width: 10),
              Text(
                '${formatDateTime(recording.createdAt)}  ·  '
                '${formatDuration(recording.duration)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Before / After toggle
          if (hasProcessed) ...[
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<bool>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: false,
                    icon: Icon(Icons.volume_up_outlined),
                    label: Text('Before'),
                  ),
                  ButtonSegment(
                    value: true,
                    icon: Icon(Icons.auto_awesome),
                    label: Text('After'),
                  ),
                ],
                selected: {_showProcessed},
                onSelectionChanged: (selection) =>
                    _setShowProcessed(selection.first),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Player
          _PlayerCard(
            title: hasProcessed
                ? (_showProcessed ? 'After (cleaned)' : 'Before (original)')
                : 'Original',
            position: _position,
            duration: _duration,
            playing: _playing,
            error: _playerError,
            onTogglePlay: _player.togglePlay,
            onSeek: (position) => _player.seek(position),
          ),
          const SizedBox(height: 16),

          // Noise removal controls
          _CleanCard(
            level: _level,
            onLevelChanged: (value) => setState(() => _level = value),
            isBusy: isBusy,
            hasProcessed: hasProcessed,
            errorMessage: recording.status == ProcessingStatus.failed
                ? recording.errorMessage
                : null,
            onClean: () => ref
                .read(processingControllerProvider.notifier)
                .process(recording, level: _level),
            onCancel: () =>
                ref.read(processingControllerProvider.notifier).cancel(),
          ),

          // Export
          if (hasProcessed && !isBusy) ...[
            const SizedBox(height: 24),
            Text('Export', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => _share(recording),
              icon: const Icon(Icons.share),
              label: const Text('Share (WhatsApp, Instagram…)'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => _saveToDevice(recording),
              icon: const Icon(Icons.download),
              label: const Text('Save to device'),
            ),
          ],
        ],
      ),
    );
  }
}

class _PlayerCard extends StatelessWidget {
  const _PlayerCard({
    required this.title,
    required this.position,
    required this.duration,
    required this.playing,
    required this.onTogglePlay,
    required this.onSeek,
    this.error,
  });

  final String title;
  final Duration position;
  final Duration duration;
  final bool playing;
  final String? error;
  final VoidCallback onTogglePlay;
  final ValueChanged<Duration> onSeek;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxMs = math.max(duration.inMilliseconds, 1);
    final valueMs = position.inMilliseconds.clamp(0, maxMs).toDouble();

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          children: [
            Text(title, style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            Slider(
              value: valueMs,
              max: maxMs.toDouble(),
              onChanged: (v) => onSeek(Duration(milliseconds: v.round())),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(formatDuration(position)),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(formatDuration(duration)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            IconButton.filled(
              iconSize: 36,
              onPressed: onTogglePlay,
              icon: Icon(playing ? Icons.pause : Icons.play_arrow),
            ),
            if (error != null) ...[
              const SizedBox(height: 8),
              Text(
                error!,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CleanCard extends StatelessWidget {
  const _CleanCard({
    required this.level,
    required this.onLevelChanged,
    required this.isBusy,
    required this.hasProcessed,
    required this.onClean,
    required this.onCancel,
    this.errorMessage,
  });

  final NoiseReductionLevel level;
  final ValueChanged<NoiseReductionLevel> onLevelChanged;
  final bool isBusy;
  final bool hasProcessed;
  final String? errorMessage;
  final VoidCallback onClean;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Background noise removal', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            SegmentedButton<NoiseReductionLevel>(
              showSelectedIcon: false,
              segments: [
                for (final l in NoiseReductionLevel.values)
                  ButtonSegment(value: l, label: Text(l.label)),
              ],
              selected: {level},
              onSelectionChanged:
                  isBusy ? null : (selection) => onLevelChanged(selection.first),
            ),
            const SizedBox(height: 8),
            Text(
              level.description,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            if (isBusy) ...[
              const LinearProgressIndicator(),
              const SizedBox(height: 10),
              Text(
                'Cleaning on your device… keep the app open.',
                style: theme.textTheme.bodySmall,
              ),
              TextButton(onPressed: onCancel, child: const Text('Cancel')),
            ] else
              FilledButton.icon(
                onPressed: onClean,
                icon: const Icon(Icons.graphic_eq),
                label: Text(
                  hasProcessed ? 'Clean again' : 'Remove background noise',
                ),
              ),
            if (errorMessage != null) ...[
              const SizedBox(height: 10),
              Text(
                errorMessage!,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
