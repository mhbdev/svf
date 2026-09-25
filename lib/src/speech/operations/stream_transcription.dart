import 'dart:async';
import '../contracts/speech_to_text_model.dart';
import '../models/transcription_chunk.dart';
import '../models/transcription_options.dart';

/// Initiates real-time streaming audio transcription (Vercel AI SDK style).
///
/// Example:
/// ```dart
/// final stream = streamTranscription(
///   model: svf.speechModel('device-stt'),
/// );
/// await for (final chunk in stream) {
///   print('${chunk.isFinal ? "[FINAL]" : "[PARTIAL]"} ${chunk.text}');
/// }
/// ```
Stream<TranscriptionChunk> streamTranscription({
  required SpeechToTextModel model,
  Stream<List<int>>? audioStream,
  TranscriptionOptions? options,
}) {
  return model.doStreamTranscription(
    audioStream: audioStream,
    options: options,
  );
}
