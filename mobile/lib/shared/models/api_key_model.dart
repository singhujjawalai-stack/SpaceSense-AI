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

  /// Ordered with Google first — it's the only provider with a genuinely
  /// free API tier; the others are strictly pay-per-use.
  static List<String> get all => [google, openai, anthropic];

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
      };

  /// Human-friendly hint shown in Settings for each provider.
  static String? hint(String provider) {
    switch (provider) {
      case google:
        return 'Free tier available — \$0 charges, rate-limited';
      case openai:
        return 'Pay per request from prepaid credits';
      case anthropic:
        return 'Pay per request from prepaid credits';
      default:
        return null;
    }
  }
}
