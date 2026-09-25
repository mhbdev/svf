import 'dart:math' as math;

/// Represents an audio amplitude measurement at a specific point in time.
class SvfAmplitude {
  /// Current amplitude in decibels (typically -160.0 dB to 0.0 dB).
  final double current;

  /// Peak amplitude in decibels.
  final double max;

  const SvfAmplitude({
    required this.current,
    required this.max,
  });

  /// Empty / silence amplitude.
  static const silence = SvfAmplitude(current: -160.0, max: -160.0);

  /// Converts the logarithmic decibel value into a linear normalized scale [0.0 - 1.0].
  /// Calibrated specifically for smooth visual representation in waveforms.
  double get normalized {
    if (current.isNaN || current <= -60.0) return 0.02;
    if (current >= 0.0) return 1.0;
    // Map -60 dB .. 0 dB to 0.0 .. 1.0 logarithmically
    final linear = (current + 60.0) / 60.0;
    return math.max(0.02, math.min(1.0, linear));
  }

  @override
  String toString() => 'SvfAmplitude(current: ${current.toStringAsFixed(1)}dB, norm: ${normalized.toStringAsFixed(2)})';
}
