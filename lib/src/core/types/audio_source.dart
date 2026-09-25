import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'audio_format.dart';
import '../errors/svf_exception.dart';

// Conditional file reader for IO vs Web platforms
import 'audio_source_io.dart'
    if (dart.library.js_interop) 'audio_source_web.dart'
    as platform_impl;

/// Universal cross-platform audio container supporting files (native),
/// byte arrays (memory / web blobs), and streaming buffers.
class SvfAudioSource {
  final Uint8List? bytes;
  final String? path;
  final Stream<List<int>>? stream;
  final int? length;
  final String? _customName;
  final SvfAudioFormat format;

  const SvfAudioSource._({
    this.bytes,
    this.path,
    this.stream,
    this.length,
    this._customName,
    required this.format,
  });

  /// Creates an audio source from an in-memory byte buffer (works everywhere, including Web).
  factory SvfAudioSource.fromBytes(
    Uint8List bytes, {
    String? name,
    SvfAudioFormat format = SvfAudioFormat.m4a,
  }) {
    return SvfAudioSource._(
      bytes: bytes,
      length: bytes.length,
      customName: name ?? 'recording.${format.extension}',
      format: format,
    );
  }

  /// Creates an audio source from a local file path (Android, iOS, Desktop).
  factory SvfAudioSource.fromFile(
    String path, {
    String? name,
    SvfAudioFormat? format,
  }) {
    final guessedFormat = format ?? SvfAudioFormat.fromExtension(path);
    return SvfAudioSource._(
      path: path,
      customName: name,
      format: guessedFormat,
    );
  }

  /// Creates an audio source from an active byte stream (e.g. microphone chunks).
  factory SvfAudioSource.fromStream(
    Stream<List<int>> stream, {
    int? length,
    String? name,
    SvfAudioFormat format = SvfAudioFormat.wav,
  }) {
    return SvfAudioSource._(
      stream: stream,
      length: length,
      customName: name ?? 'stream.${format.extension}',
      format: format,
    );
  }

  /// Creates an audio source from a base64 encoded audio string.
  factory SvfAudioSource.fromBase64(
    String base64String, {
    String? name,
    SvfAudioFormat format = SvfAudioFormat.m4a,
  }) {
    final decodedBytes = base64Decode(base64String);
    return SvfAudioSource.fromBytes(decodedBytes, name: name, format: format);
  }

  /// The MIME type for HTTP multipart or playback.
  String get mimeType => format.mimeType;

  /// The file name or default identifier.
  String get name {
    final cn = _customName;
    if (cn != null) return cn;
    final p = path;
    if (p != null) return p.split(RegExp(r'[\\/]')).last;
    return 'audio.${format.extension}';
  }

  /// Returns true if this source is backed by an in-memory byte buffer.
  bool get hasBytes => bytes != null;

  /// Returns true if this source is backed by a local file path.
  bool get hasPath => path != null;

  /// Reads and returns all bytes as [Uint8List].
  Future<Uint8List> readBytes() async {
    final b = bytes;
    if (b != null) {
      return b;
    }
    final p = path;
    if (p != null) {
      return platform_impl.readFileBytes(p);
    }
    final s = stream;
    if (s != null) {
      final builder = BytesBuilder(copy: false);
      await for (final chunk in s) {
        builder.add(chunk);
      }
      return builder.takeBytes();
    }
    throw const SvfAudioException(
      'Empty audio source: no bytes, path, or stream available',
    );
  }

  /// Converts the audio bytes into a Base64-encoded string.
  Future<String> toBase64() async {
    final b = await readBytes();
    return base64Encode(b);
  }

  /// Converts to a data URI string (e.g. data:audio/mp4;base64,...).
  Future<String> toDataUri() async {
    final b64 = await toBase64();
    return 'data:${format.mimeType};base64,$b64';
  }

  /// Opens a byte stream for reading.
  Stream<List<int>> openRead() {
    final s = stream;
    if (s != null) {
      return s;
    }
    final b = bytes;
    if (b != null) {
      return Stream.value(b);
    }
    final p = path;
    if (p != null) {
      return platform_impl.openFileStream(p);
    }
    return Stream.error(
      const SvfAudioException('No data available in audio source'),
    );
  }
}
