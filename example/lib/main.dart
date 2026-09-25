import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:svf/svf.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SvfExampleApp());
}

class SvfExampleApp extends StatelessWidget {
  const SvfExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Voice Foundation',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2F6B58),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF7F8F4),
        cardTheme: CardThemeData(
          elevation: 0,
          margin: EdgeInsets.zero,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: Colors.black.withValues(alpha: 0.07)),
          ),
        ),
        useMaterial3: true,
      ),
      home: const SvfShowcasePage(),
    );
  }
}

class SvfShowcasePage extends StatefulWidget {
  const SvfShowcasePage({super.key});

  @override
  State<SvfShowcasePage> createState() => _SvfShowcasePageState();
}

class _SvfShowcasePageState extends State<SvfShowcasePage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  late final Svf _svf;
  late final SvfWaveformController _waveform;
  late final DemoSpeechModel _demoSpeech;
  late final DemoLanguageModel _demoModel;
  late final DemoSpeechSynthesis _demoTts;

  final _promptController = TextEditingController(
    text: 'Summarize the reviewed voice note in two sentences.',
  );
  final _apiKeyController = TextEditingController();
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _notesController = TextEditingController();

  String _provider = 'Demo offline';
  String _transcript = '';
  String _streamedText = '';
  String _agentResult = '';
  String _structuredJson = '';
  String _eventLog = '';
  String _operationStatus = 'Choose an operation to inspect its result.';
  String _voiceStatus = 'Ready';
  String _ttsStatus = 'Not synthesized';
  String _audioDetails = 'No audio source captured yet.';
  String _agentTrace = 'No agent run yet.';
  SvfAudioSource? _recording;
  SvfRecorderState _recordState = SvfRecorderState.idle;
  bool _busy = false;
  bool _urgent = false;
  bool _approvalRequired = true;
  CancellationToken? _generationCancellation;

  static final _caseSchema = SvfSchema.object(
    description: 'A reviewed voice-note case record.',
    properties: {
      'name': SvfSchema.string(description: 'Person name'),
      'age': SvfSchema.integer(description: 'Person age', minimum: 0),
      'summary': SvfSchema.string(description: 'Reviewed summary'),
      'urgent': SvfSchema.boolean(
        description: 'Whether urgent follow-up is needed',
      ),
    },
    required: ['name', 'age', 'summary', 'urgent'],
  );

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 6, vsync: this);
    _svf = Svf();
    _waveform = SvfWaveformController(maxVisibleSamples: 96);
    _demoSpeech = DemoSpeechModel();
    _demoModel = DemoLanguageModel();
    _demoTts = DemoSpeechSynthesis();
    _svf.recorder.stateStream.listen((state) {
      if (mounted) setState(() => _recordState = state);
    });
    _waveform.attachRecorder(_svf.recorder);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _waveform.dispose();
    _svf.dispose();
    _promptController.dispose();
    _apiKeyController.dispose();
    _nameController.dispose();
    _ageController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  LanguageModel _selectedModel() {
    final key = _apiKeyController.text.trim();
    return switch (_provider) {
      'OpenRouter' => _svf.openRouter(
        'openai/gpt-4o-mini',
        apiKey: key,
        httpReferer: 'https://example.invalid',
        appTitle: 'SVF Showcase',
      ),
      'OpenAI' => _svf.openai('gpt-4o-mini', apiKey: key),
      'Groq' => _svf.groq('llama-3.3-70b-versatile', apiKey: key),
      'Ollama' => _svf.ollama('llama3.2'),
      _ => _demoModel,
    };
  }

  Future<void> _runEndToEndDemo() async {
    setState(() => _busy = true);
    try {
      final audio = SvfAudioSource.fromBytes(
        Uint8List.fromList(List<int>.filled(32, 0)),
        format: SvfAudioFormat.wav,
      );
      final transcription = await _svf.transcribe(
        model: _demoSpeech,
        audio: audio,
      );
      final structured = await _svf.generateObject<DemoCaseRecord>(
        model: _demoModel,
        schema: _caseSchema,
        prompt: transcription.text,
        parser: DemoCaseRecord.fromJson,
      );
      _applyRecord(structured.object);
      final audioBytes = await audio.readBytes();
      setState(() {
        _recording = audio;
        _transcript = transcription.text;
        _audioDetails =
            '${audio.name} · ${audio.mimeType} · ${audioBytes.length} bytes';
        _voiceStatus = 'Transcribed, validated, and ready for review';
      });
      await _runStreaming();
      await _runAgent(showFeedback: false);
      await _runTts();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleRecording() async {
    try {
      if (_recordState.isRecording) {
        final audio = await _svf.recorder.stop();
        setState(() => _recording = audio);
        final result = await _svf.transcribe(model: _demoSpeech, audio: audio);
        final audioBytes = await audio.readBytes();
        setState(() {
          _transcript = result.text;
          _audioDetails =
              '${audio.name} · ${audio.mimeType} · ${audioBytes.length} bytes';
          _voiceStatus = 'Recording transcribed with the offline demo adapter';
        });
      } else {
        _waveform.clear();
        await _svf.recorder.start(format: SvfAudioFormat.webm);
      }
    } catch (error) {
      if (mounted) _showMessage('Recording unavailable: $error');
    }
  }

  Future<void> _runStructuredOutput() async {
    setState(() => _busy = true);
    try {
      final result = await _svf.generateObject<DemoCaseRecord>(
        model: _selectedModel(),
        schema: _caseSchema,
        prompt: _transcript.isEmpty ? _promptController.text : _transcript,
        parser: DemoCaseRecord.fromJson,
      );
      _applyRecord(result.object);
      if (mounted) {
        _showMessage(
          'Structured output validated and applied to the editable review.',
        );
      }
    } catch (error) {
      if (mounted) _showMessage('Structured output failed: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _runGenerateJson() async {
    setState(() => _busy = true);
    try {
      final json = await _svf.generateJson(
        model: _selectedModel(),
        schema: _caseSchema,
        prompt: _transcript.isEmpty ? _promptController.text : _transcript,
      );
      if (mounted) {
        setState(() {
          _structuredJson = const JsonEncoder.withIndent('  ').convert(json);
          _operationStatus = 'generateJson returned validated JSON.';
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _operationStatus = 'generateJson failed: $error');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _runStreamObject() async {
    setState(() => _busy = true);
    try {
      final result = _svf.streamObject<DemoCaseRecord>(
        model: _demoModel,
        schema: _caseSchema,
        prompt: _transcript.isEmpty ? _promptController.text : _transcript,
        parser: DemoCaseRecord.fromJson,
      );
      await for (final partial in result.partialObjectStream) {
        if (mounted) {
          setState(
            () => _operationStatus =
                'streamObject partial: ${partial.keys.join(', ')}',
          );
        }
      }
      final object = await result.finalObject;
      if (mounted) {
        _applyRecord(object);
        setState(
          () => _operationStatus = 'streamObject completed and validated.',
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() => _operationStatus = 'streamObject failed: $error');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _runEventStream() async {
    final result = _svf.streamText(
      model: _selectedModel(),
      prompt: _promptController.text,
    );
    final log = <String>[];
    await for (final event in result.events!) {
      switch (event) {
        case GenerationStarted():
          log.add('started');
        case TextDelta(:final text):
          log.add('text(${text.length})');
        case ToolCallDelta(:final name):
          log.add('tool($name)');
        case GenerationFinished(:final finishReason):
          log.add('finished(${finishReason.value})');
        case GenerationFailed(:final error):
          log.add('failed($error)');
      }
      if (mounted) setState(() => _eventLog = log.join(' → '));
    }
  }

  void _cancelGeneration() {
    _generationCancellation?.cancel();
    if (mounted) setState(() => _operationStatus = 'Cancellation requested.');
  }

  Future<void> _runStreaming() async {
    final cancellation = CancellationToken();
    _generationCancellation = cancellation;
    final result = _svf.streamText(
      model: _selectedModel(),
      prompt: _promptController.text,
      cancellationToken: cancellation,
    );
    final buffer = StringBuffer();
    try {
      await for (final chunk in result.textStream) {
        buffer.write(chunk);
        if (mounted) setState(() => _streamedText = buffer.toString());
      }
    } finally {
      _generationCancellation = null;
    }
  }

  Future<void> _runAgent({bool showFeedback = true}) async {
    _demoModel.resetAgent();
    final tool = SvfTool(
      name: 'lookup_case',
      description: 'Looks up the status of a case by identifier.',
      parameters: SvfSchema.object(
        properties: {'case_id': SvfSchema.string()},
        required: ['case_id'],
      ),
      requiresApproval: showFeedback && _approvalRequired,
      approvalReason: 'The agent is requesting access to a case record.',
      execute: (arguments) async => {
        'case_id': arguments['case_id'],
        'status': 'review_required',
      },
    );
    final result = await _svf.agentLoop(
      model: _demoModel,
      messages: [
        ChatMessage.user('Check case C-100 and summarize its status.'),
      ],
      tools: [tool],
      maxSteps: 3,
      requestApproval: _approvalRequired
          ? (tool, call) => _requestToolApproval(tool, call)
          : null,
    );
    if (mounted) {
      setState(() {
        _agentResult = result.text;
        _agentTrace = result.steps
            .map(
              (step) =>
                  'step ${step.stepIndex}: ${step.toolExecutions.isEmpty ? 'model response' : step.toolExecutions.map((call) => call.toolCall.name).join(', ')}',
            )
            .join('\n');
      });
      if (showFeedback) {
        _showMessage(
          'Agent completed ${result.steps.length} step${result.steps.length == 1 ? '' : 's'} with ${result.totalUsage.totalTokens} tokens.',
        );
      }
    }
  }

  Future<void> _runLiveTranscription() async {
    final buffer = StringBuffer();
    await for (final event in _svf.streamTranscription(model: _demoSpeech)) {
      buffer
        ..clear()
        ..write(event.text);
      if (mounted) {
        setState(
          () => _voiceStatus =
              '${event.isFinal ? 'Final' : 'Partial'}: ${event.text}',
        );
      }
    }
  }

  Future<void> _runBatchTranscription() async {
    final audio =
        _recording ??
        SvfAudioSource.fromBytes(
          Uint8List.fromList(List<int>.filled(32, 0)),
          format: SvfAudioFormat.wav,
        );
    final result = await _svf.transcribe(model: _demoSpeech, audio: audio);
    final bytes = await audio.readBytes();
    if (mounted) {
      setState(() {
        _recording = audio;
        _transcript = result.text;
        _audioDetails =
            '${audio.name} · ${audio.mimeType} · ${bytes.length} bytes';
        _voiceStatus =
            'Batch transcription completed with confidence ${result.confidence?.toStringAsFixed(2) ?? 'n/a'}';
      });
    }
  }

  Future<void> _runRouterTranscription() async {
    final router = _svf.speechRouter(
      primary: DemoSpeechModel(supported: false),
      fallback: _demoSpeech,
    );
    final result = await _svf.transcribe(
      model: router,
      audio:
          _recording ??
          SvfAudioSource.fromBytes(
            Uint8List.fromList(List<int>.filled(32, 0)),
            format: SvfAudioFormat.wav,
          ),
    );
    if (mounted) {
      setState(
        () => _voiceStatus =
            'Router selected the fallback adapter: ${result.text}',
      );
    }
  }

  Future<void> _runTts() async {
    final audio = await _svf.synthesize(
      model: _demoTts,
      text: _notesController.text.isEmpty
          ? 'SVF synthesis is ready.'
          : _notesController.text,
    );
    final bytes = await audio.readBytes();
    if (mounted) {
      setState(() {
        _ttsStatus = 'Generated ${bytes.length} bytes of audio';
        _audioDetails =
            '${audio.name} · ${audio.mimeType} · ${bytes.length} bytes';
      });
    }
  }

  Widget _buildAgentsTab() {
    return ListView(
      key: const ValueKey('agents-page'),
      padding: const EdgeInsets.all(16),
      children: [
        _sectionCard(
          title: 'Agent loop with explicit tool approval',
          subtitle:
              'Agents are ordinary typed model operations. Tools declare schemas, execution stays in your process, and approval can pause before side effects.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Material(
                color: Colors.transparent,
                child: SwitchListTile(
                  key: const ValueKey('approval-toggle'),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Require approval before tool execution'),
                  value: _approvalRequired,
                  onChanged: (value) =>
                      setState(() => _approvalRequired = value),
                ),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                key: const ValueKey('run-agent'),
                onPressed: _busy ? null : _runAgent,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Run approved agent loop'),
              ),
              if (_agentResult.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(_agentResult, key: const ValueKey('agents-result')),
              ],
              _codeBlock('Agent trace', _agentTrace),
              _codeBlock(
                'Tool contract',
                '{\n  "name": "lookup_case",\n  "parameters": { "case_id": "string" },\n  "approval": "optional"\n}',
              ),
            ],
          ),
        ),
        _sectionCard(
          title: 'Production controls',
          subtitle:
              'The same loop supports max steps, cancellation, provider options, usage reporting, and typed tool results.',
          child: const Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(label: Text('maxSteps')),
              Chip(label: Text('requestApproval')),
              Chip(label: Text('tool schema validation')),
              Chip(label: Text('usage accounting')),
              Chip(label: Text('typed tool output')),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFacadeTab() {
    const providers = [
      'Demo / custom offline',
      'OpenAI-compatible',
      'OpenRouter',
      'Groq',
      'Ollama',
      'Gemini',
      'Whisper / Groq Whisper',
      'Device speech',
      'OpenAI TTS',
    ];
    const operations = [
      'generateText',
      'streamText + normalized events',
      'generateJson',
      'generateObject<T>',
      'streamObject<T>',
      'agentLoop',
      'transcribe',
      'streamTranscription',
      'synthesize',
    ];
    return ListView(
      key: const ValueKey('facade-page'),
      padding: const EdgeInsets.all(16),
      children: [
        _sectionCard(
          title: 'One facade, explicit escape hatches',
          subtitle:
              'Svf is the ergonomic entry point. Every provider and operation remains independently typed and injectable for advanced applications and tests.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Runtime', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text('isDisposed: ${_svf.isDisposed}'),
              Text('transport: ${_svf.httpClient.runtimeType}'),
              Text('cache: ${_svf.modelCache.runtimeType}'),
              const SizedBox(height: 16),
              Text(
                'Provider adapters',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: providers
                    .map((item) => Chip(label: Text(item)))
                    .toList(),
              ),
            ],
          ),
        ),
        _sectionCard(
          title: 'Shared operation vocabulary',
          subtitle:
              'Switch models without rewriting your application workflow.',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: operations
                .map((item) => Chip(label: Text(item)))
                .toList(),
          ),
        ),
        _sectionCard(
          title: 'Typical integration',
          subtitle:
              'The facade keeps application code small while preserving strict contracts.',
          child: _codeBlock(
            'Dart',
            "final result = await svf.generateObject<MyRecord>(\n  model: model,\n  schema: schema,\n  prompt: transcript,\n  parser: MyRecord.fromJson,\n);",
          ),
        ),
      ],
    );
  }

  Future<bool> _requestToolApproval(SvfTool tool, ToolCall call) async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approve tool call?'),
        content: Text(
          '${tool.name}\n${tool.approvalReason ?? 'This action was requested by the model.'}\n\nArguments: ${call.arguments}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Deny'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Approve'),
          ),
        ],
      ),
    );
    return approved ?? false;
  }

  void _applyRecord(DemoCaseRecord record) {
    _nameController.text = record.name;
    _ageController.text = record.age.toString();
    _notesController.text = record.summary;
    _urgent = record.urgent;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SVF Showcase'),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabs: const [
            Tab(
              key: ValueKey('tab-end-to-end'),
              icon: Icon(Icons.mic),
              text: 'End-to-end',
            ),
            Tab(
              key: ValueKey('tab-ai-sdk'),
              icon: Icon(Icons.auto_awesome),
              text: 'AI SDK',
            ),
            Tab(
              key: ValueKey('tab-voice'),
              icon: Icon(Icons.graphic_eq),
              text: 'Voice lab',
            ),
            Tab(
              key: ValueKey('tab-downloads'),
              icon: Icon(Icons.download),
              text: 'Downloads',
            ),
            Tab(
              key: ValueKey('tab-agents'),
              icon: Icon(Icons.build_circle_outlined),
              text: 'Agents',
            ),
            Tab(
              key: ValueKey('tab-facade'),
              icon: Icon(Icons.menu_book_outlined),
              text: 'Facade map',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _buildEndToEndTab(),
          _buildAiSdkTab(),
          _buildVoiceTab(),
          _buildDownloadsTab(),
          _buildAgentsTab(),
          _buildFacadeTab(),
        ],
      ),
    );
  }

  Widget _buildEndToEndTab() {
    return ListView(
      key: const ValueKey('end-to-end-page'),
      padding: const EdgeInsets.all(16),
      children: [
        _sectionCard(
          title: 'Voice → transcript → structured review',
          subtitle:
              'The default demo is offline, deterministic, and safe to run without credentials.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton.icon(
                key: const ValueKey('run-end-to-end'),
                onPressed: _busy ? null : _runEndToEndDemo,
                icon: const Icon(Icons.play_circle),
                label: const Text('Run complete offline workflow'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                key: const ValueKey('record-button'),
                onPressed: _toggleRecording,
                icon: Icon(_recordState.isRecording ? Icons.stop : Icons.mic),
                label: Text(
                  _recordState.isRecording
                      ? 'Stop recording'
                      : 'Record with microphone',
                ),
              ),
              const SizedBox(height: 12),
              Text(_voiceStatus),
              if (_transcript.isNotEmpty) ...[
                const SizedBox(height: 12),
                SelectableText(_transcript, key: const ValueKey('transcript')),
              ],
              if (_recording != null)
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Audio source captured and retained for review.'),
                ),
            ],
          ),
        ),
        _sectionCard(
          title: 'Human-in-the-loop review',
          subtitle:
              'AI output is never the final record until the user reviews and edits it.',
          child: Column(
            children: [
              TextField(
                key: const ValueKey('name-field'),
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              TextField(
                key: const ValueKey('age-field'),
                controller: _ageController,
                decoration: const InputDecoration(labelText: 'Age'),
              ),
              TextField(
                key: const ValueKey('notes-field'),
                controller: _notesController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Reviewed notes'),
              ),
              Material(
                color: Colors.transparent,
                child: SwitchListTile(
                  key: const ValueKey('urgent-field'),
                  title: const Text('Urgent follow-up'),
                  value: _urgent,
                  onChanged: (value) => setState(() => _urgent = value),
                ),
              ),
              FilledButton.icon(
                key: const ValueKey('approve-export'),
                onPressed: _showExportDialog,
                icon: const Icon(Icons.verified),
                label: const Text('Approve and export reviewed record'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAiSdkTab() {
    return ListView(
      key: const ValueKey('ai-sdk-page'),
      padding: const EdgeInsets.all(16),
      children: [
        _sectionCard(
          title: 'Provider-neutral AI operations',
          subtitle:
              'Switch between demo offline, OpenAI, OpenRouter, Groq, and Ollama using the same operations.',
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                key: const ValueKey('provider-picker'),
                initialValue: _provider,
                items:
                    const [
                          'Demo offline',
                          'OpenRouter',
                          'OpenAI',
                          'Groq',
                          'Ollama',
                        ]
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(value),
                          ),
                        )
                        .toList(),
                onChanged: (value) =>
                    setState(() => _provider = value ?? 'Demo offline'),
                decoration: const InputDecoration(labelText: 'Provider'),
              ),
              if (_provider != 'Demo offline' && _provider != 'Ollama')
                TextField(
                  controller: _apiKeyController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'API key'),
                ),
              TextField(
                key: const ValueKey('prompt-field'),
                controller: _promptController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Prompt'),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton(
                    key: const ValueKey('generate-text'),
                    onPressed: _busy
                        ? null
                        : () async => _showResult(
                            await _svf.generateText(
                              model: _selectedModel(),
                              prompt: _promptController.text,
                            ),
                          ),
                    child: const Text('generateText'),
                  ),
                  OutlinedButton(
                    key: const ValueKey('stream-text'),
                    onPressed: _busy ? null : _runStreaming,
                    child: const Text('streamText'),
                  ),
                  OutlinedButton(
                    key: const ValueKey('generate-object'),
                    onPressed: _busy ? null : _runStructuredOutput,
                    child: const Text('generateObject'),
                  ),
                  OutlinedButton(
                    key: const ValueKey('agent-loop'),
                    onPressed: _busy ? null : _runAgent,
                    child: const Text('agentLoop'),
                  ),
                  OutlinedButton(
                    key: const ValueKey('generate-json'),
                    onPressed: _busy ? null : _runGenerateJson,
                    child: const Text('generateJson'),
                  ),
                  OutlinedButton(
                    key: const ValueKey('stream-object'),
                    onPressed: _busy ? null : _runStreamObject,
                    child: const Text('streamObject'),
                  ),
                  OutlinedButton(
                    key: const ValueKey('event-stream'),
                    onPressed: _busy ? null : _runEventStream,
                    child: const Text('events'),
                  ),
                  TextButton.icon(
                    key: const ValueKey('cancel-generation'),
                    onPressed: _generationCancellation == null
                        ? null
                        : _cancelGeneration,
                    icon: const Icon(Icons.stop_circle_outlined),
                    label: const Text('Cancel'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _operationStatus,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              if (_eventLog.isNotEmpty)
                _codeBlock('Normalized events', _eventLog),
              if (_structuredJson.isNotEmpty)
                _codeBlock('Validated JSON', _structuredJson),
              if (_streamedText.isNotEmpty)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      _streamedText,
                      key: const ValueKey('stream-output'),
                    ),
                  ),
                ),
              if (_agentResult.isNotEmpty)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      'Agent: $_agentResult',
                      key: const ValueKey('agent-output'),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVoiceTab() {
    return ListView(
      key: const ValueKey('voice-page'),
      padding: const EdgeInsets.all(16),
      children: [
        _sectionCard(
          title: 'Realtime voice primitives',
          subtitle:
              'Partial/final transcription events, amplitude streams, waveform rendering, and TTS output.',
          child: Column(
            children: [
              Container(
                height: 96,
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(8),
                child: SvfLiveWaveform(
                  controller: _waveform,
                  style: const SvfWaveformStyle(
                    barColor: Colors.cyanAccent,
                    isSymmetric: true,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                key: const ValueKey('live-transcription'),
                onPressed: _runLiveTranscription,
                child: const Text('Run live transcription demo'),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    key: const ValueKey('batch-transcription'),
                    onPressed: _runBatchTranscription,
                    child: const Text('Batch transcribe'),
                  ),
                  OutlinedButton(
                    key: const ValueKey('router-transcription'),
                    onPressed: _runRouterTranscription,
                    child: const Text('Try speech router'),
                  ),
                ],
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(_voiceStatus, key: const ValueKey('live-status')),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _audioDetails,
                  key: const ValueKey('audio-details'),
                ),
              ),
              OutlinedButton(
                key: const ValueKey('synthesize-speech'),
                onPressed: _runTts,
                child: const Text('Synthesize speech demo'),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(_ttsStatus, key: const ValueKey('tts-status')),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDownloadsTab() {
    return ListView(
      key: const ValueKey('downloads-page'),
      padding: const EdgeInsets.all(16),
      children: [
        _sectionCard(
          title: 'Resumable model artifacts',
          subtitle:
              'Download weights on demand, observe progress, pause/resume, verify, then hand the artifact to an offline runtime.',
          child: Column(
            children: ModelRegistry.allBuiltIn
                .map(
                  (manifest) => _ModelTile(
                    svf: _svf,
                    manifest: manifest,
                    onMessage: _showMessage,
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _codeBlock(String title, String value) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF17211D),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFFB9E6D0),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          SelectableText(
            value,
            style: const TextStyle(
              color: Color(0xFFE9F2EC),
              fontFamily: 'monospace',
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withValues(alpha: 0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
          const Divider(height: 28),
          child,
        ],
      ),
    );
  }

  Future<void> _showExportDialog() async {
    final data = {
      'name': _nameController.text,
      'age': int.tryParse(_ageController.text) ?? 0,
      'summary': _notesController.text,
      'urgent': _urgent,
      'transcript': _transcript,
    };
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reviewed record exported'),
        content: SingleChildScrollView(
          child: SelectableText(
            const JsonEncoder.withIndent('  ').convert(data),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showResult(GenerateTextResult result) {
    if (mounted) {
      _showMessage(
        'Generated ${result.text.length} characters (${result.usage.totalTokens} tokens).',
      );
    }
  }
}

class _ModelTile extends StatefulWidget {
  const _ModelTile({
    required this.svf,
    required this.manifest,
    required this.onMessage,
  });

  final Svf svf;
  final ModelManifest manifest;
  final ValueChanged<String> onMessage;

  @override
  State<_ModelTile> createState() => _ModelTileState();
}

class _ModelTileState extends State<_ModelTile> {
  DownloadProgress? _progress;
  late final StreamSubscription<DownloadProgress> _progressSubscription;
  bool _busy = false;
  bool _cached = false;

  @override
  void initState() {
    super.initState();
    _progressSubscription = widget.svf.downloader
        .progressStream(widget.manifest.id)
        .listen((progress) {
          if (mounted) {
            setState(() {
              _progress = progress;
              _busy = !progress.status.isTerminal;
            });
          }
        });
    _checkCache();
  }

  @override
  void dispose() {
    _progressSubscription.cancel();
    super.dispose();
  }

  Future<void> _checkCache() async {
    final cached = await widget.svf.modelCache.isModelCached(widget.manifest);
    if (mounted) setState(() => _cached = cached);
  }

  Future<void> _download() async {
    setState(() => _busy = true);
    try {
      await widget.svf.downloader.download(widget.manifest);
      await _checkCache();
      widget.onMessage('Downloaded and verified ${widget.manifest.name}.');
    } catch (error) {
      widget.onMessage('Download failed: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pause() async {
    await widget.svf.downloader.pause(widget.manifest.id);
  }

  Future<void> _resume() async {
    setState(() => _busy = true);
    try {
      await widget.svf.downloader.resume(widget.manifest.id);
    } catch (error) {
      widget.onMessage('Resume failed: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel() async {
    await widget.svf.downloader.cancel(widget.manifest.id);
    if (mounted) {
      setState(() {
        _progress = null;
        _cached = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = _progress;
    final status = progress?.status;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8F4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.manifest.name,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(widget.manifest.description ?? widget.manifest.formattedSize),
          if (progress != null) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(value: progress.fraction),
            Text(
              '${progress.status.name} · ${progress.percentageFormatted} · ${progress.speedFormatted}',
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: _busy ? null : _download,
                icon: Icon(_cached ? Icons.check : Icons.download),
                label: Text(_cached ? 'Cached' : 'Download'),
              ),
              if (status == DownloadStatus.downloading ||
                  status == DownloadStatus.connecting)
                OutlinedButton(onPressed: _pause, child: const Text('Pause')),
              if (status == DownloadStatus.paused)
                OutlinedButton(
                  onPressed: _busy ? null : _resume,
                  child: const Text('Resume'),
                ),
              if (_progress != null && !_progress!.status.isTerminal)
                TextButton(onPressed: _cancel, child: const Text('Cancel')),
            ],
          ),
        ],
      ),
    );
  }
}

final class DemoCaseRecord {
  final String name;
  final int age;
  final String summary;
  final bool urgent;

  const DemoCaseRecord({
    required this.name,
    required this.age,
    required this.summary,
    required this.urgent,
  });

  factory DemoCaseRecord.fromJson(Map<String, dynamic> json) => DemoCaseRecord(
    name: json['name'] as String,
    age: json['age'] as int,
    summary: json['summary'] as String,
    urgent: json['urgent'] as bool,
  );
}

class DemoSpeechModel implements SpeechToTextModel {
  DemoSpeechModel({this.supported = true});

  final bool supported;

  static const _text =
      'Alice is 34 and reports a severe headache with fever for three days. Follow-up is urgent.';

  @override
  String get modelId => 'demo-speech';

  @override
  String get providerId => 'demo';

  @override
  bool get isOffline => true;

  @override
  Future<bool> isSupported() async => supported;

  @override
  Future<TranscriptionResult> doTranscribe({
    required SvfAudioSource audio,
    TranscriptionOptions? options,
  }) async =>
      const TranscriptionResult(text: _text, language: 'en', confidence: 0.99);

  @override
  Stream<TranscriptionChunk> doStreamTranscription({
    Stream<List<int>>? audioStream,
    TranscriptionOptions? options,
  }) async* {
    yield const TranscriptionChunk(text: 'Alice is 34', isFinal: false);
    yield const TranscriptionChunk(
      text: _text,
      isFinal: true,
      confidence: 0.99,
    );
  }
}

class DemoLanguageModel implements LanguageModel {
  int _agentTurn = 0;

  void resetAgent() => _agentTurn = 0;

  @override
  String get modelId => 'demo-language';

  @override
  String get providerId => 'demo';

  @override
  bool get isOffline => true;

  @override
  Future<GenerateTextResult> doGenerate({
    required List<ChatMessage> messages,
    SvfSchema? responseSchema,
    List<SvfTool>? tools,
    double? temperature,
    int? maxTokens,
    double? topP,
    List<String>? stopSequences,
  }) async {
    if (tools != null && tools.isNotEmpty && _agentTurn++ == 0) {
      return const GenerateTextResult(
        text: 'I will check the case status.',
        toolCalls: [
          ToolCall(
            id: 'demo-call',
            name: 'lookup_case',
            arguments: {'case_id': 'C-100'},
          ),
        ],
        finishReason: FinishReason.toolCalls,
      );
    }
    if (responseSchema != null) {
      return const GenerateTextResult(
        text:
            '{"name":"Alice","age":34,"summary":"Severe headache and fever for three days.","urgent":true}',
      );
    }
    return const GenerateTextResult(
      text: 'The reviewed case is urgent and requires follow-up.',
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
  }) async* {
    if (responseSchema != null) {
      const json =
          '{"name":"Alice","age":34,"summary":"Severe headache and fever for three days.","urgent":true}';
      for (final chunk in [
        json.substring(0, 24),
        json.substring(24, 62),
        json.substring(62),
      ]) {
        yield chunk;
      }
      return;
    }
    for (final chunk in [
      'Streaming ',
      'output ',
      'from ',
      'the ',
      'offline ',
      'SVF ',
      'demo.',
    ]) {
      yield chunk;
    }
  }
}

class DemoSpeechSynthesis implements TextToSpeechModel {
  @override
  String get modelId => 'demo-tts';

  @override
  String get providerId => 'demo';

  @override
  Future<SvfAudioSource> doSynthesize({
    required String text,
    SynthesisOptions? options,
  }) async => SvfAudioSource.fromBytes(
    Uint8List.fromList(text.codeUnits),
    format: SvfAudioFormat.wav,
  );
}
