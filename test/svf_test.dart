import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:svf/svf.dart';

// Mock language model for deterministic unit testing
class MockLanguageModel implements LanguageModel {
  @override
  final String modelId;
  @override
  final String providerId;
  @override
  final bool isOffline;

  final Future<GenerateTextResult> Function({
    required List<ChatMessage> messages,
    SvfSchema? responseSchema,
    List<SvfTool>? tools,
  }) onGenerate;

  final Stream<String> Function({
    required List<ChatMessage> messages,
    SvfSchema? responseSchema,
    List<SvfTool>? tools,
  })? onStream;

  MockLanguageModel({
    this.modelId = 'mock-model',
    this.providerId = 'mock',
    this.isOffline = true,
    required this.onGenerate,
    this.onStream,
  });

  @override
  Future<GenerateTextResult> doGenerate({
    required List<ChatMessage> messages,
    SvfSchema? responseSchema,
    List<SvfTool>? tools,
    double? temperature,
    int? maxTokens,
    double? topP,
    List<String>? stopSequences,
  }) {
    return onGenerate(
      messages: messages,
      responseSchema: responseSchema,
      tools: tools,
    );
  }

  @override
  Stream<String> doStream({
    required List<ChatMessage> messages,
    SvfSchema? responseSchema,
    List<SvfTool>? tools,
    double? temperature,
    int? maxTokens,
    double? topP,
    List<String>? stopSequences,
  }) {
    if (onStream != null) {
      return onStream!(
        messages: messages,
        responseSchema: responseSchema,
        tools: tools,
      );
    }
    return Stream.value('mock stream output');
  }
}

// Mock speech-to-text model
class MockSpeechToTextModel implements SpeechToTextModel {
  @override
  final String modelId;
  @override
  final String providerId;
  @override
  final bool isOffline;
  final bool supported;

  MockSpeechToTextModel({
    this.modelId = 'mock-stt',
    this.providerId = 'mock',
    this.isOffline = false,
    this.supported = true,
  });

  @override
  Future<bool> isSupported() async => supported;

  @override
  Future<TranscriptionResult> doTranscribe({
    required SvfAudioSource audio,
    TranscriptionOptions? options,
  }) async {
    return const TranscriptionResult(
      text: 'Patient Alice has mild fever for three days.',
      confidence: 0.98,
      language: 'en',
    );
  }

  @override
  Stream<TranscriptionChunk> doStreamTranscription({
    Stream<List<int>>? audioStream,
    TranscriptionOptions? options,
  }) {
    return Stream.fromIterable([
      const TranscriptionChunk(text: 'Patient Alice', isFinal: false),
      const TranscriptionChunk(text: 'Patient Alice has mild fever', isFinal: true),
    ]);
  }
}

void main() {
  group('SvfSchema & JSON Schema Generation', () {
    test('Builds strict JSON schema for structured objects', () {
      final schema = SvfSchema.object(
        properties: {
          'name': SvfSchema.string(description: 'Full name', minLength: 2),
          'age': SvfSchema.integer(description: 'Age in years', minimum: 0),
          'role': SvfSchema.enumeration(['Admin', 'Doctor', 'Patient']),
          'tags': SvfSchema.array(items: SvfSchema.string()),
          'isVerified': SvfSchema.boolean(),
        },
        required: ['name', 'age', 'role'],
      );

      final jsonSchema = schema.toJsonSchema(strict: true);

      expect(jsonSchema['type'], 'object');
      expect(jsonSchema['required'], ['name', 'age', 'role']);
      expect(jsonSchema['additionalProperties'], isFalse);

      final props = jsonSchema['properties'] as Map<String, dynamic>;
      expect(props['name']['type'], 'string');
      expect(props['age']['type'], 'integer');
      expect(props['role']['enum'], ['Admin', 'Doctor', 'Patient']);
      expect(props['tags']['type'], 'array');
      expect(props['isVerified']['type'], 'boolean');
    });

    test('Validates data correctly against schema', () {
      final schema = SvfSchema.object(
        properties: {
          'name': SvfSchema.string(minLength: 2),
          'age': SvfSchema.integer(minimum: 18),
          'role': SvfSchema.enumeration(['User', 'Admin']),
        },
        required: ['name', 'age'],
      );

      // Valid map
      final validData = {'name': 'John', 'age': 25, 'role': 'Admin'};
      expect(schema.isValid(validData), isTrue);
      expect(schema.validate(validData), isEmpty);

      // Missing required field
      final missingAge = {'name': 'John'};
      expect(schema.isValid(missingAge), isFalse);
      expect(schema.validate(missingAge).any((e) => e.contains('age')), isTrue);

      // Constraint violation
      final underAge = {'name': 'J', 'age': 16, 'role': 'Hacker'};
      final errors = schema.validate(underAge);
      expect(errors.length, 3); // name too short, age < 18, role not in enum
    });
  });

  group('Vercel AI SDK Style Operations', () {
    test('generateText generates response and formats prompts', () async {
      final mockModel = MockLanguageModel(
        onGenerate: ({required messages, responseSchema, tools}) async {
          expect(messages.first.role, ChatRole.system);
          expect(messages.last.role, ChatRole.user);
          return const GenerateTextResult(
            text: 'Hello, this is a response from SVF!',
            usage: SvfUsage(promptTokens: 10, completionTokens: 8),
          );
        },
      );

      final result = await generateText(
        model: mockModel,
        system: 'You are a helpful voice assistant.',
        prompt: 'Say hello!',
      );

      expect(result.text, 'Hello, this is a response from SVF!');
      expect(result.usage.totalTokens, 18);
    });

    test('generateObject parses structured JSON and handles markdown wrapper', () async {
      final mockModel = MockLanguageModel(
        onGenerate: ({required messages, responseSchema, tools}) async {
          // Returns JSON wrapped in markdown code fence
          return const GenerateTextResult(
            text: '''
```json
{
  "name": "Alice Johnson",
  "age": 30,
  "symptoms": ["headache", "fatigue"],
  "confirmed": true
}
```
''',
            usage: SvfUsage(promptTokens: 25, completionTokens: 15),
          );
        },
      );

      final patientSchema = SvfSchema.object(
        properties: {
          'name': SvfSchema.string(),
          'age': SvfSchema.integer(),
          'symptoms': SvfSchema.array(items: SvfSchema.string()),
          'confirmed': SvfSchema.boolean(),
        },
      );

      final result = await generateObject(
        model: mockModel,
        schema: patientSchema,
        prompt: 'Extract patient data: Alice Johnson, age 30, symptoms: headache, fatigue.',
      );

      expect(result.object['name'], 'Alice Johnson');
      expect(result.object['age'], 30);
      expect(result.object['symptoms'], ['headache', 'fatigue']);
      expect(result.object['confirmed'], isTrue);
      expect(result.warnings, isEmpty);
    });

    test('agentLoop handles tool execution and multi-turn reasoning', () async {
      int turn = 0;
      final mockModel = MockLanguageModel(
        onGenerate: ({required messages, responseSchema, tools}) async {
          turn++;
          if (turn == 1) {
            // Model calls tool in turn 1
            return const GenerateTextResult(
              text: 'Looking up patient records...',
              toolCalls: [
                ToolCall(
                  id: 'call_1',
                  name: 'lookup_patient',
                  arguments: {'patient_id': 'P-101'},
                ),
              ],
            );
          } else {
            // Model produces final answer in turn 2
            return const GenerateTextResult(
              text: 'Patient Alice is due for checkup.',
            );
          }
        },
      );

      final lookupTool = SvfTool(
        name: 'lookup_patient',
        description: 'Looks up patient records by ID',
        parameters: SvfSchema.object(
          properties: {'patient_id': SvfSchema.string()},
        ),
        execute: (args) async {
          expect(args['patient_id'], 'P-101');
          return {'id': 'P-101', 'name': 'Alice', 'status': 'due'};
        },
      );

      final result = await agentLoop(
        model: mockModel,
        messages: [ChatMessage.user('Check status of patient P-101')],
        tools: [lookupTool],
        maxSteps: 3,
      );

      expect(result.text, 'Patient Alice is due for checkup.');
      expect(result.steps.length, 2);
      expect(result.steps[0].toolExecutions.first.isSuccess, isTrue);
    });
  });

  group('Universal Audio & Waveform Foundation', () {
    test('SvfAudioSource handles bytes, base64, and MIME types', () async {
      final sampleBytes = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]);
      final source = SvfAudioSource.fromBytes(
        sampleBytes,
        name: 'test_voice.m4a',
        format: SvfAudioFormat.m4a,
      );

      expect(source.format, SvfAudioFormat.m4a);
      expect(source.mimeType, 'audio/mp4');
      expect(source.name, 'test_voice.m4a');
      expect(source.hasBytes, isTrue);

      final readBytes = await source.readBytes();
      expect(readBytes, sampleBytes);

      final b64 = await source.toBase64();
      expect(b64, base64Encode(sampleBytes));

      final dataUri = await source.toDataUri();
      expect(dataUri.startsWith('data:audio/mp4;base64,'), isTrue);
    });

    test('SvfAmplitude correctly normalizes logarithmic decibels', () {
      const silence = SvfAmplitude(current: -160.0, max: -160.0);
      expect(silence.normalized, 0.02);

      const loud = SvfAmplitude(current: 0.0, max: 0.0);
      expect(loud.normalized, 1.0);

      const mid = SvfAmplitude(current: -30.0, max: 0.0);
      expect(mid.normalized, closeTo(0.5, 0.01));
    });

    test('SvfWaveformController manages amplitude window and scrub position', () {
      final controller = SvfWaveformController(maxVisibleSamples: 10);
      expect(controller.samples, isEmpty);

      // Add samples
      controller.addSample(0.2);
      controller.addSample(0.8);
      expect(controller.samples.length, 2);

      // Scrubbing
      controller.seekTo(0.75);
      expect(controller.playbackPosition, 0.75);

      // Clear
      controller.clear();
      expect(controller.samples, isEmpty);
      expect(controller.playbackPosition, 0.0);
    });
  });

  group('Speech-to-Text & SpeechRouter', () {
    test('transcribeAudio returns transcription result', () async {
      final mockStt = MockSpeechToTextModel();
      final audio = SvfAudioSource.fromBytes(
        Uint8List.fromList([0, 0, 0]),
        format: SvfAudioFormat.wav,
      );

      final result = await transcribeAudio(
        model: mockStt,
        audio: audio,
      );

      expect(result.text, 'Patient Alice has mild fever for three days.');
      expect(result.confidence, 0.98);
      expect(result.language, 'en');
    });

    test('SpeechRouter routes to fallback when primary fails or is unsupported', () async {
      final unsupportedPrimary = MockSpeechToTextModel(
        modelId: 'primary-offline',
        supported: false,
      );
      final workingFallback = MockSpeechToTextModel(
        modelId: 'fallback-cloud',
        supported: true,
      );

      final router = SpeechRouter(
        primary: unsupportedPrimary,
        fallback: workingFallback,
      );

      final audio = SvfAudioSource.fromBytes(Uint8List.fromList([1, 2, 3]));
      final result = await router.doTranscribe(audio: audio);

      expect(result.text, isNotEmpty);
    });
  });

  group('Model Downloader & Registry', () {
    test('ModelManifest formats sizes and ModelRegistry contains built-ins', () {
      final whisper = ModelRegistry.whisperTinyEn;
      expect(whisper.id, 'whisper-tiny-en');
      expect(whisper.formattedSize, '74.1 MB');
      expect(whisper.sha256, isNotNull);

      final gemma = ModelRegistry.gemma2bQ4;
      expect(gemma.id, 'gemma-2b-it-q4');
      expect(gemma.formattedSize, '1.40 GB');

      expect(ModelRegistry.find('whisper-tiny-en'), isNotNull);
      expect(ModelRegistry.find('non-existent'), isNull);
    });

    test('DownloadProgress calculates progress percentage and formatted speed', () {
      const progress = DownloadProgress(
        modelId: 'whisper-tiny-en',
        status: DownloadStatus.downloading,
        bytesDownloaded: 40000000,
        totalBytes: 80000000,
        speedBytesPerSecond: 5242880, // 5 MB/s
      );

      expect(progress.fraction, 0.5);
      expect(progress.percentageFormatted, '50.0%');
      expect(progress.speedFormatted, '5.00 MB/s');
      expect(progress.estimatedRemainingTime?.inSeconds, closeTo(7, 2));
    });
  });

  group('SvfUsage Metrics', () {
    test('Combines token metrics correctly with operator +', () {
      const u1 = SvfUsage(promptTokens: 10, completionTokens: 5, durationMs: 120);
      const u2 = SvfUsage(promptTokens: 20, completionTokens: 15, durationMs: 200);

      final total = u1 + u2;
      expect(total.promptTokens, 30);
      expect(total.completionTokens, 20);
      expect(total.totalTokens, 50);
      expect(total.durationMs, 320);
    });
  });
}
