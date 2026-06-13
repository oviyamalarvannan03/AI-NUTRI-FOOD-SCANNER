import 'package:flutter_test/flutter_test.dart';
import 'package:nutri_ai_scanner/models/user_profile.dart';

void main() {
  group('UserProfile Model Tests', () {
    test('fromMap should parse map correctly', () {
      final map = {
        'name': 'Test User',
        'email': 'test@example.com',
        'age': 30,
        'gender': 'Male',
        'dailyCalorieGoal': 2200,
        'diabetesRisk': 20,
        'obesityRisk': 15,
        'heartRisk': 10,
        'bpRisk': 5,
        'weight': 75.5,
        'height': 180,
        'bmi': 23.3,
      };

      final profile = UserProfile.fromMap(map, 'user_123');

      expect(profile.uid, 'user_123');
      expect(profile.name, 'Test User');
      expect(profile.email, 'test@example.com');
      expect(profile.age, 30);
      expect(profile.gender, 'Male');
      expect(profile.dailyCalorieGoal, 2200);
      expect(profile.diabetesRisk, 20);
      expect(profile.obesityRisk, 15);
      expect(profile.heartRisk, 10);
      expect(profile.bpRisk, 5);
      expect(profile.weight, 75.5);
      expect(profile.height, 180);
      expect(profile.bmi, 23.3);
    });

    test('toMap should output map correctly', () {
      final profile = UserProfile(
        uid: 'user_123',
        name: 'Test User',
        email: 'test@example.com',
        age: 30,
        gender: 'Male',
        dailyCalorieGoal: 2200,
        diabetesRisk: 20,
        obesityRisk: 15,
        heartRisk: 10,
        bpRisk: 5,
        weight: 75.5,
        height: 180,
        bmi: 23.3,
      );

      final map = profile.toMap();

      expect(map['name'], 'Test User');
      expect(map['email'], 'test@example.com');
      expect(map['age'], 30);
      expect(map['gender'], 'Male');
      expect(map['dailyCalorieGoal'], 2200);
      expect(map['diabetesRisk'], 20);
      expect(map['obesityRisk'], 15);
      expect(map['heartRisk'], 10);
      expect(map['bpRisk'], 5);
      expect(map['weight'], 75.5);
      expect(map['height'], 180);
      expect(map['bmi'], 23.3);
    });
  });
}
