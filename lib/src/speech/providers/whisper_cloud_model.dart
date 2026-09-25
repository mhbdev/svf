import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../../core/errors/svf_exception.dart';
import '../../core/types/audio_source.dart';
import '../contracts/speech_to_text_model.dart';
import '../models/transcription_chunk.dart';
import '../models/transcription_options.dart';
import '../models/transcription_result.dart';

/// Direct Whisper SpeechToText provider supporting OpenAI Whisper and Groq Whisper.
class WhisperCloudModel implements SpeechToTextModel {
  @override
  final String modelId;

  final String apiKey;
  final String baseUrl;
  @override
  final String providerId;

  final http.Client _client;

  WhisperCloudModel({
    this.modelId = 'whisper-1',
    required this.apiKey,
    this.baseUrl = 'https://api.openai.com/v1',
    this.providerId = 'openai',
    http.Client? client,
  }) : _client = client ?? http.Client();

  /// Pre-configured factory for ultra-fast Groq Whisper (latency < 250ms).
  factory WhisperCloudModel.groq({
    required String apiKey,
    String modelId = 'whisper-large-v3-turbo',
    http.Client? client,
  }) {
    return WhisperCloudModel(
      modelId: modelId,
      apiKey: apiKey,
      baseUrl: 'https://api.groq.com/openai/v1',
      providerId: 'groq',
      client: client,
    );
  }

  @override
  bool get isOffline => false;

  @override
  Future<bool> isSupported() async => true;

  @override
  Future<TranscriptionResult> doTranscribe({
    required SvfAudioSource audio,
    TranscriptionOptions? options,
  }) async {
    final cleanBase = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    final url = Uri.parse('$cleanBase/audio/transcriptions');

    final bytes = await audio.readBytes();

    final request = http.MultipartRequest('POST', url);
    if (apiKey.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $apiKey';
    }

    final mimeParts = audio.mimeType.split('/');
    final mediaType = MediaType(mimeParts[0], mimeParts.length > 1 ? mimeParts[1] : 'octet-stream');

    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: audio.name,
        contentType: mediaType,
      ),
    );

    request.fields['model'] = modelId;
    request.fields['response_format'] = 'verbose_json';

    if (options?.language != null) {
      request.fields['language'] = options!.language!;
    }
    if (options?.prompt != null) {
      request.fields['prompt'] = options!.prompt!;
    }
    if (options?.temperature != null) {
      request.fields['temperature'] = options!.temperature!.toString();
    }
    if (options?.includeTimestamps == true) {
      request.fields['timestamp_granularities[]'] = 'word';
    }

    final streamedResponse = await _client.send(request);
    final responseBody = await streamedResponse.stream.bytesToString();

    if (streamedResponse.statusCode != 200) {
      throw SvfSpeechException(
        'Whisper API error: $responseBody',
        engineId: modelId,
      );
    }

    final data = jsonDecode(responseBody) as Map<String, dynamic>;
    final text = data['text'] as String? ?? '';
    final language = data['language'] as String?;
    final durationSec = (data['duration'] as num?)?.toDouble();
    final duration = durationSec != null ? Duration(milliseconds: (durationSec * 1000).round()) : null;

    final segments = <TranscriptionSegment>[];
    if (data['segments'] is List) {
      for (final seg in data['segments'] as List) {
        if (seg is Map<String, dynamic>) {
          final segWords = <TranscriptionWord>[];
          if (seg['words'] is List) {
            for (final w in seg['words'] as List) {
              if (w is Map<String, dynamic>) {
                segWords.add(
                  TranscriptionWord(
                    word: w['word'] as String? ?? '',
                    start: w['start'] != null ? Duration(milliseconds: ((w['start'] as num) * 1000).round()) : null,
                    end: w['end'] != null ? Duration(milliseconds: ((w['end'] as num) * 1000).round()) : null,
                  ),
                );
              }
            }
          }

          segments.add(
            TranscriptionSegment(
              id: seg['id'] as int? ?? 0,
              text: seg['text'] as String? ?? '',
              start: Duration(milliseconds: (((seg['start'] as num?) ?? 0) * 1000).round()),
              end: Duration(milliseconds: (((seg['end'] as num?) ?? 0) * 1000).round()),
              words: segWords,
            ),
          );
        }
      }
    }

    return TranscriptionResult(
      text: text,
      language: language,
      duration: duration,
      segments: segments,
      rawResponse: data,
    );
  }

  @override
  Stream<TranscriptionChunk> doStreamTranscription({
    Stream<List<int>>? audioStream,
    TranscriptionOptions? options,
  }) {
    // Cloud Whisper API does not provide a raw duplex WebSocket by default.
    // Emits batch result chunk when complete.
    final controller = StreamController<TranscriptionChunk>.broadcast();

    if (audioStream != null) {
      () async {
        try {
          final audio = SvfAudioSource.fromStream(audioStream);
          final result = await doTranscribe(audio: audio, options: options);
          controller.add(TranscriptionChunk(text: result.text, isFinal: true));
        } catch (e, st) {
          controller.addError(e, st);
        } finally {
          await controller.close();
        }
      }();
    } else {
      controller.addError(
        const SvfSpeechException('Stream transcription requires audioStream input for WhisperCloudModel', engineId: 'whisper-cloud'),
      );
      controller.close();
    }

    return controller.stream;
  }
}
