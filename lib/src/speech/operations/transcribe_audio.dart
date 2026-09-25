import '../../core/types/audio_source.dart';
import '../contracts/speech_to_text_model.dart';
import '../models/transcription_options.dart';
import '../models/transcription_result.dart';

/// Transcribes an audio source using the specified speech-to-text [model] (Vercel AI SDK style).
///
/// Example:
/// ```dart
/// final result = await transcribeAudio(
///   model: svf.speechModel('whisper-1'),
///   audio: recordedAudioSource,
///   options: const TranscriptionOptions(language: 'en'),
/// );
/// print('Transcript: ${result.text}');
/// ```
Future<TranscriptionResult> transcribeAudio({
  required SpeechToTextModel model,
  required SvfAudioSource audio,
  TranscriptionOptions? options,
}) async {
  return model.doTranscribe(audio: audio, options: options);
}
