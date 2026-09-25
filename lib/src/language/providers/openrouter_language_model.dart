import 'openai_language_model.dart';

/// OpenRouter adapter using its OpenAI-compatible Chat Completions API.
///
/// The optional attribution headers are useful for OpenRouter rankings and are
/// passed through unchanged. API keys should not be embedded in Flutter Web
/// production builds; use a server-side proxy for browser applications.
class OpenRouterLanguageModel extends OpenAiLanguageModel {
  OpenRouterLanguageModel({
    required super.modelId,
    required super.apiKey,
    String? httpReferer,
    String? appTitle,
    Map<String, String> headers = const {},
    super.requestOptions = const {},
    super.requestTimeout,
    super.client,
  }) : super(
         baseUrl: 'https://openrouter.ai/api/v1',
         providerId: 'openrouter',
         isOffline: false,
         headers: {
           if (httpReferer != null && httpReferer.isNotEmpty)
             'HTTP-Referer': httpReferer,
           if (appTitle != null && appTitle.isNotEmpty)
             'X-OpenRouter-Title': appTitle,
           ...headers,
         },
       );
}
