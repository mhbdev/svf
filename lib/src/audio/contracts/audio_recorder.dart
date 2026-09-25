import 'dart:async';
import '../../core/types/audio_format.dart';
import '../../core/types/audio_source.dart';
import '../models/amplitude.dart';
import '../models/recorder_state.dart';

/// Universal audio recorder contract for Android, Web, and desktop.
abstract interface class ISvfAudioRecorder {
  /// Stream of recorder lifecycle states.
  Stream<SvfRecorderState> get stateStream;

  /// Real-time stream of audio amplitude values for waveform visualizers.
  Stream<SvfAmplitude> get amplitudeStream;

  /// Current state of the recorder.
  SvfRecorderState get state;

  /// Checks if microphone capture permission has been granted.
  Future<bool> hasPermission();

  /// Starts recording audio.
  /// On native platforms, saves to [destinationPath] if provided.
  /// On Web, records in-memory or to temporary blob.
  Future<void> start({
    SvfAudioFormat format = SvfAudioFormat.m4a,
    int sampleRate = 44100,
    int bitRate = 128000,
    String? destinationPath,
  });

  /// Temporarily pauses the ongoing recording session.
  Future<void> pause();

  /// Resumes a paused recording session.
  Future<void> resume();

  /// Stops recording and returns the recorded [SvfAudioSource].
  Future<SvfAudioSource> stop();

  /// Releases hardware and underlying streams.
  Future<void> dispose();
}
