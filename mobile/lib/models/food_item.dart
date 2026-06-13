import 'package:cloud_firestore/cloud_firestore.dart';

class FoodItem {
  final String id;
  final String name;
  final String emoji;
  final int calories;
  final int score;
  final String serving;
  final List<String> warnings;
  final Map<String, int> macros; // carbs, fat, protein in g
  final Map<String, int> nutrients; // sodium (mg), sugar (g), fiber (g), cholesterol (mg), vitaminA (%), calcium (mg)
  final String recommendation;
  final DateTime timestamp;

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
  });

  factory FoodItem.fromJson(Map<String, dynamic> json, {String? id}) {
    return FoodItem(
      id: id ?? '',
      name: json['name'] ?? 'Unknown Food',
      emoji: json['emoji'] ?? '🍽️',
      calories: json['calories'] is int ? json['calories'] as int : (json['calories'] as num?)?.toInt() ?? 0,
      score: json['score'] is int ? json['score'] as int : (json['score'] as num?)?.toInt() ?? 70,
      serving: json['serving'] ?? '1 serving',
      warnings: List<String>.from(json['warnings'] ?? []),
      macros: (json['macros'] as Map?)?.map((k, v) => MapEntry(k.toString(), (v as num).toInt())) ?? {},
      nutrients: (json['nutrients'] as Map?)?.map((k, v) => MapEntry(k.toString(), (v as num).toInt())) ?? {},
      recommendation: json['recommendation'] ?? 'Enjoy in moderation.',
      timestamp: json['timestamp'] != null 
          ? (json['timestamp'] is Timestamp 
              ? (json['timestamp'] as Timestamp).toDate() 
              : DateTime.parse(json['timestamp'].toString()))
          : DateTime.now(),
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
    };
  }
}
