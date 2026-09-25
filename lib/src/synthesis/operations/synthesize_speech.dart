import '../../core/types/audio_source.dart';
import '../contracts/text_to_speech_model.dart';

/// Synthesizes spoken audio from text using the specified [model] (Vercel AI SDK style).
///
/// Example:
/// ```dart
/// final audioSource = await synthesizeSpeech(
///   model: svf.ttsModel('tts-1'),
///   text: 'Your medical form has been successfully saved.',
///   options: const SynthesisOptions(voice: 'nova'),
/// );
/// ```
Future<SvfAudioSource> synthesizeSpeech({
  required TextToSpeechModel model,
  required String text,
  SynthesisOptions? options,
}) {
  return model.doSynthesize(text: text, options: options);
}
