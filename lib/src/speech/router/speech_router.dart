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
  String get modelId =>
      'router(${primary.modelId}${fallback != null ? " -> ${fallback!.modelId}" : ""})';

  @override
  String get providerId => 'router';

  @override
  bool get isOffline =>
      primary.isOffline && (fallback == null || fallback!.isOffline);

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

    throw StateError(
      'Neither primary nor fallback speech model is available or supported',
    );
  }

  @override
  Stream<TranscriptionChunk> doStreamTranscription({
    Stream<List<int>>? audioStream,
    TranscriptionOptions? options,
  }) {
    return _streamWithFallback(audioStream: audioStream, options: options);
  }

  Stream<TranscriptionChunk> _streamWithFallback({
    required Stream<List<int>>? audioStream,
    required TranscriptionOptions? options,
  }) async* {
    final primarySupported = await primary.isSupported();
    if (primarySupported) {
      try {
        await for (final chunk in primary.doStreamTranscription(
          audioStream: audioStream,
          options: options,
        )) {
          yield chunk;
        }
        return;
      } catch (_) {
        if (!autoFallbackOnFailure || fallback == null) rethrow;
        // Single-subscription audio streams may already be consumed. Callers
        // should provide a replayable stream when they require retry fallback.
      }
    }

    if (fallback == null || !await fallback!.isSupported()) {
      throw StateError('No supported streaming speech model is available');
    }
    await for (final chunk in fallback!.doStreamTranscription(
      audioStream: audioStream,
      options: options,
    )) {
      yield chunk;
    }
  }
}
