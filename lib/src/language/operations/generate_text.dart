import '../contracts/language_model.dart';
import '../contracts/message.dart';
import '../contracts/tool.dart';
import '../models/generation_result.dart';

/// Generates text and handles tool call suggestions using a specified [model].
///
/// Example:
/// ```dart
/// final result = await generateText(
///   model: svf.model('gemini-1.5-flash'),
///   prompt: 'Summarize the user request in two sentences.',
/// );
/// print(result.text);
/// ```
Future<GenerateTextResult> generateText({
  required LanguageModel model,
  String? prompt,
  List<ChatMessage>? messages,
  String? system,
  List<SvfTool>? tools,
  double? temperature,
  int? maxTokens,
  double? topP,
  List<String>? stopSequences,
}) async {
  final effectiveMessages = <ChatMessage>[];

  if (system != null && system.isNotEmpty) {
    effectiveMessages.add(ChatMessage.system(system));
  }

  if (messages != null) {
    effectiveMessages.addAll(messages);
  } else if (prompt != null) {
    effectiveMessages.add(ChatMessage.user(prompt));
  } else {
    throw ArgumentError('Either prompt or messages must be provided to generateText');
  }

  return model.doGenerate(
    messages: effectiveMessages,
    tools: tools,
    temperature: temperature,
    maxTokens: maxTokens,
    topP: topP,
    stopSequences: stopSequences,
  );
}
