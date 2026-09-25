import 'dart:async';
import '../../core/types/usage.dart';
import '../contracts/message.dart';
import 'generation_event.dart';

/// Stream result returned by [streamText].
class StreamTextResult {
  /// Real-time stream of output text delta chunks.
  final Stream<String> textStream;

  /// Full normalized event stream. [textStream] is a convenience projection.
  final Stream<GenerationEvent>? events;

  final Completer<String> _fullTextCompleter = Completer<String>();
  final Completer<SvfUsage> _usageCompleter = Completer<SvfUsage>();
  final Completer<List<ToolCall>> _toolCallsCompleter =
      Completer<List<ToolCall>>();

  StreamTextResult({
    required this.textStream,
    this.events,
    Future<String>? fullText,
    Future<SvfUsage>? usage,
    Future<List<ToolCall>>? toolCalls,
  }) {
    if (fullText != null) {
      fullText
          .then(_fullTextCompleter.complete)
          .catchError(_fullTextCompleter.completeError);
    }
    if (usage != null) {
      usage
          .then(_usageCompleter.complete)
          .catchError(_usageCompleter.completeError);
    }
    if (toolCalls != null) {
      toolCalls
          .then(_toolCallsCompleter.complete)
          .catchError(_toolCallsCompleter.completeError);
    }
  }

  /// Future resolving to the complete aggregated response text.
  Future<String> get fullText => _fullTextCompleter.future;

  /// Future resolving to the overall token usage.
  Future<SvfUsage> get usage => _usageCompleter.future;

  /// Future resolving to any tool calls made during streaming.
  Future<List<ToolCall>> get toolCalls => _toolCallsCompleter.future;
}

/// Stream result returned by [streamObject] for incremental structured JSON parsing.
class StreamObjectResult<T> {
  /// Stream emitting progressively updated partial JSON maps as tokens arrive.
  final Stream<Map<String, dynamic>> partialObjectStream;

  /// Future resolving to the final validated and typed structured object.
  final Future<T> finalObject;

  const StreamObjectResult({
    required this.partialObjectStream,
    required this.finalObject,
  });
}
