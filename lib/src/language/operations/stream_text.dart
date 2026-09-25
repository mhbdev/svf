import 'dart:async';
import '../../core/control/cancellation_token.dart';
import '../../core/schema/svf_schema.dart';
import '../../core/types/usage.dart';
import '../contracts/language_model.dart';
import '../contracts/message.dart';
import '../contracts/tool.dart';
import '../models/stream_result.dart';
import '../models/generation_event.dart';
import '../models/generate_request.dart';

/// Streams text output tokens in real-time using a specified [model].
///
/// Example:
/// ```dart
/// final stream = streamText(
///   model: svf.model('groq/llama-3.3-70b'),
///   prompt: 'Explain quantum computing simply.',
/// );
/// await for (final chunk in stream.textStream) {
///   stdout.write(chunk);
/// }
/// print('\nFull output: ${await stream.fullText}');
/// ```
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
  final effectiveMessages = <ChatMessage>[];

  if (system != null && system.isNotEmpty) {
    effectiveMessages.add(ChatMessage.system(system));
  }

  if (messages != null) {
    effectiveMessages.addAll(messages);
  } else if (prompt != null) {
    effectiveMessages.add(ChatMessage.user(prompt));
  } else {
    throw ArgumentError(
      'Either prompt or messages must be provided to streamText',
    );
  }

  // Single-subscription controllers buffer synchronous local-model output
  // until the caller attaches a listener. Broadcast controllers would drop
  // those first chunks.
  final textController = StreamController<String>();
  final fullTextCompleter = Completer<String>();
  final usageCompleter = Completer<SvfUsage>();
  final textBuffer = StringBuffer();
  final startTime = DateTime.now();
  final eventController = StreamController<GenerationEvent>();

  final rawStream = model.stream(
    GenerateRequest(
      messages: effectiveMessages,
      responseSchema: responseSchema,
      tools: tools ?? const [],
      temperature: temperature,
      maxTokens: maxTokens,
      topP: topP,
      stopSequences: stopSequences ?? const [],
      providerOptions: providerOptions,
      cancellationToken: cancellationToken,
    ),
  );

  rawStream.listen(
    (event) {
      eventController.add(event);
      if (event case TextDelta(:final text)) {
        textBuffer.write(text);
        textController.add(text);
      }
      if (event case GenerationFinished(:final usage)) {
        if (!usageCompleter.isCompleted) usageCompleter.complete(usage);
      }
    },
    onError: (Object error, StackTrace stackTrace) {
      if (!fullTextCompleter.isCompleted) {
        fullTextCompleter.completeError(error, stackTrace);
      }
      if (!usageCompleter.isCompleted) {
        usageCompleter.completeError(error, stackTrace);
      }
      textController.addError(error, stackTrace);
      eventController.add(GenerationFailed(error, stackTrace));
      eventController.close();
    },
    onDone: () {
      final aggregated = textBuffer.toString();
      if (!fullTextCompleter.isCompleted) {
        fullTextCompleter.complete(aggregated);
      }
      if (!usageCompleter.isCompleted) {
        // Approximate token usage if provider doesn't report it
        final estimatedTokens = (aggregated.length / 4).ceil();
        usageCompleter.complete(
          SvfUsage(
            completionTokens: estimatedTokens,
            durationMs: DateTime.now().difference(startTime).inMilliseconds,
          ),
        );
      }
      textController.close();
      eventController.close();
    },
    cancelOnError: false,
  );

  return StreamTextResult(
    textStream: textController.stream,
    events: eventController.stream,
    fullText: fullTextCompleter.future,
    usage: usageCompleter.future,
  );
}
