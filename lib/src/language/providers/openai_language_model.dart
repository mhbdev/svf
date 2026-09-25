import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/errors/svf_exception.dart';
import '../../core/schema/svf_schema.dart';
import '../../core/types/usage.dart';
import '../contracts/language_model.dart';
import '../contracts/message.dart';
import '../contracts/tool.dart';
import '../models/generation_event.dart';
import '../models/generation_result.dart';
import '../models/generate_request.dart';

/// OpenAI-compatible language-model adapter.
///
/// This adapter also covers compatible endpoints such as OpenRouter, Groq,
/// Ollama, LM Studio, and other OpenAI-compatible gateways. Provider-specific
/// headers and routing options are injected through [headers] and
/// [requestOptions] rather than hard-coded into the core API.
class OpenAiLanguageModel
    implements
        LanguageModel,
        LanguageModelRequestSource,
        LanguageModelEventSource {
  @override
  final String modelId;

  final String apiKey;
  final String baseUrl;
  @override
  final String providerId;
  @override
  final bool isOffline;

  final http.Client _client;
  final Map<String, String> headers;
  final Map<String, dynamic> requestOptions;
  final Duration requestTimeout;

  OpenAiLanguageModel({
    required this.modelId,
    required this.apiKey,
    this.baseUrl = 'https://api.openai.com/v1',
    this.providerId = 'openai',
    this.isOffline = false,
    Map<String, String> headers = const {},
    Map<String, dynamic> requestOptions = const {},
    this.requestTimeout = const Duration(minutes: 2),
    http.Client? client,
  }) : headers = Map<String, String>.unmodifiable(headers),
       requestOptions = Map<String, dynamic>.unmodifiable(requestOptions),
       _client = client ?? http.Client();

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
    return generateRequest(
      GenerateRequest(
        messages: messages,
        responseSchema: responseSchema,
        tools: tools ?? const [],
        temperature: temperature,
        maxTokens: maxTokens,
        topP: topP,
        stopSequences: stopSequences ?? const [],
      ),
    );
  }

  @override
  Future<GenerateTextResult> generateRequest(GenerateRequest request) async {
    request.cancellationToken?.throwIfCancelled();
    final response = await _client
        .post(
          Uri.parse('$_cleanBaseUrl/chat/completions'),
          headers: _headers,
          body: jsonEncode(
            _buildRequestBody(
              messages: request.messages,
              stream: false,
              responseSchema: request.responseSchema,
              tools: request.tools,
              temperature: request.temperature,
              maxTokens: request.maxTokens,
              topP: request.topP,
              stopSequences: request.stopSequences.isEmpty
                  ? null
                  : request.stopSequences,
              providerOptions: request.providerOptions,
            ),
          ),
        )
        .timeout(requestTimeout);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw SvfModelException(
        'OpenAI-compatible API error: ${response.body}',
        modelId: modelId,
        statusCode: response.statusCode,
      );
    }

    final data = _decodeMap(response.body, 'completion response');
    final choices = data['choices'];
    if (choices is! List || choices.isEmpty || choices.first is! Map) {
      throw SvfModelException(
        'No completion choices returned by provider.',
        modelId: modelId,
      );
    }

    final choice = Map<String, dynamic>.from(choices.first as Map);
    final rawMessage = choice['message'];
    final message = rawMessage is Map
        ? Map<String, dynamic>.from(rawMessage)
        : const <String, dynamic>{};

    return GenerateTextResult(
      text: message['content'] is String ? message['content'] as String : '',
      toolCalls: _parseToolCalls(message['tool_calls']),
      finishReason: FinishReason.fromString(choice['finish_reason'] as String?),
      usage: _parseUsage(data['usage']),
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
    await for (final event in streamEvents(
      GenerateRequest(
        messages: messages,
        responseSchema: responseSchema,
        tools: tools ?? const [],
        temperature: temperature,
        maxTokens: maxTokens,
        topP: topP,
        stopSequences: stopSequences ?? const [],
      ),
    )) {
      if (event case TextDelta(:final text)) yield text;
    }
  }

  @override
  Stream<GenerationEvent> streamEvents(GenerateRequest request) async* {
    request.cancellationToken?.throwIfCancelled();
    final httpRequest =
        http.Request('POST', Uri.parse('$_cleanBaseUrl/chat/completions'))
          ..headers.addAll(_headers)
          ..body = jsonEncode(
            _buildRequestBody(
              messages: request.messages,
              stream: true,
              responseSchema: request.responseSchema,
              tools: request.tools,
              temperature: request.temperature,
              maxTokens: request.maxTokens,
              topP: request.topP,
              stopSequences: request.stopSequences.isEmpty
                  ? null
                  : request.stopSequences,
              providerOptions: request.providerOptions,
            ),
          );

    final response = await _client.send(httpRequest).timeout(requestTimeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final body = await response.stream.bytesToString();
      throw SvfModelException(
        'OpenAI-compatible streaming API error: $body',
        modelId: modelId,
        statusCode: response.statusCode,
      );
    }

    yield const GenerationStarted();
    final calls = <int, _StreamingToolCall>{};
    var finishReason = FinishReason.stop;
    var usage = SvfUsage.zero;

    final lines = response.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter());
    await for (final line in lines) {
      request.cancellationToken?.throwIfCancelled();
      if (!line.startsWith('data:')) continue;
      final jsonString = line.substring(5).trim();
      if (jsonString.isEmpty || jsonString == '[DONE]') continue;

      final data = _decodeMap(jsonString, 'stream event');
      usage = _parseUsage(data['usage'], fallback: usage);
      final choices = data['choices'];
      if (choices is! List || choices.isEmpty || choices.first is! Map) {
        continue;
      }

      final choice = Map<String, dynamic>.from(choices.first as Map);
      final reason = choice['finish_reason'] as String?;
      if (reason != null) finishReason = FinishReason.fromString(reason);
      final rawDelta = choice['delta'];
      if (rawDelta is! Map) continue;
      final delta = Map<String, dynamic>.from(rawDelta);

      final text = delta['content'];
      if (text is String && text.isNotEmpty) yield TextDelta(text);

      final rawToolCalls = delta['tool_calls'];
      if (rawToolCalls is! List) continue;
      for (final rawCall in rawToolCalls) {
        if (rawCall is! Map) continue;
        final call = Map<String, dynamic>.from(rawCall);
        final index = (call['index'] as num?)?.toInt() ?? calls.length;
        final rawFunction = call['function'];
        final function = rawFunction is Map
            ? Map<String, dynamic>.from(rawFunction)
            : const <String, dynamic>{};
        final current = calls.putIfAbsent(
          index,
          () => _StreamingToolCall(
            id: call['id'] as String? ?? 'call_$index',
            name: function['name'] as String? ?? '',
          ),
        );
        final arguments = function['arguments'] as String? ?? '';
        current.arguments.write(arguments);
        yield ToolCallDelta(
          id: current.id,
          name: current.name,
          argumentsDelta: arguments,
        );
      }
    }

    final toolCalls = <ToolCall>[];
    for (final call in calls.values) {
      var arguments = <String, dynamic>{};
      try {
        final decoded = jsonDecode(call.arguments.toString());
        if (decoded is Map) arguments = Map<String, dynamic>.from(decoded);
      } catch (_) {
        // The agent will report malformed arguments through its tool error path.
      }
      toolCalls.add(
        ToolCall(id: call.id, name: call.name, arguments: arguments),
      );
    }
    yield GenerationFinished(
      finishReason: finishReason,
      usage: usage,
      toolCalls: toolCalls,
    );
  }

  String get _cleanBaseUrl => baseUrl.endsWith('/')
      ? baseUrl.substring(0, baseUrl.length - 1)
      : baseUrl;

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (apiKey.isNotEmpty) 'Authorization': 'Bearer $apiKey',
    ...headers,
  };

  Map<String, dynamic> _buildRequestBody({
    required List<ChatMessage> messages,
    required bool stream,
    SvfSchema? responseSchema,
    List<SvfTool>? tools,
    double? temperature,
    int? maxTokens,
    double? topP,
    List<String>? stopSequences,
    Map<String, dynamic> providerOptions = const {},
  }) {
    final body = <String, dynamic>{
      ...requestOptions,
      ...providerOptions,
      'model': modelId,
      'messages': messages.map((message) => message.toMap()).toList(),
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
      body['tools'] = tools.map((tool) => tool.toFunctionDefinition()).toList();
    }
    return body;
  }

  Map<String, dynamic> _decodeMap(String source, String label) {
    try {
      final decoded = jsonDecode(source);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (error) {
      throw SvfModelException(
        'Provider returned invalid JSON for $label.',
        modelId: modelId,
        cause: error,
      );
    }
    throw SvfModelException(
      'Provider returned a non-object JSON value for $label.',
      modelId: modelId,
    );
  }

  SvfUsage _parseUsage(Object? raw, {SvfUsage fallback = SvfUsage.zero}) {
    if (raw is! Map) return fallback;
    return SvfUsage(
      promptTokens: (raw['prompt_tokens'] as num?)?.toInt() ?? 0,
      completionTokens: (raw['completion_tokens'] as num?)?.toInt() ?? 0,
      totalTokens: (raw['total_tokens'] as num?)?.toInt() ?? 0,
    );
  }

  List<ToolCall> _parseToolCalls(Object? raw) {
    if (raw is! List) return const [];
    final calls = <ToolCall>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final call = Map<String, dynamic>.from(item);
      final rawFunction = call['function'];
      final function = rawFunction is Map
          ? Map<String, dynamic>.from(rawFunction)
          : const <String, dynamic>{};
      var arguments = <String, dynamic>{};
      final rawArguments = function['arguments'];
      if (rawArguments is Map) {
        arguments = Map<String, dynamic>.from(rawArguments);
      } else if (rawArguments is String) {
        try {
          final decoded = jsonDecode(rawArguments);
          if (decoded is Map) arguments = Map<String, dynamic>.from(decoded);
        } catch (_) {}
      }
      calls.add(
        ToolCall(
          id: call['id'] as String? ?? 'call_${calls.length}',
          name: function['name'] as String? ?? 'unknown',
          arguments: arguments,
        ),
      );
    }
    return calls;
  }
}

final class _StreamingToolCall {
  final String id;
  final String name;
  final StringBuffer arguments = StringBuffer();

  _StreamingToolCall({required this.id, required this.name});
}
