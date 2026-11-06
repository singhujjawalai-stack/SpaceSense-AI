class ApiKeyModel {
  final String provider;
  final String model;
  final String apiKey;

  ApiKeyModel({
    required this.provider,
    required this.model,
    required this.apiKey,
  });

  factory ApiKeyModel.fromJson(Map<String, dynamic> json) {
    return ApiKeyModel(
      provider: json['provider'] as String,
      model: json['model'] as String,
      apiKey: json['api_key'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'provider': provider,
      'model': model,
      'api_key': apiKey,
    };
  }
}

class SupportedProvider {
  static const String openai = 'openai';
  static const String anthropic = 'anthropic';
  static const String google = 'google';
  static const String openrouter = 'openrouter';

  /// Ordered by free-friendliness: Google and OpenRouter have genuinely
  /// free tiers; the others are strictly pay-per-use.
  static List<String> get all => [google, openrouter, openai, anthropic];

  static Map<String, List<String>> get models => {
        openai: ['gpt-4o', 'gpt-4o-mini'],
        anthropic: ['claude-3-5-sonnet-20241022', 'claude-3-5-haiku-20241022'],
        google: [
          'gemini-3.8-flash',
          'gemini-3.7-flash',
          'gemini-3.5-flash',
          'gemini-3.5-flash-lite',
          'gemini-2.5-flash',
          'gemini-2.5-flash-lite',
        ],
        openrouter: [
          'nvidia/nemotron-3.5-super-vl:free',
          'google/gemma-4-26b-a4b-it:free',
          'dots-studio/dots-3-note-preview:free',
        ],
      };

  /// Where the user creates an API key for this provider.
  static String? consoleUrl(String provider) {
    switch (provider) {
      case google:
        return 'https://aistudio.google.com/apikey';
      case openrouter:
        return 'https://openrouter.ai/settings/keys';
      case openai:
        return 'https://platform.openai.com/api-keys';
      case anthropic:
        return 'https://console.anthropic.com/settings/keys';
      default:
        return null;
    }
  }

  /// Human-friendly hint shown in Settings for each provider.
  static String? hint(String provider) {
    switch (provider) {
      case google:
        return 'Free tier available — \$0 charges, rate-limited';
      case openrouter:
        return 'Free ":free" models — \$0 charges, tight daily limits';
      case openai:
        return 'Pay per request from prepaid credits';
      case anthropic:
        return 'Pay per request from prepaid credits';
      default:
        return null;
    }
  }
}
