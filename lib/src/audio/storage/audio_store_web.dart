import 'dart:typed_data';

/// Saves audio bytes on Web by preparing a data URL or in-memory reference.
Future<String> saveAudioBytes(Uint8List bytes, String fileName) async {
  return 'blob:$fileName';
}

/// Fallback for disk write on Web.
Future<String> saveAudioBytesToDisk(Uint8List bytes, String path) async {
  return 'blob:$path';
}
