import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/scanner_provider.dart';
import 'food_result_screen.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final ImagePicker _picker = ImagePicker();
  File? _imageFile;
  bool _isProcessing = false;

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (picked != null) {
        setState(() {
          _imageFile = File(picked.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to access camera/gallery: $e")),
      );
    }
  }

  void _analyzeImage() async {
    if (_imageFile == null) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final scanner = Provider.of<ScannerProvider>(context, listen: false);

    if (scanner.geminiApiKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("ℹ️ No Gemini API Key set. Running in offline fallback mode."),
          backgroundColor: Color(0xFF3B82F6),
          duration: Duration(seconds: 2),
        ),
      );
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      final bytes = await _imageFile!.readAsBytes();
      final base64Image = base64Encode(bytes);
      final ext = _imageFile!.path.split('.').last.toLowerCase();
      final mimeType = ext == 'png' ? 'image/png' : 'image/jpeg';

      final riskProfile = {
        'diabetes': auth.profile?.diabetesRisk ?? 30,
        'heart': auth.profile?.heartRisk ?? 20,
        'obesity': auth.profile?.obesityRisk ?? 25,
      };

      final result = await scanner.scanFoodImage(
        uid: auth.user!.uid,
        base64Image: base64Image,
        mimeType: mimeType,
        riskProfile: riskProfile,
        filePath: _imageFile!.path,
      );

      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => FoodResultScreen(foodItem: result, localImage: _imageFile),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll("Exception: ", "")),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scanner = Provider.of<ScannerProvider>(context);
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text("AI Food Scanner", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Card(
                color: const Color(0xFF1E293B),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                child: _imageFile == null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.photo_camera_back, size: 72, color: Colors.white24),
                          const SizedBox(height: 16),
                          const Text(
                            "Take a picture or select an image of your food",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white50, fontSize: 14),
                          ),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ElevatedButton.icon(
                                onPressed: () => _pickImage(ImageSource.camera),
                                icon: const Icon(Icons.camera_alt),
                                label: const Text("Camera"),
                                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3B82F6)),
                              ),
                              const SizedBox(width: 12),
                              OutlinedButton.icon(
                                onPressed: () => _pickImage(ImageSource.gallery),
                                icon: const Icon(Icons.photo_library),
                                label: const Text("Gallery"),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  side: const BorderSide(color: Colors.white30),
                                ),
                              ),
                            ],
                          )
                        ],
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.file(_imageFile!, fit: Platform.isAndroid ? BoxFit.cover : BoxFit.contain),
                            if (_isProcessing)
                              Container(
                                color: Colors.black54,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF10B981))),
                                    const SizedBox(height: 16),
                                    Text(
                                      scanner.scannerEngine == 'cnn'
                                          ? "Processing food on-device with ML Kit..."
                                          : "Analyzing food with Gemini AI Vision...",
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                    )
                                  ],
                                ),
                              )
                          ],
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 16),
            if (_imageFile != null && !_isProcessing) ...[
              ElevatedButton(
                onPressed: _analyzeImage,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                child: const Text("Analyze Food Item", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => setState(() => _imageFile = null),
                child: const Text("Reset and Retake", style: TextStyle(color: Colors.white50)),
              )
            ]
          ],
        ),
      ),
    );
  }
}
