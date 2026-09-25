import 'dart:async';
import 'package:http/http.dart' as http;
import '../core/errors/svf_exception.dart';
import 'cache.dart';
import 'manifest.dart';
import 'progress.dart';

// Platform chunk appender
import 'downloader_io.dart' if (dart.library.js_interop) 'downloader_web.dart' as platform_dl;

/// Active download session record.
class _ActiveSession {
  final ModelManifest manifest;
  final StreamController<DownloadProgress> controller;
  StreamSubscription<List<int>>? subscription;
  platform_dl.ChunkAppender? appender;
  bool isPaused = false;
  bool isCanceled = false;

  _ActiveSession({
    required this.manifest,
    required this.controller,
  });
}

/// Enterprise-grade resumable model downloader using standard HTTP Range headers.
/// Supports pause, resume, cancel, speed calculation, and SHA-256 integrity verification.
class ResumableDownloader {
  final ModelCache cache;
  final http.Client _client;
  final Map<String, _ActiveSession> _sessions = {};

  ResumableDownloader({
    ModelCache? cache,
    http.Client? client,
  })  : cache = cache ?? ModelCache(),
        _client = client ?? http.Client();

  /// Obtains the reactive progress stream for a specific model download.
  Stream<DownloadProgress> progressStream(String modelId) {
    if (_sessions.containsKey(modelId)) {
      return _sessions[modelId]!.controller.stream;
    }
    final controller = StreamController<DownloadProgress>.broadcast();
    return controller.stream;
  }

  /// Downloads a model specified by [manifest].
  /// If partially downloaded previously, automatically resumes from the last byte.
  Future<String> download(
    ModelManifest manifest, {
    bool forceRedownload = false,
  }) async {
    final finalPath = await cache.getModelFilePath(manifest);

    // Check if already cached and valid
    if (!forceRedownload && await cache.isModelCached(manifest)) {
      if (manifest.sha256 != null) {
        final isValid = await cache.verifyChecksum(finalPath, manifest.sha256!);
        if (isValid) {
          _emitProgress(
            manifest.id,
            DownloadProgress(
              modelId: manifest.id,
              status: DownloadStatus.completed,
              bytesDownloaded: manifest.sizeBytes,
              totalBytes: manifest.sizeBytes,
            ),
          );
          return finalPath;
        }
      } else {
        return finalPath;
      }
    }

    // Get or create session controller
    final session = _sessions.putIfAbsent(
      manifest.id,
      () => _ActiveSession(
        manifest: manifest,
        controller: StreamController<DownloadProgress>.broadcast(),
      ),
    );

    session.isPaused = false;
    session.isCanceled = false;

    final partPath = await cache.getPartFilePath(manifest.id);
    int existingBytes = forceRedownload ? 0 : await cache.getPartFileSize(manifest.id);

    _emitProgress(
      manifest.id,
      DownloadProgress(
        modelId: manifest.id,
        status: DownloadStatus.connecting,
        bytesDownloaded: existingBytes,
        totalBytes: manifest.sizeBytes,
      ),
    );

    final request = http.Request('GET', Uri.parse(manifest.downloadUrl));
    if (existingBytes > 0) {
      request.headers['Range'] = 'bytes=$existingBytes-';
    }

    final streamedResponse = await _client.send(request);

    final bool isPartial = streamedResponse.statusCode == 206;
    if (streamedResponse.statusCode != 200 && streamedResponse.statusCode != 206) {
      final err = 'Download failed with HTTP status ${streamedResponse.statusCode}';
      _emitProgress(
        manifest.id,
        DownloadProgress(
          modelId: manifest.id,
          status: DownloadStatus.failed,
          bytesDownloaded: existingBytes,
          totalBytes: manifest.sizeBytes,
          error: err,
        ),
      );
      throw SvfDownloadException(err, modelId: manifest.id);
    }

    if (!isPartial && existingBytes > 0) {
      // Server doesn't support Range requests, restarting from 0
      existingBytes = 0;
    }

    final totalBytes = isPartial
        ? existingBytes + (streamedResponse.contentLength ?? (manifest.sizeBytes - existingBytes))
        : (streamedResponse.contentLength ?? manifest.sizeBytes);

    final appender = await platform_dl.ChunkAppender.open(
      partPath,
      append: isPartial && existingBytes > 0,
    );
    session.appender = appender;

    int downloadedBytes = existingBytes;
    int bytesSinceLastSpeedCheck = 0;
    DateTime lastSpeedCheckTime = DateTime.now();
    double currentSpeed = 0.0;

    final completer = Completer<String>();

    session.subscription = streamedResponse.stream.listen(
      (chunk) {
        if (session.isPaused || session.isCanceled) return;

        appender.add(chunk);
        downloadedBytes += chunk.length;
        bytesSinceLastSpeedCheck += chunk.length;

        final now = DateTime.now();
        final elapsedMs = now.difference(lastSpeedCheckTime).inMilliseconds;
        if (elapsedMs >= 400) {
          currentSpeed = (bytesSinceLastSpeedCheck / (elapsedMs / 1000.0));
          bytesSinceLastSpeedCheck = 0;
          lastSpeedCheckTime = now;

          _emitProgress(
            manifest.id,
            DownloadProgress(
              modelId: manifest.id,
              status: DownloadStatus.downloading,
              bytesDownloaded: downloadedBytes,
              totalBytes: totalBytes,
              speedBytesPerSecond: currentSpeed,
            ),
          );
        }
      },
      onError: (e, st) async {
        await appender.close();
        if (session.isPaused) return;

        _emitProgress(
          manifest.id,
          DownloadProgress(
            modelId: manifest.id,
            status: DownloadStatus.failed,
            bytesDownloaded: downloadedBytes,
            totalBytes: totalBytes,
            error: e.toString(),
          ),
        );
        if (!completer.isCompleted) completer.completeError(e, st);
      },
      onDone: () async {
        await appender.flush();
        await appender.close();

        if (session.isPaused) {
          _emitProgress(
            manifest.id,
            DownloadProgress(
              modelId: manifest.id,
              status: DownloadStatus.paused,
              bytesDownloaded: downloadedBytes,
              totalBytes: totalBytes,
            ),
          );
          return;
        }

        if (session.isCanceled) {
          _emitProgress(
            manifest.id,
            DownloadProgress(
              modelId: manifest.id,
              status: DownloadStatus.canceled,
              bytesDownloaded: 0,
              totalBytes: totalBytes,
            ),
          );
          return;
        }

        // Verify SHA-256 integrity
        if (manifest.sha256 != null && manifest.sha256!.isNotEmpty) {
          _emitProgress(
            manifest.id,
            DownloadProgress(
              modelId: manifest.id,
              status: DownloadStatus.verifying,
              bytesDownloaded: downloadedBytes,
              totalBytes: totalBytes,
            ),
          );

          final isValid = await cache.verifyChecksum(partPath, manifest.sha256!);
          if (!isValid) {
            final err = 'SHA-256 verification failed for downloaded model ${manifest.id}';
            _emitProgress(
              manifest.id,
              DownloadProgress(
                modelId: manifest.id,
                status: DownloadStatus.failed,
                bytesDownloaded: downloadedBytes,
                totalBytes: totalBytes,
                error: err,
              ),
            );
            if (!completer.isCompleted) {
              completer.completeError(SvfDownloadException(err, modelId: manifest.id));
            }
            return;
          }
        }

        // Promote .part file to final model destination
        await cache.promotePartFile(partPath, finalPath);

        _emitProgress(
          manifest.id,
          DownloadProgress(
            modelId: manifest.id,
            status: DownloadStatus.completed,
            bytesDownloaded: downloadedBytes,
            totalBytes: totalBytes,
          ),
        );

        if (!completer.isCompleted) completer.complete(finalPath);
      },
      cancelOnError: true,
    );

    return completer.future;
  }

  /// Pauses an active download session.
  Future<void> pause(String modelId) async {
    final session = _sessions[modelId];
    if (session == null) return;
    session.isPaused = true;
    await session.subscription?.cancel();
    session.subscription = null;
    await session.appender?.close();
    session.appender = null;

    final partSize = await cache.getPartFileSize(modelId);
    _emitProgress(
      modelId,
      DownloadProgress(
        modelId: modelId,
        status: DownloadStatus.paused,
        bytesDownloaded: partSize,
        totalBytes: session.manifest.sizeBytes,
      ),
    );
  }

  /// Resumes a previously paused download session.
  Future<String> resume(String modelId) async {
    final session = _sessions[modelId];
    if (session == null) {
      throw SvfDownloadException('No active download session found to resume for model $modelId');
    }
    return download(session.manifest);
  }

  /// Cancels an active or paused download and deletes partial chunks.
  Future<void> cancel(String modelId) async {
    final session = _sessions[modelId];
    if (session != null) {
      session.isCanceled = true;
      await session.subscription?.cancel();
      session.subscription = null;
      await session.appender?.close();
      session.appender = null;
      _sessions.remove(modelId);
    }
    await cache.deleteModel(modelId);
    _emitProgress(
      modelId,
      DownloadProgress(
        modelId: modelId,
        status: DownloadStatus.canceled,
        bytesDownloaded: 0,
        totalBytes: 0,
      ),
    );
  }

  void _emitProgress(String modelId, DownloadProgress progress) {
    final session = _sessions[modelId];
    if (session != null && !session.controller.isClosed) {
      session.controller.add(progress);
    }
  }

  /// Releases resources.
  void dispose() {
    for (final session in _sessions.values) {
      session.subscription?.cancel();
      session.appender?.close();
      session.controller.close();
    }
    _sessions.clear();
  }
}
