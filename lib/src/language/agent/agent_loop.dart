import 'dart:convert';
import '../../core/control/cancellation_token.dart';
import '../../core/types/usage.dart';
import '../contracts/language_model.dart';
import '../contracts/message.dart';
import '../contracts/tool.dart';
import '../models/generation_result.dart';
import '../models/generate_request.dart';

/// Represents a single turn/step in a multi-step agentic loop.
class AgentStep {
  final int stepIndex;
  final GenerateTextResult response;
  final List<ToolExecutionRecord> toolExecutions;

  const AgentStep({
    required this.stepIndex,
    required this.response,
    required this.toolExecutions,
  });
}

/// Record of an executed tool call and its return value.
class ToolExecutionRecord {
  final ToolCall toolCall;
  final Object? output;
  final Object? error;

  const ToolExecutionRecord({required this.toolCall, this.output, this.error});

  bool get isSuccess => error == null;
}

/// Result returned from an [agentLoop] execution.
class AgentLoopResult {
  /// The final generated text answer.
  final String text;

  /// Complete list of chat messages exchanged across all turns.
  final List<ChatMessage> allMessages;

  /// Individual steps executed in the loop.
  final List<AgentStep> steps;

  /// Aggregated token usage across all steps.
  final SvfUsage totalUsage;

  const AgentLoopResult({
    required this.text,
    required this.allMessages,
    required this.steps,
    required this.totalUsage,
  });
}

/// Executes an autonomous multi-step agentic reasoning and tool-calling loop (Vercel AI SDK style).
///
/// Automatically executes tool calls, appends results to conversation history, and prompts
/// the model again until completion or [maxSteps] is reached.
Future<AgentLoopResult> agentLoop({
  required LanguageModel model,
  required List<ChatMessage> messages,
  required List<SvfTool> tools,
  int maxSteps = 5,
  Duration toolTimeout = const Duration(seconds: 30),
  Map<String, dynamic> providerOptions = const {},
  CancellationToken? cancellationToken,
  Future<bool> Function(SvfTool tool, ToolCall call)? requestApproval,
  void Function(AgentStep step)? onStepFinish,
}) async {
  if (maxSteps < 1) {
    throw ArgumentError.value(
      maxSteps,
      'maxSteps',
      'Must be greater than zero',
    );
  }

  final conversation = List<ChatMessage>.from(messages);
  final steps = <AgentStep>[];
  var accumulatedUsage = SvfUsage.zero;
  String finalOutput = '';

  for (int stepIndex = 1; stepIndex <= maxSteps; stepIndex++) {
    cancellationToken?.throwIfCancelled();
    final stepResult = await model.generate(
      GenerateRequest(
        messages: conversation,
        tools: tools,
        providerOptions: providerOptions,
        cancellationToken: cancellationToken,
      ),
    );

    accumulatedUsage += stepResult.usage;
    finalOutput = stepResult.text;

    // Append model's response to history
    conversation.add(
      ChatMessage.assistant(
        stepResult.text,
        toolCalls: stepResult.toolCalls.isNotEmpty
            ? stepResult.toolCalls
            : null,
      ),
    );

    // If no tool calls requested, the loop is finished!
    if (!stepResult.hasToolCalls) {
      final step = AgentStep(
        stepIndex: stepIndex,
        response: stepResult,
        toolExecutions: const [],
      );
      steps.add(step);
      onStepFinish?.call(step);
      break;
    }

    // Execute requested tools
    final executions = <ToolExecutionRecord>[];
    for (final call in stepResult.toolCalls) {
      final matchingTool = tools.cast<SvfTool?>().firstWhere(
        (t) => t?.name == call.name,
        orElse: () => null,
      );

      if (matchingTool == null) {
        final err = 'Tool "${call.name}" not found in available tools';
        executions.add(ToolExecutionRecord(toolCall: call, error: err));
        conversation.add(
          ChatMessage.tool(
            toolCallId: call.id,
            content: jsonEncode({'error': err}),
            name: call.name,
          ),
        );
        continue;
      }

      try {
        if (matchingTool.requiresApproval) {
          final approved =
              await requestApproval?.call(matchingTool, call) ?? false;
          if (!approved) {
            const err =
                'Tool execution was not approved by the host application';
            executions.add(ToolExecutionRecord(toolCall: call, error: err));
            conversation.add(
              ChatMessage.tool(
                toolCallId: call.id,
                content: jsonEncode({'error': err}),
                name: call.name,
              ),
            );
            continue;
          }
        }

        final validationErrors = matchingTool.parameters.validate(
          call.arguments,
        );
        if (validationErrors.isNotEmpty) {
          final err =
              'Invalid arguments for tool "${call.name}": '
              '${validationErrors.join('; ')}';
          executions.add(ToolExecutionRecord(toolCall: call, error: err));
          conversation.add(
            ChatMessage.tool(
              toolCallId: call.id,
              content: jsonEncode({'error': err}),
              name: call.name,
            ),
          );
          continue;
        }

        cancellationToken?.throwIfCancelled();
        final toolOutput = await Future<Object?>.value(
          matchingTool.execute(call.arguments),
        ).timeout(toolTimeout);
        executions.add(ToolExecutionRecord(toolCall: call, output: toolOutput));

        final stringOutput = toolOutput is String
            ? toolOutput
            : jsonEncode(toolOutput);

        conversation.add(
          ChatMessage.tool(
            toolCallId: call.id,
            content: stringOutput,
            name: call.name,
          ),
        );
      } catch (e) {
        executions.add(ToolExecutionRecord(toolCall: call, error: e));
        conversation.add(
          ChatMessage.tool(
            toolCallId: call.id,
            content: jsonEncode({'error': e.toString()}),
            name: call.name,
          ),
        );
      }
    }

    final step = AgentStep(
      stepIndex: stepIndex,
      response: stepResult,
      toolExecutions: executions,
    );
    steps.add(step);
    onStepFinish?.call(step);
  }

  return AgentLoopResult(
    text: finalOutput,
    allMessages: conversation,
    steps: steps,
    totalUsage: accumulatedUsage,
  );
}
