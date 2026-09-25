import 'openai_language_model.dart';

/// Pre-configured Groq LanguageModel provider for high-speed cloud inference.
class GroqLanguageModel extends OpenAiLanguageModel {
  GroqLanguageModel({
    required super.modelId,
    required super.apiKey,
    super.baseUrl = 'https://api.groq.com/openai/v1',
    super.client,
  }) : super(providerId: 'groq', isOffline: false);
}
