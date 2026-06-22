import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/firebase_db_service.dart';
import '../services/gemini_service.dart';
import '../services/ml_kit_service.dart';
import '../services/ollama_service.dart';
import '../services/firebase_ai_service.dart';
import '../models/food_item.dart';

class ScannerProvider with ChangeNotifier {
  final FirebaseDbService _dbService = FirebaseDbService();
  final GeminiService _geminiService = GeminiService();
  final MLKitService _mlKitService = MLKitService();
  final OllamaService _ollamaService = OllamaService();
  final FirebaseAiService _firebaseAiService = FirebaseAiService();

  List<FoodItem> _scanHistory = [];
  bool _isLoading = false;
  String _geminiApiKey = '';
  String _scannerEngine = 'gemini'; // 'gemini', 'cnn', or 'ollama'
  String _ollamaHost = 'http://192.168.1.5:11434';
  String _ollamaModel = 'minicpm-v';

  int _dailyCalories = 0;
  double _dailyWater = 0.0;
  int _dailySteps = 7234; // Sample dynamic value matching wearable integration
  int _dailyScans = 0;
  bool _isPhoneConnected = false;

  List<FoodItem> get scanHistory => _scanHistory;
  bool get isLoading => _isLoading;
  String get geminiApiKey => _geminiApiKey;
  String get scannerEngine => _scannerEngine;
  String get ollamaHost => _ollamaHost;
  String get ollamaModel => _ollamaModel;
  OllamaService get ollamaService => _ollamaService;

  int get dailyCalories => _dailyCalories;
  double get dailyWater => _dailyWater;
  int get dailySteps => _dailySteps;
  int get dailyScans => _dailyScans;
  bool get isPhoneConnected => _isPhoneConnected;

  ScannerProvider() {
    loadSettings();
  }

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _geminiApiKey = prefs.getString('GEMINI_API_KEY') ?? '';
    _scannerEngine = prefs.getString('SCANNER_ENGINE') ?? 'gemini';
    _ollamaHost = prefs.getString('OLLAMA_HOST') ?? 'http://192.168.1.5:11434';
    _ollamaModel = prefs.getString('OLLAMA_MODEL') ?? 'minicpm-v';
    notifyListeners();
  }

  Future<void> saveApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('GEMINI_API_KEY', key);
    _geminiApiKey = key;
    notifyListeners();
  }

  Future<void> setScannerEngine(String val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('SCANNER_ENGINE', val);
    _scannerEngine = val;
    notifyListeners();
  }

  Future<void> saveOllamaSettings(String host, String model) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('OLLAMA_HOST', host.trim());
    await prefs.setString('OLLAMA_MODEL', model.trim());
    _ollamaHost = host.trim();
    _ollamaModel = model.trim();
    notifyListeners();
  }

  Future<void> loadDailyStats(String uid) async {
    try {
      final stats = await _dbService.getDailyStats(uid);
      _dailyCalories = stats['calories'] ?? 0;
      _dailyWater = (stats['water'] as num?)?.toDouble() ?? 0.0;
      _dailyScans = stats['scansCount'] ?? 0;
      notifyListeners();
    } catch (e) {
      debugPrint("Error loading daily stats: $e");
    }
  }

  Future<void> loadHistory(String uid) async {
    _isLoading = true;
    notifyListeners();
    try {
      _scanHistory = await _dbService.getScanHistory(uid);
    } catch (e) {
      debugPrint("Error loading history: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logWater(String uid, double liters) async {
    try {
      await _dbService.logWater(uid, liters);
      _dailyWater += liters;
      notifyListeners();
    } catch (e) {
      debugPrint("Error logging water: $e");
    }
  }

  Future<FoodItem> scanFoodImage({
    required String uid,
    required String base64Image,
    required String mimeType,
    required Map<String, dynamic> riskProfile,
    String? filePath,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final FoodItem item;
      if (_scannerEngine == 'firebase') {
        item = await _firebaseAiService.analyzeFoodImage(
          base64Image: base64Image,
          mimeType: mimeType,
          riskProfile: riskProfile,
          filePath: filePath,
        );
      } else if (_scannerEngine == 'ollama') {
        item = await _ollamaService.analyzeFoodImage(
          ollamaHost: _ollamaHost,
          modelName: _ollamaModel,
          base64Image: base64Image,
          riskProfile: riskProfile,
          filePath: filePath,
        );
      } else if (_scannerEngine == 'cnn' && filePath != null) {
        item = await _mlKitService.analyzeImage(
          filePath: filePath,
          riskProfile: riskProfile,
        );
      } else {
        item = await _geminiService.analyzeFoodImage(
          apiKey: _scannerEngine == 'cnn' ? '' : _geminiApiKey,
          base64Image: base64Image,
          mimeType: mimeType,
          riskProfile: riskProfile,
          filePath: filePath,
        );
      }

      // Save to Firestore and reload stats/history
      await _dbService.saveFoodScan(uid, item);
      await loadDailyStats(uid);
      await loadHistory(uid);

      return item;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteScan(String uid, String scanId) async {
    try {
      await _dbService.deleteFoodScan(uid, scanId);
      _scanHistory.removeWhere((element) => element.id == scanId);
      notifyListeners();
    } catch (e) {
      debugPrint("Error deleting scan: $e");
    }
  }

  Future<void> connectPhoneAndSyncSteps() async {
    _isLoading = true;
    notifyListeners();

    // Simulate connection delay
    await Future.delayed(const Duration(milliseconds: 1500));

    _isPhoneConnected = true;
    _dailySteps += 1845; // Add some fresh synced steps
    _isLoading = false;
    notifyListeners();
  }

  Future<void> disconnectPhone() async {
    _isLoading = true;
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 500));
    _isPhoneConnected = false;
    _isLoading = false;
    notifyListeners();
  }
}
