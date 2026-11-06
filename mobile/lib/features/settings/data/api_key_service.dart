import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../../shared/models/api_key_model.dart';

class ApiKeyService {
  static const String _apiKeyKey = 'user_api_key';
  static const String _openRouterKey = 'openrouter_api_key';

  Future<void> saveApiKey(ApiKeyModel apiKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_apiKeyKey, json.encode(apiKey.toJson()));
  }

  Future<ApiKeyModel?> getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_apiKeyKey);
    if (jsonString != null) {
      return ApiKeyModel.fromJson(json.decode(jsonString) as Map<String, dynamic>);
    }
    return null;
  }

  Future<void> deleteApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_apiKeyKey);
  }

  Future<bool> hasApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_apiKeyKey);
  }

  /// Optional OpenRouter key — enables free-tier IMAGE generation fallback
  /// (e.g. Nano Banana ":free" variants) via openrouter.ai.
  Future<void> saveOpenRouterKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_openRouterKey, key);
  }

  Future<String?> getOpenRouterKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_openRouterKey);
  }

  Future<void> deleteOpenRouterKey() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_openRouterKey);
  }
}

final apiKeyServiceProvider = Provider<ApiKeyService>((ref) => ApiKeyService());

final apiKeyProvider = FutureProvider<ApiKeyModel?>((ref) async {
  final service = ref.watch(apiKeyServiceProvider);
  return await service.getApiKey();
});
