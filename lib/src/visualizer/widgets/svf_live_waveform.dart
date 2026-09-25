import 'package:flutter/material.dart';
import '../controller/waveform_controller.dart';
import '../models/waveform_style.dart';
import '../painter/waveform_painter.dart';

/// Real-time live audio recording waveform widget.
/// Zero native dependencies: operates 60fps on Android, Web, and desktop.
class SvfLiveWaveform extends StatelessWidget {
  final SvfWaveformController controller;
  final SvfWaveformStyle style;
  final double height;
  final double? width;

  const SvfLiveWaveform({
    super.key,
    required this.controller,
    this.style = const SvfWaveformStyle(),
    this.height = 80.0,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return SizedBox(
          height: height,
          width: width ?? double.infinity,
          child: CustomPaint(
            painter: SvfWaveformPainter(
              samples: controller.samples,
              playbackPosition: controller.playbackPosition,
              style: style,
              showScrubber: false,
            ),
          ),
        );
      },
    );
  }
}
