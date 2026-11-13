import 'package:flutter/material.dart';

/// Scrolling bar visualisation of recent input levels (0..1).
class LevelMeter extends StatelessWidget {
  const LevelMeter({
    super.key,
    required this.levels,
    this.barCount = 48,
    this.height = 96,
  });

  final List<double> levels;
  final int barCount;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _LevelPainter(
          levels: levels,
          barCount: barCount,
          color: Theme.of(context).colorScheme.primary,
          idleColor: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
    );
  }
}

class _LevelPainter extends CustomPainter {
  _LevelPainter({
    required this.levels,
    required this.barCount,
    required this.color,
    required this.idleColor,
  });

  final List<double> levels;
  final int barCount;
  final Color color;
  final Color idleColor;

  @override
  void paint(Canvas canvas, Size size) {
    final slot = size.width / barCount;
    final barWidth = slot * 0.6;
    final minBar = 4.0;
    final centreY = size.height / 2;

    // Right-align the newest samples; empty slots on the left stay as dots.
    final offset = barCount - levels.length;

    for (var i = 0; i < barCount; i++) {
      final index = i - offset;
      final hasValue = index >= 0 && index < levels.length;
      final level = hasValue ? levels[index] : 0.0;
      final barHeight = minBar + level * (size.height - minBar);

      final paint = Paint()
        ..color = hasValue ? color : idleColor
        ..strokeCap = StrokeCap.round;

      final x = slot * i + slot / 2;
      final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(x, centreY),
          width: barWidth,
          height: barHeight,
        ),
        Radius.circular(barWidth / 2),
      );
      canvas.drawRRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _LevelPainter old) =>
      old.levels != levels || old.color != color;
}
