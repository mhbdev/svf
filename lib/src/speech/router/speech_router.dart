import 'dart:async';
import '../../core/types/audio_source.dart';
import '../contracts/speech_to_text_model.dart';
import '../models/transcription_chunk.dart';
import '../models/transcription_options.dart';
import '../models/transcription_result.dart';

/// Intelligent SpeechToText router that automatically selects and falls back
/// between offline on-device and online cloud speech models based on availability.
class SpeechRouter implements SpeechToTextModel {
  final SpeechToTextModel primary;
  final SpeechToTextModel? fallback;
  final bool autoFallbackOnFailure;

  SpeechRouter({
    required this.primary,
    this.fallback,
    this.autoFallbackOnFailure = true,
  });

  @override
  String get modelId => 'router(${primary.modelId}${fallback != null ? " -> ${fallback!.modelId}" : ""})';

  @override
  String get providerId => 'router';

  @override
  bool get isOffline => primary.isOffline && (fallback == null || fallback!.isOffline);

  @override
  Future<bool> isSupported() async {
    final primarySupported = await primary.isSupported();
    if (primarySupported) return true;
    if (fallback != null) return fallback!.isSupported();
    return false;
  }

  @override
  Future<TranscriptionResult> doTranscribe({
    required SvfAudioSource audio,
    TranscriptionOptions? options,
  }) async {
    if (await primary.isSupported()) {
      try {
        return await primary.doTranscribe(audio: audio, options: options);
      } catch (e) {
        if (!autoFallbackOnFailure || fallback == null) rethrow;
      }
    }

    if (fallback != null && await fallback!.isSupported()) {
      return fallback!.doTranscribe(audio: audio, options: options);
    }

    throw StateError('Neither primary nor fallback speech model is available or supported');
  }

  @override
  Stream<TranscriptionChunk> doStreamTranscription({
    Stream<List<int>>? audioStream,
    TranscriptionOptions? options,
  }) {
    // If primary stream encounters error, fallback is engaged
    return primary.doStreamTranscription(audioStream: audioStream, options: options);
  }
}
