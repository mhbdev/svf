/// Metadata descriptor for an downloadable on-device AI model weight.
class ModelManifest {
  /// Unique identifier (e.g. "whisper-tiny-en", "gemma-2b-q4").
  final String id;

  /// User-friendly display name.
  final String name;

  /// Direct HTTPS download URL (e.g. Hugging Face, GitHub Releases, Cloud Storage).
  final String downloadUrl;

  /// Expected size in bytes.
  final int sizeBytes;

  /// Expected SHA-256 hexadecimal hash digest for cryptographic integrity verification.
  final String? sha256;

  /// Model format (e.g. "gguf", "tflite", "onnx", "bin").
  final String format;

  /// Optional model parameter count or description.
  final String? description;

  const ModelManifest({
    required this.id,
    required this.name,
    required this.downloadUrl,
    required this.sizeBytes,
    this.sha256,
    this.format = 'bin',
    this.description,
  });

  /// Formatted file size string (e.g. "145.2 MB").
  String get formattedSize {
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    if (sizeBytes < 1024 * 1024 * 1024) {
      return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(sizeBytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'downloadUrl': downloadUrl,
        'sizeBytes': sizeBytes,
        if (sha256 != null) 'sha256': sha256,
        'format': format,
        if (description != null) 'description': description,
      };

  factory ModelManifest.fromMap(Map<String, dynamic> map) {
    return ModelManifest(
      id: map['id'] as String,
      name: map['name'] as String,
      downloadUrl: map['downloadUrl'] as String,
      sizeBytes: map['sizeBytes'] as int,
      sha256: map['sha256'] as String?,
      format: map['format'] as String? ?? 'bin',
      description: map['description'] as String?,
    );
  }
}
