import '../contracts/message.dart';
import '../models/generation_result.dart';
import '../../core/types/usage.dart';

/// A normalized event emitted by a streaming language-model call.
sealed class GenerationEvent {
  const GenerationEvent();
}

final class GenerationStarted extends GenerationEvent {
  const GenerationStarted();
}

final class TextDelta extends GenerationEvent {
  final String text;

  const TextDelta(this.text);
}

final class ToolCallDelta extends GenerationEvent {
  final String id;
  final String name;
  final String argumentsDelta;

  const ToolCallDelta({
    required this.id,
    required this.name,
    required this.argumentsDelta,
  });
}

final class GenerationFinished extends GenerationEvent {
  final FinishReason finishReason;
  final SvfUsage usage;
  final List<ToolCall> toolCalls;

  const GenerationFinished({
    required this.finishReason,
    this.usage = SvfUsage.zero,
    this.toolCalls = const [],
  });
}

final class GenerationFailed extends GenerationEvent {
  final Object error;
  final StackTrace? stackTrace;

  const GenerationFailed(this.error, [this.stackTrace]);
}
