import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class RiskScreen extends StatelessWidget {
  const RiskScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final profile = auth.profile;

    final diabetesRisk = profile?.diabetesRisk ?? 30;
    final obesityRisk = profile?.obesityRisk ?? 25;
    final heartRisk = profile?.heartRisk ?? 20;
    final bpRisk = profile?.bpRisk ?? 15;

    final overallRisk = ((diabetesRisk + obesityRisk + heartRisk + bpRisk) / 4).toInt();

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text("Disease Risk Analysis", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Overall Risk Banner
            Card(
              color: const Color(0xFF1E293B),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    const Text("Overall Disease Susceptibility", style: TextStyle(color: Colors.white60, fontSize: 13)),
                    const SizedBox(height: 6),
                    Text(
                      "$overallRisk%",
                      style: const TextStyle(fontSize: 48, fontWeight: FontWeight.extrabold, color: Colors.white),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: _getRiskColor(overallRisk).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.solid(color: _getRiskColor(overallRisk), width: 1),
                      ),
                      child: Text(
                        _getRiskLevel(overallRisk),
                        style: TextStyle(color: _getRiskColor(overallRisk), fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            const Text("Individual Risk Indicator Metrics", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 16),

            // Risk Cards List
            _individualRiskCard(
              title: "Type 2 Diabetes Risk",
              percentage: diabetesRisk,
              icon: Icons.bloodtype,
              color: const Color(0xFFEF4444),
              advisory: "Focus on low glycemic index foods, cut out refined sugars, and maintain at least 30 minutes of daily physical activity.",
            ),
            _individualRiskCard(
              title: "Obesity / Weight Risk",
              percentage: obesityRisk,
              icon: Icons.monitor_weight,
              color: const Color(0xFFF59E0B),
              advisory: "Maintain a moderate caloric deficit (300-500 kcal deficit), track macros diligently, and limit processed trans fats.",
            ),
            _individualRiskCard(
              title: "Cardiovascular Disease Risk",
              percentage: heartRisk,
              icon: Icons.favorite,
              color: const Color(0xFF3B82F6),
              advisory: "Integrate healthy omega-3 rich foods like flaxseeds, avocados, and salmon, and limit daily sodium intake under 2300mg.",
            ),
            _individualRiskCard(
              title: "Hypertension / BP Risk",
              percentage: bpRisk,
              icon: Icons.speed,
              color: const Color(0xFF10B981),
              advisory: "Monitor high-sodium ingredients, increase potassium-rich vegetable intake, and perform light cardio daily.",
            ),
          ],
        ),
      ),
    );
  }

  Widget _individualRiskCard({
    required String title,
    required int percentage,
    required IconData icon,
    required Color color,
    required String advisory,
  }) {
    return Card(
      color: const Color(0xFF1E293B),
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
                Text(
                  "$percentage%",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
                )
              ],
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: percentage / 100,
                minHeight: 8,
                backgroundColor: Colors.white10,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              "Recommendation Advisory:",
              style: TextStyle(color: color.withOpacity(0.8), fontSize: 11, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              advisory,
              style: const TextStyle(color: Colors.white60, fontSize: 12, height: 1.4),
            )
          ],
        ),
      ),
    );
  }

  Color _getRiskColor(int pct) {
    if (pct >= 50) return const Color(0xFFEF4444); // High Risk Red
    if (pct >= 25) return const Color(0xFFF59E0B); // Med Risk Orange
    return const Color(0xFF10B981); // Low Risk Green
  }

  String _getRiskLevel(int pct) {
    if (pct >= 50) return "High Risk Threshold";
    if (pct >= 25) return "Moderate Risk Threshold";
    return "Optimal Low Risk";
  }
}
