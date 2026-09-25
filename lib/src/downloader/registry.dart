import 'manifest.dart';

/// Registry of popular pre-configured open-source model manifests
/// for on-device speech recognition and language inference.
class ModelRegistry {
  static final Map<String, ModelManifest> _customRegistry = {};

  /// OpenAI Whisper Tiny (English-only, ~75MB, fastest CPU inference).
  static const whisperTinyEn = ModelManifest(
    id: 'whisper-tiny-en',
    name: 'Whisper Tiny (English)',
    downloadUrl: 'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny.en.bin',
    sizeBytes: 77700000,
    sha256: 'bd577a113a86444523746b845ff18c6d7bd222526135f3971e70a24050a6df7a',
    format: 'bin',
    description: 'Fastest on-device Whisper model, ideal for low-end mobile CPUs.',
  );

  /// OpenAI Whisper Base (Multilingual, ~142MB).
  static const whisperBase = ModelManifest(
    id: 'whisper-base',
    name: 'Whisper Base (Multilingual)',
    downloadUrl: 'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.bin',
    sizeBytes: 147964211,
    sha256: '465707469f355b2b33da11b8436500b34e864010544c4dde78b82608c2fb86b0',
    format: 'bin',
    description: 'Balanced speed and accuracy across 99+ languages.',
  );

  /// Google Gemma 2B (Q4_K_M 4-bit quantized, ~1.4GB).
  static const gemma2bQ4 = ModelManifest(
    id: 'gemma-2b-it-q4',
    name: 'Google Gemma 2B Instruct (4-bit)',
    downloadUrl: 'https://huggingface.co/google/gemma-2b-it-GGUF/resolve/main/gemma-2b-it.Q4_K_M.gguf',
    sizeBytes: 1500000000,
    format: 'gguf',
    description: 'Compact 2B parameter LLM optimized for on-device instruction following.',
  );

  /// Qwen 2.5 1.5B (Q4_K_M 4-bit quantized, ~980MB).
  static const qwen1_5bQ4 = ModelManifest(
    id: 'qwen-2.5-1.5b-q4',
    name: 'Qwen 2.5 1.5B Instruct (4-bit)',
    downloadUrl: 'https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/qwen2.5-1.5b-instruct-q4_k_m.gguf',
    sizeBytes: 986000000,
    format: 'gguf',
    description: 'High-intelligence lightweight model suitable for edge devices.',
  );

  /// All built-in model manifests.
  static List<ModelManifest> get allBuiltIn => [
        whisperTinyEn,
        whisperBase,
        gemma2bQ4,
        qwen1_5bQ4,
      ];

  /// Registers a custom model manifest for download management.
  static void register(ModelManifest manifest) {
    _customRegistry[manifest.id] = manifest;
  }

  /// Finds a registered model manifest by identifier.
  static ModelManifest? find(String modelId) {
    if (_customRegistry.containsKey(modelId)) return _customRegistry[modelId];
    for (final m in allBuiltIn) {
      if (m.id == modelId) return m;
    }
    return null;
  }
}
