/// Tracks model token usage and operational metrics.
class SvfUsage {
  /// Number of tokens in the prompt / input context.
  final int promptTokens;

  /// Number of tokens generated in the completion / output.
  final int completionTokens;

  /// Total tokens consumed (promptTokens + completionTokens).
  final int totalTokens;

  /// Duration of the execution in milliseconds, if tracked.
  final int? durationMs;

  const SvfUsage({
    this.promptTokens = 0,
    this.completionTokens = 0,
    int? totalTokens,
    this.durationMs,
  }) : totalTokens = totalTokens ?? (promptTokens + completionTokens);

  /// Empty / zero usage instance.
  static const zero = SvfUsage();

  /// Combines two usage metrics together.
  SvfUsage operator +(SvfUsage other) {
    return SvfUsage(
      promptTokens: promptTokens + other.promptTokens,
      completionTokens: completionTokens + other.completionTokens,
      totalTokens: totalTokens + other.totalTokens,
      durationMs: (durationMs != null || other.durationMs != null)
          ? (durationMs ?? 0) + (other.durationMs ?? 0)
          : null,
    );
  }

  /// Converts to Map for serialization or logging.
  Map<String, dynamic> toMap() {
    return {
      'promptTokens': promptTokens,
      'completionTokens': completionTokens,
      'totalTokens': totalTokens,
      if (durationMs != null) 'durationMs': durationMs,
    };
  }

  @override
  String toString() =>
      'SvfUsage(prompt: $promptTokens, completion: $completionTokens, total: $totalTokens, duration: ${durationMs}ms)';
}
