import 'dart:async';
import 'dart:io';

/// Native file appender sink for resumable chunked downloads.
class ChunkAppender {
  final IOSink _sink;
  final String path;

  ChunkAppender._(this._sink, this.path);

  static Future<ChunkAppender> open(String path, {bool append = true}) async {
    final file = File(path);
    await file.parent.create(recursive: true);
    final sink = file.openWrite(
      mode: append ? FileMode.append : FileMode.write,
    );
    return ChunkAppender._(sink, path);
  }

  void add(List<int> chunk) {
    _sink.add(chunk);
  }

  Future<void> flush() async {
    await _sink.flush();
  }

  Future<void> close() async {
    await _sink.flush();
    await _sink.close();
  }
}
