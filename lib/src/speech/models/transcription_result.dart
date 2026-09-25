/// Represents an individual word with timing information in a transcription.
class TranscriptionWord {
  final String word;
  final Duration? start;
  final Duration? end;
  final double? confidence;

  const TranscriptionWord({
    required this.word,
    this.start,
    this.end,
    this.confidence,
  });

  Map<String, dynamic> toMap() => {
        'word': word,
        if (start != null) 'startMs': start!.inMilliseconds,
        if (end != null) 'endMs': end!.inMilliseconds,
        if (confidence != null) 'confidence': confidence,
      };
}

/// Represents a segment / sentence with timestamps.
class TranscriptionSegment {
  final int id;
  final String text;
  final Duration start;
  final Duration end;
  final List<TranscriptionWord> words;

  const TranscriptionSegment({
    required this.id,
    required this.text,
    required this.start,
    required this.end,
    this.words = const [],
  });
}

/// Result returned from batch audio transcription.
class TranscriptionResult {
  /// The complete recognized transcript string.
  final String text;

  /// Detected or specified language code (e.g. "en", "es").
  final String? language;

  /// Overall confidence score from 0.0 to 1.0 if available.
  final double? confidence;

  /// Duration of processed audio.
  final Duration? duration;

  /// Optional breakdown into timed segments.
  final List<TranscriptionSegment> segments;

  /// Optional breakdown into individual timed words.
  final List<TranscriptionWord> words;

  /// Raw response data from the engine.
  final Map<String, dynamic>? rawResponse;

  const TranscriptionResult({
    required this.text,
    this.language,
    this.confidence,
    this.duration,
    this.segments = const [],
    this.words = const [],
    this.rawResponse,
  });

  @override
  String toString() => 'TranscriptionResult(text: "$text", lang: $language, confidence: $confidence)';
}
