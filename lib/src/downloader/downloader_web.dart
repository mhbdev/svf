import 'dart:async';

/// Web placeholder for chunk appender.
class ChunkAppender {
  final List<List<int>> _chunks = [];
  final String path;

  ChunkAppender._(this.path);

  static Future<ChunkAppender> open(String path, {bool append = true}) async {
    return ChunkAppender._(path);
  }

  void add(List<int> chunk) {
    _chunks.add(chunk);
  }

  Future<void> flush() async {}

  Future<void> close() async {}
}
