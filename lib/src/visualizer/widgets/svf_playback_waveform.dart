import 'package:flutter/material.dart';
import '../controller/waveform_controller.dart';
import '../models/waveform_style.dart';
import '../painter/waveform_painter.dart';

/// Interactive audio playback waveform widget with tap and drag scrubbing.
class SvfPlaybackWaveform extends StatelessWidget {
  final SvfWaveformController controller;
  final SvfWaveformStyle style;
  final double height;
  final double? width;
  final ValueChanged<double>? onSeek;

  const SvfPlaybackWaveform({
    super.key,
    required this.controller,
    this.style = const SvfWaveformStyle(),
    this.height = 80.0,
    this.width,
    this.onSeek,
  });

  void _handleSeek(Offset localPosition, double totalWidth) {
    if (totalWidth <= 0) return;
    final progress = (localPosition.dx / totalWidth).clamp(0.0, 1.0);
    controller.seekTo(progress);
    onSeek?.call(progress);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final actualWidth = width ?? constraints.maxWidth;

        return GestureDetector(
          onTapDown: (details) =>
              _handleSeek(details.localPosition, actualWidth),
          onHorizontalDragUpdate: (details) =>
              _handleSeek(details.localPosition, actualWidth),
          child: ListenableBuilder(
            listenable: controller,
            builder: (context, _) {
              return SizedBox(
                height: height,
                width: actualWidth,
                child: CustomPaint(
                  painter: SvfWaveformPainter(
                    samples: controller.samples,
                    playbackPosition: controller.playbackPosition,
                    style: style,
                    showScrubber: true,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
