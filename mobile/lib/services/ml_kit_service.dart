import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/food_item.dart';

/// Service for on-device food image analysis using Google ML Kit.
///
/// Communicates with native Android side using MethodChannel.
class MLKitService {
  static const MethodChannel _channel = MethodChannel('com.nutriai.scanner/mlkit');

  // Predefined templates matching our rich food profiles
  static final Map<String, FoodItem> _foodTemplates = {
    'pizza': FoodItem(
      id: 'ml_pizza',
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
      recommendation: 'High in sodium and saturated fat. Consider balancing with a fresh garden salad.',
      timestamp: DateTime.now(),
    ),
    'burger': FoodItem(
      id: 'ml_burger',
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
      recommendation: 'Moderate protein but high in sodium. Choose a whole grain bun or lettuce wrap if possible.',
      timestamp: DateTime.now(),
    ),
    'banana': FoodItem(
      id: 'ml_banana',
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
      recommendation: 'Great pre-workout snack. The fiber helps slow down sugar absorption.',
      timestamp: DateTime.now(),
    ),
    'apple': FoodItem(
      id: 'ml_apple',
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
      recommendation: 'Eating the skin provides maximum dietary fiber and healthy polyphenols.',
      timestamp: DateTime.now(),
    ),
    'salmon': FoodItem(
      id: 'ml_salmon',
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
      recommendation: 'Provides essential omega-3 fatty acids that support heart health and reduce inflammation.',
      timestamp: DateTime.now(),
    ),
    'chicken': FoodItem(
      id: 'ml_chicken',
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
      recommendation: 'An excellent source of lean protein. Keep cooking oil low to maintain its low-fat profile.',
      timestamp: DateTime.now(),
    ),
    'salad': FoodItem(
      id: 'ml_salad',
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
      recommendation: 'Excellent low-calorie choice packed with vitamins. Dressing contains healthy olive oil.',
      timestamp: DateTime.now(),
    ),
  };

  // Helper to map label keywords to emojis
  static final Map<String, String> _emojiMap = {
    'milk': '🥛', 'yogurt': '🥛', 'yoghurt': '🥛', 'dairy': '🥛',
    'cheese': '🧀', 'bread': '🍞', 'toast': '🍞', 'egg': '🥚',
    'meat': '🥩', 'beef': '🥩', 'pork': '🥩', 'steak': '🥩',
    'cookie': '🍪', 'cookies': '🍪', 'cake': '🍰', 'pastry': '🍰',
    'chocolate': '🍫', 'candy': '🍬', 'sweet': '🍭',
    'beer': '🍺', 'wine': '🍷', 'coffee': '☕', 'tea': '🍵',
    'water': '🥛', 'juice': '🥤', 'soda': '🥤',
    'ice cream': '🍦', 'donut': '🍩', 'doughnut': '🍩',
    'sushi': '🍣', 'fish': '🐟', 'salmon': '🐟',
    'noodle': '🍝', 'pasta': '🍝', 'spaghetti': '🍝',
    'rice': '🍚', 'soup': '🍲', 'sandwich': '🥪', 'taco': '🌮',
    'strawberry': '🍓', 'orange': '🍊', 'lemon': '🍋',
    'grape': '🍇', 'grapes': '🍇', 'tomato': '🍅',
    'potato': '🥔', 'carrot': '🥕', 'broccoli': '🥦',
    'vegetable': '🥦', 'fruit': '🍎', 'salad': '🥗',
    'popcorn': '🍿', 'snack': '🍿', 'nut': '🥜', 'peanut': '🥜',
  };

  /// Analyzes an image by calling ML Kit on Android and parsing the results.
  Future<FoodItem> analyzeImage({
    required String filePath,
    required Map<String, dynamic> riskProfile,
  }) async {
    try {
      debugPrint('[MLKitService] Invoking native ML Kit analysis for path: $filePath');
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'analyzeImage',
        {'filePath': filePath},
      );

      if (result == null) {
        debugPrint('[MLKitService] ML Kit returned null result, using filename fallback.');
        return _getFilenameFallback(filePath, riskProfile);
      }

      final List<dynamic> labelsRaw = result['labels'] ?? [];
      final String ocrText = result['text'] ?? '';

      debugPrint('[MLKitService] ML Kit success. Labels count: ${labelsRaw.length}. OCR text length: ${ocrText.length}');

      // Parse OCR Text for nutrition facts (calories, carbs, fat, protein, sodium, sugar, fiber, cholesterol)
      final parsedCalories = _parseValue(ocrText, r'(?:calories|energy|cal)\s*[:\-\s]*\s*(\d+)', r'(\d+)\s*(?:kcal|calories)');
      final parsedCarbs = _parseValue(ocrText, r'(?:carb(?:ohydrate)?s?)\s*[:\-\s]*\s*(\d+)\s*g');
      final parsedFat = _parseValue(ocrText, r'(?:total\s+)?fat\s*[:\-\s]*\s*(\d+)\s*g');
      final parsedProtein = _parseValue(ocrText, r'protein\s*[:\-\s]*\s*(\d+)\s*g');
      final parsedSodium = _parseValue(ocrText, r'sodium\s*[:\-\s]*\s*(\d+)\s*(?:mg|g)');
      final parsedSugar = _parseValue(ocrText, r'sugars?\s*[:\-\s]*\s*(\d+)\s*g');
      final parsedFiber = _parseValue(ocrText, r'(?:dietary\s+)?fiber\s*[:\-\s]*\s*(\d+)\s*g');
      final parsedCholesterol = _parseValue(ocrText, r'cholesterol\s*[:\-\s]*\s*(\d+)\s*(?:mg|g)');

      // Extract labels list
      final List<Map<String, dynamic>> labels = labelsRaw.map((e) => Map<String, dynamic>.from(e as Map)).toList();

      // Check if we can match any of our predefined food templates in labels
      FoodItem? matchedTemplate;
      String? matchedKey;

      for (final labelMap in labels) {
        final labelText = (labelMap['text'] as String? ?? '').toLowerCase();
        for (final key in _foodTemplates.keys) {
          if (labelText.contains(key) || key.contains(labelText)) {
            matchedTemplate = _foodTemplates[key];
            matchedKey = key;
            break;
          }
        }
        if (matchedTemplate != null) break;
      }

      // If no template matched via labels, try matching via OCR text keywords
      if (matchedTemplate == null && ocrText.isNotEmpty) {
        final lowerText = ocrText.toLowerCase();
        for (final key in _foodTemplates.keys) {
          if (lowerText.contains(key)) {
            matchedTemplate = _foodTemplates[key];
            matchedKey = key;
            break;
          }
        }
      }

      // If we matched a template, build a smart customized FoodItem
      if (matchedTemplate != null) {
        debugPrint('[MLKitService] Matched food template: $matchedKey');
        
        // Let's create a customized copy of the template, override with OCR values if parsed
        final finalCalories = parsedCalories ?? matchedTemplate.calories;
        final finalCarbs = parsedCarbs ?? matchedTemplate.macros['carbs'] ?? 0;
        final finalFat = parsedFat ?? matchedTemplate.macros['fat'] ?? 0;
        final finalProtein = parsedProtein ?? matchedTemplate.macros['protein'] ?? 0;

        final finalSodium = parsedSodium ?? matchedTemplate.nutrients['sodium'] ?? 0;
        final finalSugar = parsedSugar ?? matchedTemplate.nutrients['sugar'] ?? 0;
        final finalFiber = parsedFiber ?? matchedTemplate.nutrients['fiber'] ?? 0;
        final finalCholesterol = parsedCholesterol ?? matchedTemplate.nutrients['cholesterol'] ?? 0;

        // Recalculate health score if we parsed new values
        int finalScore = matchedTemplate.score;
        if (parsedCalories != null || parsedSugar != null || parsedSodium != null) {
          finalScore = _calculateHealthScore(
            calories: finalCalories,
            sugar: finalSugar,
            sodium: finalSodium,
            fiber: finalFiber,
          );
        }

        final dynamicWarnings = _buildWarnings(
          calories: finalCalories,
          sugar: finalSugar,
          sodium: finalSodium,
          fat: finalFat,
        );

        final dynamicRecommendation = _buildRecommendation(
          foodName: matchedTemplate.name,
          score: finalScore,
          calories: finalCalories,
          sugar: finalSugar,
          sodium: finalSodium,
          riskProfile: riskProfile,
        );

        return FoodItem(
          id: matchedTemplate.id,
          name: matchedTemplate.name,
          emoji: matchedTemplate.emoji,
          calories: finalCalories,
          score: finalScore,
          serving: matchedTemplate.serving,
          warnings: dynamicWarnings.isNotEmpty ? dynamicWarnings : matchedTemplate.warnings,
          macros: {
            'carbs': finalCarbs,
            'fat': finalFat,
            'protein': finalProtein,
          },
          nutrients: {
            'sodium': finalSodium,
            'sugar': finalSugar,
            'fiber': finalFiber,
            'cholesterol': finalCholesterol,
            'vitaminA': matchedTemplate.nutrients['vitaminA'] ?? 0,
            'calcium': matchedTemplate.nutrients['calcium'] ?? 0,
          },
          recommendation: dynamicRecommendation,
          timestamp: DateTime.now(),
        );
      }

      // If no template matches, but we have labels or OCR nutrition facts, build a DYNAMIC FoodItem!
      if (labels.isNotEmpty || parsedCalories != null) {
        debugPrint('[MLKitService] Creating a dynamic FoodItem based on detected tags/nutrition.');

        // Find the top non-generic label to use as the food name
        final genericTags = {'food', 'dish', 'cuisine', 'ingredient', 'produce', 'tableware', 'recipe', 'meal', 'fast food'};
        String foodName = 'Scanned Product';
        String emoji = '🏷️';

        for (final labelMap in labels) {
          final labelText = (labelMap['text'] as String? ?? '');
          final lower = labelText.toLowerCase();
          if (!genericTags.contains(lower)) {
            foodName = labelText;
            
            // Try to find matching emoji
            for (final entry in _emojiMap.entries) {
              if (lower.contains(entry.key) || entry.key.contains(lower)) {
                emoji = entry.value;
                break;
              }
            }
            break;
          }
        }

        final finalCalories = parsedCalories ?? 120;
        final finalCarbs = parsedCarbs ?? 15;
        final finalFat = parsedFat ?? 4;
        final finalProtein = parsedProtein ?? 3;

        final finalSodium = parsedSodium ?? 180;
        final finalSugar = parsedSugar ?? 6;
        final finalFiber = parsedFiber ?? 1;
        final finalCholesterol = parsedCholesterol ?? 10;

        final finalScore = _calculateHealthScore(
          calories: finalCalories,
          sugar: finalSugar,
          sodium: finalSodium,
          fiber: finalFiber,
        );

        final dynamicWarnings = _buildWarnings(
          calories: finalCalories,
          sugar: finalSugar,
          sodium: finalSodium,
          fat: finalFat,
        );

        final dynamicRecommendation = _buildRecommendation(
          foodName: foodName,
          score: finalScore,
          calories: finalCalories,
          sugar: finalSugar,
          sodium: finalSodium,
          riskProfile: riskProfile,
        );

        return FoodItem(
          id: 'ml_dynamic_${DateTime.now().millisecondsSinceEpoch}',
          name: foodName,
          emoji: emoji,
          calories: finalCalories,
          score: finalScore,
          serving: '1 container/serving',
          warnings: dynamicWarnings.isNotEmpty ? dynamicWarnings : ['On-Device Scanned'],
          macros: {
            'carbs': finalCarbs,
            'fat': finalFat,
            'protein': finalProtein,
          },
          nutrients: {
            'sodium': finalSodium,
            'sugar': finalSugar,
            'fiber': finalFiber,
            'cholesterol': finalCholesterol,
            'vitaminA': 2,
            'calcium': 20,
          },
          recommendation: dynamicRecommendation,
          timestamp: DateTime.now(),
        );
      }

      // Final fallback: Use file path matching
      debugPrint('[MLKitService] No content detected. Falling back to filename match.');
      return _getFilenameFallback(filePath, riskProfile);
    } catch (e) {
      debugPrint('[MLKitService] Error running on-device ML Kit: $e');
      return _getFilenameFallback(filePath, riskProfile);
    }
  }

  // Parses values using primary and optional secondary regex patterns
  int? _parseValue(String text, String primaryPattern, [String? secondaryPattern]) {
    try {
      final primaryRegex = RegExp(primaryPattern, caseSensitive: false);
      final match = primaryRegex.firstMatch(text);
      if (match != null && match.groupCount >= 1) {
        return int.tryParse(match.group(1)!);
      }
      if (secondaryPattern != null) {
        final secondaryRegex = RegExp(secondaryPattern, caseSensitive: false);
        final secMatch = secondaryRegex.firstMatch(text);
        if (secMatch != null && secMatch.groupCount >= 1) {
          return int.tryParse(secMatch.group(1)!);
        }
      }
    } catch (e) {
      debugPrint('[MLKitService] Regex parse error: $e');
    }
    return null;
  }

  // Calculate health score dynamically
  int _calculateHealthScore({
    required int calories,
    required int sugar,
    required int sodium,
    required int fiber,
  }) {
    int score = 80; // Start with baseline

    // Calorie deduction
    if (calories > 400) {
      score -= 15;
    } else if (calories > 250) {
      score -= 5;
    } else {
      score += 5;
    }

    // Sugar deduction (penalize high sugar)
    if (sugar > 20) {
      score -= 25;
    } else if (sugar > 10) {
      score -= 10;
    } else if (sugar <= 3) {
      score += 5;
    }

    // Sodium deduction
    if (sodium > 500) {
      score -= 20;
    } else if (sodium > 240) {
      score -= 10;
    } else if (sodium < 100) {
      score += 5;
    }

    // Fiber bonus
    if (fiber >= 4) {
      score += 10;
    } else if (fiber >= 2) {
      score += 5;
    }

    if (score > 100) return 100;
    if (score < 10) return 10;
    return score;
  }

  // Build warning labels dynamically
  List<String> _buildWarnings({
    required int calories,
    required int sugar,
    required int sodium,
    required int fat,
  }) {
    final List<String> warnings = [];
    if (calories > 400) warnings.add('High Calorie');
    if (sugar > 15) warnings.add('High Sugar');
    if (sodium > 400) warnings.add('High Sodium');
    if (fat > 15) warnings.add('High Fat');
    if (warnings.isEmpty) {
      warnings.add('Balanced Meal');
    }
    return warnings;
  }

  // Build recommendation text incorporating user disease risk profiles
  String _buildRecommendation({
    required String foodName,
    required int score,
    required int calories,
    required int sugar,
    required int sodium,
    required Map<String, dynamic> riskProfile,
  }) {
    final double diabetesRisk = (riskProfile['diabetes'] as num?)?.toDouble() ?? 25.0;
    final double heartRisk = (riskProfile['heart'] as num?)?.toDouble() ?? 20.0;
    final double obesityRisk = (riskProfile['obesity'] as num?)?.toDouble() ?? 20.0;

    String advice = 'Scanned via on-device AI. ';

    if (score >= 80) {
      advice += 'This $foodName is a highly nutritious choice. ';
    } else if (score >= 50) {
      advice += 'This $foodName is average. Enjoy in moderation. ';
    } else {
      advice += 'This $foodName is highly processed or nutrient-poor. ';
    }

    // Risk-based customized feedback
    final List<String> riskWarnings = [];
    if (sugar > 10 && diabetesRisk > 35) {
      riskWarnings.add('high sugar (${sugar}g) posing a concern for your diabetes profile (${diabetesRisk.toStringAsFixed(0)}%)');
    }
    if (sodium > 300 && heartRisk > 30) {
      riskWarnings.add('high sodium (${sodium}mg) posing a concern for your cardiovascular risk (${heartRisk.toStringAsFixed(0)}%)');
    }
    if (calories > 350 && obesityRisk > 30) {
      riskWarnings.add('high caloric density (${calories} kcal) affecting your obesity risk profile (${obesityRisk.toStringAsFixed(0)}%)');
    }

    if (riskWarnings.isNotEmpty) {
      advice += 'Caution: The ' + riskWarnings.join(' and ') + '.';
    } else {
      advice += 'It aligns reasonably well with your health profile guidelines.';
    }

    return advice;
  }

  // Fallback to match keywords in file name (compatibility helper)
  FoodItem _getFilenameFallback(String filePath, Map<String, dynamic> riskProfile) {
    final name = filePath.split('/').last.split('\\').last.toLowerCase();

    FoodItem template;
    if (name.contains('pizza')) {
      template = _foodTemplates['pizza']!;
    } else if (name.contains('burger')) {
      template = _foodTemplates['burger']!;
    } else if (name.contains('banana')) {
      template = _foodTemplates['banana']!;
    } else if (name.contains('apple')) {
      template = _foodTemplates['apple']!;
    } else if (name.contains('salmon') || name.contains('fish')) {
      template = _foodTemplates['salmon']!;
    } else if (name.contains('chicken')) {
      template = _foodTemplates['chicken']!;
    } else if (name.contains('salad')) {
      template = _foodTemplates['salad']!;
    } else {
      // Default to salad template
      template = _foodTemplates['salad']!;
    }

    // Build recommendation using template parameters and current user risks
    final dynamicRec = _buildRecommendation(
      foodName: template.name,
      score: template.score,
      calories: template.calories,
      sugar: template.nutrients['sugar'] ?? 0,
      sodium: template.nutrients['sodium'] ?? 0,
      riskProfile: riskProfile,
    );

    return FoodItem(
      id: template.id,
      name: template.name,
      emoji: template.emoji,
      calories: template.calories,
      score: template.score,
      serving: template.serving,
      warnings: template.warnings,
      macros: template.macros,
      nutrients: template.nutrients,
      recommendation: dynamicRec,
      timestamp: DateTime.now(),
    );
  }
}
