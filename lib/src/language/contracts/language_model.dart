import 'dart:async';
import '../../core/schema/svf_schema.dart';
import 'message.dart';
import 'tool.dart';
import '../models/generation_result.dart';

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
