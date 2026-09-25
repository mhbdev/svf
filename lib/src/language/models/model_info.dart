/// Capabilities and identity information exposed by a language model adapter.
final class ModelInfo {
  final String modelId;
  final String providerId;
  final bool isOffline;
  final bool supportsStreaming;
  final bool supportsToolCalls;
  final bool supportsStructuredOutput;

  const ModelInfo({
    required this.modelId,
    required this.providerId,
    required this.isOffline,
    this.supportsStreaming = true,
    this.supportsToolCalls = false,
    this.supportsStructuredOutput = false,
  });
}
