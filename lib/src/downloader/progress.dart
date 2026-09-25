/// Status state of a model download session.
enum DownloadStatus {
  idle,
  connecting,
  downloading,
  paused,
  verifying,
  completed,
  failed,
  canceled;

  bool get isTerminal =>
      this == DownloadStatus.completed ||
      this == DownloadStatus.failed ||
      this == DownloadStatus.canceled;
}

/// Real-time progress metric emitted during model downloading.
class DownloadProgress {
  /// The model manifest identifier.
  final String modelId;

  /// Current download state.
  final DownloadStatus status;

  /// Number of bytes downloaded so far.
  final int bytesDownloaded;

  /// Total expected bytes (from manifest or Content-Length header).
  final int totalBytes;

  /// Current transfer speed in bytes per second.
  final double speedBytesPerSecond;

  /// Optional error message on failure.
  final String? error;

  const DownloadProgress({
    required this.modelId,
    required this.status,
    required this.bytesDownloaded,
    required this.totalBytes,
    this.speedBytesPerSecond = 0.0,
    this.error,
  });

  /// Download percentage progress from 0.0 to 1.0.
  double get fraction {
    if (totalBytes <= 0) return 0.0;
    return (bytesDownloaded / totalBytes).clamp(0.0, 1.0);
  }

  /// Percentage progress formatted string (e.g. "45.8%").
  String get percentageFormatted => '${(fraction * 100).toStringAsFixed(1)}%';

  /// Transfer speed formatted string (e.g. "4.2 MB/s").
  String get speedFormatted {
    if (speedBytesPerSecond < 1024 * 1024) {
      return '${(speedBytesPerSecond / 1024).toStringAsFixed(1)} KB/s';
    }
    return '${(speedBytesPerSecond / (1024 * 1024)).toStringAsFixed(2)} MB/s';
  }

  /// Estimated time remaining based on current speed.
  Duration? get estimatedRemainingTime {
    if (speedBytesPerSecond <= 0 || totalBytes <= bytesDownloaded) return null;
    final remainingBytes = totalBytes - bytesDownloaded;
    final seconds = (remainingBytes / speedBytesPerSecond).round();
    return Duration(seconds: seconds);
  }

  @override
  String toString() =>
      'DownloadProgress($modelId: $status, $percentageFormatted, $speedFormatted)';
}
