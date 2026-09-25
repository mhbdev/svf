import 'dart:async';
import '../../core/schema/svf_schema.dart';

/// Callback type for executing a tool.
typedef ToolExecuteCallback = FutureOr<dynamic> Function(Map<String, dynamic> arguments);

/// A callable tool/function that an AI language model can invoke during generation.
class SvfTool {
  /// The unique name of the tool (e.g. "search_database", "fill_field").
  final String name;

  /// A detailed description explaining to the LLM when and how to use this tool.
  final String description;

  /// The parameter schema required by this tool.
  final SvfObjectSchema parameters;

  /// The execution callback that fulfills the tool call.
  final ToolExecuteCallback execute;

  const SvfTool({
    required this.name,
    required this.description,
    required this.parameters,
    required this.execute,
  });

  /// Formats this tool to standard OpenAI/Gemini function specification format.
  Map<String, dynamic> toFunctionDefinition() {
    return {
      'type': 'function',
      'function': {
        'name': name,
        'description': description,
        'parameters': parameters.toJsonSchema(strict: true),
      },
    };
  }
}
