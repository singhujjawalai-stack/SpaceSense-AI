import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import '../config/env.dart';

class ApiClient {
  late final Dio _dio;
  final Logger _logger = Logger();

  ApiClient() {
    _dio = Dio(
      BaseOptions(
        baseUrl: Env.apiBaseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    if (Env.enableLogging) {
      _dio.interceptors.add(LogInterceptor(
        requestBody: true,
        responseBody: true,
        logPrint: (obj) => _logger.d(obj),
      ));
    }
  }

  Future<Response> analyzeRoom({
    required String imageBase64,
    required String userApiKey,
    required String userApiProvider,
    required String userApiModel,
    required String roomName,
    required String authToken,
    List<String>? goals,
  }) async {
    try {
      final response = await _dio.post(
        '/api/v1/analyze',
        data: {
          'image_base64': imageBase64,
          'user_api_key': userApiKey,
          'user_api_provider': userApiProvider,
          'user_api_model': userApiModel,
          'room_name': roomName,
          'goals': goals ?? [],
        },
        options: Options(
          headers: {'Authorization': 'Bearer $authToken'},
        ),
      );
      return response;
    } catch (e) {
      _logger.e('Error analyzing room: $e');
      rethrow;
    }
  }

  Future<Response> testApiKey({
    required String apiKey,
    required String provider,
    required String model,
  }) async {
    try {
      final response = await _dio.post(
        '/api/v1/test-api-key',
        data: {
          'api_key': apiKey,
          'provider': provider,
          'model': model,
        },
      );
      return response;
    } catch (e) {
      _logger.e('Error testing API key: $e');
      rethrow;
    }
  }

  Future<Response> healthCheck() async {
    try {
      final response = await _dio.get('/health');
      return response;
    } catch (e) {
      _logger.e('Health check failed: $e');
      rethrow;
    }
  }
}
