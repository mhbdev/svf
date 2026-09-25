# Smart Voice Foundation (`svf`)

[![pub package](https://img.shields.io/badge/pub-v0.0.1-blue.svg)](https://pub.dev)
[![license](https://img.shields.io/badge/license-MIT-purple.svg)](LICENSE)
[![platform](https://img.shields.io/badge/platform-android%20|%20web%20|%20ios%20|%20desktop-teal.svg)](https://flutter.dev)

A universal, production-ready, dependency-minimal Smart Voice and AI foundation SDK for Flutter and Dart. Designed with the architectural elegance of **Vercel's AI SDK**, tailored for real-time voice recording, pure Flutter Canvas waveforms, speech recognition, speech synthesis, structured data extraction (`generateObject`), and resumable offline model downloading.

---

## 🌟 Key Highlights

- **Vercel AI SDK Inspired Architecture**: Universal primitives: `generateText`, `streamText`, `generateObject`, `streamObject`, `transcribeAudio`, `streamTranscription`, and `agentLoop`.
- **Zero Native Bloat & Day-1 Web Parity**: Runs smoothly on **Android and Web** without native FFI compilation crashes or missing-plugin errors.
- **Pure Flutter 60fps Canvas Waveforms**: `SvfLiveWaveform` and `SvfPlaybackWaveform` widgets powered by custom `CustomPainter`. Zero native C++/Kotlin dependencies; smooth gesture seeking and scrubbing everywhere.
- **Provider-Agnostic LLM Protocol**: Seamlessly toggle between Google Gemini, OpenAI (GPT-4o), Groq Cloud (Llama 3.3), Ollama, and on-device models via a shared `LanguageModel` contract.
- **Type-Safe Structured Output (`generateObject`)**: Build strict declarative schemas (`SvfSchema.object(...)`) to extract validated forms, entities, or JSON data directly from voice transcripts or prompts.
- **Resilient Resumable Model Downloader**: HTTP `Range` chunked downloader with pause/resume support, network reconnection, progress tracking (speed, ETA), and SHA-256 integrity verification.
- **Human-in-the-Loop (HITL) by Design**: Review, edit, approve, and export voice-populated forms.

---

## 📦 Installation

Add `svf` to your `pubspec.yaml`:

```yaml
dependencies:
  svf: ^0.0.1
```

Or run:

```bash
flutter pub add svf
```

---

## 🚀 Quickstart

### 1. Initialize the SDK

```dart
import 'package:svf/svf.dart';

final svf = Svf();
```

---

### 2. Universal Voice Recording with 60fps Live Waveform

```dart
// 1. Controller manages amplitudes and sliding window
final waveformController = SvfWaveformController();
waveformController.attachRecorder(svf.recorder);

// 2. Start recording (works on Android & Web)
await svf.recorder.start();

// 3. Render 60fps Canvas waveform in Flutter UI
SvfLiveWaveform(
  controller: waveformController,
  style: const SvfWaveformStyle(
    barColor: Colors.cyanAccent,
    barWidth: 3.5,
    barSpacing: 3.0,
    isSymmetric: true,
  ),
  height: 90,
);

// 4. Stop recording and obtain the universal audio source
final audioSource = await svf.recorder.stop();
```

---

### 3. Speech-to-Text Transcription

```dart
// Batch transcription via Cloud Whisper (OpenAI / Groq)
final transcription = await transcribeAudio(
  model: svf.groqWhisper(apiKey: 'YOUR_GROQ_KEY'),
  audio: audioSource,
  options: const TranscriptionOptions(language: 'en'),
);

print('Transcript: ${transcription.text}');
```

---

### 4. Structured Output Extraction (`generateObject`)

Extract typed data from voice transcripts into any schema (forms, records, objects):

```dart
// Define declarative schema
final patientSchema = SvfSchema.object(
  properties: {
    'patient_name': SvfSchema.string(description: 'Full name'),
    'age': SvfSchema.integer(description: 'Age in years'),
    'primary_complaint': SvfSchema.enumeration(['Fever', 'Headache', 'Cough']),
    'is_urgent': SvfSchema.boolean(),
  },
  required: ['patient_name', 'primary_complaint'],
);

// Extract structured object using Gemini, OpenAI, or local model
final result = await generateObject(
  model: svf.gemini('gemini-1.5-flash', apiKey: 'YOUR_GEMINI_KEY'),
  schema: patientSchema,
  prompt: 'Patient Alice, age 32, reports high fever since yesterday. Urgent.',
);

print(result.object);
// Output: { patient_name: 'Alice', age: 32, primary_complaint: 'Fever', is_urgent: true }
```

---

### 5. Multi-Turn Agentic Tool Calling (`agentLoop`)

```dart
final lookupTool = SvfTool(
  name: 'check_inventory',
  description: 'Checks item stock quantity',
  parameters: SvfSchema.object(
    properties: {'sku': SvfSchema.string()},
  ),
  execute: (args) async => {'sku': args['sku'], 'stock': 42},
);

final loopResult = await agentLoop(
  model: svf.openai('gpt-4o', apiKey: 'YOUR_OPENAI_KEY'),
  messages: [ChatMessage.user('Do we have item A-100 in stock?')],
  tools: [lookupTool],
  maxSteps: 3,
);

print(loopResult.text);
```

---

### 6. Resumable Model Downloader

Download large GGUF / TFLite weights on demand without bundling them in the APK or Web bundle:

```dart
// Watch real-time progress
svf.downloader.progressStream('whisper-tiny-en').listen((progress) {
  print('${progress.percentageFormatted} | ${progress.speedFormatted} | ETA: ${progress.estimatedRemainingTime}');
});

// Download with pause/resume and SHA-256 verification
final localPath = await svf.downloader.download(
  ModelRegistry.whisperTinyEn,
);

print('Model ready on disk: $localPath');
```

---

## 🏛️ Architecture Overview

```
svf/
├── lib/
│   ├── svf.dart                          // Main SDK public exports
│   │
│   └── src/
│       ├── core/                         // Primitives, SvfSchema, AudioSource, Exceptions
│       ├── audio/                        // Recorder (record: ^7.1.1), Storage, Metadata
│       ├── visualizer/                   // 60fps Canvas waveform painter & interactive widgets
│       ├── language/                     // LanguageModel, generateText, streamText, generateObject, streamObject, agentLoop
│       │   └── providers/                // Gemini, OpenAI, Groq, Ollama, CustomOffline
│       ├── speech/                       // SpeechToTextModel, transcribeAudio, streamTranscription, DeviceSpeech, WhisperCloud
│       ├── synthesis/                    // TextToSpeechModel, synthesizeSpeech, OpenAiSpeech
│       └── downloader/                   // ResumableDownloader (HTTP Range + Checksum), ModelCache, Registry
```

---

## 🧪 Testing

Run all unit and integration tests:

```bash
flutter test
```

Run static analysis:

```bash
flutter analyze
```

---

## 📱 Running the Showcase Example App

Navigate to the `example/` directory and run:

```bash
cd example
flutter run
```

---

## 📄 License

MIT License. See [LICENSE](LICENSE) for details.
