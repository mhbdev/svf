import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../audio/contracts/audio_recorder.dart';

/// Reactive controller managing waveform sample history, scrubbing, and seeking.
class SvfWaveformController extends ChangeNotifier {
  final List<double> _samples = [];
  double _playbackPosition = 0.0;
  int _maxVisibleSamples;
  StreamSubscription? _recorderSub;

  SvfWaveformController({this._maxVisibleSamples = 80});

  /// Unmodifiable view of recorded amplitude samples.
  List<double> get samples => List.unmodifiable(_samples);

  /// Current scrubber progress position from 0.0 to 1.0.
  double get playbackPosition => _playbackPosition;

  /// Maximum samples retained for live scrolling window.
  int get maxVisibleSamples => _maxVisibleSamples;

  set maxVisibleSamples(int val) {
    _maxVisibleSamples = val;
    notifyListeners();
  }

  /// Appends a new normalized amplitude sample [0.0 .. 1.0].
  void addSample(double normalizedSample) {
    final clamped = normalizedSample.clamp(0.02, 1.0);
    _samples.add(clamped);
    if (_samples.length > _maxVisibleSamples * 2) {
      // Retain sliding window to prevent unbounded memory growth during long recordings
      _samples.removeRange(0, _samples.length - (_maxVisibleSamples * 2));
    }
    notifyListeners();
  }

  /// Replaces all samples (e.g. when loading an existing audio file's peaks).
  void setSamples(List<double> newSamples) {
    _samples.clear();
    _samples.addAll(newSamples.map((s) => s.clamp(0.02, 1.0)));
    notifyListeners();
  }

  /// Updates the current playback seek position [0.0 .. 1.0].
  void seekTo(double position) {
    _playbackPosition = position.clamp(0.0, 1.0);
    notifyListeners();
  }

  /// Resets and clears all amplitude samples.
  void clear() {
    _samples.clear();
    _playbackPosition = 0.0;
    notifyListeners();
  }

  /// Automatically attaches this controller to an [ISvfAudioRecorder]'s amplitude stream.
  void attachRecorder(ISvfAudioRecorder recorder) {
    _recorderSub?.cancel();
    _recorderSub = recorder.amplitudeStream.listen((amp) {
      addSample(amp.normalized);
    });
  }

  /// Detaches from any actively subscribed recorder.
  void detachRecorder() {
    _recorderSub?.cancel();
    _recorderSub = null;
  }

  @override
  void dispose() {
    detachRecorder();
    super.dispose();
  }
}
