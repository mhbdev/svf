import 'package:flutter/material.dart';

/// Visual styling configuration for SVF waveform renderers.
class SvfWaveformStyle {
  /// Primary color of waveform bars.
  final Color barColor;

  /// Optional gradient for waveform bars.
  final Gradient? barGradient;

  /// Width of each vertical bar in logical pixels.
  final double barWidth;

  /// Spacing between consecutive bars in logical pixels.
  final double barSpacing;

  /// Corner radius of bar rectangles (for rounded pills).
  final double barRadius;

  /// Whether to render a horizontal center dividing line.
  final bool showCenterLine;

  /// Color of the center dividing line.
  final Color centerLineColor;

  /// Whether waveform expands symmetrically around the horizontal center.
  final bool isSymmetric;

  /// Color of the seekhead playback scrubber indicator.
  final Color scrubberColor;

  /// Width of the scrubber line.
  final double scrubberWidth;

  const SvfWaveformStyle({
    this.barColor = const Color(0xFF6750A4),
    this.barGradient,
    this.barWidth = 3.0,
    this.barSpacing = 3.0,
    this.barRadius = 2.0,
    this.showCenterLine = false,
    this.centerLineColor = const Color(0x33000000),
    this.isSymmetric = true,
    this.scrubberColor = const Color(0xFFE91E63),
    this.scrubberWidth = 2.0,
  });

  SvfWaveformStyle copyWith({
    Color? barColor,
    Gradient? barGradient,
    double? barWidth,
    double? barSpacing,
    double? barRadius,
    bool? showCenterLine,
    Color? centerLineColor,
    bool? isSymmetric,
    Color? scrubberColor,
    double? scrubberWidth,
  }) {
    return SvfWaveformStyle(
      barColor: barColor ?? this.barColor,
      barGradient: barGradient ?? this.barGradient,
      barWidth: barWidth ?? this.barWidth,
      barSpacing: barSpacing ?? this.barSpacing,
      barRadius: barRadius ?? this.barRadius,
      showCenterLine: showCenterLine ?? this.showCenterLine,
      centerLineColor: centerLineColor ?? this.centerLineColor,
      isSymmetric: isSymmetric ?? this.isSymmetric,
      scrubberColor: scrubberColor ?? this.scrubberColor,
      scrubberWidth: scrubberWidth ?? this.scrubberWidth,
    );
  }
}
