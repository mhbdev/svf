import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'manifest.dart';

// Platform conditional imports for file operations
import 'cache_io.dart' if (dart.library.js_interop) 'cache_web.dart' as platform_cache;

/// Manages local disk caching and verification of downloaded model files.
class ModelCache {
  final String _subDir;

  ModelCache({String subDirectory = 'svf_models'}) : _subDir = subDirectory;

  /// Resolves the root models directory path.
  Future<String> getModelsDirectory() async {
    if (kIsWeb) return 'indexed_db://models';
    final docsDir = await getApplicationDocumentsDirectory();
    return '${docsDir.path}/$_subDir';
  }

  /// Returns the target finalized file path for a model.
  Future<String> getModelFilePath(ModelManifest manifest) async {
    final root = await getModelsDirectory();
    return '$root/${manifest.id}.${manifest.format}';
  }

  /// Returns the temporary partial file path for a model.
  Future<String> getPartFilePath(String modelId) async {
    final root = await getModelsDirectory();
    return '$root/$modelId.part';
  }

  /// Checks if a model file is already downloaded and cached locally.
  Future<bool> isModelCached(ModelManifest manifest) async {
    if (kIsWeb) return false;
    final path = await getModelFilePath(manifest);
    return platform_cache.doesFileExist(path);
  }

  /// Returns the size in bytes of an in-progress partial `.part` file.
  Future<int> getPartFileSize(String modelId) async {
    if (kIsWeb) return 0;
    final path = await getPartFilePath(modelId);
    return platform_cache.getFileSize(path);
  }

  /// Verifies a downloaded file's SHA-256 checksum against [expectedSha256].
  Future<bool> verifyChecksum(String filePath, String expectedSha256) async {
    if (kIsWeb) return true;
    return platform_cache.verifySha256(filePath, expectedSha256);
  }

  /// Promotes a finished `.part` file to the final destination path.
  Future<void> promotePartFile(String partPath, String finalPath) async {
    await platform_cache.renameFile(partPath, finalPath);
  }

  /// Deletes a cached model or partial download.
  Future<void> deleteModel(String modelId, {String format = 'bin'}) async {
    final root = await getModelsDirectory();
    await platform_cache.deleteFile('$root/$modelId.$format');
    await platform_cache.deleteFile('$root/$modelId.part');
  }
}
