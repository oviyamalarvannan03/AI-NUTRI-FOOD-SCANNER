import 'dart:io';
import 'package:flutter/material.dart';
import '../models/food_item.dart';

class FoodResultScreen extends StatelessWidget {
  final FoodItem foodItem;
  final File? localImage;

  const FoodResultScreen({
    super.key,
    required this.foodItem,
    this.localImage,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scoreColor = foodItem.score >= 80
        ? const Color(0xFF10B981)
        : (foodItem.score >= 50 ? const Color(0xFFF59E0B) : const Color(0xFFEF4444));

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: Text(foodItem.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Preview Image & Score overlay
            if (localImage != null)
              Container(
                height: 200,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  image: DecorationImage(
                    image: FileImage(localImage!),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            const SizedBox(height: 16),

            // Health Score Ring Card
            Card(
              color: const Color(0xFF1E293B),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 70,
                          height: 70,
                          child: CircularProgressIndicator(
                            value: foodItem.score / 100,
                            strokeWidth: 6,
                            backgroundColor: Colors.white10,
                            valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
                          ),
                        ),
                        Text(
                          "${foodItem.score}",
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: scoreColor),
                        ),
                      ],
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Health Score Rating", style: TextStyle(color: Colors.white60, fontSize: 13)),
                          const SizedBox(height: 2),
                          Text(
                            foodItem.score >= 80 ? "Highly Recommended" : (foodItem.score >= 50 ? "Moderate Choice" : "Caution Required"),
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          const SizedBox(height: 4),
                          Text(foodItem.serving, style: const TextStyle(fontSize: 12, color: Colors.white38)),
                        ],
                      ),
                    )
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Health Warnings / Badges
            if (foodItem.warnings.isNotEmpty) ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: foodItem.warnings.map((w) {
                  final isHealthy = w.toLowerCase().contains("balanced") || w.toLowerCase().contains("protein") || w.toLowerCase().contains("low");
                  return Chip(
                    label: Text(w, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                    backgroundColor: isHealthy ? const Color(0xFF10B981).withOpacity(0.2) : const Color(0xFFEF4444).withOpacity(0.2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
            ],

            // Macro Metrics Info
            const Text("Macronutrients", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 12),
            _macroRow("Carbohydrates", "${foodItem.macros['carbs'] ?? 0}g", Colors.amber),
            _macroRow("Fat", "${foodItem.macros['fat'] ?? 0}g", Colors.redAccent),
            _macroRow("Protein", "${foodItem.macros['protein'] ?? 0}g", Colors.green),
            const SizedBox(height: 24),

            // Micro Metrics Rows
            const Text("Detailed Nutrients", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 12),
            Card(
              color: const Color(0xFF1E293B),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  children: [
                    _nutrientRow("Sodium", "${foodItem.nutrients['sodium'] ?? 0}mg"),
                    const Divider(color: Colors.white12),
                    _nutrientRow("Sugar", "${foodItem.nutrients['sugar'] ?? 0}g"),
                    const Divider(color: Colors.white12),
                    _nutrientRow("Fiber", "${foodItem.nutrients['fiber'] ?? 0}g"),
                    const Divider(color: Colors.white12),
                    _nutrientRow("Cholesterol", "${foodItem.nutrients['cholesterol'] ?? 0}mg"),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // AI Recommendations Banner
            const Text("Personalized AI Recommendation", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 12),
            Card(
              color: const Color(0xFF7C3AED).withOpacity(0.15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: Color(0xFF7C3AED), width: 1),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.psychology, color: Color(0xFFA855F7)),
                        SizedBox(width: 8),
                        Text("NutriAI Diagnostic Insight", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      foodItem.recommendation,
                      style: const TextStyle(color: Colors.white90, fontSize: 13, height: 1.5),
                    )
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _macroRow(String name, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 10),
              Text(name, style: const TextStyle(color: Colors.white70, fontSize: 14)),
            ],
          ),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _nutrientRow(String name, String val) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(name, style: const TextStyle(color: Colors.white70)),
          Text(val, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
