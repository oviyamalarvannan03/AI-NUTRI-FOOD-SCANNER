import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/food_item.dart';
import 'ml_kit_service.dart';

/// Service for interacting with Google Gemini AI.
///
/// Uses the official `google_generative_ai` SDK for:
/// - **Food Recognition**: Gemini 2.0 Flash (vision) analyzes food photos and
///   returns structured nutritional data as JSON.
/// - **Health Chat**: Multi-turn conversational AI providing personalized
///   nutrition advice based on the user's health profile.
class GeminiService {
  /// The Gemini model used for both vision (food scanning) and text (chat).
  static const String _modelName = 'gemini-2.0-flash';

  // ─────────────────────────────────────────────────────────────────────────
  //  FOOD IMAGE ANALYSIS
  // ─────────────────────────────────────────────────────────────────────────

  /// Analyzes a food image using Gemini 2.0 Flash Vision and returns a
  /// [FoodItem] with nutritional breakdown, health score, and personalized
  /// recommendations.
  ///
  /// Falls back to a local keyword-based matcher when no valid API key is
  /// provided, ensuring the app works offline / without configuration.
  Future<FoodItem> analyzeFoodImage({
    required String apiKey,
    required String base64Image,
    required String mimeType,
    required Map<String, dynamic> riskProfile,
    String? filePath,
  }) async {
    // ── Guard: Invalid API key → offline fallback ──
    if (apiKey.isEmpty || apiKey == 'YOUR_GEMINI_API_KEY') {
      debugPrint('[GeminiService] No valid API key – using local fallback.');
      return await _getSmartFallback(filePath, riskProfile);
    }

    try {
      // ── Initialize the Gemini model via official SDK ──
      final model = GenerativeModel(
        model: _modelName,
        apiKey: apiKey,
        generationConfig: GenerationConfig(
          temperature: 0.2,
          maxOutputTokens: 1024,
          responseMimeType: 'application/json',
        ),
      );

      // ── Build the vision prompt ──
      final prompt = _buildFoodScanPrompt(riskProfile);

      // ── Decode base64 image to bytes ──
      final Uint8List imageBytes = base64Decode(base64Image);

      // ── Send image + prompt to Gemini Vision ──
      final content = Content.multi([
        DataPart(mimeType, imageBytes),
        TextPart(prompt),
      ]);

      debugPrint('[GeminiService] Sending image to Gemini 2.0 Flash Vision…');
      final response = await model.generateContent([content]);

      final aiText = response.text;
      if (aiText == null || aiText.trim().isEmpty) {
        debugPrint('[GeminiService] Empty response from Gemini.');
        return _getLocalFallbackFood(filePath);
      }

      debugPrint('[GeminiService] Gemini response: $aiText');

      // ── Parse JSON response ──
      final cleanedJson = _cleanJsonString(aiText);
      final Map<String, dynamic> foodMap = jsonDecode(cleanedJson);
      return FoodItem.fromJson(foodMap);
    } on GenerativeAIException catch (e) {
      debugPrint('[GeminiService] Gemini API error: $e. Using fallback.');
      return await _getSmartFallback(filePath, riskProfile);
    } catch (e) {
      debugPrint('[GeminiService] Scan failed: $e. Using local fallback.');
      return await _getSmartFallback(filePath, riskProfile);
    }
  }

  /// Builds the structured prompt instructing Gemini to return food nutrition
  /// data as a raw JSON object.
  String _buildFoodScanPrompt(Map<String, dynamic> riskProfile) {
    return '''You are NutriAI, an expert visual food scanner powered by Google Gemini. Analyze the food image provided.

CRITICAL INSTRUCTIONS:
1. Output ONLY a raw JSON object — no markdown, no code fences, no backticks, no explanation text.
2. Start your response directly with { and end with }.
3. All numeric fields must be plain numbers (no units, no strings).
4. Do NOT include comments inside the JSON.

Required JSON structure (fill in real values from the image):
{
  "name": "Name of the food dish",
  "emoji": "single emoji like 🥗 or 🍕",
  "calories": 320,
  "score": 85,
  "serving": "1 plate",
  "warnings": ["High Sodium", "Balanced Meal"],
  "macros": {
    "carbs": 35,
    "fat": 12,
    "protein": 18
  },
  "nutrients": {
    "sodium": 340,
    "sugar": 8,
    "fiber": 4,
    "cholesterol": 15,
    "vitaminA": 20,
    "calcium": 150
  },
  "recommendation": "Personalized advice for this user: diabetes risk ${riskProfile['diabetes'] ?? 'unknown'}%, heart risk ${riskProfile['heart'] ?? 'unknown'}%, obesity risk ${riskProfile['obesity'] ?? 'unknown'}%."
}

Analyze the food in the image and return the JSON above with accurate nutritional values.''';
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  HEALTH CHAT
  // ─────────────────────────────────────────────────────────────────────────

  /// Sends a chat message to Gemini and returns the AI's response.
  /// Supports multi-turn conversation with history context.
  Future<String> askGemini({
    required String apiKey,
    required String prompt,
    required List<Map<String, String>> chatHistory,
    required Map<String, dynamic> systemContext,
  }) async {
    final model = GenerativeModel(
      model: _modelName,
      apiKey: apiKey,
      generationConfig: GenerationConfig(
        temperature: 0.7,
        maxOutputTokens: 400,
      ),
    );

    final systemPrompt = _buildChatSystemPrompt(systemContext);

    // ── Build conversation contents ──
    // Gemini API does not have a dedicated system role, so we prepend the
    // system context as the first user turn + a model acknowledgement.
    final List<Content> contents = [
      Content('user', [
        TextPart(
            '[SYSTEM CONTEXT – follow these instructions for the entire conversation]\n$systemPrompt'),
      ]),
      Content('model', [
        TextPart(
            'Understood. I am NutriAI, your personal AI nutritionist. I will provide personalized, concise, and science-backed health advice based on your profile.'),
      ]),
    ];

    // Add chat history
    for (final msg in chatHistory) {
      final role = msg['role'] == 'user' ? 'user' : 'model';
      contents.add(Content(role, [TextPart(msg['text'] ?? '')]));
    }

    // Add the current user prompt
    contents.add(Content('user', [TextPart(prompt)]));

    try {
      final response = await model.generateContent(contents);
      return response.text ?? "I'm sorry, I couldn't generate a response.";
    } on GenerativeAIException catch (e) {
      throw Exception('Gemini AI chat error: $e');
    } catch (e) {
      throw Exception('Gemini AI communication failed: $e');
    }
  }

  /// Builds the system prompt for the health chat, incorporating the user's
  /// profile, goals, and disease risk data.
  String _buildChatSystemPrompt(Map<String, dynamic> ctx) {
    return '''You are NutriAI, an expert AI health assistant and nutritionist. You are friendly, concise, and science-backed.

USER HEALTH PROFILE:
- Name: ${ctx['name'] ?? 'User'}
- Age: ${ctx['age'] ?? 'unknown'}
- Daily Calorie Goal: ${ctx['calorieGoal'] ?? 2000} kcal

DISEASE RISK PROFILE:
- Diabetes risk: ${ctx['diabetesRisk'] ?? 'unknown'}%
- Heart disease risk: ${ctx['heartRisk'] ?? 'unknown'}%
- Obesity risk: ${ctx['obesityRisk'] ?? 'unknown'}%

INSTRUCTIONS:
- Give personalized advice based on the user's actual data above.
- Keep responses concise (under 150 words) but rich in actionable advice.
- Use bullet points using • for lists.
- Avoid markdown headers.
''';
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  HELPERS
  // ─────────────────────────────────────────────────────────────────────────

  /// Resolves to ML Kit dynamic analysis as the smart fallback before falling back to local food profiles.
  Future<FoodItem> _getSmartFallback(String? filePath, Map<String, dynamic> riskProfile) async {
    if (filePath != null) {
      try {
        final mlKit = MLKitService();
        return await mlKit.analyzeImage(filePath: filePath, riskProfile: riskProfile);
      } catch (e) {
        debugPrint('[GeminiService] ML Kit fallback failed: $e. Using local fallback.');
      }
    }
    return _getLocalFallbackFood(filePath);
  }

  /// Strips markdown code fences and extracts the first valid JSON object
  /// from a Gemini response, which may include preamble or explanation text.
  String _cleanJsonString(String str) {
    var cleaned = str.trim();

    // Remove markdown code fences (```json ... ``` or ``` ... ```)
    if (cleaned.contains('```')) {
      cleaned = cleaned.replaceAll(
          RegExp(r'```(?:json)?\s*', caseSensitive: false), '');
      cleaned = cleaned.replaceAll('```', '');
      cleaned = cleaned.trim();
    }

    // If Gemini added preamble text before the JSON, find the first '{'
    final jsonStart = cleaned.indexOf('{');
    final jsonEnd = cleaned.lastIndexOf('}');
    if (jsonStart != -1 && jsonEnd != -1 && jsonEnd > jsonStart) {
      cleaned = cleaned.substring(jsonStart, jsonEnd + 1);
    }

    return cleaned.trim();
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  OFFLINE FALLBACK (no API key / no network)
  // ─────────────────────────────────────────────────────────────────────────

  /// Returns a hardcoded [FoodItem] based on keywords in the file name.
  /// This ensures the app remains functional without an API key.
  FoodItem _getLocalFallbackFood(String? filePath) {
    final name =
        filePath?.split('/').last.split('\\').last.toLowerCase() ?? '';

    if (name.contains('pizza')) {
      return FoodItem(
        id: 'fallback_pizza',
        name: 'Pepperoni Pizza',
        emoji: '🍕',
        calories: 290,
        score: 45,
        serving: '1 slice (100g)',
        warnings: ['High Sodium', 'Saturated Fat'],
        macros: {'carbs': 32, 'fat': 12, 'protein': 13},
        nutrients: {
          'sodium': 640, 'sugar': 3, 'fiber': 2,
          'cholesterol': 30, 'vitaminA': 4, 'calcium': 180,
        },
        recommendation:
            'High in sodium and saturated fat. Consider balancing with a fresh garden salad.',
        timestamp: DateTime.now(),
      );
    } else if (name.contains('burger')) {
      return FoodItem(
        id: 'fallback_burger',
        name: 'Beef Cheeseburger',
        emoji: '🍔',
        calories: 540,
        score: 48,
        serving: '1 burger',
        warnings: ['High Saturated Fat', 'Processed Grains'],
        macros: {'carbs': 40, 'fat': 28, 'protein': 32},
        nutrients: {
          'sodium': 980, 'sugar': 7, 'fiber': 2,
          'cholesterol': 85, 'vitaminA': 6, 'calcium': 200,
        },
        recommendation:
            'Moderate protein but high in sodium. Choose a whole grain bun or lettuce wrap if possible.',
        timestamp: DateTime.now(),
      );
    } else if (name.contains('banana')) {
      return FoodItem(
        id: 'fallback_banana',
        name: 'Fresh Banana',
        emoji: '🍌',
        calories: 105,
        score: 88,
        serving: '1 medium (118g)',
        warnings: ['Rich in Potassium', 'Natural Energy'],
        macros: {'carbs': 27, 'fat': 0, 'protein': 1},
        nutrients: {
          'sodium': 1, 'sugar': 14, 'fiber': 3,
          'cholesterol': 0, 'vitaminA': 2, 'calcium': 6,
        },
        recommendation:
            'Great pre-workout snack. The fiber helps slow down sugar absorption.',
        timestamp: DateTime.now(),
      );
    } else if (name.contains('apple')) {
      return FoodItem(
        id: 'fallback_apple',
        name: 'Red Apple',
        emoji: '🍎',
        calories: 95,
        score: 90,
        serving: '1 medium (182g)',
        warnings: ['High Fiber', 'Antioxidant Rich'],
        macros: {'carbs': 25, 'fat': 0, 'protein': 0},
        nutrients: {
          'sodium': 2, 'sugar': 19, 'fiber': 4,
          'cholesterol': 0, 'vitaminA': 1, 'calcium': 11,
        },
        recommendation:
            'Eating the skin provides maximum dietary fiber and healthy polyphenols.',
        timestamp: DateTime.now(),
      );
    } else if (name.contains('salmon') || name.contains('fish')) {
      return FoodItem(
        id: 'fallback_salmon',
        name: 'Grilled Salmon Fillet',
        emoji: '🐟',
        calories: 280,
        score: 93,
        serving: '1 fillet (150g)',
        warnings: ['Omega-3 Rich', 'High Protein'],
        macros: {'carbs': 0, 'fat': 15, 'protein': 34},
        nutrients: {
          'sodium': 90, 'sugar': 0, 'fiber': 0,
          'cholesterol': 80, 'vitaminA': 2, 'calcium': 15,
        },
        recommendation:
            'Provides essential omega-3 fatty acids that support heart health and reduce inflammation.',
        timestamp: DateTime.now(),
      );
    } else if (name.contains('chicken')) {
      return FoodItem(
        id: 'fallback_chicken',
        name: 'Grilled Chicken Breast',
        emoji: '🍗',
        calories: 165,
        score: 95,
        serving: '1 breast (100g)',
        warnings: ['Lean Protein', 'Low Fat'],
        macros: {'carbs': 0, 'fat': 3, 'protein': 31},
        nutrients: {
          'sodium': 74, 'sugar': 0, 'fiber': 0,
          'cholesterol': 85, 'vitaminA': 1, 'calcium': 15,
        },
        recommendation:
            'An excellent source of lean protein. Keep cooking oil low to maintain its low-fat profile.',
        timestamp: DateTime.now(),
      );
    }

    // Default fallback — healthy Mediterranean Garden Salad
    return FoodItem(
      id: 'fallback_salad',
      name: 'Mediterranean Garden Salad',
      emoji: '🥗',
      calories: 180,
      score: 94,
      serving: '1 large bowl',
      warnings: ['Balanced Meal', 'Rich in Fiber'],
      macros: {'carbs': 12, 'fat': 11, 'protein': 6},
      nutrients: {
        'sodium': 220, 'sugar': 4, 'fiber': 5,
        'cholesterol': 0, 'vitaminA': 80, 'calcium': 120,
      },
      recommendation:
          'Excellent low-calorie choice packed with vitamins. Dressing contains healthy olive oil.',
      timestamp: DateTime.now(),
    );
  }
}
