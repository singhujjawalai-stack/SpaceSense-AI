class ScoreModel {
  final int overall;
  final int clutter;
  final int design;
  final int functionality;
  final int storage;
  final int lighting;

  ScoreModel({
    required this.overall,
    required this.clutter,
    required this.design,
    required this.functionality,
    required this.storage,
    required this.lighting,
  });

  factory ScoreModel.fromJson(Map<String, dynamic> json) {
    int score(dynamic v) => (v as num?)?.toInt() ?? 0;
    return ScoreModel(
      overall: score(json['overall']),
      clutter: score(json['clutter']),
      design: score(json['design']),
      functionality: score(json['functionality']),
      storage: score(json['storage']),
      lighting: score(json['lighting']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'overall': overall,
      'clutter': clutter,
      'design': design,
      'functionality': functionality,
      'storage': storage,
      'lighting': lighting,
    };
  }

  List<MapEntry<String, int>> get allScores => [
        MapEntry('Overall', overall),
        MapEntry('Clutter', clutter),
        MapEntry('Design', design),
        MapEntry('Functionality', functionality),
        MapEntry('Storage', storage),
        MapEntry('Lighting', lighting),
      ];
}

class RecommendationModel {
  final String category;
  final String title;
  final String description;
  final String budgetTier;
  final String reasoning;
  final String difficulty;
  final String estimatedCost;
  /// AI-assigned impact score (0-100): estimated improvement to the room's
  /// overall score if this recommendation is followed. Higher = better.
  final int impact;
  final int priority;

  RecommendationModel({
    required this.category,
    required this.title,
    required this.description,
    required this.budgetTier,
    this.reasoning = '',
    this.difficulty = 'easy',
    this.estimatedCost = '\$0',
    this.impact = 0,
    required this.priority,
  });

  factory RecommendationModel.fromJson(Map<String, dynamic> json, [int index = 0]) {
    return RecommendationModel(
      category: (json['category'] ?? 'design') as String,
      title: (json['title'] ?? 'Untitled suggestion') as String,
      description: (json['description'] ?? '') as String,
      budgetTier: (json['budget_tier'] ?? 'free') as String,
      reasoning: ((json['reasoning'] ?? '') as String?) ??
          (json['reasoning'] as String?) ??
          '',
      difficulty: (json['difficulty'] ?? 'easy') as String,
      estimatedCost: ((json['estimated_cost'] ?? '\$0') as String),
      impact: ((json['impact'] as num?)?.toInt()) ?? 0,
      priority: ((json['priority'] as num?)?.toInt()) ?? index + 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'category': category,
      'title': title,
      'description': description,
      'budget_tier': budgetTier,
      'reasoning': reasoning,
      'difficulty': difficulty,
      'estimated_cost': estimatedCost,
      'impact': impact,
      'priority': priority,
    };
  }
}

/// A concrete product the AI suggests to add or remove from the room.
/// The app turns [searchQuery] into live web-shop search links — the AI never
/// produces URLs, only search terms, so links always resolve to real items.
class ProductSuggestionModel {
  final String searchQuery;
  final String name;
  /// 'add' (fill space / fix a gap) or 'remove' (declutter / replace)
  final String action;
  final String reason;
  final String estimatedPrice;
  final String category;
  final String budgetTier;

  ProductSuggestionModel({
    required this.searchQuery,
    required this.name,
    required this.action,
    required this.reason,
    required this.estimatedPrice,
    required this.category,
    required this.budgetTier,
  });

  factory ProductSuggestionModel.fromJson(Map<String, dynamic> json) {
    final actionRaw = (json['action'] ?? 'add') as String;
    return ProductSuggestionModel(
      searchQuery: ((json['search_query'] ?? json['name'] ?? '') as String),
      name: ((json['name'] ?? (json['search_query'] ?? 'Suggested product')) as String),
      action: actionRaw.toLowerCase() == 'remove' ? 'remove' : 'add',
      reason: ((json['reason'] ?? '') as String),
      estimatedPrice: ((json['estimated_price'] ?? '\$0') as String),
      category: ((json['category'] ?? 'other') as String),
      budgetTier: ((json['budget_tier'] ?? 'low') as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'search_query': searchQuery,
      'name': name,
      'action': action,
      'reason': reason,
      'estimated_price': estimatedPrice,
      'category': category,
      'budget_tier': budgetTier,
    };
  }

  bool get isRemove => action == 'remove';
}

class AnalysisModel {
  final String id;
  final String roomId;
  final String roomName;
  final String roomType;
  final double roomTypeConfidence;
  final DateTime analyzedAt;
  final ScoreModel scores;
  final List<String> detectedObjects;
  final List<RecommendationModel> recommendations;
  final List<ProductSuggestionModel> suggestedProducts;
  final int processingTimeMs;
  final String aiProvider;
  final String aiModel;
  final String? imagePath;

  AnalysisModel({
    required this.id,
    required this.roomId,
    required this.roomName,
    required this.roomType,
    required this.roomTypeConfidence,
    required this.analyzedAt,
    required this.scores,
    required this.detectedObjects,
    required this.recommendations,
    this.suggestedProducts = const [],
    required this.processingTimeMs,
    required this.aiProvider,
    required this.aiModel,
    this.imagePath,
  });

  factory AnalysisModel.fromJson(Map<String, dynamic> json) {
    return AnalysisModel(
      id: (json['id'] ?? 'ana_${DateTime.now().millisecondsSinceEpoch}') as String,
      roomId: (json['room_id'] ?? 'room_${DateTime.now().millisecondsSinceEpoch}') as String,
      roomName: (json['room_name'] ?? 'Untitled Room') as String,
      roomType: (json['room_type'] ?? 'unknown') as String,
      roomTypeConfidence: ((json['room_type_confidence'] ?? 0.0) as num).toDouble(),
      analyzedAt: DateTime.tryParse(json['analyzed_at'] ?? '') ?? DateTime.now(),

      scores: ScoreModel.fromJson(json['scores'] as Map<String, dynamic>),
      detectedObjects: ((json['detected_objects'] as List?) ?? []).map((e) {
        if (e is Map) return (e['label'] ?? '').toString();
        return e.toString();
      }).where((s) => s.isNotEmpty).toList(),
      suggestedProducts: ((json['suggested_products'] as List?) ?? [])
          .map((e) => ProductSuggestionModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      recommendations: ((json['recommendations'] as List?) ?? [])
          .asMap()
          .entries
          .map((e) {
            if (e.value is Map<String, dynamic>) {
              return RecommendationModel.fromJson(
                  e.value as Map<String, dynamic>, e.key);
            }
            // Very defensive: non-map entries become a generic recommendation
            return RecommendationModel.fromJson(
                {'title': e.value.toString()}, e.key);
          })
          .toList(),
      processingTimeMs: ((json['processing_time_ms'] ?? 0) as num).toInt(),
      aiProvider: (json['ai_provider'] ?? 'unknown') as String,
      aiModel: (json['ai_model'] ?? 'unknown') as String,
      imagePath: json['image_path'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'room_id': roomId,
      'room_name': roomName,
      'room_type': roomType,
      'room_type_confidence': roomTypeConfidence,
      'analyzed_at': analyzedAt.toIso8601String(),
      'scores': scores.toJson(),
      'detected_objects': detectedObjects,
      'suggested_products': suggestedProducts.map((p) => p.toJson()).toList(),
      'recommendations': recommendations.map((e) => e.toJson()).toList(),
      'processing_time_ms': processingTimeMs,
      'ai_provider': aiProvider,
      'ai_model': aiModel,
      'image_path': imagePath,
    };
  }

  AnalysisModel copyWith({String? imagePath}) {
    return AnalysisModel(
      id: id,
      roomId: roomId,
      roomName: roomName,
      roomType: roomType,
      roomTypeConfidence: roomTypeConfidence,
      analyzedAt: analyzedAt,
      scores: scores,
      detectedObjects: detectedObjects,
      suggestedProducts: suggestedProducts,
      recommendations: recommendations,
      processingTimeMs: processingTimeMs,
      aiProvider: aiProvider,
      aiModel: aiModel,
      imagePath: imagePath ?? this.imagePath,
    );
  }
}
