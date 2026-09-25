/// Optional parameters for controlling audio transcription behavior.
class TranscriptionOptions {
  /// BCP-47 language tag (e.g. "en", "es", "fr", "auto").
  final String? language;

  /// Optional context prompt / glossary to guide model transcription of specialized terms.
  final String? prompt;

  /// Sampling temperature for the model (e.g. 0.0 for deterministic output).
  final double? temperature;

  /// Whether to include word-level timestamps in the result.
  final bool includeTimestamps;

  const TranscriptionOptions({
    this.language,
    this.prompt,
    this.temperature,
    this.includeTimestamps = false,
  });
}
