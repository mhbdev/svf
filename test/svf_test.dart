import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
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
  })
  onGenerate;

  final Stream<String> Function({
    required List<ChatMessage> messages,
    SvfSchema? responseSchema,
    List<SvfTool>? tools,
  })?
  onStream;

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
      const TranscriptionChunk(
        text: 'Patient Alice has mild fever',
        isFinal: true,
      ),
    ]);
  }
}

class FakeAudioRecorder implements ISvfAudioRecorder {
  @override
  Stream<SvfRecorderState> get stateStream =>
      Stream.value(SvfRecorderState.idle);

  @override
  Stream<SvfAmplitude> get amplitudeStream => const Stream.empty();

  @override
  SvfRecorderState get state => SvfRecorderState.idle;

  @override
  Future<bool> hasPermission() async => true;

  @override
  Future<void> start({
    SvfAudioFormat format = SvfAudioFormat.m4a,
    int sampleRate = 44100,
    int bitRate = 128000,
    String? destinationPath,
  }) async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> resume() async {}

  @override
  Future<SvfAudioSource> stop() async => SvfAudioSource.fromBytes(Uint8List(0));

  @override
  Future<void> dispose() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
      final name = props['name'] as Map<String, dynamic>;
      final age = props['age'] as Map<String, dynamic>;
      final role = props['role'] as Map<String, dynamic>;
      final tags = props['tags'] as Map<String, dynamic>;
      final isVerified = props['isVerified'] as Map<String, dynamic>;
      expect(name['type'], 'string');
      expect(age['type'], 'integer');
      expect(role['enum'], ['Admin', 'Doctor', 'Patient']);
      expect(tags['type'], 'array');
      expect(isVerified['type'], 'boolean');
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

    test(
      'generateObject parses structured JSON and handles markdown wrapper',
      () async {
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

        final result = await generateObject<Map<String, dynamic>>(
          model: mockModel,
          schema: patientSchema,
          prompt:
              'Extract patient data: Alice Johnson, age 30, symptoms: headache, fatigue.',
        );

        expect(result.object['name'], 'Alice Johnson');
        expect(result.object['age'], 30);
        expect(result.object['symptoms'], ['headache', 'fatigue']);
        expect(result.object['confirmed'], isTrue);
        expect(result.warnings, isEmpty);
      },
    );

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

    test('typed structured output requires an explicit decoder', () async {
      final mockModel = MockLanguageModel(
        onGenerate: ({required messages, responseSchema, tools}) async {
          return const GenerateTextResult(text: '{"name":"Alice"}');
        },
      );

      final result = await generateObject<Map<String, dynamic>>(
        model: mockModel,
        schema: SvfSchema.object(properties: {'name': SvfSchema.string()}),
        prompt: 'Extract the name Alice.',
        parser: (json) => json,
      );

      expect(result.object['name'], 'Alice');
    });

    test('cancellation is checked before generation', () async {
      final token = CancellationToken()..cancel();
      final mockModel = MockLanguageModel(
        onGenerate: ({required messages, responseSchema, tools}) async {
          return const GenerateTextResult(text: 'should not run');
        },
      );

      expect(
        () => mockModel.generate(
          GenerateRequest(
            messages: [ChatMessage.user('hello')],
            cancellationToken: token,
          ),
        ),
        throwsA(isA<OperationCanceledException>()),
      );
    });

    test(
      'streamText exposes normalized events and aggregates output',
      () async {
        final mockModel = MockLanguageModel(
          onGenerate: ({required messages, responseSchema, tools}) async {
            return const GenerateTextResult(text: 'unused');
          },
          onStream: ({required messages, responseSchema, tools}) {
            return Stream.fromIterable(['hello', ' world']);
          },
        );

        final result = streamText(model: mockModel, prompt: 'Say hello');
        final events = await result.events!.toList();

        expect(events.first, isA<GenerationStarted>());
        expect(
          events.whereType<TextDelta>().map((event) => event.text).join(),
          'hello world',
        );
        expect(events.last, isA<GenerationFinished>());
        expect(await result.fullText, 'hello world');
      },
    );

    test(
      'streamObject preserves synchronous partial output and validates final JSON',
      () async {
        final schema = SvfSchema.object(
          properties: {'name': SvfSchema.string(minLength: 2)},
          required: ['name'],
        );
        final mockModel = MockLanguageModel(
          onGenerate: ({required messages, responseSchema, tools}) async {
            return const GenerateTextResult(text: '{}');
          },
          onStream: ({required messages, responseSchema, tools}) {
            expect(responseSchema, same(schema));
            return Stream.fromIterable(['{"name":"Al', 'ice"}']);
          },
        );

        final result = streamObject<Map<String, dynamic>>(
          model: mockModel,
          schema: schema,
          prompt: 'Extract Alice',
          parser: (json) => json,
        );

        final partials = await result.partialObjectStream.toList();
        final finalObject = await result.finalObject;

        expect(partials, isNotEmpty);
        expect(partials.last['name'], 'Alice');
        expect(finalObject['name'], 'Alice');
      },
    );

    test('agentLoop validates arguments and honors approval gates', () async {
      final mockModel = MockLanguageModel(
        onGenerate: ({required messages, responseSchema, tools}) async {
          return const GenerateTextResult(
            text: 'done',
            toolCalls: [
              ToolCall(
                id: 'call-invalid',
                name: 'sensitive_tool',
                arguments: {'value': 1},
              ),
            ],
          );
        },
      );
      var executed = false;
      final tool = SvfTool(
        name: 'sensitive_tool',
        description: 'A gated tool',
        requiresApproval: true,
        parameters: SvfSchema.object(
          properties: {'value': SvfSchema.string()},
          required: ['value'],
        ),
        execute: (arguments) async {
          executed = true;
          return 'should not execute';
        },
      );

      final result = await agentLoop(
        model: mockModel,
        messages: [ChatMessage.user('run it')],
        tools: [tool],
        maxSteps: 1,
        requestApproval: (tool, call) async => true,
      );

      expect(executed, isFalse);
      expect(result.steps.single.toolExecutions.single.isSuccess, isFalse);
      expect(
        result.steps.single.toolExecutions.single.error,
        contains('Invalid arguments'),
      );
    });
  });

  group('OpenAI-compatible providers', () {
    test(
      'OpenRouter uses its compatible endpoint and attribution headers',
      () async {
        late http.Request captured;
        final client = MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode({
              'choices': [
                {
                  'message': {'role': 'assistant', 'content': 'Hello'},
                  'finish_reason': 'stop',
                },
              ],
              'usage': {
                'prompt_tokens': 2,
                'completion_tokens': 3,
                'total_tokens': 5,
              },
            }),
            200,
          );
        });

        final model = OpenRouterLanguageModel(
          modelId: 'openai/gpt-4o-mini',
          apiKey: 'test-key',
          httpReferer: 'https://example.com',
          appTitle: 'SVF test',
          client: client,
        );

        final result = await model.generate(
          GenerateRequest(
            messages: [ChatMessage.user('Hello')],
            providerOptions: {'top_k': 2},
          ),
        );

        expect(
          captured.url.toString(),
          'https://openrouter.ai/api/v1/chat/completions',
        );
        expect(captured.headers['http-referer'], 'https://example.com');
        expect(captured.headers['x-openrouter-title'], 'SVF test');
        final requestBody = jsonDecode(captured.body) as Map<String, dynamic>;
        expect(requestBody['top_k'], 2);
        expect(requestBody['stream'], isFalse);
        expect(result.text, 'Hello');
        expect(result.usage.totalTokens, 5);
        expect(model.info.providerId, 'openrouter');
      },
    );
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

    test(
      'SvfWaveformController manages amplitude window and scrub position',
      () {
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
      },
    );
  });

  group('Speech-to-Text & SpeechRouter', () {
    test('transcribeAudio returns transcription result', () async {
      final mockStt = MockSpeechToTextModel();
      final audio = SvfAudioSource.fromBytes(
        Uint8List.fromList([0, 0, 0]),
        format: SvfAudioFormat.wav,
      );

      final result = await transcribeAudio(model: mockStt, audio: audio);

      expect(result.text, 'Patient Alice has mild fever for three days.');
      expect(result.confidence, 0.98);
      expect(result.language, 'en');
    });

    test(
      'SpeechRouter routes to fallback when primary fails or is unsupported',
      () async {
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
      },
    );
  });

  group('Model Downloader & Registry', () {
    test(
      'ModelManifest formats sizes and ModelRegistry contains built-ins',
      () {
        final whisper = ModelRegistry.whisperTinyEn;
        expect(whisper.id, 'whisper-tiny-en');
        expect(whisper.formattedSize, '74.1 MB');
        expect(whisper.sha256, isNotNull);

        final gemma = ModelRegistry.gemma2bQ4;
        expect(gemma.id, 'gemma-2b-it-q4');
        expect(gemma.formattedSize, '1.40 GB');

        expect(ModelRegistry.find('whisper-tiny-en'), isNotNull);
        expect(ModelRegistry.find('non-existent'), isNull);
      },
    );

    test(
      'DownloadProgress calculates progress percentage and formatted speed',
      () {
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
      },
    );
  });

  group('SvfUsage Metrics', () {
    test('Combines token metrics correctly with operator +', () {
      const u1 = SvfUsage(
        promptTokens: 10,
        completionTokens: 5,
        durationMs: 120,
      );
      const u2 = SvfUsage(
        promptTokens: 20,
        completionTokens: 15,
        durationMs: 200,
      );

      final total = u1 + u2;
      expect(total.promptTokens, 30);
      expect(total.completionTokens, 20);
      expect(total.totalTokens, 50);
      expect(total.durationMs, 320);
    });
  });

  group('Svf facade', () {
    test(
      'creates typed adapters over one injected transport and disposes safely',
      () async {
        final client = MockClient((_) async => http.Response('{}', 200));
        final svf = Svf(httpClient: client, recorder: FakeAudioRecorder());

        expect(svf.httpClient, same(client));
        expect(
          svf.openRouter('openai/gpt-4o-mini', apiKey: 'test').providerId,
          'openrouter',
        );
        expect(svf.openai('gpt-4o-mini', apiKey: 'test').providerId, 'openai');
        expect(svf.groq('llama', apiKey: 'test').providerId, 'groq');
        expect(svf.ollama('llama').isOffline, isTrue);
        expect(svf.deviceSpeech().providerId, 'device');

        await svf.dispose();
        expect(svf.isDisposed, isTrue);
        expect(() => svf.ollama('llama'), throwsStateError);
        await svf.dispose();
      },
    );
  });
}
