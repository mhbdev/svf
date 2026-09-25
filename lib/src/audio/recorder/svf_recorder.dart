import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:record/record.dart';
import '../../core/errors/svf_exception.dart';
import '../../core/types/audio_format.dart';
import '../../core/types/audio_source.dart';
import '../contracts/audio_recorder.dart';
import '../models/amplitude.dart';
import '../models/recorder_state.dart';

/// Production-ready audio recorder implementation wrapping `record: ^7.1.1`.
/// Supports Android, Web, iOS, macOS, Windows, and Linux.
class SvfRecorder implements ISvfAudioRecorder {
  final AudioRecorder _recorder;

  final StreamController<SvfRecorderState> _stateController =
      StreamController<SvfRecorderState>.broadcast();
  final StreamController<SvfAmplitude> _amplitudeController =
      StreamController<SvfAmplitude>.broadcast();

  StreamSubscription<Amplitude>? _amplitudeSub;
  SvfRecorderState _state = SvfRecorderState.idle;
  SvfAudioFormat _currentFormat = SvfAudioFormat.m4a;

  SvfRecorder({AudioRecorder? recorder})
    : _recorder = recorder ?? AudioRecorder();

  @override
  Stream<SvfRecorderState> get stateStream => _stateController.stream;

  @override
  Stream<SvfAmplitude> get amplitudeStream => _amplitudeController.stream;

  @override
  SvfRecorderState get state => _state;

  @override
  Future<bool> hasPermission() async {
    try {
      return await _recorder.hasPermission();
    } catch (e) {
      throw SvfAudioException(
        'Failed to query microphone permissions',
        cause: e,
      );
    }
  }

  @override
  Future<void> start({
    SvfAudioFormat format = SvfAudioFormat.m4a,
    int sampleRate = 44100,
    int bitRate = 128000,
    String? destinationPath,
  }) async {
    final granted = await hasPermission();
    if (!granted) {
      throw const SvfAudioException(
        'Microphone permission was denied by the user',
      );
    }

    _currentFormat = format;
    final encoder = _mapFormatToEncoder(format);

    final config = RecordConfig(
      encoder: encoder,
      sampleRate: sampleRate,
      bitRate: bitRate,
    );

    try {
      // On Web, passing an empty path tells record_web to record in-memory / blob
      final path = destinationPath ?? (kIsWeb ? '' : null);
      if (path != null) {
        await _recorder.start(config, path: path);
      } else {
        await _recorder.start(config, path: '');
      }

      _updateState(SvfRecorderState.recording);

      // Start listening to amplitude stream (every 60ms for smooth 60fps waveform UI)
      _amplitudeSub?.cancel();
      _amplitudeSub = _recorder
          .onAmplitudeChanged(const Duration(milliseconds: 60))
          .listen(
            (amp) {
              _amplitudeController.add(
                SvfAmplitude(current: amp.current, max: amp.max),
              );
            },
            onError: (Object error, StackTrace stackTrace) {
              _amplitudeController.add(SvfAmplitude.silence);
            },
          );
    } catch (e) {
      _updateState(SvfRecorderState.idle);
      throw SvfAudioException('Failed to start audio recording: $e', cause: e);
    }
  }

  @override
  Future<void> pause() async {
    if (_state != SvfRecorderState.recording) return;
    try {
      await _recorder.pause();
      _updateState(SvfRecorderState.paused);
    } catch (e) {
      throw SvfAudioException('Failed to pause recording: $e', cause: e);
    }
  }

  @override
  Future<void> resume() async {
    if (_state != SvfRecorderState.paused) return;
    try {
      await _recorder.resume();
      _updateState(SvfRecorderState.recording);
    } catch (e) {
      throw SvfAudioException('Failed to resume recording: $e', cause: e);
    }
  }

  @override
  Future<SvfAudioSource> stop() async {
    if (_state == SvfRecorderState.idle) {
      throw const SvfAudioException('Cannot stop an idle recorder');
    }

    try {
      _amplitudeSub?.cancel();
      _amplitudeSub = null;

      final pathResult = await _recorder.stop();
      _updateState(SvfRecorderState.stopped);

      if (pathResult == null || pathResult.isEmpty) {
        throw const SvfAudioException(
          'Recorder stopped but produced no output path or data',
        );
      }

      _updateState(SvfRecorderState.idle);

      if (kIsWeb) {
        final response = await http.get(Uri.parse(pathResult));
        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw SvfAudioException(
            'Failed to read browser recording blob (${response.statusCode})',
          );
        }
        return SvfAudioSource.fromBytes(
          response.bodyBytes,
          name: 'recording.${_currentFormat.extension}',
          format: _currentFormat,
        );
      }

      return SvfAudioSource.fromFile(pathResult, format: _currentFormat);
    } catch (e) {
      _updateState(SvfRecorderState.idle);
      throw SvfAudioException('Failed to stop recording: $e', cause: e);
    }
  }

  @override
  Future<void> dispose() async {
    _amplitudeSub?.cancel();
    _amplitudeSub = null;
    await _recorder.dispose();
    await _stateController.close();
    await _amplitudeController.close();
  }

  void _updateState(SvfRecorderState newState) {
    _state = newState;
    if (!_stateController.isClosed) {
      _stateController.add(newState);
    }
  }

  AudioEncoder _mapFormatToEncoder(SvfAudioFormat format) {
    switch (format) {
      case SvfAudioFormat.m4a:
      case SvfAudioFormat.aac:
        return AudioEncoder.aacLc;
      case SvfAudioFormat.wav:
        return AudioEncoder.wav;
      case SvfAudioFormat.opus:
      case SvfAudioFormat.webm:
        return AudioEncoder.opus;
      case SvfAudioFormat.pcm16:
        return AudioEncoder.pcm16bits;
    }
  }
}
