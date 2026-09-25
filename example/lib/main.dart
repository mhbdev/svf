import 'dart:convert';
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
      title: 'Smart Voice Foundation (SVF)',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6750A4),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const SvfHomeDashboard(),
    );
  }
}

class SvfHomeDashboard extends StatefulWidget {
  const SvfHomeDashboard({super.key});

  @override
  State<SvfHomeDashboard> createState() => _SvfHomeDashboardState();
}

class _SvfHomeDashboardState extends State<SvfHomeDashboard>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final Svf _svf;
  late final SvfWaveformController _waveformController;

  // Selected AI Provider
  String _selectedProvider = 'Mock (Offline Test)';
  final TextEditingController _apiKeyController = TextEditingController();

  // Audio Recording State
  SvfRecorderState _recordState = SvfRecorderState.idle;
  SvfAudioSource? _lastRecordedAudio;
  String _transcript = '';
  bool _isTranscribing = false;
  bool _isExtracting = false;

  // Editable Form Controllers (Human-in-the-Loop)
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _durationController = TextEditingController();
  String _selectedComplaint = 'Fever';
  String _selectedSeverity = 'Moderate';
  bool _isUrgent = false;

  // Model Downloader State
  final Map<String, DownloadProgress> _downloadProgressMap = {};

  // Form Schema Definition
  final SvfObjectSchema _intakeSchema = SvfSchema.object(
    description: 'Medical patient intake form',
    properties: {
      'patient_name': SvfSchema.string(description: 'Full name of patient'),
      'age': SvfSchema.integer(description: 'Patient age in years'),
      'primary_complaint': SvfSchema.enumeration(
        ['Fever', 'Headache', 'Cough', 'Chest Pain', 'Fatigue', 'Back Pain'],
        description: 'Primary symptom or complaint',
      ),
      'duration_days': SvfSchema.integer(description: 'Duration of symptoms in days'),
      'severity': SvfSchema.enumeration(['Mild', 'Moderate', 'Severe']),
      'notes': SvfSchema.string(description: 'Clinical observation notes'),
      'is_urgent': SvfSchema.boolean(description: 'Whether immediate attention is needed'),
    },
    required: ['patient_name', 'primary_complaint', 'severity'],
  );

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _svf = Svf();
    _waveformController = SvfWaveformController(maxVisibleSamples: 90);

    // Bind recorder states to local UI
    _svf.recorder.stateStream.listen((state) {
      if (mounted) setState(() => _recordState = state);
    });

    _waveformController.attachRecorder(_svf.recorder);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _waveformController.dispose();
    _svf.dispose();
    _nameController.dispose();
    _ageController.dispose();
    _notesController.dispose();
    _durationController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  // --- Voice Recording Operations ---

  Future<void> _toggleRecord() async {
    if (_recordState.isRecording) {
      final audioSource = await _svf.recorder.stop();
      setState(() {
        _lastRecordedAudio = audioSource;
      });

      // Auto-transcribe upon recording completion
      await _runTranscription(audioSource);
    } else {
      _waveformController.clear();
      setState(() {
        _transcript = '';
      });
      await _svf.recorder.start();
    }
  }

  Future<void> _runTranscription(SvfAudioSource audio) async {
    setState(() => _isTranscribing = true);

    try {
      if (_selectedProvider == 'Mock (Offline Test)') {
        // Deterministic realistic transcription simulation
        await Future.delayed(const Duration(milliseconds: 600));
        setState(() {
          _transcript =
              'Patient Alice Henderson, 34 years old, reports severe headache and moderate fever for 3 days. She complains of fatigue, no chest pain. Case marked urgent.';
        });
      } else if (_selectedProvider == 'Groq (Whisper Cloud)') {
        final whisper = _svf.groqWhisper(apiKey: _apiKeyController.text.trim());
        final result = await transcribeAudio(model: whisper, audio: audio);
        setState(() => _transcript = result.text);
      } else if (_selectedProvider == 'OpenAI (Whisper Cloud)') {
        final whisper = _svf.whisper(apiKey: _apiKeyController.text.trim());
        final result = await transcribeAudio(model: whisper, audio: audio);
        setState(() => _transcript = result.text);
      } else {
        // Device Speech
        setState(() {
          _transcript = 'Patient recorded audio ready for AI structured extraction.';
        });
      }

      // Automatically trigger structured AI extraction
      if (_transcript.isNotEmpty) {
        await _runStructuredExtraction(_transcript);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Transcription error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isTranscribing = false);
    }
  }

  // --- Structured Object AI Extraction (generateObject) ---

  Future<void> _runStructuredExtraction(String text) async {
    setState(() => _isExtracting = true);

    try {
      final LanguageModel model = _resolveSelectedModel();

      final result = await generateObject(
        model: model,
        schema: _intakeSchema,
        prompt: 'Extract patient intake information from this clinical audio transcript: "$text"',
      );

      final data = result.object;
      setState(() {
        _nameController.text = data['patient_name']?.toString() ?? '';
        _ageController.text = data['age']?.toString() ?? '';
        _selectedComplaint = data['primary_complaint']?.toString() ?? 'Headache';
        _durationController.text = data['duration_days']?.toString() ?? '3';
        _selectedSeverity = data['severity']?.toString() ?? 'Moderate';
        _notesController.text = data['notes']?.toString() ?? text;
        _isUrgent = data['is_urgent'] == true;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Form populated via generateObject! Review & edit below.'),
            backgroundColor: Colors.teal,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('AI Extraction error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isExtracting = false);
    }
  }

  LanguageModel _resolveSelectedModel() {
    final key = _apiKeyController.text.trim();

    if (_selectedProvider == 'Google Gemini') {
      return _svf.gemini('gemini-1.5-flash', apiKey: key);
    } else if (_selectedProvider == 'OpenAI (GPT-4o)') {
      return _svf.openai('gpt-4o-mini', apiKey: key);
    } else if (_selectedProvider == 'Groq (Llama 3.3)') {
      return _svf.groq('llama-3.3-70b-versatile', apiKey: key);
    } else if (_selectedProvider == 'Ollama (Local)') {
      return _svf.ollama('llama3.2');
    }

    // Mock Offline Model
    return CustomOfflineLanguageModel(
      modelId: 'mock-offline-llm',
      onGenerate: ({required messages, responseSchema, tools, temperature, maxTokens}) async {
        await Future.delayed(const Duration(milliseconds: 500));
        return const GenerateTextResult(
          text: '''
{
  "patient_name": "Alice Henderson",
  "age": 34,
  "primary_complaint": "Headache",
  "duration_days": 3,
  "severity": "Severe",
  "notes": "Patient reports severe headache and fever. No chest pain noted.",
  "is_urgent": true
}
''',
          usage: SvfUsage(promptTokens: 45, completionTokens: 38),
        );
      },
      onStream: ({required messages, responseSchema, tools, temperature, maxTokens}) {
        return Stream.value('{"patient_name": "Alice"}');
      },
    );
  }

  // --- Human-In-The-Loop Approval & Export ---

  Future<void> _approveAndExport() async {
    final finalData = {
      'patient_name': _nameController.text.trim(),
      'age': int.tryParse(_ageController.text.trim()) ?? 0,
      'primary_complaint': _selectedComplaint,
      'duration_days': int.tryParse(_durationController.text.trim()) ?? 1,
      'severity': _selectedSeverity,
      'notes': _notesController.text.trim(),
      'is_urgent': _isUrgent,
      'transcript': _transcript,
      'timestamp': DateTime.now().toIso8601String(),
    };

    final formattedJson = const JsonEncoder.withIndent('  ').convert(finalData);

    // Save audio if present
    if (_lastRecordedAudio != null) {
      await SvfAudioStore.saveRecording(
        source: _lastRecordedAudio!,
        prefix: 'patient_intake',
      );
    }


    if (mounted) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 8),
              Text('Form Approved & Exported'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Verified structured data (saved locally):'),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade900,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    formattedJson,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: Colors.greenAccent,
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    }
  }

  // --- Resumable Model Downloader Handlers ---

  void _startModelDownload(ModelManifest manifest) {
    _svf.downloader.progressStream(manifest.id).listen((progress) {
      if (mounted) {
        setState(() {
          _downloadProgressMap[manifest.id] = progress;
        });
      }
    });

    _svf.downloader.download(manifest).then((path) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Downloaded & verified: ${manifest.name}')),
        );
      }
    }).catchError((e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $e')),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Voice Foundation (SVF)'),
        elevation: 1,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.mic), text: 'Voice-to-Form (HITL)'),
            Tab(icon: Icon(Icons.download), text: 'Model Downloader'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildVoiceToFormTab(),
          _buildModelDownloaderTab(),
        ],
      ),
    );
  }

  // --- TAB 1: Voice-to-Form & Human-in-the-Loop Review ---

  Widget _buildVoiceToFormTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Provider Configuration Bar
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('AI Provider & Inference Mode:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedProvider,
                    decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                    items: const [
                      DropdownMenuItem(value: 'Mock (Offline Test)', child: Text('Mock Engine (Zero Setup / Offline Test)')),
                      DropdownMenuItem(value: 'Google Gemini', child: Text('Google Gemini (Direct REST)')),
                      DropdownMenuItem(value: 'Groq (Llama 3.3)', child: Text('Groq Cloud (Llama 3.3 / Whisper)')),
                      DropdownMenuItem(value: 'OpenAI (GPT-4o)', child: Text('OpenAI (GPT-4o / Whisper)')),
                      DropdownMenuItem(value: 'Ollama (Local)', child: Text('Ollama (Localhost:11434)')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedProvider = val);
                    },
                  ),
                  if (_selectedProvider != 'Mock (Offline Test)' && _selectedProvider != 'Ollama (Local)') ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: _apiKeyController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'API Key',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Live Waveform Visualizer (Canvas 60fps)
          Card(
            color: Colors.grey.shade900,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  SizedBox(
                    height: 90,
                    child: SvfLiveWaveform(
                      controller: _waveformController,
                      style: const SvfWaveformStyle(
                        barColor: Colors.cyanAccent,
                        barWidth: 3.5,
                        barSpacing: 3.0,
                        barRadius: 2.0,
                        isSymmetric: true,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _toggleRecord,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _recordState.isRecording ? Colors.red : Colors.deepPurple,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                        icon: Icon(_recordState.isRecording ? Icons.stop : Icons.mic),
                        label: Text(_recordState.isRecording ? 'Stop & Process Voice' : 'Start Recording'),
                      ),
                      if (_recordState.isRecording) ...[
                        const SizedBox(width: 12),
                        IconButton(
                          onPressed: () {
                            if (_recordState.isPaused) {
                              _svf.recorder.resume();
                            } else {
                              _svf.recorder.pause();
                            }
                          },
                          icon: Icon(_recordState.isPaused ? Icons.play_arrow : Icons.pause, color: Colors.white),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Speech Transcript & Status
          if (_isTranscribing || _isExtracting) ...[
            const Center(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(width: 12),
                    Text('Processing audio & extracting structured fields...'),
                  ],
                ),
              ),
            ),
          ],
          if (_transcript.isNotEmpty) ...[
            Card(
              color: Colors.deepPurple.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.record_voice_over, size: 18, color: Colors.deepPurple),
                        SizedBox(width: 6),
                        Text('Voice Transcription:', style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(_transcript),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Human-in-the-Loop Editable Form Section
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.assignment, color: Colors.deepPurple),
                      SizedBox(width: 8),
                      Text('Human-in-the-Loop Patient Review', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const Text('Review AI extracted fields and make manual corrections if needed:', style: TextStyle(color: Colors.grey)),
                  const Divider(height: 24),
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'Patient Full Name', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _ageController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Age', border: OutlineInputBorder()),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _durationController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Duration (Days)', border: OutlineInputBorder()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _selectedComplaint,
                          decoration: const InputDecoration(labelText: 'Primary Complaint', border: OutlineInputBorder()),
                          items: ['Fever', 'Headache', 'Cough', 'Chest Pain', 'Fatigue', 'Back Pain']
                              .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedComplaint = val);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _selectedSeverity,
                          decoration: const InputDecoration(labelText: 'Severity', border: OutlineInputBorder()),
                          items: ['Mild', 'Moderate', 'Severe']
                              .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedSeverity = val);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _notesController,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Clinical Notes', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    title: const Text('Mark as Urgent Case'),
                    value: _isUrgent,
                    onChanged: (val) => setState(() => _isUrgent = val),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _approveAndExport,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Approve & Export Verified Data', style: TextStyle(fontSize: 16)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- TAB 2: Resumable Model Downloader ---

  Widget _buildModelDownloaderTab() {
    final models = ModelRegistry.allBuiltIn;

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: models.length,
      itemBuilder: (context, index) {
        final manifest = models[index];
        final progress = _downloadProgressMap[manifest.id];

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(manifest.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                    Chip(
                      label: Text(manifest.formattedSize),
                      backgroundColor: Colors.grey.shade200,
                    ),
                  ],
                ),
                if (manifest.description != null) ...[
                  const SizedBox(height: 4),
                  Text(manifest.description!, style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                ],
                const SizedBox(height: 12),
                if (progress != null) ...[
                  LinearProgressIndicator(
                    value: progress.fraction > 0 ? progress.fraction : null,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Status: ${progress.status.name.toUpperCase()}'),
                      Text('${progress.percentageFormatted} (${progress.speedFormatted})'),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (progress?.status == DownloadStatus.downloading) ...[
                      TextButton.icon(
                        onPressed: () => _svf.downloader.pause(manifest.id),
                        icon: const Icon(Icons.pause),
                        label: const Text('Pause'),
                      ),
                      TextButton.icon(
                        onPressed: () => _svf.downloader.cancel(manifest.id),
                        icon: const Icon(Icons.cancel, color: Colors.red),
                        label: const Text('Cancel', style: TextStyle(color: Colors.red)),
                      ),
                    ] else if (progress?.status == DownloadStatus.paused) ...[
                      ElevatedButton.icon(
                        onPressed: () => _svf.downloader.resume(manifest.id),
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Resume Download'),
                      ),
                    ] else ...[
                      ElevatedButton.icon(
                        onPressed: () => _startModelDownload(manifest),
                        icon: const Icon(Icons.download),
                        label: const Text('Download Model'),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
