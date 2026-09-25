import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:web/web.dart' as web;

const _databaseName = 'svf-model-cache';
const _databaseVersion = 1;
const _storeName = 'artifacts';
const _metaSuffix = ':meta';

Future<JSAny?> _requestResult(web.IDBRequest request) {
  final completer = Completer<JSAny?>();
  request.onsuccess = ((web.Event _) {
    if (!completer.isCompleted) completer.complete(request.result);
  }).toJS;
  request.onerror = ((web.Event _) {
    if (!completer.isCompleted) {
      final error = request.error;
      completer.completeError(
        StateError('IndexedDB request failed: ${error?.name ?? 'unknown'}'),
      );
    }
  }).toJS;
  return completer.future;
}

Future<void> _transactionCompleted(web.IDBTransaction transaction) {
  final completer = Completer<void>();
  transaction.oncomplete = ((web.Event _) {
    if (!completer.isCompleted) completer.complete();
  }).toJS;
  transaction.onerror = ((web.Event _) {
    if (!completer.isCompleted) {
      completer.completeError(
        StateError(
          'IndexedDB transaction failed: ${transaction.error?.name ?? 'unknown'}',
        ),
      );
    }
  }).toJS;
  transaction.onabort = ((web.Event _) {
    if (!completer.isCompleted) {
      completer.completeError(StateError('IndexedDB transaction aborted.'));
    }
  }).toJS;
  return completer.future;
}

Future<web.IDBDatabase> _openDatabase() async {
  final request = web.window.indexedDB.open(_databaseName, _databaseVersion);
  request.onupgradeneeded = ((web.Event _) {
    final database = request.result as web.IDBDatabase;
    if (!database.objectStoreNames.contains(_storeName)) {
      database.createObjectStore(_storeName);
    }
  }).toJS;
  return (await _requestResult(request)) as web.IDBDatabase;
}

String _metaKey(String path) => '$path$_metaSuffix';

Object? _dartify(JSAny? value) => value?.dartify();

Future<Map<String, dynamic>?> _readMeta(String path) async {
  final database = await _openDatabase();
  final transaction = database.transaction(_storeName.toJS, 'readonly');
  final value = await _requestResult(
    transaction.objectStore(_storeName).get(_metaKey(path).toJS),
  );
  await _transactionCompleted(transaction);
  database.close();
  final dartValue = _dartify(value);
  if (dartValue is Map) return Map<String, dynamic>.from(dartValue);
  return null;
}

Future<List<int>?> _readChunk(String path, int index) async {
  final database = await _openDatabase();
  final transaction = database.transaction(_storeName.toJS, 'readonly');
  final value = await _requestResult(
    transaction.objectStore(_storeName).get('$path:$index'.toJS),
  );
  await _transactionCompleted(transaction);
  database.close();
  if (value?.isA<JSUint8Array>() ?? false) {
    return (value as JSUint8Array).toDart;
  }
  final dartValue = _dartify(value);
  if (dartValue is List) return List<int>.from(dartValue);
  return null;
}

Future<void> _deleteArtifact(String path) async {
  final meta = await _readMeta(path);
  if (meta == null) return;

  final database = await _openDatabase();
  final transaction = database.transaction(_storeName.toJS, 'readwrite');
  final store = transaction.objectStore(_storeName);
  final count = meta['chunkCount'] as int? ?? 0;
  for (var index = 0; index < count; index++) {
    await _requestResult(store.delete('$path:$index'.toJS));
  }
  await _requestResult(store.delete(_metaKey(path).toJS));
  await _transactionCompleted(transaction);
  database.close();
}

Future<List<int>> readFileBytes(String path) async {
  final meta = await _readMeta(path);
  if (meta == null) return <int>[];

  final count = meta['chunkCount'] as int? ?? 0;
  final bytes = BytesBuilder(copy: false);
  for (var index = 0; index < count; index++) {
    final chunk = await _readChunk(path, index);
    if (chunk != null) bytes.add(chunk);
  }
  return bytes.takeBytes();
}

Future<bool> doesFileExist(String path) async =>
    (await _readMeta(path)) != null;

Future<int> getFileSize(String path) async {
  final meta = await _readMeta(path);
  return meta?['sizeBytes'] as int? ?? 0;
}

Future<bool> verifySha256(String filePath, String expectedSha256) async {
  final bytes = await readFileBytes(filePath);
  if (bytes.isEmpty && await getFileSize(filePath) != 0) return false;
  return sha256.convert(bytes).toString().toLowerCase() ==
      expectedSha256.toLowerCase();
}

Future<void> renameFile(String oldPath, String newPath) async {
  final meta = await _readMeta(oldPath);
  if (meta == null) return;

  await _deleteArtifact(newPath);
  final count = meta['chunkCount'] as int? ?? 0;
  for (var index = 0; index < count; index++) {
    final chunk = await _readChunk(oldPath, index);
    if (chunk == null) continue;

    final database = await _openDatabase();
    final transaction = database.transaction(_storeName.toJS, 'readwrite');
    await _requestResult(
      transaction
          .objectStore(_storeName)
          .put(chunk.toUint8List().toJS, '$newPath:$index'.toJS),
    );
    await _transactionCompleted(transaction);
    database.close();
  }

  final database = await _openDatabase();
  final transaction = database.transaction(_storeName.toJS, 'readwrite');
  await _requestResult(
    transaction
        .objectStore(_storeName)
        .put(meta.jsify(), _metaKey(newPath).toJS),
  );
  await _transactionCompleted(transaction);
  database.close();
  await _deleteArtifact(oldPath);
}

Future<void> deleteFile(String path) => _deleteArtifact(path);

/// Web-backed appender that persists each download chunk in IndexedDB.
class ChunkAppender {
  final String path;
  int _nextIndex;
  int _sizeBytes;
  Future<void> _pending = Future<void>.value();

  ChunkAppender._(this.path, this._nextIndex, this._sizeBytes);

  static Future<ChunkAppender> open(String path, {bool append = true}) async {
    if (!append) await deleteFile(path);
    final meta = append ? await _readMeta(path) : null;
    return ChunkAppender._(
      path,
      meta?['chunkCount'] as int? ?? 0,
      meta?['sizeBytes'] as int? ?? 0,
    );
  }

  void add(List<int> chunk) {
    final index = _nextIndex++;
    final bytes = Uint8List.fromList(chunk);
    _sizeBytes += bytes.length;
    final size = _sizeBytes;
    _pending = _pending.then((_) async {
      final database = await _openDatabase();
      final transaction = database.transaction(_storeName.toJS, 'readwrite');
      final store = transaction.objectStore(_storeName);
      await _requestResult(store.put(bytes.toJS, '$path:$index'.toJS));
      await _requestResult(
        store.put(
          <String, Object?>{'chunkCount': index + 1, 'sizeBytes': size}.jsify(),
          _metaKey(path).toJS,
        ),
      );
      await _transactionCompleted(transaction);
      database.close();
    });
  }

  Future<void> flush() => _pending;

  Future<void> close() => flush();
}

extension on List<int> {
  Uint8List toUint8List() =>
      this is Uint8List ? this as Uint8List : Uint8List.fromList(this);
}
