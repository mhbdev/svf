import 'dart:async';
import '../../core/schema/svf_schema.dart';
import 'message.dart';
import 'tool.dart';
import '../models/generation_result.dart';
import '../models/generation_event.dart';
import '../models/generate_request.dart';
import '../models/model_info.dart';

/// Universal LanguageModel protocol specification (inspired by Vercel AI SDK LanguageModelV1).
/// All cloud and on-device models implement this contract.
abstract interface class LanguageModel {
  /// The unique model name (e.g. "gemini-1.5-flash", "gpt-4o", "llama-3.3-70b", "gemma-2b-local").
  String get modelId;

  /// The provider namespace (e.g. "google", "openai", "groq", "ollama", "offline").
  String get providerId;

  /// Whether this model runs completely offline/on-device without network calls.
  bool get isOffline;

  /// Executes non-streaming generation with optional structured schema and tools.
  Future<GenerateTextResult> doGenerate({
    required List<ChatMessage> messages,
    SvfSchema? responseSchema,
    List<SvfTool>? tools,
    double? temperature,
    int? maxTokens,
    double? topP,
    List<String>? stopSequences,
  });

  /// Executes streaming token generation.
  Stream<String> doStream({
    required List<ChatMessage> messages,
    SvfSchema? responseSchema,
    List<SvfTool>? tools,
    double? temperature,
    int? maxTokens,
    double? topP,
    List<String>? stopSequences,
  });
}

/// Optional provider capability for lossless normalized streaming events.
abstract interface class LanguageModelEventSource {
  Stream<GenerationEvent> streamEvents(GenerateRequest request);
}

/// Optional modern request-based generation capability.
///
/// Providers implementing this interface receive the complete normalized
/// request, including cancellation and provider-specific options. The legacy
/// [LanguageModel] methods remain available for source compatibility.
abstract interface class LanguageModelRequestSource {
  Future<GenerateTextResult> generateRequest(GenerateRequest request);
}

/// Modern normalized operations layered over the stable provider contract.
extension LanguageModelOperations on LanguageModel {
  ModelInfo get info => ModelInfo(
    modelId: modelId,
    providerId: providerId,
    isOffline: isOffline,
    supportsToolCalls: true,
    supportsStructuredOutput: true,
  );

  Future<GenerateTextResult> generate(GenerateRequest request) {
    request.cancellationToken?.throwIfCancelled();
    if (this case final LanguageModelRequestSource source) {
      return source.generateRequest(request);
    }
    return doGenerate(
      messages: request.messages,
      responseSchema: request.responseSchema,
      tools: request.tools,
      temperature: request.temperature,
      maxTokens: request.maxTokens,
      topP: request.topP,
      stopSequences: request.stopSequences.isEmpty
          ? null
          : request.stopSequences,
    );
  }

  Stream<GenerationEvent> stream(GenerateRequest request) async* {
    request.cancellationToken?.throwIfCancelled();
    yield const GenerationStarted();
    try {
      await for (final chunk in doStream(
        messages: request.messages,
        responseSchema: request.responseSchema,
        tools: request.tools,
        temperature: request.temperature,
        maxTokens: request.maxTokens,
        topP: request.topP,
        stopSequences: request.stopSequences.isEmpty
            ? null
            : request.stopSequences,
      )) {
        request.cancellationToken?.throwIfCancelled();
        yield TextDelta(chunk);
      }
      yield const GenerationFinished(finishReason: FinishReason.stop);
    } catch (error, stackTrace) {
      yield GenerationFailed(error, stackTrace);
      rethrow;
    }
  }
}
