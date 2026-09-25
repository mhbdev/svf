import 'dart:convert';

import '../../core/control/cancellation_token.dart';
import '../../core/errors/svf_exception.dart';
import '../../core/schema/svf_schema.dart';
import '../contracts/language_model.dart';
import '../contracts/message.dart';
import 'generate_object.dart';

/// Generates validated JSON without pretending that an arbitrary map is a Dart
/// domain object. Use [generateObject] with a parser for typed domain values.
Future<Map<String, dynamic>> generateJson({
  required LanguageModel model,
  required SvfSchema schema,
  String? prompt,
  List<ChatMessage>? messages,
  String? system,
  Map<String, dynamic> providerOptions = const {},
  CancellationToken? cancellationToken,
}) async {
  final result = await generateObject<Map<String, dynamic>>(
    model: model,
    schema: schema,
    prompt: prompt,
    messages: messages,
    system: system,
    providerOptions: providerOptions,
    cancellationToken: cancellationToken,
    parser: (json) => json,
  );
  return result.object;
}

/// Parses a model response as a JSON object with a useful provider-facing error.
Map<String, dynamic> decodeJsonObject(String text) {
  try {
    final decoded = jsonDecode(text);
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
  } on FormatException catch (error) {
    throw SvfSchemaValidationException(
      'The model returned invalid JSON: ${error.message}',
      cause: error,
    );
  }

  throw SvfSchemaValidationException(
    'The model response was valid JSON but not a JSON object.',
    rawOutput: null,
  );
}
