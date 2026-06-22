import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/food_item.dart';
import 'ml_kit_service.dart';

/// Service for interacting with the Firebase Cloud Function scanFood endpoint.
class FirebaseAiService {
  static const String _endpoint =
      'https://us-central1-nutri-ai-scanner.cloudfunctions.net/scanFood';

  /// Analyzes a food image using the deployed Cloud Function.
  Future<FoodItem> analyzeFoodImage({
    required String base64Image,
    required String mimeType,
    required Map<String, dynamic> riskProfile,
    String? filePath,
  }) async {
    final uri = Uri.parse(_endpoint);

    final body = jsonEncode({
      'base64Image': base64Image,
      'mimeType': mimeType,
      'riskProfile': riskProfile,
    });

    try {
      debugPrint('[FirebaseAiService] POST $uri');
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 120));

      if (response.statusCode != 200) {
        debugPrint('[FirebaseAiService] HTTP ${response.statusCode} – ${response.body}');
        return await _mlKitFallback(filePath, riskProfile);
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (decoded['success'] != true || decoded['data'] == null) {
        debugPrint('[FirebaseAiService] API error: success=false or data=null');
        return await _mlKitFallback(filePath, riskProfile);
      }

      final Map<String, dynamic> foodMap = Map<String, dynamic>.from(decoded['data'] as Map);
      
      return FoodItem.fromJson(foodMap,
          id: 'firebase_${DateTime.now().millisecondsSinceEpoch}');
    } on Exception catch (e) {
      debugPrint('[FirebaseAiService] Request failed: $e. Using ML Kit fallback.');
      return await _mlKitFallback(filePath, riskProfile);
    }
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
      id: 'firebase_fallback',
      name: 'Food Item',
      emoji: '🍽️',
      calories: 200,
      score: 70,
      serving: '1 serving',
      warnings: ['Could not reach Firebase Cloud AI'],
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
          'Firebase Cloud AI was unreachable or not yet configured (e.g. Gemini API key missing on Firebase).',
      timestamp: DateTime.now(),
    );
  }
}
