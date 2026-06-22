import 'package:cloud_firestore/cloud_firestore.dart';

/// A single alternative food suggestion returned when model confidence < 70%.
class FoodAlternative {
  final String name;
  final String emoji;
  final int confidence;
  final int calories;

  const FoodAlternative({
    required this.name,
    required this.emoji,
    required this.confidence,
    required this.calories,
  });

  factory FoodAlternative.fromJson(Map<String, dynamic> json) {
    return FoodAlternative(
      name: json['name'] as String? ?? 'Unknown',
      emoji: json['emoji'] as String? ?? '🍽️',
      confidence: (json['confidence'] as num?)?.toInt() ?? 0,
      calories: (json['calories'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'emoji': emoji,
        'confidence': confidence,
        'calories': calories,
      };
}

class FoodItem {
  final String id;
  final String name;
  final String emoji;
  final int calories;
  final int score;
  final String serving;
  final List<String> warnings;
  final Map<String, int> macros;     // carbs, fat, protein in g
  final Map<String, int> nutrients;  // sodium(mg), sugar(g), fiber(g), cholesterol(mg), vitaminA(%), calcium(mg)
  final String recommendation;
  final DateTime timestamp;

  // ── Ollama expert-prompt fields ──────────────────────────────────────────
  /// Recognition confidence from the vision model (0–100 %).
  final int? confidence;

  /// Whether the food name was found in Open Food Facts / USDA database.
  final bool? databaseVerified;

  /// Food category e.g. "Street Food", "Salad", "Fast Food".
  final String? category;

  /// Main visible ingredients.
  final List<String>? ingredients;

  /// Top-3 alternative identifications — populated only when confidence < 70.
  final List<FoodAlternative>? alternatives;

  /// Diabetes risk note returned by the model (e.g. "Moderate — 35g carbs").
  final String? diabetesRisk;

  FoodItem({
    required this.id,
    required this.name,
    required this.emoji,
    required this.calories,
    required this.score,
    required this.serving,
    required this.warnings,
    required this.macros,
    required this.nutrients,
    required this.recommendation,
    required this.timestamp,
    this.confidence,
    this.databaseVerified,
    this.category,
    this.ingredients,
    this.alternatives,
    this.diabetesRisk,
  });

  factory FoodItem.fromJson(Map<String, dynamic> json, {String? id}) {
    // Parse alternatives list (only present when confidence < 70)
    List<FoodAlternative>? alternatives;
    if (json['alternatives'] != null) {
      final raw = json['alternatives'] as List<dynamic>;
      if (raw.isNotEmpty) {
        alternatives = raw
            .map((e) =>
                FoodAlternative.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
    }

    return FoodItem(
      id: id ?? '',
      name: json['name'] ?? 'Unknown Food',
      emoji: json['emoji'] ?? '🍽️',
      calories: json['calories'] is int
          ? json['calories'] as int
          : (json['calories'] as num?)?.toInt() ?? 0,
      score: json['score'] is int
          ? json['score'] as int
          : (json['score'] as num?)?.toInt() ?? 70,
      serving: json['serving'] ?? '1 serving',
      warnings: List<String>.from(json['warnings'] ?? []),
      macros: (json['macros'] as Map?)
              ?.map((k, v) => MapEntry(k.toString(), (v as num).toInt())) ??
          {},
      nutrients: (json['nutrients'] as Map?)
              ?.map((k, v) => MapEntry(k.toString(), (v as num).toInt())) ??
          {},
      recommendation: json['recommendation'] ?? 'Enjoy in moderation.',
      timestamp: json['timestamp'] != null
          ? (json['timestamp'] is Timestamp
              ? (json['timestamp'] as Timestamp).toDate()
              : DateTime.parse(json['timestamp'].toString()))
          : DateTime.now(),
      confidence: json['confidence'] != null
          ? (json['confidence'] as num).toInt()
          : null,
      databaseVerified: json['database_verified'] as bool?,
      category: json['category'] as String?,
      ingredients: json['ingredients'] != null
          ? List<String>.from(json['ingredients'] as List)
          : null,
      alternatives: alternatives,
      diabetesRisk: json['possible_diabetes_risk'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'emoji': emoji,
      'calories': calories,
      'score': score,
      'serving': serving,
      'warnings': warnings,
      'macros': macros,
      'nutrients': nutrients,
      'recommendation': recommendation,
      'timestamp': timestamp.toIso8601String(),
      if (confidence != null) 'confidence': confidence,
      if (databaseVerified != null) 'database_verified': databaseVerified,
      if (category != null) 'category': category,
      if (ingredients != null) 'ingredients': ingredients,
      if (alternatives != null)
        'alternatives': alternatives!.map((a) => a.toJson()).toList(),
      if (diabetesRisk != null) 'possible_diabetes_risk': diabetesRisk,
    };
  }
}
