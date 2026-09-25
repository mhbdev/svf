import 'openai_language_model.dart';

/// Pre-configured Ollama / Local LanguageModel provider for on-premises or local server inference.
class OllamaLanguageModel extends OpenAiLanguageModel {
  OllamaLanguageModel({
    required super.modelId,
    super.apiKey = 'ollama',
    super.baseUrl = 'http://localhost:11434/v1',
    super.client,
  }) : super(
         providerId: 'ollama',
         isOffline: true, // Runs locally on user's machine/network
       );
}
