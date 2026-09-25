/// Lifecycle state of the audio recorder.
enum SvfRecorderState {
  /// The recorder is idle and ready to record.
  idle,

  /// Actively capturing audio.
  recording,

  /// Audio capture is temporarily paused.
  paused,

  /// Finalizing and saving recorded audio.
  stopped;

  bool get isRecording => this == SvfRecorderState.recording;
  bool get isPaused => this == SvfRecorderState.paused;
  bool get isIdle => this == SvfRecorderState.idle;
}
