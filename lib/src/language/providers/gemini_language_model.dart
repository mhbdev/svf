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

/// Direct Google Gemini API LanguageModel provider without bloated client SDK dependencies.
class GeminiLanguageModel implements LanguageModel {
  @override
  final String modelId;

  final String apiKey;
  final http.Client _client;

  GeminiLanguageModel({
    required this.modelId,
    required this.apiKey,
    http.Client? client,
  }) : _client = client ?? http.Client();

  @override
  String get providerId => 'google';

  @override
  bool get isOffline => false;

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
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$modelId:generateContent?key=$apiKey',
    );

    final body = _buildRequestBody(
      messages: messages,
      responseSchema: responseSchema,
      tools: tools,
      temperature: temperature,
      maxTokens: maxTokens,
      topP: topP,
      stopSequences: stopSequences,
    );

    final response = await _client.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      throw SvfModelException(
        'Gemini API error: ${response.body}',
        modelId: modelId,
        statusCode: response.statusCode,
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = data['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) {
      throw SvfModelException('No generation candidates returned from Gemini', modelId: modelId);
    }

    final firstCandidate = candidates.first as Map<String, dynamic>;
    final content = firstCandidate['content'] as Map<String, dynamic>?;
    final parts = content?['parts'] as List? ?? [];

    final textBuffer = StringBuffer();
    final toolCalls = <ToolCall>[];

    for (final part in parts) {
      if (part is Map<String, dynamic>) {
        if (part.containsKey('text')) {
          textBuffer.write(part['text']);
        }
        if (part.containsKey('functionCall')) {
          final fn = part['functionCall'] as Map<String, dynamic>;
          toolCalls.add(
            ToolCall(
              id: 'call_${DateTime.now().millisecondsSinceEpoch}',
              name: fn['name'] as String,
              arguments: Map<String, dynamic>.from(fn['args'] as Map? ?? {}),
            ),
          );
        }
      }
    }

    final usageMetadata = data['usageMetadata'] as Map<String, dynamic>?;
    final usage = SvfUsage(
      promptTokens: usageMetadata?['promptTokenCount'] as int? ?? 0,
      completionTokens: usageMetadata?['candidatesTokenCount'] as int? ?? 0,
      totalTokens: usageMetadata?['totalTokenCount'] as int? ?? 0,
    );

    final finishReasonStr = firstCandidate['finishReason'] as String?;

    return GenerateTextResult(
      text: textBuffer.toString(),
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
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$modelId:streamGenerateContent?alt=sse&key=$apiKey',
    );

    final body = _buildRequestBody(
      messages: messages,
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

    final streamedResponse = await _client.send(request);

    if (streamedResponse.statusCode != 200) {
      final errorBody = await streamedResponse.stream.bytesToString();
      throw SvfModelException(
        'Gemini streaming API error: $errorBody',
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
          final candidates = data['candidates'] as List?;
          if (candidates != null && candidates.isNotEmpty) {
            final parts = candidates[0]['content']?['parts'] as List? ?? [];
            for (final part in parts) {
              if (part is Map<String, dynamic> && part.containsKey('text')) {
                yield part['text'] as String;
              }
            }
          }
        } catch (_) {}
      }
    }
  }

  Map<String, dynamic> _buildRequestBody({
    required List<ChatMessage> messages,
    SvfSchema? responseSchema,
    List<SvfTool>? tools,
    double? temperature,
    int? maxTokens,
    double? topP,
    List<String>? stopSequences,
  }) {
    final contents = <Map<String, dynamic>>[];
    Map<String, dynamic>? systemInstruction;

    for (final msg in messages) {
      if (msg.role == ChatRole.system) {
        systemInstruction = {
          'parts': [{'text': msg.content}],
        };
      } else {
        final role = msg.role == ChatRole.assistant ? 'model' : 'user';
        final parts = <Map<String, dynamic>>[];

        if (msg.role == ChatRole.tool) {
          parts.add({
            'functionResponse': {
              'name': msg.name ?? 'tool_result',
              'response': {'content': msg.content},
            },
          });
        } else {
          parts.add({'text': msg.content});
        }

        contents.add({
          'role': role,
          'parts': parts,
        });
      }
    }

    final generationConfig = <String, dynamic>{};
    if (temperature != null) generationConfig['temperature'] = temperature;
    if (maxTokens != null) generationConfig['maxOutputTokens'] = maxTokens;
    if (topP != null) generationConfig['topP'] = topP;
    if (stopSequences != null) generationConfig['stopSequences'] = stopSequences;

    if (responseSchema != null) {
      generationConfig['responseMimeType'] = 'application/json';
      generationConfig['responseSchema'] = responseSchema.toJsonSchema(strict: true);
    }

    final body = <String, dynamic>{
      'contents': contents,
      'systemInstruction': ?systemInstruction,
      if (generationConfig.isNotEmpty) 'generationConfig': generationConfig,
    };

    if (tools != null && tools.isNotEmpty) {
      body['tools'] = [
        {
          'functionDeclarations': tools.map((t) {
            return {
              'name': t.name,
              'description': t.description,
              'parameters': t.parameters.toJsonSchema(strict: true),
            };
          }).toList(),
        }
      ];
    }

    return body;
  }
}
