import 'dart:typed_data';
import '../errors/svf_exception.dart';

/// Web fallback for reading file path bytes (in web, direct file system paths are not accessible).
Future<Uint8List> readFileBytes(String path) async {
  throw SvfUnsupportedPlatformException(
    feature: 'Reading direct file path',
    platform: 'Web',
    message: 'Direct file system paths are not supported on Flutter Web. Use SvfAudioSource.fromBytes instead.',
  );
}

/// Web fallback for file stream.
Stream<List<int>> openFileStream(String path) {
  return Stream.error(
    SvfUnsupportedPlatformException(
      feature: 'Streaming direct file path',
      platform: 'Web',
      message: 'Direct file system paths are not supported on Flutter Web. Use SvfAudioSource.fromBytes instead.',
    ),
  );
}
