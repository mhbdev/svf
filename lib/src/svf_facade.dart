import 'audio/contracts/audio_recorder.dart';
import 'audio/recorder/svf_recorder.dart';
import 'downloader/cache.dart';
import 'downloader/resumable_downloader.dart';
import 'language/contracts/language_model.dart';
import 'language/providers/gemini_language_model.dart';
import 'language/providers/groq_language_model.dart';
import 'language/providers/ollama_language_model.dart';
import 'language/providers/openai_language_model.dart';
import 'speech/contracts/speech_to_text_model.dart';
import 'speech/providers/device_speech_model.dart';
import 'speech/providers/whisper_cloud_model.dart';
import 'synthesis/contracts/text_to_speech_model.dart';
import 'synthesis/providers/openai_speech_model.dart';

/// Smart Voice Foundation (SVF) main client facade.
/// Provides unified access to audio recorders, speech engines, language models,
/// and resumable model downloading.
class Svf {
  final ISvfAudioRecorder _recorder;
  final ResumableDownloader _downloader;
  final ModelCache _modelCache;

  Svf({
    ISvfAudioRecorder? recorder,
    ResumableDownloader? downloader,
    ModelCache? modelCache,
  })  : _modelCache = modelCache ?? ModelCache(),
        _recorder = recorder ?? SvfRecorder(),
        _downloader = downloader ?? ResumableDownloader(cache: modelCache);

  /// Access to the universal audio recorder.
  ISvfAudioRecorder get recorder => _recorder;

  /// Access to the resumable model weight downloader.
  ResumableDownloader get downloader => _downloader;

  /// Access to the local model disk cache.
  ModelCache get modelCache => _modelCache;

  /// Creates a Google Gemini LanguageModel provider.
  LanguageModel gemini(String modelId, {required String apiKey}) {
    return GeminiLanguageModel(modelId: modelId, apiKey: apiKey);
  }

  /// Creates an OpenAI LanguageModel provider.
  LanguageModel openai(String modelId, {required String apiKey, String baseUrl = 'https://api.openai.com/v1'}) {
    return OpenAiLanguageModel(modelId: modelId, apiKey: apiKey, baseUrl: baseUrl);
  }

  /// Creates an ultra-fast Groq Cloud LanguageModel provider.
  LanguageModel groq(String modelId, {required String apiKey}) {
    return GroqLanguageModel(modelId: modelId, apiKey: apiKey);
  }

  /// Creates a local Ollama LanguageModel provider.
  LanguageModel ollama(String modelId, {String baseUrl = 'http://localhost:11434/v1'}) {
    return OllamaLanguageModel(modelId: modelId, baseUrl: baseUrl);
  }

  /// Creates a Whisper speech recognition provider (OpenAI or Groq).
  SpeechToTextModel whisper({
    required String apiKey,
    String modelId = 'whisper-1',
    String baseUrl = 'https://api.openai.com/v1',
  }) {
    return WhisperCloudModel(
      modelId: modelId,
      apiKey: apiKey,
      baseUrl: baseUrl,
    );
  }

  /// Creates a Groq high-speed Whisper speech recognition provider.
  SpeechToTextModel groqWhisper({
    required String apiKey,
    String modelId = 'whisper-large-v3-turbo',
  }) {
    return WhisperCloudModel.groq(
      apiKey: apiKey,
      modelId: modelId,
    );
  }

  /// Creates a device-native speech recognition provider (speech_to_text).
  SpeechToTextModel deviceSpeech() {
    return DeviceSpeechModel();
  }

  /// Creates an OpenAI Text-to-Speech provider.
  TextToSpeechModel tts({
    required String apiKey,
    String modelId = 'tts-1',
    String baseUrl = 'https://api.openai.com/v1',
  }) {
    return OpenAiSpeechModel(
      modelId: modelId,
      apiKey: apiKey,
      baseUrl: baseUrl,
    );
  }

  /// Disposes background resources.
  Future<void> dispose() async {
    await _recorder.dispose();
    _downloader.dispose();
  }
}
