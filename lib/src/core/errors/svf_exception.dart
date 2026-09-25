/// Base exception for all Smart Voice Foundation (SVF) errors.
abstract class SvfException implements Exception {
  /// A human-readable error message.
  final String message;

  /// Optional underlying cause or stack trace details.
  final Object? cause;

  const SvfException(this.message, {this.cause});

  @override
  String toString() {
    if (cause != null) {
      return '$runtimeType: $message (Cause: $cause)';
    }
    return '$runtimeType: $message';
  }
}

/// Thrown when an error occurs in the Language Model subsystem.
class SvfModelException extends SvfException {
  /// The model identifier that raised the error.
  final String? modelId;

  /// HTTP status code or provider error code if applicable.
  final int? statusCode;

  const SvfModelException(
    super.message, {
    this.modelId,
    this.statusCode,
    super.cause,
  });

  @override
  String toString() {
    final buffer = StringBuffer('SvfModelException: $message');
    if (modelId != null) buffer.write(' [Model: $modelId]');
    if (statusCode != null) buffer.write(' [Status: $statusCode]');
    if (cause != null) buffer.write(' (Cause: $cause)');
    return buffer.toString();
  }
}

/// Thrown when an error occurs during audio recording, streaming, or playback.
class SvfAudioException extends SvfException {
  final String? reasonCode;

  const SvfAudioException(super.message, {this.reasonCode, super.cause});
}

/// Thrown when an error occurs in the Speech-to-Text or Text-to-Speech engines.
class SvfSpeechException extends SvfException {
  final String? engineId;

  const SvfSpeechException(super.message, {this.engineId, super.cause});
}

/// Thrown when an error occurs during resumable model downloads or checksum verification.
class SvfDownloadException extends SvfException {
  final String? modelId;
  final int? bytesDownloaded;

  const SvfDownloadException(
    super.message, {
    this.modelId,
    this.bytesDownloaded,
    super.cause,
  });
}

/// Thrown when an operation is not supported on the current platform.
class SvfUnsupportedPlatformException extends SvfException {
  final String platform;
  final String feature;

  SvfUnsupportedPlatformException({
    required this.feature,
    required this.platform,
    String? message,
  }) : super(message ?? '$feature is not supported on platform: $platform');
}

/// Thrown when structured output schema validation fails.
class SvfSchemaValidationException extends SvfException {
  final Map<String, dynamic>? rawOutput;
  final List<String> validationErrors;

  const SvfSchemaValidationException(
    super.message, {
    this.rawOutput,
    this.validationErrors = const [],
    super.cause,
  });
}
