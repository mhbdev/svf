/// Represents a real-time partial or finalized transcription chunk during live audio streaming.
class TranscriptionChunk {
  /// The transcribed text in this chunk.
  final String text;

  /// True if this chunk has been definitively finalized by the speech engine,
  /// false if it is an interim / provisional hypothesis that might change.
  final bool isFinal;

  /// Confidence score between 0.0 and 1.0.
  final double? confidence;

  /// Timestamp offset from the start of the audio stream.
  final Duration? timestamp;

  const TranscriptionChunk({
    required this.text,
    this.isFinal = false,
    this.confidence,
    this.timestamp,
  });

  @override
  String toString() => 'TranscriptionChunk(text: "$text", isFinal: $isFinal)';
}
