import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/errors/svf_exception.dart';
import '../../core/schema/svf_schema.dart';
import '../../core/types/usage.dart';
import '../contracts/language_model.dart';
import '../contracts/message.dart';
import '../contracts/tool.dart';
import '../models/generation_result.dart';

/// Direct OpenAI-compatible LanguageModel provider (GPT-4o, Groq, DeepSeek, Ollama, LM Studio).
class OpenAiLanguageModel implements LanguageModel {
  @override
  final String modelId;

  final String apiKey;
  final String baseUrl;
  @override
  final String providerId;
  @override
  final bool isOffline;

  final http.Client _client;

  OpenAiLanguageModel({
    required this.modelId,
    required this.apiKey,
    this.baseUrl = 'https://api.openai.com/v1',
    this.providerId = 'openai',
    this.isOffline = false,
    http.Client? client,
  }) : _client = client ?? http.Client();

  @override
  Future<GenerateTextResult> doGenerate({
    required List<ChatMessage> messages,
    SvfSchema? responseSchema,
    List<SvfTool>? tools,
    double? temperature,
    int? maxTokens,
    double? topP,
    List<String>? stopSequences,
  }) async {
    final cleanBase = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    final url = Uri.parse('$cleanBase/chat/completions');

    final body = _buildRequestBody(
      messages: messages,
      stream: false,
      responseSchema: responseSchema,
      tools: tools,
      temperature: temperature,
      maxTokens: maxTokens,
      topP: topP,
      stopSequences: stopSequences,
    );

    final response = await _client.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        if (apiKey.isNotEmpty) 'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      throw SvfModelException(
        'OpenAI API error: ${response.body}',
        modelId: modelId,
        statusCode: response.statusCode,
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final choices = data['choices'] as List?;
    if (choices == null || choices.isEmpty) {
      throw SvfModelException('No completion choices returned from OpenAI', modelId: modelId);
    }

    final firstChoice = choices.first as Map<String, dynamic>;
    final messageMap = firstChoice['message'] as Map<String, dynamic>?;
    final contentText = messageMap?['content'] as String? ?? '';

    final toolCalls = <ToolCall>[];
    if (messageMap?['tool_calls'] is List) {
      for (final call in messageMap!['tool_calls'] as List) {
        if (call is Map<String, dynamic>) {
          final fn = call['function'] as Map<String, dynamic>?;
          final argsStr = fn?['arguments'] as String? ?? '{}';
          Map<String, dynamic> parsedArgs = {};
          try {
            parsedArgs = Map<String, dynamic>.from(jsonDecode(argsStr) as Map);
          } catch (_) {}

          toolCalls.add(
            ToolCall(
              id: call['id'] as String? ?? 'call_${DateTime.now().millisecondsSinceEpoch}',
              name: fn?['name'] as String? ?? 'unknown',
              arguments: parsedArgs,
            ),
          );
        }
      }
    }

    final usageData = data['usage'] as Map<String, dynamic>?;
    final usage = SvfUsage(
      promptTokens: usageData?['prompt_tokens'] as int? ?? 0,
      completionTokens: usageData?['completion_tokens'] as int? ?? 0,
      totalTokens: usageData?['total_tokens'] as int? ?? 0,
    );

    final finishReasonStr = firstChoice['finish_reason'] as String?;

    return GenerateTextResult(
      text: contentText,
      toolCalls: toolCalls,
      finishReason: FinishReason.fromString(finishReasonStr),
      usage: usage,
      rawResponse: data,
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
  }) async* {
    final cleanBase = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    final url = Uri.parse('$cleanBase/chat/completions');

    final body = _buildRequestBody(
      messages: messages,
      stream: true,
      responseSchema: responseSchema,
      tools: tools,
      temperature: temperature,
      maxTokens: maxTokens,
      topP: topP,
      stopSequences: stopSequences,
    );

    final request = http.Request('POST', url)
      ..headers['Content-Type'] = 'application/json'
      ..body = jsonEncode(body);

    if (apiKey.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $apiKey';
    }

    final streamedResponse = await _client.send(request);

    if (streamedResponse.statusCode != 200) {
      final errorBody = await streamedResponse.stream.bytesToString();
      throw SvfModelException(
        'OpenAI streaming API error: $errorBody',
        modelId: modelId,
        statusCode: streamedResponse.statusCode,
      );
    }

    final lines = streamedResponse.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    await for (final line in lines) {
      if (line.startsWith('data: ')) {
        final jsonStr = line.substring(6).trim();
        if (jsonStr.isEmpty || jsonStr == '[DONE]') continue;
        try {
          final data = jsonDecode(jsonStr) as Map<String, dynamic>;
          final choices = data['choices'] as List?;
          if (choices != null && choices.isNotEmpty) {
            final delta = choices[0]['delta'] as Map<String, dynamic>?;
            final content = delta?['content'] as String?;
            if (content != null && content.isNotEmpty) {
              yield content;
            }
          }
        } catch (_) {}
      }
    }
  }

  Map<String, dynamic> _buildRequestBody({
    required List<ChatMessage> messages,
    required bool stream,
    SvfSchema? responseSchema,
    List<SvfTool>? tools,
    double? temperature,
    int? maxTokens,
    double? topP,
    List<String>? stopSequences,
  }) {
    final body = <String, dynamic>{
      'model': modelId,
      'messages': messages.map((m) => m.toMap()).toList(),
      'stream': stream,
    };

    if (temperature != null) body['temperature'] = temperature;
    if (maxTokens != null) body['max_tokens'] = maxTokens;
    if (topP != null) body['top_p'] = topP;
    if (stopSequences != null) body['stop'] = stopSequences;

    if (responseSchema != null) {
      body['response_format'] = {
        'type': 'json_schema',
        'json_schema': {
          'name': 'structured_output',
          'strict': true,
          'schema': responseSchema.toJsonSchema(strict: true),
        },
      };
    }

    if (tools != null && tools.isNotEmpty) {
      body['tools'] = tools.map((t) => t.toFunctionDefinition()).toList();
    }

    return body;
  }
}
