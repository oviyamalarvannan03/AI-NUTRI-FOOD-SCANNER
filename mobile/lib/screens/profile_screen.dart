import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/scanner_provider.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _calorieController = TextEditingController();
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  final _apiKeyController = TextEditingController();
  final _ollamaHostController = TextEditingController();
  final _ollamaModelController = TextEditingController();

  String _gender = 'Male';
  bool _isEditing = false;
  bool _isTestingOllama = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final scanner = Provider.of<ScannerProvider>(context, listen: false);

      if (auth.profile != null) {
        _nameController.text = auth.profile!.name;
        _ageController.text = auth.profile!.age.toString();
        _calorieController.text = auth.profile!.dailyCalorieGoal.toString();
        _weightController.text = auth.profile!.weight?.toString() ?? '';
        _heightController.text = auth.profile!.height?.toString() ?? '';
        setState(() {
          _gender = auth.profile!.gender;
        });
      }
      _apiKeyController.text = scanner.geminiApiKey;
      _ollamaHostController.text = scanner.ollamaHost;
      _ollamaModelController.text = scanner.ollamaModel;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _calorieController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    _apiKeyController.dispose();
    _ollamaHostController.dispose();
    _ollamaModelController.dispose();
    super.dispose();
  }

  void _saveProfile() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final name = _nameController.text.trim();
    final age = int.tryParse(_ageController.text.trim()) ?? 25;
    final cal = int.tryParse(_calorieController.text.trim()) ?? 2000;
    final weight = double.tryParse(_weightController.text.trim());
    final height = int.tryParse(_heightController.text.trim());

    try {
      await auth.updateProfile(
        name: name,
        age: age,
        gender: _gender,
        calorieGoal: cal,
        weight: weight,
        height: height,
      );
      setState(() {
        _isEditing = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Profile updated successfully!")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to update profile: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _saveApiKey() async {
    final scanner = Provider.of<ScannerProvider>(context, listen: false);
    await scanner.saveApiKey(_apiKeyController.text.trim());
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("🔑 Gemini API Key updated in local storage!")),
      );
    }
  }

  void _saveOllamaSettings() async {
    final scanner = Provider.of<ScannerProvider>(context, listen: false);
    await scanner.saveOllamaSettings(
      _ollamaHostController.text.trim(),
      _ollamaModelController.text.trim(),
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("🤖 Ollama settings saved!"),
          backgroundColor: Color(0xFF7C3AED),
        ),
      );
    }
  }

  void _testOllamaConnection() async {
    final scanner = Provider.of<ScannerProvider>(context, listen: false);
    setState(() => _isTestingOllama = true);
    final error = await scanner.ollamaService
        .testConnection(_ollamaHostController.text.trim());
    if (!mounted) return;
    setState(() => _isTestingOllama = false);
    if (error == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("✅ Ollama server reachable!"),
          backgroundColor: Color(0xFF10B981),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("❌ $error"),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    }
  }

  void _signOut() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    await auth.signOut();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final scanner = Provider.of<ScannerProvider>(context);
    final theme = Theme.of(context);

    final email = auth.profile?.email ?? auth.user?.email ?? '';
    final initials = auth.profile?.name.isNotEmpty == true ? auth.profile!.name[0].toUpperCase() : 'U';

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text("My Profile", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_isEditing ? Icons.save : Icons.edit, color: const Color(0xFF10B981)),
            onPressed: () {
              if (_isEditing) {
                _saveProfile();
              } else {
                setState(() => _isEditing = true);
              }
            },
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Avatar glass card
            Card(
              color: const Color(0xFF1E293B),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 46,
                      backgroundColor: const Color(0xFF7C3AED),
                      child: Text(initials, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                    const SizedBox(height: 16),
                    _isEditing
                        ? TextFormField(
                            controller: _nameController,
                            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                            decoration: const InputDecoration(border: InputBorder.none, hintText: "Enter name"),
                          )
                        : Text(
                            auth.profile?.name ?? 'User',
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                    const SizedBox(height: 4),
                    Text(email, style: const TextStyle(color: Colors.white60, fontSize: 13)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Profile fields
            const Text("Profile Settings", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 12),
            Card(
              color: const Color(0xFF1E293B),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _profileEditRow("Age", _ageController, TextInputType.number, _isEditing),
                    const Divider(color: Colors.white12),
                    _profileGenderRow(_isEditing),
                    const Divider(color: Colors.white12),
                    _profileEditRow("Weight (kg)", _weightController, const TextInputType.numberWithOptions(decimal: true), _isEditing),
                    const Divider(color: Colors.white12),
                    _profileEditRow("Height (cm)", _heightController, TextInputType.number, _isEditing),
                    const Divider(color: Colors.white12),
                    _profileBmiRow(auth.profile?.bmi),
                    const Divider(color: Colors.white12),
                    _profileEditRow("Calorie Goal (kcal)", _calorieController, TextInputType.number, _isEditing),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Profile actions
            _isEditing
                ? Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _saveProfile,
                          icon: const Icon(Icons.check, color: Colors.white),
                          label: const Text("Save Changes", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            setState(() {
                              _isEditing = false;
                              if (auth.profile != null) {
                                _nameController.text = auth.profile!.name;
                                _ageController.text = auth.profile!.age.toString();
                                _calorieController.text = auth.profile!.dailyCalorieGoal.toString();
                                _weightController.text = auth.profile!.weight?.toString() ?? '';
                                _heightController.text = auth.profile!.height?.toString() ?? '';
                                _gender = auth.profile!.gender;
                              }
                            });
                          },
                          icon: const Icon(Icons.close, color: Colors.white70),
                          label: const Text("Cancel", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.white24),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
                      ),
                    ],
                  )
                : ElevatedButton.icon(
                    onPressed: () => setState(() => _isEditing = true),
                    icon: const Icon(Icons.edit, color: Colors.white),
                    label: const Text("Edit Profile", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3B82F6),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
            const SizedBox(height: 24),

            // Gemini API Key entry card
            const Text("AI Configuration", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 12),
            Card(
              color: const Color(0xFF1E293B),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      "Scanner AI Engine",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: scanner.scannerEngine,
                      dropdownColor: const Color(0xFF1E293B),
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.black26,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF3B82F6))),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'gemini', child: Text("☁️  Cloud Vision AI (Gemini 2.0)")),
                        DropdownMenuItem(value: 'cnn', child: Text("📱  On-Device CNN (ML Kit)")),
                        DropdownMenuItem(value: 'ollama', child: Text("🦙  Ollama Local Vision")),
                        DropdownMenuItem(value: 'firebase', child: Text("☁️  Firebase Cloud AI")),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          scanner.setScannerEngine(val);
                        }
                      },
                    ),
                    // ── Ollama Settings Panel ──────────────────────────────
                    if (scanner.scannerEngine == 'ollama') ...[
                      const SizedBox(height: 16),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFF7C3AED).withValues(alpha: 0.5)),
                          borderRadius: BorderRadius.circular(14),
                          color: const Color(0xFF7C3AED).withValues(alpha: 0.08),
                        ),
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: const [
                                Icon(Icons.computer, color: Color(0xFF7C3AED), size: 16),
                                SizedBox(width: 6),
                                Text(
                                  "Ollama Server Settings",
                                  style: TextStyle(
                                    color: Color(0xFF7C3AED),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              "Use your PC's LAN IP (not localhost) so the phone can reach the server over Wi-Fi.",
                              style: TextStyle(color: Colors.white38, fontSize: 11),
                            ),
                            const SizedBox(height: 12),
                            const Text("Host URL",
                                style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            TextFormField(
                              controller: _ollamaHostController,
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                              decoration: InputDecoration(
                                hintText: "http://192.168.1.x:11434",
                                hintStyle: const TextStyle(color: Colors.white24),
                                filled: true,
                                fillColor: Colors.black26,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide.none),
                                focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(color: Color(0xFF7C3AED))),
                              ),
                            ),
                            const SizedBox(height: 10),
                            const Text("Model Name",
                                style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            TextFormField(
                              controller: _ollamaModelController,
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                              decoration: InputDecoration(
                                hintText: "minicpm-v",
                                hintStyle: const TextStyle(color: Colors.white24),
                                filled: true,
                                fillColor: Colors.black26,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide.none),
                                focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(color: Color(0xFF7C3AED))),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _saveOllamaSettings,
                                    icon: const Icon(Icons.save, size: 16),
                                    label: const Text("Save",
                                        style: TextStyle(fontWeight: FontWeight.bold)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF7C3AED),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10)),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed:
                                        _isTestingOllama ? null : _testOllamaConnection,
                                    icon: _isTestingOllama
                                        ? const SizedBox(
                                            width: 14,
                                            height: 14,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor: AlwaysStoppedAnimation<Color>(
                                                  Color(0xFF7C3AED)),
                                            ))
                                        : const Icon(Icons.wifi_tethering, size: 16),
                                    label: Text(
                                        _isTestingOllama ? "Testing…" : "Test",
                                        style: const TextStyle(fontWeight: FontWeight.bold)),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFF7C3AED),
                                      side: const BorderSide(color: Color(0xFF7C3AED)),
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    const Text(
                      "Gemini API Key",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      "Required to enable image visual scanners and real-time personalized recommendations.",
                      style: TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _apiKeyController,
                      obscureText: true,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: "Enter your Gemini API key...",
                        hintStyle: const TextStyle(color: Colors.white30),
                        filled: true,
                        fillColor: Colors.black26,
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF3B82F6)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _saveApiKey,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3B82F6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text("Save API Key", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    )
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Logout Button
            ElevatedButton.icon(
              onPressed: _signOut,
              icon: const Icon(Icons.logout, color: Colors.white),
              label: const Text("Sign Out of Account", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _profileEditRow(String label, TextEditingController controller, TextInputType type, bool isEdit) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 14)),
          SizedBox(
            width: 100,
            child: TextFormField(
              controller: controller,
              keyboardType: type,
              enabled: isEdit,
              style: TextStyle(color: isEdit ? Colors.white : Colors.white60, fontWeight: FontWeight.bold, fontSize: 14),
              textAlign: TextAlign.right,
              decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.zero),
            ),
          )
        ],
      ),
    );
  }

  Widget _profileGenderRow(bool isEdit) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text("Gender", style: TextStyle(color: Colors.white70, fontSize: 14)),
          isEdit
              ? DropdownButton<String>(
                  value: _gender,
                  dropdownColor: const Color(0xFF1E293B),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  items: ['Male', 'Female', 'Other'].map((g) {
                    return DropdownMenuItem(value: g, child: Text(g));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _gender = val);
                    }
                  },
                )
              : Text(_gender, style: const TextStyle(color: Colors.white60, fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _profileBmiRow(double? bmi) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text("BMI", style: TextStyle(color: Colors.white70, fontSize: 14)),
          Text(
            bmi != null ? bmi.toStringAsFixed(1) : '—',
            style: const TextStyle(color: Colors.white60, fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
