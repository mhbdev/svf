/// Supported audio encoding formats across mobile, desktop, and web.
enum SvfAudioFormat {
  /// MPEG-4 Audio (AAC container), widely supported on iOS/Android.
  m4a('audio/mp4', 'm4a'),

  /// Waveform Audio File Format (uncompressed PCM).
  wav('audio/wav', 'wav'),

  /// Advanced Audio Coding.
  aac('audio/aac', 'aac'),

  /// Ogg / Opus audio, highly efficient for voice streaming.
  opus('audio/opus', 'opus'),

  /// WebM container, preferred default on Flutter Web.
  webm('audio/webm', 'webm'),

  /// Raw 16-bit linear PCM audio.
  pcm16('audio/pcm', 'pcm');

  /// The standard MIME content type.
  final String mimeType;

  /// The standard file extension without dot.
  final String extension;

  const SvfAudioFormat(this.mimeType, this.extension);

  /// Guesses the format from a file path or URL extension.
  static SvfAudioFormat fromExtension(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.wav')) return SvfAudioFormat.wav;
    if (lower.endsWith('.m4a')) return SvfAudioFormat.m4a;
    if (lower.endsWith('.aac')) return SvfAudioFormat.aac;
    if (lower.endsWith('.opus') || lower.endsWith('.ogg')) return SvfAudioFormat.opus;
    if (lower.endsWith('.webm')) return SvfAudioFormat.webm;
    if (lower.endsWith('.pcm')) return SvfAudioFormat.pcm16;
    return SvfAudioFormat.m4a;
  }
}
