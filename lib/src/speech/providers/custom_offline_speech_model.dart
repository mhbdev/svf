import 'dart:async';
import '../../core/types/audio_source.dart';
import '../contracts/speech_to_text_model.dart';
import '../models/transcription_chunk.dart';
import '../models/transcription_options.dart';
import '../models/transcription_result.dart';

typedef OfflineTranscribeDelegate =
    Future<TranscriptionResult> Function(
      SvfAudioSource audio,
      TranscriptionOptions? options,
    );

typedef OfflineStreamTranscribeDelegate =
    Stream<TranscriptionChunk> Function(
      Stream<List<int>>? audioStream,
      TranscriptionOptions? options,
    );

/// Pluggable offline SpeechToText adapter allowing integration of on-device Whisper,
/// sherpa-onnx, or tflite without coupling the core package to native C++ dependencies.
class CustomOfflineSpeechModel implements SpeechToTextModel {
  @override
  final String modelId;

  @override
  final String providerId;

  final OfflineTranscribeDelegate _onTranscribe;
  final OfflineStreamTranscribeDelegate _onStream;

  CustomOfflineSpeechModel({
    required this.modelId,
    this.providerId = 'offline_whisper',
    required this._onTranscribe,
    required this._onStream,
  });

  @override
  bool get isOffline => true;

  @override
  Future<bool> isSupported() async => true;

  @override
  Future<TranscriptionResult> doTranscribe({
    required SvfAudioSource audio,
    TranscriptionOptions? options,
  }) {
    return _onTranscribe(audio, options);
  }

  @override
  Stream<TranscriptionChunk> doStreamTranscription({
    Stream<List<int>>? audioStream,
    TranscriptionOptions? options,
  }) {
    return _onStream(audioStream, options);
  }
}
