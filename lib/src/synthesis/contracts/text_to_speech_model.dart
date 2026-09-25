import '../../core/types/audio_format.dart';
import '../../core/types/audio_source.dart';

/// Request options for speech synthesis.
class SynthesisOptions {
  /// Voice identifier (e.g. "alloy", "echo", "fable", "onyx", "nova", "shimmer").
  final String? voice;

  /// Output audio format (mp3, aac, opus, flac, wav, pcm).
  final SvfAudioFormat format;

  /// Speaking speed rate (0.25 to 4.0, default 1.0).
  final double speed;

  const SynthesisOptions({
    this.voice,
    this.format = SvfAudioFormat.m4a,
    this.speed = 1.0,
  });
}

/// Universal Text-to-Speech contract.
abstract interface class TextToSpeechModel {
  /// Model identifier (e.g. "tts-1", "tts-1-hd").
  String get modelId;

  /// Provider namespace (e.g. "openai", "elevenlabs", "device").
  String get providerId;

  /// Generates synthesized audio speech from text.
  Future<SvfAudioSource> doSynthesize({
    required String text,
    SynthesisOptions? options,
  });
}
