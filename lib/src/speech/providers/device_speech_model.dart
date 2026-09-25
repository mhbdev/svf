import 'dart:async';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../core/errors/svf_exception.dart';
import '../../core/types/audio_source.dart';
import '../contracts/speech_to_text_model.dart';
import '../models/transcription_chunk.dart';
import '../models/transcription_options.dart';
import '../models/transcription_result.dart';

/// Speech-to-Text provider wrapping device-native speech recognition (`speech_to_text: ^7.5.0`).
/// Supports Android SpeechRecognizer, iOS Speech framework, and Web Speech API.
class DeviceSpeechModel implements SpeechToTextModel {
  final stt.SpeechToText _speech;
  bool _isInitialized = false;

  DeviceSpeechModel({stt.SpeechToText? speech})
      : _speech = speech ?? stt.SpeechToText();

  @override
  String get modelId => 'device-stt';

  @override
  String get providerId => 'device';

  @override
  bool get isOffline => false; // Device engine might use cloud or offline pack depending on OS settings

  @override
  Future<bool> isSupported() async {
    try {
      if (!_isInitialized) {
        _isInitialized = await _speech.initialize();
      }
      return _isInitialized;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<TranscriptionResult> doTranscribe({
    required SvfAudioSource audio,
    TranscriptionOptions? options,
  }) async {
    // Device STT listens directly from microphone in real-time.
    // For file-based batch transcription, users should use WhisperCloudModel or an offline whisper model.
    throw SvfUnsupportedPlatformException(
      feature: 'Batch file transcription with DeviceSpeechModel',
      platform: 'Device ASR',
      message: 'DeviceSpeechModel recognizes live microphone speech. For recorded audio files, use WhisperCloudModel or OfflineWhisperModel.',
    );
  }

  @override
  Stream<TranscriptionChunk> doStreamTranscription({
    Stream<List<int>>? audioStream,
    TranscriptionOptions? options,
  }) {
    final controller = StreamController<TranscriptionChunk>.broadcast();

    () async {
      final available = await isSupported();
      if (!available) {
        controller.addError(
          const SvfSpeechException('Device speech recognition is not available or permissions denied', engineId: 'device-stt'),
        );
        await controller.close();
        return;
      }

      await _speech.listen(
        onResult: (result) {
          controller.add(
            TranscriptionChunk(
              text: result.recognizedWords,
              isFinal: result.finalResult,
              confidence: result.confidence > 0 ? result.confidence : null,
            ),
          );

          if (result.finalResult) {
            controller.close();
          }
        },
        listenOptions: stt.SpeechListenOptions(
          localeId: options?.language,
        ),
      );
    }();

    return controller.stream;
  }
}
