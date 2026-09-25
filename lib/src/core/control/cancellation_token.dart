import 'dart:async';

/// Cooperative cancellation signal shared by long-running SVF operations.
///
/// Providers should check [isCancelled] between network/model steps and should
/// complete their streams when [cancel] is called. Cancellation is deliberately
/// cooperative because Dart cannot safely interrupt arbitrary native inference.
final class CancellationToken {
  final Completer<void> _completer = Completer<void>();

  /// Completes exactly once when cancellation is requested.
  Future<void> get cancelled => _completer.future;

  /// Whether cancellation has already been requested.
  bool get isCancelled => _completer.isCompleted;

  /// Requests cancellation.
  void cancel() {
    if (!_completer.isCompleted) {
      _completer.complete();
    }
  }

  /// Throws [OperationCanceledException] when cancellation was requested.
  void throwIfCancelled() {
    if (isCancelled) {
      throw const OperationCanceledException();
    }
  }
}

/// Error raised when an operation is cancelled by its caller.
final class OperationCanceledException implements Exception {
  const OperationCanceledException();

  @override
  String toString() =>
      'OperationCanceledException: The operation was cancelled.';
}
