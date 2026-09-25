import 'dart:convert';

import '../../core/control/cancellation_token.dart';
import '../../core/errors/svf_exception.dart';
import '../../core/schema/svf_schema.dart';
import '../contracts/language_model.dart';
import '../contracts/message.dart';
import '../models/generation_result.dart';
import '../models/generate_request.dart';

/// Generates a strictly typed or structured JSON object from a language model,
/// enforcing compliance against the provided [schema] (inspired by Vercel AI SDK generateObject).
///
/// Example:
/// ```dart
/// final result = await generateObject(
///   model: svf.model('gemini-1.5-flash'),
///   schema: SvfSchema.object(properties: {
///     'name': SvfSchema.string(),
///     'age': SvfSchema.integer(),
///   }),
///   prompt: 'Patient named Alice, 29 years old.',
/// );
/// print(result.object['name']); // Alice
/// ```
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
}) async {
  final effectiveMessages = <ChatMessage>[];

  // Build strict JSON output system instruction
  final jsonSchemaString = schema is SvfObjectSchema
      ? schema.toJsonSchemaString(pretty: false)
      : jsonEncode(schema.toJsonSchema());

  final schemaSystemPrompt =
      'You are a precise structured data extraction engine. '
      'You must respond ONLY with a single valid JSON object that strictly conforms to this JSON Schema:\n'
      '$jsonSchemaString\n'
      'Do not include any conversational filler, markdown formatting (no ```json), or explanatory text.';

  final effectiveSystem = system != null && system.isNotEmpty
      ? '$system\n\n$schemaSystemPrompt'
      : schemaSystemPrompt;

  effectiveMessages.add(ChatMessage.system(effectiveSystem));

  if (messages != null) {
    effectiveMessages.addAll(messages);
  } else if (prompt != null) {
    effectiveMessages.add(ChatMessage.user(prompt));
  } else {
    throw ArgumentError(
      'Either prompt or messages must be provided to generateObject',
    );
  }

  // Request model generation with responseSchema constraint
  final rawResult = await model.generate(
    GenerateRequest(
      messages: effectiveMessages,
      responseSchema: schema,
      temperature: temperature ?? 0.1,
      providerOptions: providerOptions,
      cancellationToken: cancellationToken,
    ),
  );

  // Parse and extract JSON map from response text
  final rawJson = _extractJsonMap(rawResult.text);

  // Validate output against schema
  final validationErrors = schema.validate(rawJson);
  if (validationErrors.isNotEmpty) {
    throw SvfSchemaValidationException(
      'Generated output did not match the requested schema.',
      rawOutput: rawJson,
      validationErrors: validationErrors,
    );
  }

  // Parse into typed object T
  final T parsedObject;
  if (parser != null) {
    try {
      parsedObject = parser(rawJson);
    } catch (e) {
      throw SvfSchemaValidationException(
        'Failed to parse extracted JSON into target type $T: $e',
        rawOutput: rawJson,
        cause: e,
      );
    }
  } else if (T == dynamic || T == Map<String, dynamic>) {
    parsedObject = rawJson as T;
  } else {
    throw SvfSchemaValidationException(
      'A parser is required for generateObject<$T>. Use generateJson for a dynamic JSON map.',
      rawOutput: rawJson,
    );
  }

  return GenerateObjectResult<T>(
    object: parsedObject,
    rawJson: rawJson,
    usage: rawResult.usage,
    warnings: const [],
  );
}

/// Robust JSON map extraction from LLM text output (handles markdown ticks, wrappers).
Map<String, dynamic> _extractJsonMap(String text) {
  final trimmed = text.trim();

  // 1. Direct JSON parse
  if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
    try {
      return Map<String, dynamic>.from(jsonDecode(trimmed) as Map);
    } catch (_) {}
  }

  // 2. Strip ```json ... ``` code blocks
  final codeBlockRegex = RegExp(
    r'```(?:json)?\s*([\s\S]*?)\s*```',
    multiLine: true,
  );
  final match = codeBlockRegex.firstMatch(trimmed);
  if (match != null) {
    final candidate = match.group(1)?.trim();
    if (candidate != null) {
      try {
        return Map<String, dynamic>.from(jsonDecode(candidate) as Map);
      } catch (_) {}
    }
  }

  // 3. Substring between first '{' and last '}'
  final firstBrace = trimmed.indexOf('{');
  final lastBrace = trimmed.lastIndexOf('}');
  if (firstBrace != -1 && lastBrace != -1 && lastBrace > firstBrace) {
    final candidate = trimmed.substring(firstBrace, lastBrace + 1);
    try {
      return Map<String, dynamic>.from(jsonDecode(candidate) as Map);
    } catch (e) {
      throw SvfSchemaValidationException(
        'Malformed JSON inside candidate braces: $candidate',
        cause: e,
      );
    }
  }

  throw SvfSchemaValidationException(
    'No valid JSON object could be extracted from model response: $text',
  );
}
