import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/errors/svf_exception.dart';
import '../../core/types/audio_format.dart';
import '../../core/types/audio_source.dart';
import '../contracts/text_to_speech_model.dart';

/// Direct OpenAI Text-to-Speech provider (tts-1, tts-1-hd).
class OpenAiSpeechModel implements TextToSpeechModel {
  @override
  final String modelId;

  final String apiKey;
  final String baseUrl;
  final http.Client _client;

  OpenAiSpeechModel({
    this.modelId = 'tts-1',
    required this.apiKey,
    this.baseUrl = 'https://api.openai.com/v1',
    http.Client? client,
  }) : _client = client ?? http.Client();

  @override
  String get providerId => 'openai';

  @override
  Future<SvfAudioSource> doSynthesize({
    required String text,
    SynthesisOptions? options,
  }) async {
    final cleanBase = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    final url = Uri.parse('$cleanBase/audio/speech');

    final voice = options?.voice ?? 'alloy';
    final format = options?.format ?? SvfAudioFormat.aac;

    final body = {
      'model': modelId,
      'input': text,
      'voice': voice,
      'response_format': format.extension == 'm4a' ? 'aac' : format.extension,
      if (options != null) 'speed': options.speed,
    };

    final response = await _client.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        if (apiKey.isNotEmpty) 'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      throw SvfSpeechException(
        'OpenAI TTS error: ${response.body}',
        engineId: modelId,
      );
    }

    return SvfAudioSource.fromBytes(
      response.bodyBytes,
      name: 'speech_${DateTime.now().millisecondsSinceEpoch}.${format.extension}',
      format: format,
    );
  }
}
