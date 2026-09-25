import 'dart:io';
import 'dart:typed_data';

/// Saves audio bytes to local filesystem on native platforms.
Future<String> saveAudioBytesToDisk(Uint8List bytes, String path) async {
  final file = File(path);
  await file.parent.create(recursive: true);
  await file.writeAsBytes(bytes);
  return file.path;
}

/// Web placeholder for native.
Future<String> saveAudioBytes(Uint8List bytes, String fileName) async {
  return fileName;
}
