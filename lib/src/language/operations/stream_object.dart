import 'dart:async';
import 'dart:convert';
import '../../core/schema/svf_schema.dart';
import '../contracts/language_model.dart';
import '../contracts/message.dart';
import '../models/stream_result.dart';
import 'stream_text.dart';

/// Streams partial structured objects in real-time as tokens arrive from the model
/// (inspired by Vercel AI SDK streamObject).
///
/// Emits progressive updates to [StreamObjectResult.partialObjectStream], allowing
/// Flutter UIs to update form fields in real-time as the model generates them.
StreamObjectResult<T> streamObject<T>({
  required LanguageModel model,
  required SvfSchema schema,
  String? prompt,
  List<ChatMessage>? messages,
  String? system,
  double? temperature,
  T Function(Map<String, dynamic> json)? parser,
}) {
  final partialController = StreamController<Map<String, dynamic>>.broadcast();
  final finalObjectCompleter = Completer<T>();

  final jsonSchemaString = schema is SvfObjectSchema
      ? schema.toJsonSchemaString(pretty: false)
      : jsonEncode(schema.toJsonSchema());

  final schemaSystemPrompt =
      'You are a precise structured data extraction engine. '
      'You must stream ONLY a valid JSON object matching this schema:\n$jsonSchemaString\n'
      'Do not include markdown blocks (no ```json) or explanations.';

  final effectiveSystem = system != null && system.isNotEmpty
      ? '$system\n\n$schemaSystemPrompt'
      : schemaSystemPrompt;

  final textStreamResult = streamText(
    model: model,
    prompt: prompt,
    messages: messages,
    system: effectiveSystem,
    temperature: temperature ?? 0.1,
  );

  final buffer = StringBuffer();
  Map<String, dynamic> lastEmittedPartial = {};

  textStreamResult.textStream.listen(
    (chunk) {
      buffer.write(chunk);
      final currentText = buffer.toString();

      // Attempt best-effort partial JSON recovery
      final partialMap = _tryParsePartialJson(currentText);
      if (partialMap != null && partialMap.isNotEmpty) {
        lastEmittedPartial = partialMap;
        partialController.add(partialMap);
      }
    },
    onError: (e, st) {
      if (!finalObjectCompleter.isCompleted) finalObjectCompleter.completeError(e, st);
      partialController.addError(e, st);
    },
    onDone: () async {
      try {
        final fullText = await textStreamResult.fullText;
        final completeMap = _extractCompleteJson(fullText) ?? lastEmittedPartial;

        final T result;
        if (parser != null) {
          result = parser(completeMap);
        } else if (completeMap is T) {
          result = completeMap as T;
        } else {
          result = completeMap as T;
        }

        if (!finalObjectCompleter.isCompleted) finalObjectCompleter.complete(result);
      } catch (e, st) {
        if (!finalObjectCompleter.isCompleted) finalObjectCompleter.completeError(e, st);
      } finally {
        partialController.close();
      }
    },
  );

  return StreamObjectResult<T>(
    partialObjectStream: partialController.stream,
    finalObject: finalObjectCompleter.future,
  );
}

/// Attempts to parse an incomplete streaming JSON string by auto-closing braces/quotes.
Map<String, dynamic>? _tryParsePartialJson(String text) {
  final trimmed = text.trim();
  final firstBrace = trimmed.indexOf('{');
  if (firstBrace == -1) return null;

  String candidate = trimmed.substring(firstBrace);

  // If already valid JSON
  try {
    return Map<String, dynamic>.from(jsonDecode(candidate) as Map);
  } catch (_) {}

  // Heuristic auto-repair: close open quotes and close open braces
  final openQuotes = '"'.allMatches(candidate).length % 2 != 0;
  if (openQuotes) {
    candidate += '"';
  }

  // Count unclosed braces
  int openBraces = 0;
  bool inString = false;
  for (int i = 0; i < candidate.length; i++) {
    final char = candidate[i];
    if (char == '"' && (i == 0 || candidate[i - 1] != '\\')) {
      inString = !inString;
    } else if (!inString) {
      if (char == '{') openBraces++;
      if (char == '}') openBraces--;
    }
  }

  while (openBraces > 0) {
    candidate += '}';
    openBraces--;
  }

  try {
    return Map<String, dynamic>.from(jsonDecode(candidate) as Map);
  } catch (_) {
    return null;
  }
}

/// Final pass JSON extractor.
Map<String, dynamic>? _extractCompleteJson(String text) {
  final trimmed = text.trim();
  final firstBrace = trimmed.indexOf('{');
  final lastBrace = trimmed.lastIndexOf('}');
  if (firstBrace != -1 && lastBrace != -1 && lastBrace > firstBrace) {
    try {
      final jsonSub = trimmed.substring(firstBrace, lastBrace + 1);
      return Map<String, dynamic>.from(jsonDecode(jsonSub) as Map);
    } catch (_) {}
  }
  return null;
}
