import 'dart:io';
import 'dart:typed_data';

/// Reads all bytes from a file on native platforms.
Future<Uint8List> readFileBytes(String path) async {
  final file = File(path);
  if (!await file.exists()) {
    throw FileSystemException('Audio file not found at path: $path', path);
  }
  return file.readAsBytes();
}

/// Opens a file read stream on native platforms.
Stream<List<int>> openFileStream(String path) {
  final file = File(path);
  return file.openRead();
}
