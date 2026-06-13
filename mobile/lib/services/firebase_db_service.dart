import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_profile.dart';
import '../models/food_item.dart';

class FirebaseDbService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<UserProfile?> getUserProfile(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        return UserProfile.fromMap(doc.data()!, uid);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to load user profile: $e');
    }
  }

  Future<void> saveUserProfile(UserProfile profile) async {
    try {
      // Get scan history first to compute risks
      final scans = await getScanHistory(profile.uid);
      final risks = _calculateDynamicRisks(
        age: profile.age,
        bmi: profile.bmi,
        gender: profile.gender,
        scans: scans,
      );

      final profileWithRisks = UserProfile(
        uid: profile.uid,
        name: profile.name,
        email: profile.email,
        age: profile.age,
        gender: profile.gender,
        dailyCalorieGoal: profile.dailyCalorieGoal,
        diabetesRisk: risks['diabetes']!,
        obesityRisk: risks['obesity']!,
        heartRisk: risks['heart']!,
        bpRisk: risks['bp']!,
        weight: profile.weight,
        height: profile.height,
        bmi: profile.bmi,
      );

      // Write user profile to users/{uid}
      await _db.collection('users').doc(profile.uid).set(profileWithRisks.toMap(), SetOptions(merge: true));

      // Also write to risks/{uid} for web cross-compatibility
      await _db.collection('risks').doc(profile.uid).set({
        'diabetes': risks['diabetes'],
        'heart': risks['heart'],
        'obesity': risks['obesity'],
        'bp': risks['bp'],
        'overall': risks['overall'],
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to save user profile: $e');
    }
  }

  Future<void> saveFoodScan(String uid, FoodItem item) async {
    try {
      await _db
          .collection('scans')
          .doc(uid)
          .collection('history')
          .add(item.toJson());

      // Update daily scans count and calorie totals in transactions matching the web's dailyStats path
      final statsRef = _db.collection('dailyStats').doc(uid).collection('days').doc(_getTodayId());
      await _db.runTransaction((transaction) async {
        final snapshot = await transaction.get(statsRef);
        int currentCal = 0;
        int currentScans = 0;
        if (snapshot.exists) {
          currentCal = snapshot.data()?['calories'] ?? 0;
          currentScans = snapshot.data()?['scansCount'] ?? 0;
        }
        transaction.set(statsRef, {
          'calories': currentCal + item.calories,
          'scansCount': currentScans + 1,
          'lastUpdated': FieldValue.serverTimestamp()
        }, SetOptions(merge: true));
      });

      // Now calculate dynamic risks and update risks in risks/{uid} and users/{uid}
      final userDoc = await _db.collection('users').doc(uid).get();
      if (userDoc.exists && userDoc.data() != null) {
        final profileMap = userDoc.data()!;
        final age = profileMap['age'] is int ? profileMap['age'] as int : 25;
        final bmi = profileMap['bmi'] != null ? double.tryParse(profileMap['bmi'].toString()) : null;
        final gender = profileMap['gender'] ?? 'Not Disclosed';

        final scans = await getScanHistory(uid);
        final risks = _calculateDynamicRisks(age: age, bmi: bmi, gender: gender, scans: scans);

        await _db.collection('users').doc(uid).update({
          'diabetesRisk': risks['diabetes'],
          'obesityRisk': risks['obesity'],
          'heartRisk': risks['heart'],
          'bpRisk': risks['bp'],
        });

        await _db.collection('risks').doc(uid).set({
          'diabetes': risks['diabetes'],
          'heart': risks['heart'],
          'obesity': risks['obesity'],
          'bp': risks['bp'],
          'overall': risks['overall'],
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      throw Exception('Failed to save food scan: $e');
    }
  }

  Future<List<FoodItem>> getScanHistory(String uid) async {
    try {
      final snap = await _db
          .collection('scans')
          .doc(uid)
          .collection('history')
          .orderBy('timestamp', descending: true)
          .get();

      return snap.docs
          .map((doc) => FoodItem.fromJson(doc.data(), id: doc.id))
          .toList();
    } catch (e) {
      throw Exception('Failed to load scan history: $e');
    }
  }

  Future<void> deleteFoodScan(String uid, String scanId) async {
    try {
      await _db
          .collection('scans')
          .doc(uid)
          .collection('history')
          .doc(scanId)
          .delete();
    } catch (e) {
      throw Exception('Failed to delete scan: $e');
    }
  }

  Future<Map<String, dynamic>> getDailyStats(String uid) async {
    try {
      final doc = await _db
          .collection('dailyStats')
          .doc(uid)
          .collection('days')
          .doc(_getTodayId())
          .get();

      if (doc.exists && doc.data() != null) {
        return doc.data()!;
      }
      return {'calories': 0, 'water': 0.0, 'steps': 0, 'scansCount': 0};
    } catch (e) {
      throw Exception('Failed to load daily stats: $e');
    }
  }

  Future<void> logWater(String uid, double liters) async {
    try {
      final statsRef = _db.collection('dailyStats').doc(uid).collection('days').doc(_getTodayId());
      await _db.runTransaction((transaction) async {
        final snapshot = await transaction.get(statsRef);
        double currentWater = 0.0;
        if (snapshot.exists) {
          currentWater = (snapshot.data()?['water'] as num?)?.toDouble() ?? 0.0;
        }
        transaction.set(statsRef, {
          'water': currentWater + liters,
          'lastUpdated': FieldValue.serverTimestamp()
        }, SetOptions(merge: true));
      });
    } catch (e) {
      throw Exception('Failed to log water: $e');
    }
  }

  String _getTodayId() {
    final now = DateTime.now();
    return "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
  }

  Map<String, int> _calculateDynamicRisks({
    required int age,
    required double? bmi,
    required String gender,
    required List<FoodItem> scans,
  }) {
    double avgSugar = 0.0;
    double avgSodium = 0.0;
    if (scans.isNotEmpty) {
      double totalSugar = 0.0;
      double totalSodium = 0.0;
      for (var s in scans) {
        totalSugar += (s.nutrients['sugar'] ?? 0);
        totalSodium += (s.nutrients['sodium'] ?? 0);
      }
      avgSugar = totalSugar / scans.length;
      avgSodium = totalSodium / scans.length;
    }

    // Obesity Risk based on BMI
    int obesity = 25;
    if (bmi != null) {
      if (bmi < 18.5) {
        obesity = 5;
      } else if (bmi < 25) {
        obesity = 10;
      } else if (bmi < 30) {
        obesity = (40 + (bmi - 25) * 4).round();
      } else {
        obesity = (70 + (bmi - 30) * 1.5).round();
      }
    }
    obesity = obesity.clamp(5, 95);

    // Diabetes Risk
    int diabetes = 10;
    if (bmi != null) {
      if (bmi >= 30) {
        diabetes += 30;
      } else if (bmi >= 25) {
        diabetes += 15;
      }
    }
    if (age >= 45) {
      diabetes += 15;
    } else if (age >= 35) {
      diabetes += 5;
    }
    if (gender.toLowerCase() == 'male') {
      diabetes += 5;
    }
    if (avgSugar > 20) {
      diabetes += 15;
    }
    diabetes = diabetes.clamp(5, 95);

    // Heart Disease Risk
    int heart = 15;
    if (age >= 50) {
      heart += 20;
    } else if (age >= 40) {
      heart += 10;
    }
    if (bmi != null) {
      if (bmi >= 30) {
        heart += 20;
      } else if (bmi >= 25) {
        heart += 10;
      }
    }
    if (gender.toLowerCase() == 'male') {
      heart += 10;
    }
    if (avgSodium > 1500) {
      heart += 15;
    }
    heart = heart.clamp(5, 95);

    // BP Risk
    int bp = 10;
    if (age >= 45) {
      bp += 15;
    } else if (age >= 35) {
      bp += 5;
    }
    if (bmi != null) {
      if (bmi >= 30) {
        bp += 25;
      } else if (bmi >= 25) {
        bp += 15;
      }
    }
    if (avgSodium > 1500) {
      bp += 20;
    }
    bp = bp.clamp(5, 95);

    int overall = ((diabetes + heart + obesity + bp) / 4).round();

    return {
      'diabetes': diabetes,
      'heart': heart,
      'obesity': obesity,
      'bp': bp,
      'overall': overall,
    };
  }
}
