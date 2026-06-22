import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/food_item.dart';
import 'ml_kit_service.dart';

/// Service for interacting with a locally-running Ollama vision model server.
///
/// Pipeline for each scan:
///   1. Send image + expert prompt to Ollama `/api/chat`
///   2. Parse the JSON response into a [FoodItem]
///   3. Verify the identified food name against **Open Food Facts** (free, no key)
///   4. If confidence < 70 %, the model returns up to 3 alternatives which are
///      stored in [FoodItem.alternatives] and surfaced in the UI.
///
/// Supported vision models (pull via `ollama pull <name>`):
///   • minicpm-v  (default)
///   • qwen2.5-vl
///   • llava / llava:13b
///   • bakllava
class OllamaService {
  static const String _offApiBase = 'https://world.openfoodfacts.org';

  // ─────────────────────────────────────────────────────────────────────────
  //  PUBLIC API
  // ─────────────────────────────────────────────────────────────────────────

  /// Analyzes a food image and returns a fully-populated [FoodItem].
  ///
  /// Steps:
  ///   1. Ask the Ollama vision model to identify the food.
  ///   2. Verify the top result via Open Food Facts.
  ///   3. If confidence < 70 %, alternatives are already in the model response.
  Future<FoodItem> analyzeFoodImage({
    required String ollamaHost,
    required String modelName,
    required String base64Image,
    required Map<String, dynamic> riskProfile,
    String? filePath,
  }) async {
    final host = ollamaHost.trim().replaceAll(RegExp(r'/$'), '');
    final uri = Uri.parse('$host/api/chat');

    final body = jsonEncode({
      'model': modelName,
      'stream': false,
      'messages': [
        {
          'role': 'user',
          'content': _buildFoodScanPrompt(riskProfile),
          'images': [base64Image],
        }
      ],
    });

    try {
      debugPrint('[OllamaService] POST $uri  model=$modelName');
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 90));

      if (response.statusCode != 200) {
        debugPrint('[OllamaService] HTTP ${response.statusCode} – ${response.body}');
        return await _mlKitFallback(filePath, riskProfile);
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final String aiText =
          (decoded['message']?['content'] as String? ?? '').trim();

      if (aiText.isEmpty) {
        debugPrint('[OllamaService] Empty response from model.');
        return await _mlKitFallback(filePath, riskProfile);
      }

      debugPrint('[OllamaService] Model response: $aiText');

      final cleanedJson = _extractJson(aiText);
      final Map<String, dynamic> rawMap = jsonDecode(cleanedJson);

      // ── Normalise the flat Ollama schema → FoodItem schema ──
      final Map<String, dynamic> foodMap = _normalizeOllamaResponse(rawMap, riskProfile);

      // ── Step 2: Verify top result against Open Food Facts ──
      final foodName = foodMap['name'] as String? ?? '';
      final confidence = (foodMap['confidence'] as num?)?.toInt() ?? 0;
      bool dbVerified = false;

      if (foodName.isNotEmpty &&
          foodName != 'Unable to identify confidently') {
        dbVerified = await _verifyWithOpenFoodFacts(foodName);
        debugPrint('[OllamaService] DB verified: $dbVerified for "$foodName"');
      }

      foodMap['database_verified'] = dbVerified;

      // ── Step 3: Log low-confidence situation ──
      if (confidence < 70) {
        debugPrint(
            '[OllamaService] Low confidence ($confidence%). Alternatives: ${foodMap['alternatives']}');
      }

      return FoodItem.fromJson(foodMap,
          id: 'ollama_${DateTime.now().millisecondsSinceEpoch}');
    } on Exception catch (e) {
      debugPrint('[OllamaService] Request failed: $e. Using ML Kit fallback.');
      return await _mlKitFallback(filePath, riskProfile);
    }
  }

  /// Tests connectivity to the Ollama server by calling `GET /api/tags`.
  /// Returns `null` on success, or an error message string on failure.
  Future<String?> testConnection(String ollamaHost) async {
    final host = ollamaHost.trim().replaceAll(RegExp(r'/$'), '');
    try {
      final response = await http
          .get(Uri.parse('$host/api/tags'))
          .timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) return null;
      return 'Server returned HTTP ${response.statusCode}';
    } on Exception catch (e) {
      return 'Could not reach Ollama: $e';
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  PROMPT
  // ─────────────────────────────────────────────────────────────────────────

  String _buildFoodScanPrompt(Map<String, dynamic> riskProfile) {
    return '''Analyze the uploaded image as a food recognition expert.

Identify the exact food visible in the image.

Rules:
- Never use mock data.
- Analyze the uploaded image directly.
- If the image is unclear, set food_name to "Unable to identify confidently" and confidence to 0.
- If confidence is below 70, populate the "alternatives" array with the top 3 possible foods.
- If confidence is 70 or above, set alternatives to [].
- Verify the food name exists in real food databases (USDA, Open Food Facts). Set database_verified accordingly.
- All numeric fields must be plain numbers — no units, no strings, no % signs.
- Return only valid JSON. No markdown, no code fences, no backticks, no explanation.
- Start directly with { and end with }.

Return this exact JSON:
{
  "food_name": "Exact food name visible in image",
  "emoji": "single relevant emoji",
  "confidence": 92,
  "database_verified": true,
  "category": "e.g. Street Food / Salad / Beverage / Dessert / Fast Food / Fruit / Snack",
  "ingredients": ["ingredient 1", "ingredient 2", "ingredient 3"],
  "calories": 320,
  "protein": 18,
  "carbohydrates": 35,
  "fat": 12,
  "health_score": 85,
  "possible_diabetes_risk": "Moderate — contains 35g carbs and 8g sugar; monitor portion size",
  "serving": "1 plate (approx. 250g)",
  "warnings": ["High Sodium", "Balanced Meal"],
  "nutrients": {
    "sodium": 340,
    "sugar": 8,
    "fiber": 4,
    "cholesterol": 15,
    "vitaminA": 20,
    "calcium": 150
  },
  "alternatives": [
    { "name": "Possible Food 1", "emoji": "🍛", "confidence": 45, "calories": 280 },
    { "name": "Possible Food 2", "emoji": "🥘", "confidence": 30, "calories": 310 },
    { "name": "Possible Food 3", "emoji": "🍲", "confidence": 15, "calories": 250 }
  ],
  "recommendation": "Personalized advice: diabetes risk ${riskProfile['diabetes'] ?? 'unknown'}%, heart risk ${riskProfile['heart'] ?? 'unknown'}%, obesity risk ${riskProfile['obesity'] ?? 'unknown'}%."
}

Analyze the image now and return only the filled JSON.''';
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  SCHEMA NORMALIZER
  // ─────────────────────────────────────────────────────────────────────────

  /// Maps the flat Ollama response schema to the [FoodItem.fromJson] schema.
  ///
  /// Ollama returns a flat layout (`food_name`, `carbohydrates`, `fat`,
  /// `health_score`, `possible_diabetes_risk`) whereas [FoodItem] expects
  /// nested `macros` and `score`. This normalizer bridges the gap so both
  /// Gemini and Ollama can share the same model class.
  Map<String, dynamic> _normalizeOllamaResponse(
      Map<String, dynamic> raw, Map<String, dynamic> riskProfile) {
    // ── Core identity ──
    final name =
        raw['food_name'] as String? ?? raw['name'] as String? ?? 'Unknown Food';
    final emoji = raw['emoji'] as String? ?? '🍽️';
    final confidence = _toInt(raw['confidence']);
    final dbVerified = raw['database_verified'] as bool?;
    final category = raw['category'] as String?;
    final serving = raw['serving'] as String? ?? '1 serving';

    // ── Macros (flat → nested) ──
    final protein = _toInt(raw['protein']);
    final carbs = _toInt(raw['carbohydrates'] ?? raw['carbs']);
    final fat = _toInt(raw['fat']);
    final calories = _toInt(raw['calories']);

    // ── Scores ──
    final score = _toInt(raw['health_score'] ?? raw['score']) ?? 70;

    // ── Nutrients (pass-through or empty) ──
    final nutrients = (raw['nutrients'] as Map?)?.map(
            (k, v) => MapEntry(k.toString(), _toInt(v) ?? 0)) ??
        <String, int>{};

    // ── Extras ──
    final ingredients = raw['ingredients'] != null
        ? List<String>.from(raw['ingredients'] as List)
        : null;
    final warnings = raw['warnings'] != null
        ? List<String>.from(raw['warnings'] as List)
        : <String>[];
    final recommendation =
        raw['recommendation'] as String? ?? 'Enjoy in moderation.';
    final diabetesRisk = raw['possible_diabetes_risk'] as String?;

    // ── Alternatives ──
    List<Map<String, dynamic>>? alternatives;
    if (raw['alternatives'] != null) {
      final list = raw['alternatives'] as List<dynamic>;
      if (list.isNotEmpty) {
        alternatives = list
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      }
    }

    return {
      'name': name,
      'emoji': emoji,
      'confidence': confidence,
      'database_verified': dbVerified,
      'category': category,
      'calories': calories ?? 0,
      'score': score,
      'serving': serving,
      'warnings': warnings,
      'macros': {
        'carbs': carbs ?? 0,
        'fat': fat ?? 0,
        'protein': protein ?? 0,
      },
      'nutrients': nutrients,
      'ingredients': ingredients,
      'alternatives': alternatives,
      'possible_diabetes_risk': diabetesRisk,
      'recommendation': recommendation,
    };
  }

  /// Safely converts a dynamic value to int (handles String, int, double).
  int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v.replaceAll(RegExp(r'[^0-9]'), ''));
    return null;
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  OPEN FOOD FACTS VERIFICATION
  // ─────────────────────────────────────────────────────────────────────────

  /// Checks if [foodName] exists in Open Food Facts.
  /// Returns true if at least one matching product is found.
  /// Silently returns false on any network error (non-blocking).
  Future<bool> _verifyWithOpenFoodFacts(String foodName) async {
    try {
      final encoded = Uri.encodeComponent(foodName);
      final uri = Uri.parse(
          '$_offApiBase/cgi/search.pl?search_terms=$encoded&search_simple=1&action=process&json=1&page_size=1&fields=product_name');

      final response =
          await http.get(uri).timeout(const Duration(seconds: 6));

      if (response.statusCode != 200) return false;

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final count = (body['count'] as num?)?.toInt() ?? 0;
      return count > 0;
    } on Exception catch (e) {
      debugPrint('[OllamaService] Open Food Facts lookup failed: $e');
      return false; // non-blocking — don't fail the scan
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  HELPERS
  // ─────────────────────────────────────────────────────────────────────────

  /// Strips markdown fences and extracts the first valid JSON object.
  String _extractJson(String raw) {
    var text = raw.trim();
    if (text.contains('```')) {
      text = text.replaceAll(
          RegExp(r'```(?:json)?\s*', caseSensitive: false), '');
      text = text.replaceAll('```', '').trim();
    }
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start != -1 && end != -1 && end > start) {
      text = text.substring(start, end + 1);
    }
    return text.trim();
  }

  Future<FoodItem> _mlKitFallback(
      String? filePath, Map<String, dynamic> riskProfile) async {
    if (filePath != null) {
      try {
        return await MLKitService()
            .analyzeImage(filePath: filePath, riskProfile: riskProfile);
      } catch (_) {}
    }
    return FoodItem(
      id: 'ollama_fallback',
      name: 'Food Item',
      emoji: '🍽️',
      calories: 200,
      score: 70,
      serving: '1 serving',
      warnings: ['Could not reach Ollama server'],
      macros: {'carbs': 25, 'fat': 8, 'protein': 10},
      nutrients: {
        'sodium': 200,
        'sugar': 5,
        'fiber': 2,
        'cholesterol': 10,
        'vitaminA': 5,
        'calcium': 50,
      },
      recommendation:
          'Ollama server was unreachable. Please check your host URL and ensure Ollama is running.',
      timestamp: DateTime.now(),
    );
  }
}
