# Smart Voice Foundation (`svf`)

`svf` is a Flutter/Dart foundation for voice-driven AI applications. It provides provider-neutral contracts and practical adapters for:

- microphone recording and amplitude events;
- batch and live speech recognition;
- text-to-speech;
- immediate and streamed LLM generation;
- validated structured JSON output;
- tool calling and approval-aware agent loops;
- OpenAI-compatible providers, including OpenRouter;
- offline model adapters and resumable model artifacts;
- Android and Flutter Web applications.

The package is designed for applications where a person speaks naturally, an AI system extracts or reasons over the transcript, the application reviews the result, and the person remains in control of the final saved or exported data.

## Installation

Add `svf` to the application:

```yaml
dependencies:
  svf: ^0.0.1
```

Then run:

```bash
flutter pub get
```

The core abstractions do not depend on Genkit, `llm_toolkit`, a particular LLM vendor, or an offline inference runtime. The package uses small, replaceable adapters around official Flutter/platform integrations such as `record`, `speech_to_text`, `http`, and `path_provider`.

## Platform setup

### Android

Add microphone permission to `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.RECORD_AUDIO" />
```

Configure any provider API keys through a secure backend or platform-specific secret mechanism. Do not commit keys to source control.

### Web

Run from HTTPS or localhost so the browser can grant microphone access. Browser recording returns a Blob URL; SVF resolves that recording into bytes before exposing it as an `SvfAudioSource`.

Never ship a production OpenAI, OpenRouter, Groq, or Gemini secret in a Flutter Web bundle. Use a server-side proxy for browser applications.

## Quick start

```dart
import 'package:svf/svf.dart';

final svf = Svf();

Future<void> recordAndTranscribe() async {
  await svf.recorder.start(format: SvfAudioFormat.webm);
  // Connect svf.recorder.amplitudeStream to your waveform UI.

  final audio = await svf.recorder.stop();
  final result = await transcribeAudio(
    model: svf.groqWhisper(apiKey: 'YOUR_SERVER_TOKEN'),
    audio: audio,
    options: const TranscriptionOptions(language: 'en'),
  );

  print(result.text);
  await svf.dispose();
}
```

For production Web deployments, replace the direct cloud model with an authenticated application backend.

## Generate text

```dart
final model = svf.openRouter(
  'openai/gpt-4o-mini',
  apiKey: 'YOUR_TOKEN',
  httpReferer: 'https://your-app.example',
  appTitle: 'Your application',
);

final response = await generateText(
  model: model,
  system: 'You are a concise assistant.',
  prompt: 'Summarize this transcript in three sentences: $transcript',
);

print(response.text);
```

The OpenAI-compatible adapter also supports OpenAI, Groq, Ollama, LM Studio, and compatible gateways:

```dart
final openAi = svf.openai('gpt-4o-mini', apiKey: 'YOUR_TOKEN');
final groq = svf.groq('llama-3.3-70b-versatile', apiKey: 'YOUR_TOKEN');
final ollama = svf.ollama('llama3.2');
```

## Stream text and typed events

```dart
final result = streamText(
  model: model,
  prompt: 'Explain the transcript to a non-technical user.',
);

await for (final delta in result.textStream) {
  print(delta);
}

final fullText = await result.fullText;
final usage = await result.usage;
```

For richer integrations, consume the normalized event stream:

```dart
await for (final event in result.events!) {
  switch (event) {
    case GenerationStarted():
      break;
    case TextDelta(:final text):
      print(text);
    case ToolCallDelta(:final name, :final argumentsDelta):
      print('Tool $name: $argumentsDelta');
    case GenerationFinished(:final finishReason):
      print('Finished: ${finishReason.value}');
    case GenerationFailed(:final error):
      print('Failed: $error');
  }
}
```

## Structured output

Use `generateJson` when a dynamic JSON map is exactly what your application needs:

```dart
final schema = SvfSchema.object(
  properties: {
    'summary': SvfSchema.string(),
    'priority': SvfSchema.enumeration(['low', 'medium', 'high']),
    'needs_follow_up': SvfSchema.boolean(),
  },
  required: ['summary', 'priority', 'needs_follow_up'],
);

final json = await generateJson(
  model: model,
  schema: schema,
  prompt: transcript,
);
```

For a real Dart domain object, always provide a decoder:

```dart
final result = await generateObject<CaseRecord>(
  model: model,
  schema: caseRecordSchema,
  prompt: transcript,
  parser: CaseRecord.fromJson,
);

final record = result.object;
```

SVF validates the generated JSON before decoding it. Invalid fields, missing required properties, unexpected properties, and type mismatches raise `SvfSchemaValidationException` with validation details.

The application owns its domain schemas. SVF deliberately does not contain a form-specific subsystem; a form is simply one possible structured output model.

## Tool calling and agent loops

```dart
final lookupTool = SvfTool(
  name: 'lookup_case',
  description: 'Looks up a case by its identifier.',
  parameters: SvfSchema.object(
    properties: {'case_id': SvfSchema.string()},
    required: ['case_id'],
  ),
  execute: (arguments) async {
    return {'case_id': arguments['case_id'], 'status': 'open'};
  },
);

final result = await agentLoop(
  model: model,
  messages: [ChatMessage.user('Check case C-100.')],
  tools: [lookupTool],
  maxSteps: 5,
  toolTimeout: const Duration(seconds: 15),
);
```

For destructive or sensitive tools, require explicit host approval:

```dart
final tool = SvfTool(
  name: 'export_record',
  description: 'Exports the reviewed record.',
  parameters: exportSchema,
  requiresApproval: true,
  approvalReason: 'This writes the final reviewed record to device storage.',
  execute: exportRecord,
);
```

Tool arguments are validated before execution. The agent loop supports maximum steps, cancellation, approval callbacks, and execution timeouts.

## Speech recognition and synthesis

Batch transcription:

```dart
final transcript = await transcribeAudio(
  model: svf.whisper(apiKey: 'YOUR_TOKEN'),
  audio: audioSource,
  options: const TranscriptionOptions(
    language: 'en',
    includeTimestamps: true,
  ),
);
```

Device-native live recognition:

```dart
final events = streamTranscription(
  model: svf.deviceSpeech(),
  options: const TranscriptionOptions(language: 'en-US'),
);

await for (final event in events) {
  print('${event.isFinal ? "FINAL" : "PARTIAL"}: ${event.text}');
}
```

Cloud Whisper endpoints are batch transcription APIs. They can consume an incoming stream and emit a final result, but that is not equivalent to duplex realtime recognition. Use a provider or offline runtime that explicitly supports realtime audio for partial low-latency transcription.

Text-to-speech:

```dart
final audio = await synthesizeSpeech(
  model: svf.tts(apiKey: 'YOUR_TOKEN'),
  text: 'The reviewed record is ready.',
  options: const SynthesisOptions(voice: 'alloy'),
);
```

## Offline models and adapters

SVF keeps native inference runtimes out of the core package. Integrate Whisper, llama.cpp, ONNX, Genkit, `llm_toolkit`, or another runtime through:

- `CustomOfflineLanguageModel`;
- `CustomOfflineSpeechModel`;
- the shared `LanguageModel` and `SpeechToTextModel` contracts.

This lets the application switch between local and online models without changing its generation, transcription, structured-output, or agent orchestration code.

## Resumable model downloads

```dart
final progress = svf.downloader.progressStream('whisper-tiny-en');
final subscription = progress.listen((event) {
  print('${event.percentageFormatted} ${event.speedFormatted}');
});

final path = await svf.downloader.download(ModelRegistry.whisperTinyEn);
await subscription.cancel();
print('Model artifact ready at $path');

// Pass verified bytes to an application-owned offline runtime when needed.
final modelBytes = await svf.modelCache.readModelBytes(ModelRegistry.whisperTinyEn);
```

Downloads use HTTP range requests when supported, write to a partial artifact, verify SHA-256 when a manifest provides it, and promote the verified artifact atomically. A downloaded artifact still needs an offline runtime adapter before it can perform inference.

On Android and other IO platforms, artifacts are stored in the application documents directory. On Web, partial chunks and completed artifacts are stored in IndexedDB so downloads can resume across requests and browser reloads. Browser storage quotas and eviction policies still apply; applications should surface download failures and provide a way to redownload an artifact.

## Architecture

The public API is organized around replaceable boundaries:

```text
Application
  ├─ recording / waveform UI
  ├─ transcript review
  ├─ domain schema + decoder
  └─ final persistence/export

SVF orchestration
  ├─ generateText / streamText
  ├─ generateJson / generateObject
  ├─ tool validation + agent loop
  ├─ transcription and synthesis contracts
  └─ model download lifecycle

Adapters
  ├─ record + device speech recognition
  ├─ OpenAI-compatible HTTP providers
  ├─ Whisper/TTS providers
  └─ application-owned offline runtimes
```

## Testing and quality checks

```bash
dart analyze
flutter test
cd example
flutter analyze
flutter test
flutter build web --release
```

The repository tests schema validation, typed output decoding, cancellation, tool execution, OpenRouter request construction, audio-source behavior, routing, download progress, and usage aggregation. Provider integrations should additionally be tested against captured fixtures or a local mock server rather than live credentials.

## Production checklist

- Keep cloud credentials behind a server-side proxy for Web.
- Treat transcripts and generated objects as untrusted until validated and reviewed.
- Require approval for tools that write, delete, export, purchase, or transmit data.
- Persist the original audio, transcript, model/provider metadata, and reviewed final object separately.
- Store model manifests with immutable URLs and checksums.
- Test microphone permissions, browser HTTPS, background interruption, network loss, cancellation, and provider timeouts on every supported platform.

## License

Apache 2.0. See [LICENSE](LICENSE).
