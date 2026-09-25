import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/types/audio_format.dart';
import '../../core/types/audio_source.dart';

// Conditional storage helpers
import 'audio_store_io.dart'
    if (dart.library.js_interop) 'audio_store_web.dart'
    as platform_store;

/// Manages local audio file storage, directory paths, and persistence.
class SvfAudioStore {
  /// Generates a recommended destination file path for a new recording.
  /// On Web, returns an empty string or virtual path.
  static Future<String> generateRecordingPath({
    String prefix = 'rec',
    SvfAudioFormat format = SvfAudioFormat.m4a,
  }) async {
    if (kIsWeb) {
      return '';
    }
    final dir = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '${dir.path}/${prefix}_$timestamp.${format.extension}';
  }

  /// Persists an in-memory [SvfAudioSource] or byte buffer to a local persistent file.
  static Future<String> saveRecording({
    required SvfAudioSource source,
    String? customPath,
    String prefix = 'saved_rec',
  }) async {
    final bytes = await source.readBytes();
    if (kIsWeb) {
      // On web, triggers browser file download or keeps in memory
      return platform_store.saveAudioBytes(bytes, source.name);
    }
    final targetPath =
        customPath ??
        await generateRecordingPath(prefix: prefix, format: source.format);
    return platform_store.saveAudioBytesToDisk(bytes, targetPath);
  }
}
