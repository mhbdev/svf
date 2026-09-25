import 'dart:async';

import 'package:http/http.dart' as http;

import 'audio/contracts/audio_recorder.dart';
import 'audio/recorder/svf_recorder.dart';
import 'core/control/cancellation_token.dart';
import 'core/schema/svf_schema.dart';
import 'core/types/audio_source.dart';
import 'downloader/cache.dart';
import 'downloader/resumable_downloader.dart';
import 'language/agent/agent_loop.dart' as language_agent;
import 'language/contracts/language_model.dart';
import 'language/contracts/message.dart';
import 'language/contracts/tool.dart';
import 'language/models/generation_result.dart';
import 'language/models/stream_result.dart';
import 'language/operations/generate_object.dart' as language_generate_object;
import 'language/operations/generate_json.dart' as language_generate_json;
import 'language/operations/generate_text.dart' as language_generate_text;
import 'language/operations/stream_object.dart' as language_stream_object;
import 'language/operations/stream_text.dart' as language_stream_text;
import 'language/providers/gemini_language_model.dart';
import 'language/providers/groq_language_model.dart';
import 'language/providers/ollama_language_model.dart';
import 'language/providers/openai_language_model.dart';
import 'language/providers/openrouter_language_model.dart';
import 'speech/contracts/speech_to_text_model.dart';
import 'speech/models/transcription_chunk.dart';
import 'speech/models/transcription_options.dart';
import 'speech/models/transcription_result.dart';
import 'speech/operations/stream_transcription.dart' as speech_stream;
import 'speech/operations/transcribe_audio.dart' as speech_transcribe;
import 'speech/providers/device_speech_model.dart';
import 'speech/providers/whisper_cloud_model.dart';
import 'speech/router/speech_router.dart';
import 'synthesis/contracts/text_to_speech_model.dart';
import 'synthesis/operations/synthesize_speech.dart' as synthesis;
import 'synthesis/providers/openai_speech_model.dart';

/// The main dependency-injection and orchestration client for SVF.
///
/// [Svf] owns the default recorder, model cache, downloader, and shared HTTP
/// transport. Inject [httpClient] in tests or when the host application needs
/// custom proxy, retry, tracing, or authentication behavior.
final class Svf {
  final ISvfAudioRecorder _recorder;
  final ResumableDownloader _downloader;
  final ModelCache _modelCache;
  final http.Client _httpClient;
  final bool _ownsHttpClient;
  bool _isDisposed = false;

  Svf({
    ISvfAudioRecorder? recorder,
    ResumableDownloader? downloader,
    ModelCache? modelCache,
    http.Client? httpClient,
  }) : this._configured(
         recorder: recorder,
         downloader: downloader,
         modelCache: modelCache ?? ModelCache(),
         httpClient: httpClient ?? http.Client(),
         ownsHttpClient: httpClient == null,
       );

  Svf._configured({
    required ISvfAudioRecorder? recorder,
    required ResumableDownloader? downloader,
    required ModelCache modelCache,
    required this._httpClient,
    required this._ownsHttpClient,
  }) : _modelCache = modelCache,
       _recorder = recorder ?? SvfRecorder(),
       _downloader = downloader ?? ResumableDownloader(cache: modelCache);

  /// Access to the universal audio recorder.
  ISvfAudioRecorder get recorder => _recorder;

  /// Access to the resumable model artifact downloader.
  ResumableDownloader get downloader => _downloader;

  /// Access to the platform-aware model cache.
  ModelCache get modelCache => _modelCache;

  /// The shared transport used by providers created by this client.
  http.Client get httpClient => _httpClient;

  /// Whether [dispose] has already been called.
  bool get isDisposed => _isDisposed;

  /// Creates a Google Gemini language model.
  GeminiLanguageModel gemini(String modelId, {required String apiKey}) {
    _ensureActive();
    return GeminiLanguageModel(
      modelId: modelId,
      apiKey: apiKey,
      client: _httpClient,
    );
  }

  /// Creates an OpenAI-compatible language model.
  OpenAiLanguageModel openai(
    String modelId, {
    required String apiKey,
    String baseUrl = 'https://api.openai.com/v1',
    Map<String, String> headers = const {},
    Map<String, dynamic> requestOptions = const {},
    Duration requestTimeout = const Duration(minutes: 2),
  }) {
    _ensureActive();
    return OpenAiLanguageModel(
      modelId: modelId,
      apiKey: apiKey,
      baseUrl: baseUrl,
      headers: headers,
      requestOptions: requestOptions,
      requestTimeout: requestTimeout,
      client: _httpClient,
    );
  }

  /// Creates an OpenRouter language model with optional attribution headers.
  OpenRouterLanguageModel openRouter(
    String modelId, {
    required String apiKey,
    String? httpReferer,
    String? appTitle,
    Map<String, String> headers = const {},
    Map<String, dynamic> requestOptions = const {},
    Duration requestTimeout = const Duration(minutes: 2),
  }) {
    _ensureActive();
    return OpenRouterLanguageModel(
      modelId: modelId,
      apiKey: apiKey,
      httpReferer: httpReferer,
      appTitle: appTitle,
      headers: headers,
      requestOptions: requestOptions,
      requestTimeout: requestTimeout,
      client: _httpClient,
    );
  }

  /// Creates a preconfigured Groq language model.
  GroqLanguageModel groq(String modelId, {required String apiKey}) {
    _ensureActive();
    return GroqLanguageModel(
      modelId: modelId,
      apiKey: apiKey,
      client: _httpClient,
    );
  }

  /// Creates a local Ollama-compatible language model.
  OllamaLanguageModel ollama(
    String modelId, {
    String baseUrl = 'http://localhost:11434/v1',
  }) {
    _ensureActive();
    return OllamaLanguageModel(
      modelId: modelId,
      baseUrl: baseUrl,
      client: _httpClient,
    );
  }

  /// Creates a Whisper-compatible cloud transcription model.
  WhisperCloudModel whisper({
    required String apiKey,
    String modelId = 'whisper-1',
    String baseUrl = 'https://api.openai.com/v1',
  }) {
    _ensureActive();
    return WhisperCloudModel(
      modelId: modelId,
      apiKey: apiKey,
      baseUrl: baseUrl,
      client: _httpClient,
    );
  }

  /// Creates the Groq Whisper transcription model.
  WhisperCloudModel groqWhisper({
    required String apiKey,
    String modelId = 'whisper-large-v3-turbo',
  }) {
    _ensureActive();
    return WhisperCloudModel.groq(
      apiKey: apiKey,
      modelId: modelId,
      client: _httpClient,
    );
  }

  /// Creates the platform-native speech recognizer.
  DeviceSpeechModel deviceSpeech() {
    _ensureActive();
    return DeviceSpeechModel();
  }

  /// Creates a speech router that prefers [primary] and optionally falls back.
  SpeechRouter speechRouter({
    required SpeechToTextModel primary,
    SpeechToTextModel? fallback,
    bool autoFallbackOnFailure = true,
  }) {
    _ensureActive();
    return SpeechRouter(
      primary: primary,
      fallback: fallback,
      autoFallbackOnFailure: autoFallbackOnFailure,
    );
  }

  /// Creates an OpenAI-compatible text-to-speech model.
  OpenAiSpeechModel tts({
    required String apiKey,
    String modelId = 'tts-1',
    String baseUrl = 'https://api.openai.com/v1',
  }) {
    _ensureActive();
    return OpenAiSpeechModel(
      modelId: modelId,
      apiKey: apiKey,
      baseUrl: baseUrl,
      client: _httpClient,
    );
  }

  /// Runs immediate text generation through the same operation used by the
  /// top-level API.
  Future<GenerateTextResult> generateText({
    required LanguageModel model,
    String? prompt,
    List<ChatMessage>? messages,
    String? system,
    List<SvfTool>? tools,
    double? temperature,
    int? maxTokens,
    double? topP,
    List<String>? stopSequences,
    Map<String, dynamic> providerOptions = const {},
    CancellationToken? cancellationToken,
  }) {
    _ensureActive();
    return language_generate_text.generateText(
      model: model,
      prompt: prompt,
      messages: messages,
      system: system,
      tools: tools,
      temperature: temperature,
      maxTokens: maxTokens,
      topP: topP,
      stopSequences: stopSequences,
      providerOptions: providerOptions,
      cancellationToken: cancellationToken,
    );
  }

  /// Starts streaming text generation with normalized event support.
  StreamTextResult streamText({
    required LanguageModel model,
    String? prompt,
    List<ChatMessage>? messages,
    String? system,
    SvfSchema? responseSchema,
    List<SvfTool>? tools,
    double? temperature,
    int? maxTokens,
    double? topP,
    List<String>? stopSequences,
    Map<String, dynamic> providerOptions = const {},
    CancellationToken? cancellationToken,
  }) {
    _ensureActive();
    return language_stream_text.streamText(
      model: model,
      prompt: prompt,
      messages: messages,
      system: system,
      responseSchema: responseSchema,
      tools: tools,
      temperature: temperature,
      maxTokens: maxTokens,
      topP: topP,
      stopSequences: stopSequences,
      providerOptions: providerOptions,
      cancellationToken: cancellationToken,
    );
  }

  /// Runs schema-validated structured generation.
  Future<GenerateObjectResult<T>> generateObject<T>({
    required LanguageModel model,
    required SvfSchema schema,
    String? prompt,
    List<ChatMessage>? messages,
    String? system,
    double? temperature,
    Map<String, dynamic> providerOptions = const {},
    CancellationToken? cancellationToken,
    T Function(Map<String, dynamic> json)? parser,
  }) {
    _ensureActive();
    return language_generate_object.generateObject<T>(
      model: model,
      schema: schema,
      prompt: prompt,
      messages: messages,
      system: system,
      temperature: temperature,
      providerOptions: providerOptions,
      cancellationToken: cancellationToken,
      parser: parser,
    );
  }

  /// Runs schema-validated JSON generation for callers that do not need a
  /// domain decoder.
  Future<Map<String, dynamic>> generateJson({
    required LanguageModel model,
    required SvfSchema schema,
    String? prompt,
    List<ChatMessage>? messages,
    String? system,
    Map<String, dynamic> providerOptions = const {},
    CancellationToken? cancellationToken,
  }) {
    _ensureActive();
    return language_generate_json.generateJson(
      model: model,
      schema: schema,
      prompt: prompt,
      messages: messages,
      system: system,
      providerOptions: providerOptions,
      cancellationToken: cancellationToken,
    );
  }

  /// Runs streaming, incrementally parsed structured generation.
  StreamObjectResult<T> streamObject<T>({
    required LanguageModel model,
    required SvfSchema schema,
    String? prompt,
    List<ChatMessage>? messages,
    String? system,
    double? temperature,
    Map<String, dynamic> providerOptions = const {},
    CancellationToken? cancellationToken,
    T Function(Map<String, dynamic> json)? parser,
  }) {
    _ensureActive();
    return language_stream_object.streamObject<T>(
      model: model,
      schema: schema,
      prompt: prompt,
      messages: messages,
      system: system,
      temperature: temperature,
      providerOptions: providerOptions,
      cancellationToken: cancellationToken,
      parser: parser,
    );
  }

  /// Runs a multi-step tool-calling loop with approval and cancellation.
  Future<language_agent.AgentLoopResult> agentLoop({
    required LanguageModel model,
    required List<ChatMessage> messages,
    required List<SvfTool> tools,
    int maxSteps = 5,
    Duration toolTimeout = const Duration(seconds: 30),
    Map<String, dynamic> providerOptions = const {},
    CancellationToken? cancellationToken,
    Future<bool> Function(SvfTool tool, ToolCall call)? requestApproval,
    void Function(language_agent.AgentStep step)? onStepFinish,
  }) {
    _ensureActive();
    return language_agent.agentLoop(
      model: model,
      messages: messages,
      tools: tools,
      maxSteps: maxSteps,
      toolTimeout: toolTimeout,
      providerOptions: providerOptions,
      cancellationToken: cancellationToken,
      requestApproval: requestApproval,
      onStepFinish: onStepFinish,
    );
  }

  /// Runs batch transcription.
  Future<TranscriptionResult> transcribe({
    required SpeechToTextModel model,
    required SvfAudioSource audio,
    TranscriptionOptions? options,
  }) {
    _ensureActive();
    return speech_transcribe.transcribeAudio(
      model: model,
      audio: audio,
      options: options,
    );
  }

  /// Starts realtime or streamed transcription.
  Stream<TranscriptionChunk> streamTranscription({
    required SpeechToTextModel model,
    Stream<List<int>>? audioStream,
    TranscriptionOptions? options,
  }) {
    _ensureActive();
    return speech_stream.streamTranscription(
      model: model,
      audioStream: audioStream,
      options: options,
    );
  }

  /// Synthesizes speech through a text-to-speech model.
  Future<SvfAudioSource> synthesize({
    required TextToSpeechModel model,
    required String text,
    SynthesisOptions? options,
  }) {
    _ensureActive();
    return synthesis.synthesizeSpeech(
      model: model,
      text: text,
      options: options,
    );
  }

  /// Releases owned resources. Safe to call more than once.
  Future<void> dispose() async {
    if (_isDisposed) return;
    _isDisposed = true;
    await _recorder.dispose();
    _downloader.dispose();
    if (_ownsHttpClient) _httpClient.close();
  }

  void _ensureActive() {
    if (_isDisposed) {
      throw StateError('Svf has been disposed and cannot create new work.');
    }
  }
}
