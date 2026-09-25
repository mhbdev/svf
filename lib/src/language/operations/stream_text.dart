import 'dart:async';
import '../../core/types/usage.dart';
import '../contracts/language_model.dart';
import '../contracts/message.dart';
import '../contracts/tool.dart';
import '../models/stream_result.dart';

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
  List<SvfTool>? tools,
  double? temperature,
  int? maxTokens,
  double? topP,
  List<String>? stopSequences,
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
    throw ArgumentError('Either prompt or messages must be provided to streamText');
  }

  final textController = StreamController<String>.broadcast();
  final fullTextCompleter = Completer<String>();
  final usageCompleter = Completer<SvfUsage>();
  final textBuffer = StringBuffer();
  final startTime = DateTime.now();

  final rawStream = model.doStream(
    messages: effectiveMessages,
    tools: tools,
    temperature: temperature,
    maxTokens: maxTokens,
    topP: topP,
    stopSequences: stopSequences,
  );

  rawStream.listen(
    (chunk) {
      textBuffer.write(chunk);
      textController.add(chunk);
    },
    onError: (e, st) {
      if (!fullTextCompleter.isCompleted) fullTextCompleter.completeError(e, st);
      if (!usageCompleter.isCompleted) usageCompleter.completeError(e, st);
      textController.addError(e, st);
    },
    onDone: () {
      final aggregated = textBuffer.toString();
      if (!fullTextCompleter.isCompleted) fullTextCompleter.complete(aggregated);
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
    },
    cancelOnError: false,
  );

  return StreamTextResult(
    textStream: textController.stream,
    fullText: fullTextCompleter.future,
    usage: usageCompleter.future,
  );
}
