import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/waveform_style.dart';

/// High-performance 60fps Flutter Canvas CustomPainter for audio waveforms.
/// Operates universally across Android, Web, and desktop without native plugins.
class SvfWaveformPainter extends CustomPainter {
  final List<double> samples;
  final double playbackPosition;
  final SvfWaveformStyle style;
  final bool showScrubber;

  SvfWaveformPainter({
    required this.samples,
    required this.playbackPosition,
    required this.style,
    this.showScrubber = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final barPitch = style.barWidth + style.barSpacing;
    final maxBars = (size.width / barPitch).floor();
    if (maxBars <= 0) return;

    // Draw horizontal center line if enabled
    if (style.showCenterLine) {
      final centerPaint = Paint()
        ..color = style.centerLineColor
        ..strokeWidth = 1.0;
      canvas.drawLine(
        Offset(0, size.height / 2),
        Offset(size.width, size.height / 2),
        centerPaint,
      );
    }

    // Determine slice of samples to render (align to right for live scrolling)
    final visibleSamples = samples.length > maxBars
        ? samples.sublist(samples.length - maxBars)
        : samples;

    final barPaint = Paint()..isAntiAlias = true;

    if (style.barGradient != null) {
      barPaint.shader = style.barGradient!.createShader(
        Rect.fromLTWH(0, 0, size.width, size.height),
      );
    } else {
      barPaint.color = style.barColor;
    }

    final centerY = size.height / 2;
    final minBarHeight = 4.0;
    final maxBarHeight = size.height * 0.95;

    for (int i = 0; i < visibleSamples.length; i++) {
      final sample = visibleSamples[i];
      final x = i * barPitch;
      final rawHeight = sample * maxBarHeight;
      final barHeight = math.max(minBarHeight, rawHeight);

      final Rect barRect;
      if (style.isSymmetric) {
        barRect = Rect.fromCenter(
          center: Offset(x + style.barWidth / 2, centerY),
          width: style.barWidth,
          height: barHeight,
        );
      } else {
        barRect = Rect.fromLTWH(
          x,
          size.height - barHeight,
          style.barWidth,
          barHeight,
        );
      }

      if (style.barRadius > 0) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(barRect, Radius.circular(style.barRadius)),
          barPaint,
        );
      } else {
        canvas.drawRect(barRect, barPaint);
      }
    }

    // Draw scrubber playhead indicator
    if (showScrubber && playbackPosition >= 0.0 && playbackPosition <= 1.0) {
      final scrubberX = playbackPosition * size.width;
      final scrubberPaint = Paint()
        ..color = style.scrubberColor
        ..strokeWidth = style.scrubberWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(
        Offset(scrubberX, 0),
        Offset(scrubberX, size.height),
        scrubberPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant SvfWaveformPainter oldDelegate) {
    return oldDelegate.playbackPosition != playbackPosition ||
        oldDelegate.samples.length != samples.length ||
        oldDelegate.style != style;
  }
}
