import '../../core/types/usage.dart';
import '../contracts/message.dart';

/// The reason why model generation concluded.
enum FinishReason {
  stop('stop'),
  length('length'),
  toolCalls('tool_calls'),
  contentFilter('content_filter'),
  other('other');

  final String value;
  const FinishReason(this.value);

  static FinishReason fromString(String? val) {
    if (val == null) return FinishReason.stop;
    final lower = val.toLowerCase();
    if (lower.contains('stop')) return FinishReason.stop;
    if (lower.contains('length') || lower.contains('max_token')) return FinishReason.length;
    if (lower.contains('tool') || lower.contains('function')) return FinishReason.toolCalls;
    if (lower.contains('filter') || lower.contains('safety')) return FinishReason.contentFilter;
    return FinishReason.other;
  }
}

/// Result returned by [generateText].
class GenerateTextResult {
  /// The primary generated text response.
  final String text;

  /// Optional list of tool calls requested by the model.
  final List<ToolCall> toolCalls;

  /// The reason why generation finished.
  final FinishReason finishReason;

  /// Token usage and latency metrics.
  final SvfUsage usage;

  /// Raw response body map from the provider.
  final Map<String, dynamic>? rawResponse;

  const GenerateTextResult({
    required this.text,
    this.toolCalls = const [],
    this.finishReason = FinishReason.stop,
    this.usage = SvfUsage.zero,
    this.rawResponse,
  });

  /// True if the model requested one or more tool calls.
  bool get hasToolCalls => toolCalls.isNotEmpty;

  @override
  String toString() => 'GenerateTextResult(text: $text, toolCalls: ${toolCalls.length}, reason: ${finishReason.value})';
}

/// Result returned by [generateObject] containing a typed or structured object.
class GenerateObjectResult<T> {
  /// The parsed structured object.
  final T object;

  /// The raw JSON map extracted from the generation.
  final Map<String, dynamic> rawJson;

  /// Token usage and latency metrics.
  final SvfUsage usage;

  /// Optional validation or parsing warnings.
  final List<String> warnings;

  const GenerateObjectResult({
    required this.object,
    required this.rawJson,
    this.usage = SvfUsage.zero,
    this.warnings = const [],
  });

  @override
  String toString() => 'GenerateObjectResult<$T>(object: $object, warnings: ${warnings.length})';
}
