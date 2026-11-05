import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

/// Riverpod provider for the app-wide AI service instance.
final aiServiceProviderSimple = Provider<AiService>((ref) => AiService());

/// AI service that calls vision AI providers DIRECTLY from the app.
///
/// Architecture: no intermediary backend — Supabase handles auth only, and
/// this service sends the user's own API key straight to the provider.
///
/// Supported providers: OpenAI (gpt-4o), Anthropic (Claude), Google (Gemini).
class AiService {
  final Logger _logger = Logger();

  late final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 60),
      receiveTimeout: const Duration(seconds: 180),
    ),
  );

  static const int _maxTokens = 4096;

  /// Result of a full room analysis (everything the app needs).
  /// The returned map matches AnalysisModel.fromJson, plus it contains
  /// the raw vision fields under 'vision' for future use.
  Future<Map<String, dynamic>> analyzeRoom({
    required String imageBase64,
    required String roomName,
    required String provider,
    required String model,
    required String apiKey,
    List<String> goals = const [],
  }) async {
    final stopwatch = Stopwatch()..start();
    final prompt = _buildAnalyzePrompt(roomName, goals);

    _logger.d('Starting direct AI analysis with $provider/$model');

    try {
      final String contentText = switch (provider) {
        'openai' => await _callOpenai(
            imageBase64: imageBase64,
            prompt: prompt,
            model: model,
            apiKey: apiKey,
          ),
        'anthropic' => await _callAnthropic(
            imageBase64: imageBase64,
            prompt: prompt,
            model: model,
            apiKey: apiKey,
          ),
        'google' => await _callGoogleWithFallback(
            imageBase64: imageBase64,
            prompt: prompt,
            model: model,
            apiKey: apiKey,
          ),
        _ => throw AiException('Unsupported provider: $provider'),
      };

      final vision = _extractJson(contentText);

      // Scores are computed locally (no AI call needed for math).
      final scores = calculateScores(vision);

      final recommendationsRaw = (vision['recommendations'] as List?) ?? [];

      final recommendations = <Map<String, dynamic>>[];
      for (var i = 0; i < recommendationsRaw.length; i++) {
        final rec = recommendationsRaw[i];
        if (rec is Map) {
          recommendations.add({
            'category': rec['category'] ?? 'design',
            'title': rec['title'] ?? 'Untitled suggestion',
            'description': rec['description'] ?? '',
            'reasoning': rec['reasoning'] ?? '',
            'budget_tier': rec['budget_tier'] ?? 'free',
            'difficulty': rec['difficulty'] ?? 'easy',
            'estimated_cost': rec['estimated_cost'] ?? '\$0',
            // AI-assigned impact score; degrade gracefully if missing
            'impact': ((rec['impact'] as num?)?.toInt()) ??
                (100 - i * 100 ~/ (recommendationsRaw.length + 1)),
            'priority':
                ((rec['priority'] as num?)?.toInt()) ?? i + 1,
          });
        }
      }
      // Rank = impact (desc). Lower rank number = better recommendation.
      recommendations.sort(
          (a, b) => (b['impact'] as int).compareTo(a['impact'] as int));
      if (recommendations.isEmpty) {
        recommendations.addAll(
            _getFallbackRecommendations(scores, goals).asMap().entries.map(
                  (e) => {
                    ...e.value,
                    'priority': e.key + 1,
                    'impact': 100 - e.key * 15,
                  },
                ));
      }

      // detected_objects are stored as simple label strings.
      final detectedLabels = <String>[];
      for (final obj in (vision['detected_objects'] as List?) ?? []) {
        if (obj is Map && obj['label'] != null) {
          detectedLabels.add(obj['label'] as String);
        } else if (obj is String) {
          detectedLabels.add(obj);
        }
      }

      final analysis = {
        'id': 'ana_${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}',
        'room_id': 'room_${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}',
        'room_name': roomName,
        'room_type': (vision['room_type'] ?? 'unknown') as String,
        'room_type_confidence':
            ((vision['room_type_confidence'] ?? 0.0) as num).toDouble(),
        'analyzed_at': DateTime.now().toUtc().toIso8601String(),
        'scores': scores,
        'detected_objects': detectedLabels,
        'suggested_products': (vision['suggested_products'] as List?) ?? [],
        'recommendations': recommendations,
        'processing_time_ms': stopwatch.elapsedMilliseconds,
        'ai_provider': provider,
        'ai_model': model,
        'vision': {
          'spatial_analysis': vision['spatial_analysis'] ?? {},
          'storage_areas': vision['storage_areas'] ?? [],
          'style_elements': vision['style_elements'] ?? [],
          'organization_opportunities':
              vision['organization_opportunities'] ?? [],
        },
      };

      _logger.d(
          'Analysis complete in ${stopwatch.elapsedMilliseconds}ms (${recommendations.length} recommendations)');

      return analysis;
    } on AiException {
      rethrow;
    } on DioException catch (e) {
      _logger.e('AI request failed: $e');
      throw AiException.fromDio(e);
    } catch (e) {
      _logger.e('Analysis failed: $e');
      throw AiException('Analysis failed: $e');
    }
  }

  /// Checks whether the provided key is accepted by the provider.
  /// Uses cheap/free endpoints where possible.
  Future<bool> validateKey({
    required String provider,
    required String model,
    required String apiKey,
  }) async {
    try {
      switch (provider) {
        case 'openai':
          final res = await _dio.get(
            'https://api.openai.com/v1/models',
            options: Options(headers: {'Authorization': 'Bearer $apiKey'}),
          );
          return res.statusCode == 200;

        case 'anthropic':
          final res = await _dio.post(
            'https://api.anthropic.com/v1/messages',
            options: Options(headers: {
              'x-api-key': apiKey,
              'anthropic-version': '2023-06-01',
            }),
            data: {
              'model': model,
              'max_tokens': 1,
              'messages': [
                {'role': 'user', 'content': 'hi'}
              ],
            },
          );
          return res.statusCode == 200;

        case 'google':
          final res = await _dio.get(
            'https://generativelanguage.googleapis.com/v1beta/models',
            queryParameters: {'key': apiKey},
          );
          return res.statusCode == 200;

        default:
          return false;
      }
    } on DioException catch (e) {
      _logger.d('Key validation failed: ${e.message}');
      return false;
    } catch (e) {
      _logger.d('Key validation failed: $e');
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Provider calls
  // ---------------------------------------------------------------------------

  Future<String> _callOpenai({
    required String imageBase64,
    required String prompt,
    required String model,
    required String apiKey,
  }) async {
    final res = await _dio.post(
      'https://api.openai.com/v1/chat/completions',
      options: Options(headers: {'Authorization': 'Bearer $apiKey'}),
      data: {
        'model': model,
        'max_tokens': _maxTokens,
        'temperature': 0.1,
        'response_format': {'type': 'json_object'},
        'messages': [
          {
            'role': 'user',
            'content': [
              {'type': 'text', 'text': prompt},
              {
                'type': 'image_url',
                'image_url': {'url': 'data:image/jpeg;base64,$imageBase64'},
              },
            ],
          },
        ],
      },
    );
    return (res.data['choices'][0]['message']['content'] ?? '') as String;
  }

  Future<String> _callAnthropic({
    required String imageBase64,
    required String prompt,
    required String model,
    required String apiKey,
  }) async {
    final res = await _dio.post(
      'https://api.anthropic.com/v1/messages',
      options: Options(headers: {
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
      }),
      data: {
        'model': model,
        'max_tokens': _maxTokens,
        'temperature': 0.1,
        'messages': [
          {
            'role': 'user',
            'content': [
              {
                'type': 'image',
                'source': {
                  'type': 'base64',
                  'media_type': 'image/jpeg',
                  'data': imageBase64,
                },
              },
              {'type': 'text', 'text': prompt},
            ],
          },
        ],
      },
    );
    return (res.data['content'][0]['text'] ?? '') as String;
  }

  /// Preferred order for free-tier Gemini models (best -> cheapest).
  static const List<String> _googlePreferred = [
    'gemini-2.5-flash',
    'gemini-2.5-flash-lite',
    'gemini-flash-latest',
    'gemini-2.0-flash',
    'gemini-2.0-flash-lite',
    'gemini-1.5-flash',
    'gemini-2.5-pro',
  ];

  /// Queries Google's free ListModels endpoint for what THIS key can use.
  /// Returns bare model names (no 'models/' prefix), newest space first.
  Future<List<String>> listGoogleModels(String apiKey) async {
    final names = <String>[];
    String? pageToken;
    do {
      final res = await _dio.get(
        'https://generativelanguage.googleapis.com/v1beta/models',
        queryParameters: {
          'key': apiKey,
          'pageSize': 200,
          if (pageToken != null) 'pageToken': pageToken,
        },
      );
      for (final m in (res.data['models'] as List?) ?? []) {
        final methods = ((m['supportedGenerationMethods'] as List?) ?? [])
            .map((e) => e.toString());
        final name =
            (m['name'] as String? ?? '').replaceFirst('models/', '');
        if (name.isNotEmpty && methods.contains('generateContent')) {
          names.add(name);
        }
      }
      pageToken = res.data['nextPageToken'] as String?;
    } while (pageToken != null);

    // Newest generations first within the same family
    names.sort((a, b) {
      int gen(String n) {
        if (n.contains('2.5')) return 0;
        if (n.contains('2.0')) return 1;
        if (n.contains('1.5')) return 2;
        return 3;
      }
      final g = gen(a).compareTo(gen(b));
      if (g != 0) return g;
      // pro < flash < flash-lite within a generation
      int rank(String n) {
        if (n.contains('pro')) return 0;
        if (n.contains('flash-lite')) return 2;
        if (n.contains('flash')) return 1;
        return 3;
      }
      return rank(a).compareTo(rank(b));
    });
    return names;
  }

  /// Google call with automatic model fallback: if the selected model isn't
  /// available for this key, retries with the best model the key offers.
  Future<String> _callGoogleWithFallback({
    required String imageBase64,
    required String prompt,
    required String model,
    required String apiKey,
  }) async {
    String current = model;
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        return await _callGoogle(
          imageBase64: imageBase64,
          prompt: prompt,
          model: current,
          apiKey: apiKey,
        );
      } on AiException catch (e) {
        final isModelMissing =
            e.message.contains('404') || e.message.contains('not found');
        if (!isModelMissing) rethrow;

        final available = await listGoogleModels(apiKey);
        if (available.isEmpty) rethrow;
        if (!available.contains(current)) {
          final best = _googlePreferred
              .firstWhere(available.contains, orElse: () => available.first);
          _logger.w(
              "Model '$current' unavailable for this key; falling back to '$best'");
          current = best;
          continue;
        }
        rethrow;
      }
    }
    throw AiException(
      'Model not available for your API key. Open Settings and pick one of: '
      '${current.isEmpty ? 'a Gemini model' : current}.',
    );
  }

  Future<String> _callGoogle({
    required String imageBase64,
    required String prompt,
    required String model,
    required String apiKey,
  }) async {
    final res = await _dio.post(
      'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent',
      queryParameters: {'key': apiKey},
      data: {
        'contents': [
          {
            'parts': [
              {
                'inline_data': {
                  'mime_type': 'image/jpeg',
                  'data': imageBase64,
                },
              },
              {'text': prompt},
            ],
          },
        ],
        'generationConfig': {
          'response_mime_type': 'application/json',
          'temperature': 0.1,
          'maxOutputTokens': _maxTokens,
        },
      },
    );
    final candidates = res.data['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) return '';
    final parts = candidates[0]['content']['parts'] as List?;
    return parts == null ? '' : (parts.first['text'] ?? '') as String;
  }

  // ---------------------------------------------------------------------------
  // Prompt (single combined call: vision analysis + recommendations)
  // ---------------------------------------------------------------------------

  String _buildAnalyzePrompt(String roomName, List<String> goals) {
    final goalsText = goals.isEmpty
        ? 'No specific goals — optimize generally.'
        : 'User goals: ${goals.join(", ")}.';

    return '''
You are an expert interior designer analyzing room photos for SpaceSense AI.

Analyze the photo of room "$roomName" and return ONLY valid JSON (no markdown, no commentary) with ALL of these fields:

{
  "room_type": "specific room type (bedroom, kitchen, living_room, bathroom, office, dining_room, hallway, closet, other)",
  "room_type_confidence": 0.X,
  "detected_objects": [{
    "label": "object name (sofa, table, chair, door, window, lamp, painting, plant, etc.)",
    "confidence": 0.X,
    "size": "small/medium/large",
    "color": "primary color",
    "function": "what it does (seating, storage, decoration, etc.)"
  }],
  "spatial_analysis": {
    "traffic_flow": "excellent/good/fair/poor",
    "empty_areas": ["empty area descriptions"],
    "furniture_arrangement": "tight/loose/balanced",
    "orientation": "description of room orientation"
  },
  "clutter_score": X,
  "available_windows": X,
  "available_doors": X,
  "lighting_conditions": "bright/natural/artificial/direct/indirect/estimated",
  "storage_areas": ["storage location descriptions"],
  "style_elements": ["modern", "traditional", "minimalist"],
  "organization_opportunities": ["suggestion1", "suggestion2"],
  "recommendations": [{
    "category": "layout/organization/design",
    "title": "concise, action-oriented title",
    "description": "2-3 sentences explaining the recommendation",
    "reasoning": "why this helps based on the analysis",
    "budget_tier": "free/low/medium/premium",
    "difficulty": "easy/medium/hard",
    "estimated_cost": "\$-approximate",
    "impact": X
  }],
  "suggested_products": [{
    "name": "short human-readable product label, e.g. 'Over-the-door shoe organizer'",
    "search_query": "generic product search keywords WITHOUT brands, e.g. 'over the door organizer'",
    "action": "add/remove",
    "reason": "1-2 sentences on why this product helps THIS specific room",
    "estimated_price": "\$-approximate",
    "category": "storage/furniture/decor/lighting/organization/appliance/other",
    "budget_tier": "free/low/medium/premium"
  }]
}

IMPACT SCORING - for each recommendation, "impact" is an integer 0-100 estimating
how much the room's OVERALL condition (clutter, design, functionality, storage,
lighting) would improve if the user followed it:
- Base it on: the magnitude of the current problem in this room (from detected
  objects, clutter level, traffic flow, lighting) x effectiveness of the fix x
  feasibility of doing it.
- 90-100 = transformational fix of the room's biggest problem; 70-89 = major
  improvement; 40-69 = solid improvement; below 40 = minor polish.
- Recommendations that address the room's WEAKEST area must get the highest
  impact scores. Do NOT score based on price alone.

PRODUCT SUGGESTIONS ("suggested_products"):
- Use the detected empty/wasted areas and clutter to suggest up to 6 concrete
  products: "add" items to FILL empty space or add missing function, and
  "remove" items to REPLACE bulky/cluttering objects with slimmer alternatives
  (for remove, the search_query should be what to buy instead, and reason
  should say what to remove and why).
- Respect any user goals (e.g. maximize_storage) and keep a mix of
  budget_tiers so users on a small budget still get options.
- search_query MUST be short, generic, non-branded keywords that work as a
  webshop search: 'wall mounted folding desk', 'pegboard organizer kit'.
- estimated_price must be a realistic single-item price range like '\$15-40'.

Guidelines for the analysis:
- clutterscore is 0-100 where 100 is highly cluttered
- Respond with at least one recommendation in EACH of the 3 categories (layout, organization, design)
- Order recommendations from HIGHEST impact to LOWEST impact
- $goalsText
- Focus on functional analysis for space optimization
- Be specific in object detection; estimate room dimensions when possible
- Consider furniture scale and room proportions
- Ignore background details (trees, sky, distant objects); focus on architectural elements
''';
  }

  // ---------------------------------------------------------------------------
  // Scoring (local math, ported from the original backend logic)
  // ---------------------------------------------------------------------------

  Map<String, int> calculateScores(Map<String, dynamic> vision) {
    int clamp(int v) => v.clamp(0, 100);

    final baseClutter = (vision['clutter_score'] as num?)?.toInt() ?? 50;
    final objects = (vision['detected_objects'] as List?) ?? [];
    final emptyAreas = (vision['spatial_analysis']?['empty_areas'] as List?) ??
        (vision['empty_areas'] as List?) ??
        [];

    var clutterReductions = 0;
    if (objects.length > 15) {
      clutterReductions += 30;
    } else if (objects.length > 10) {
      clutterReductions += 20;
    }
    if (emptyAreas.isEmpty) clutterReductions += 25;
    final clutter = clamp(baseClutter - clutterReductions);

    final roomType = (vision['room_type'] ?? 'other') as String;
    var design = 60;
    if (['living_room', 'bedroom'].contains(roomType)) {
      design += 25;
    } else if (['kitchen', 'bathroom'].contains(roomType)) {
      design += 20;
    }
    final styleElements = ((vision['style_elements'] as List?) ?? [])
        .map((e) => e.toString())
        .toList();
    if (styleElements.any((s) => ['modern', 'minimalist'].contains(s))) {
      design += 15;
    }
    final designScore = clamp(design);

    var functionality = 50;
    final trafficFlow =
        (vision['spatial_analysis']?['traffic_flow'] ?? 'poor') as String;
    if (trafficFlow == 'excellent') {
      functionality += 30;
    } else if (trafficFlow == 'good') {
      functionality += 20;
    } else if (trafficFlow == 'fair') {
      functionality += 10;
    }
    functionality += ((vision['available_doors'] as num?)?.toInt() ?? 0) * 10;
    if (['office', 'study'].contains(roomType)) functionality += 25;
    final funcScore = clamp(functionality);

    var storage = 50;
    final storageAreas = (vision['storage_areas'] as List?) ?? [];
    storage += storageAreas.length * 15;
    final objectLabels = objects
        .map((o) {
          if (o is Map) return (o['label'] ?? '').toString().toLowerCase();
          return o.toString().toLowerCase();
        })
        .toList();
    if (objectLabels.any((l) => l.contains('shelf'))) storage += 20;
    if (objectLabels.any((l) => l.contains('cabinet'))) storage += 20;
    final storageScore = clamp(storage);

    var lighting = 50;
    final lightingConditions =
        (vision['lighting_conditions'] ?? 'poor') as String;
    if (lightingConditions == 'bright') {
      lighting += 30;
    } else if (lightingConditions == 'natural') {
      lighting += 25;
    } else if (lightingConditions == 'direct') {
      lighting += 15;
    }
    lighting += ((vision['available_windows'] as num?)?.toInt() ?? 0) * 10;
    final lightingScore = clamp(lighting);

    final overall = (0.25 * clutterScoreIn(clutter) +
            0.20 * designScore +
            0.20 * funcScore +
            0.15 * storageScore +
            0.20 * lightingScore)
        .round();

    return {
      'overall': clamp(overall),
      'clutter': clutterScoreIn(clutter),
      'design': designScore,
      'functionality': funcScore,
      'storage': storageScore,
      'lighting': lightingScore,
    };
  }

  /// The AI's clutter_score counts 'highly cluttered' as 100, but the app's
  /// clutter score means "how well organized the room is" (higher = better).
  int clutterScoreIn(int aiClutter) => 100 - aiClutter;

  List<Map<String, dynamic>> _getFallbackRecommendations(
    Map<String, int> scores,
    List<String> goals,
  ) {
    return [
      {
        'category': 'layout',
        'title': 'Rearrange furniture for better flow',
        'description':
            'Move larger furniture away from walkways to create balanced, functional zones.',
        'reasoning':
            'Basic layout optimization improves traffic flow and usability.',
        'budget_tier': 'free',
        'difficulty': 'easy',
        'estimated_cost': '\$0',
      },
      {
        'category': 'organization',
        'title': 'Declutter and reorganize',
        'description':
            'Remove excess items and create designated storage zones.',
        'reasoning':
            'Decluttering provides the biggest immediate visual improvement.',
        'budget_tier': 'free',
        'difficulty': 'medium',
        'estimated_cost': '\$0',
      },
      {
        'category': 'design',
        'title': 'Improve lighting',
        'description':
            'Add layered lighting: overhead, task, and accent lighting.',
        'reasoning': 'Better lighting makes the whole room feel larger.',
        'budget_tier': 'low',
        'difficulty': 'easy',
        'estimated_cost': '\$30-80',
      },
    ];
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Map<String, dynamic> _extractJson(String text) {
    if (text.isEmpty) {
      throw AiException('The AI returned an empty response. Please try again.');
    }

    var cleaned = text.trim();
    // Strip markdown code fences if present
    if (cleaned.startsWith('```')) {
      cleaned = cleaned
          .replaceFirst(RegExp(r'^```(json)?\s*'), '')
          .replaceFirst(RegExp(r'\s*```$'), '');
    }

    try {
      final decoded = json.decode(cleaned);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {
      // Fall through to brace-extraction below
    }

    // Fallback: extract the outermost JSON object
    final start = cleaned.indexOf('{');
    final end = cleaned.lastIndexOf('}');
    if (start != -1 && end > start) {
      try {
        final decoded = json.decode(cleaned.substring(start, end + 1));
        if (decoded is Map<String, dynamic>) return decoded;
      } catch (_) {}
    }

    throw AiException(
      'Could not parse the AI response as JSON. Please try again.',
    );
  }
}

/// Friendly AI errors for the UI, translated from raw Dio errors.
class AiException implements Exception {
  final String message;
  const AiException(this.message);

  factory AiException.fromDio(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
        return const AiException(
          'No internet connection. Please check your network and try again.',
        );
      case DioExceptionType.receiveTimeout:
        return const AiException(
          'The AI took too long to respond. Please try again.',
        );
      case DioExceptionType.cancel:
        return const AiException('The request was cancelled.');
      default:
        final status = e.response?.statusCode;
        final detail = _extractErrorDetail(e.response?.data);
        switch (status) {
          case 401:
          case 403:
            return const AiException(
              'Invalid or unauthorized API key. Please check your API key in Settings.',
            );
          case 429:
            return const AiException(
              'Rate limit exceeded on your AI provider account. Please wait a moment and try again.',
            );
          case 413:
            return const AiException('The photo is too large. Try a smaller one.');
          case 404:
            return const AiException(
              'Model not found (404) — the model you selected may have been '
              'retired by the provider. Open Settings and pick a newer model.',
            );
          default:
            return AiException(
                'AI request failed${status != null ? ' (HTTP $status)' : ''}${detail != null ? ': $detail' : '.'}');
        }
    }
  }

  static String? _extractErrorDetail(dynamic data) {
    try {
      if (data is Map) {
        final err = data['error'];
        if (err is Map && err['message'] != null) {
          return err['message'].toString();
        }
        if (err is String) return err;
        if (data['message'] != null) return data['message'].toString();
      }
    } catch (_) {}
    return null;
  }

  @override
  String toString() => message;
}
