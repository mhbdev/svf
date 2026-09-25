import 'dart:async';
import '../../core/types/audio_source.dart';
import '../models/transcription_chunk.dart';
import '../models/transcription_options.dart';
import '../models/transcription_result.dart';

/// Universal speech-to-text contract (Vercel AI SDK style SpeechModel).
abstract interface class SpeechToTextModel {
  /// The model identifier (e.g. "whisper-1", "device-asr", "whisper-large-v3").
  String get modelId;

  /// The provider namespace (e.g. "openai", "groq", "device", "offline").
  String get providerId;

  /// Whether this model runs entirely offline on-device without internet access.
  bool get isOffline;

  /// Checks if this model is available and supported on the current platform.
  Future<bool> isSupported();

  /// Transcribes a recorded or stored audio source (batch mode).
  Future<TranscriptionResult> doTranscribe({
    required SvfAudioSource audio,
    TranscriptionOptions? options,
  });

  /// Transcribes an incoming live audio stream in real-time.
  Stream<TranscriptionChunk> doStreamTranscription({
    Stream<List<int>>? audioStream,
    TranscriptionOptions? options,
  });
}
