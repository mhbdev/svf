import 'dart:async';
import '../../core/schema/svf_schema.dart';
import '../contracts/language_model.dart';
import '../contracts/message.dart';
import '../contracts/tool.dart';
import '../models/generation_result.dart';

/// Delegate function for generating text offline.
typedef OfflineGenerateDelegate =
    Future<GenerateTextResult> Function({
      required List<ChatMessage> messages,
      SvfSchema? responseSchema,
      List<SvfTool>? tools,
      double? temperature,
      int? maxTokens,
    });

/// Delegate function for streaming text offline.
typedef OfflineStreamDelegate =
    Stream<String> Function({
      required List<ChatMessage> messages,
      SvfSchema? responseSchema,
      List<SvfTool>? tools,
      double? temperature,
      int? maxTokens,
    });

/// Pluggable offline LanguageModel adapter.
/// Allows embedding any on-device engine (e.g. llm_toolkit, llama_cpp, tflite, flutter_gemma)
/// into the SVF unified architecture with zero native compile issues in core.
class CustomOfflineLanguageModel implements LanguageModel {
  @override
  final String modelId;

  @override
  final String providerId;

  final OfflineGenerateDelegate _onGenerate;
  final OfflineStreamDelegate _onStream;

  CustomOfflineLanguageModel({
    required this.modelId,
    this.providerId = 'offline_custom',
    required this._onGenerate,
    required this._onStream,
  });

  @override
  bool get isOffline => true;

  @override
  Future<GenerateTextResult> doGenerate({
    required List<ChatMessage> messages,
    SvfSchema? responseSchema,
    List<SvfTool>? tools,
    double? temperature,
    int? maxTokens,
    double? topP,
    List<String>? stopSequences,
  }) {
    return _onGenerate(
      messages: messages,
      responseSchema: responseSchema,
      tools: tools,
      temperature: temperature,
      maxTokens: maxTokens,
    );
  }

  @override
  Stream<String> doStream({
    required List<ChatMessage> messages,
    SvfSchema? responseSchema,
    List<SvfTool>? tools,
    double? temperature,
    int? maxTokens,
    double? topP,
    List<String>? stopSequences,
  }) {
    return _onStream(
      messages: messages,
      responseSchema: responseSchema,
      tools: tools,
      temperature: temperature,
      maxTokens: maxTokens,
    );
  }
}
