class UserProfile {
  final String uid;
  final String name;
  final String email;
  final int age;
  final String gender;
  final int dailyCalorieGoal;
  final int diabetesRisk;
  final int obesityRisk;
  final int heartRisk;
  final int bpRisk;
  final double? weight;
  final int? height;
  final double? bmi;

  UserProfile({
    required this.uid,
    required this.name,
    required this.email,
    required this.age,
    required this.gender,
    required this.dailyCalorieGoal,
    required this.diabetesRisk,
    required this.obesityRisk,
    required this.heartRisk,
    required this.bpRisk,
    this.weight,
    this.height,
    this.bmi,
  });

  factory UserProfile.fromMap(Map<String, dynamic> map, String uid) {
    return UserProfile(
      uid: uid,
      name: map['name'] ?? 'User',
      email: map['email'] ?? '',
      age: map['age'] is int ? map['age'] as int : (map['age'] as num?)?.toInt() ?? 25,
      gender: map['gender'] ?? 'Not Disclosed',
      dailyCalorieGoal: map['dailyCalorieGoal'] is int ? map['dailyCalorieGoal'] as int : (map['dailyCalorieGoal'] as num?)?.toInt() ?? 2000,
      diabetesRisk: map['diabetesRisk'] is int ? map['diabetesRisk'] as int : (map['diabetesRisk'] as num?)?.toInt() ?? 30,
      obesityRisk: map['obesityRisk'] is int ? map['obesityRisk'] as int : (map['obesityRisk'] as num?)?.toInt() ?? 25,
      heartRisk: map['heartRisk'] is int ? map['heartRisk'] as int : (map['heartRisk'] as num?)?.toInt() ?? 20,
      bpRisk: map['bpRisk'] is int ? map['bpRisk'] as int : (map['bpRisk'] as num?)?.toInt() ?? 15,
      weight: map['weight'] != null ? double.tryParse(map['weight'].toString()) : null,
      height: map['height'] != null ? int.tryParse(map['height'].toString()) : null,
      bmi: map['bmi'] != null ? double.tryParse(map['bmi'].toString()) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'age': age,
      'gender': gender,
      'dailyCalorieGoal': dailyCalorieGoal,
      'diabetesRisk': diabetesRisk,
      'obesityRisk': obesityRisk,
      'heartRisk': heartRisk,
      'bpRisk': bpRisk,
      'weight': weight,
      'height': height,
      'bmi': bmi,
    };
  }
}
