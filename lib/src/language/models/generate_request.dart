import '../../core/control/cancellation_token.dart';
import '../../core/schema/svf_schema.dart';
import '../contracts/message.dart';
import '../contracts/tool.dart';

/// Normalized request used by both immediate and streaming generation.
final class GenerateRequest {
  final List<ChatMessage> messages;
  final SvfSchema? responseSchema;
  final List<SvfTool> tools;
  final double? temperature;
  final int? maxTokens;
  final double? topP;
  final List<String> stopSequences;
  final Map<String, dynamic> providerOptions;
  final CancellationToken? cancellationToken;

  GenerateRequest({
    required List<ChatMessage> messages,
    this.responseSchema,
    List<SvfTool> tools = const [],
    this.temperature,
    this.maxTokens,
    this.topP,
    List<String> stopSequences = const [],
    Map<String, dynamic> providerOptions = const {},
    this.cancellationToken,
  }) : messages = List<ChatMessage>.unmodifiable(messages),
       tools = List<SvfTool>.unmodifiable(tools),
       stopSequences = List<String>.unmodifiable(stopSequences),
       providerOptions = Map<String, dynamic>.unmodifiable(providerOptions);
}
