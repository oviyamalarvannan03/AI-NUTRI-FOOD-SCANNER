import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firebase_auth_service.dart';
import '../services/firebase_db_service.dart';
import '../models/user_profile.dart';

class AuthProvider with ChangeNotifier {
  final FirebaseAuthService _authService = FirebaseAuthService();
  final FirebaseDbService _dbService = FirebaseDbService();

  User? _user;
  UserProfile? _profile;
  bool _isLoading = false;

  User? get user => _user;
  UserProfile? get profile => _profile;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null;

  AuthProvider() {
    _authService.authStateChanges.listen((User? firebaseUser) async {
      _user = firebaseUser;
      if (firebaseUser != null) {
        await fetchUserProfile();
      } else {
        _profile = null;
      }
      notifyListeners();
    });
  }

  Future<void> fetchUserProfile() async {
    if (_user == null) return;
    try {
      _profile = await _dbService.getUserProfile(_user!.uid);
      notifyListeners();
    } catch (e) {
      debugPrint("Error fetching user profile: $e");
    }
  }

  Future<void> signIn(String email, String password) async {
    _setLoading(true);
    try {
      await _authService.signInWithEmail(email, password);
    } finally {
      _setLoading(false);
    }
  }

  Future<void> signUp(String name, String email, String password, int age, String gender) async {
    _setLoading(true);
    try {
      final credential = await _authService.signUpWithEmail(email, password);
      if (credential?.user != null) {
        final profile = UserProfile(
          uid: credential!.user!.uid,
          name: name,
          email: email,
          age: age,
          gender: gender,
          dailyCalorieGoal: 2000,
          diabetesRisk: 30, // Default baseline risks
          obesityRisk: 25,
          heartRisk: 20,
          bpRisk: 15,
        );
        await _dbService.saveUserProfile(profile);
        _profile = profile;
      }
    } finally {
      _setLoading(false);
    }
  }

  Future<void> signInWithGoogle() async {
    _setLoading(true);
    try {
      final credential = await _authService.signInWithGoogle();
      if (credential?.user != null) {
        final existing = await _dbService.getUserProfile(credential!.user!.uid);
        if (existing == null) {
          final profile = UserProfile(
            uid: credential.user!.uid,
            name: credential.user!.displayName ?? 'NutriAI User',
            email: credential.user!.email ?? '',
            age: 25,
            gender: 'Not Disclosed',
            dailyCalorieGoal: 2000,
            diabetesRisk: 30,
            obesityRisk: 25,
            heartRisk: 20,
            bpRisk: 15,
          );
          await _dbService.saveUserProfile(profile);
          _profile = profile;
        } else {
          _profile = existing;
        }
      }
    } finally {
      _setLoading(false);
    }
  }

  Future<void> updateProfile({
    required String name,
    required int age,
    required String gender,
    required int calorieGoal,
    double? weight,
    int? height,
  }) async {
    if (_user == null || _profile == null) return;
    _setLoading(true);
    try {
      double? bmi;
      if (weight != null && height != null && height > 0) {
        bmi = double.parse((weight / ((height / 100) * (height / 100))).toStringAsFixed(1));
      }
      final updated = UserProfile(
        uid: _profile!.uid,
        name: name,
        email: _profile!.email,
        age: age,
        gender: gender,
        dailyCalorieGoal: calorieGoal,
        diabetesRisk: _profile!.diabetesRisk,
        obesityRisk: _profile!.obesityRisk,
        heartRisk: _profile!.heartRisk,
        bpRisk: _profile!.bpRisk,
        weight: weight,
        height: height,
        bmi: bmi,
      );
      await _dbService.saveUserProfile(updated);
      await fetchUserProfile();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> resetPassword(String email) async {
    await _authService.sendPasswordReset(email);
  }

  Future<void> signOut() async {
    _setLoading(true);
    try {
      await _authService.signOut();
      _user = null;
      _profile = null;
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool val) {
    _isLoading = val;
    notifyListeners();
  }
}
