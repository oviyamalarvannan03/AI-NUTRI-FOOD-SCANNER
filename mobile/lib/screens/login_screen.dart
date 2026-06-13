import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../main.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();

  bool _isSignUp = false;
  String _selectedGender = 'Male';
  bool _obscureText = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    try {
      if (_isSignUp) {
        final age = int.tryParse(_ageController.text.trim()) ?? 25;
        await authProvider.signUp(
          _nameController.text.trim(),
          _emailController.text.trim(),
          _passwordController.text,
          age,
          _selectedGender,
        );
      } else {
        await authProvider.signIn(
          _emailController.text.trim(),
          _passwordController.text,
        );
      }
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MainNavigationShell()),
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
    }
  }

  void _signInWithGoogle() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    try {
      await authProvider.signInWithGoogle();
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MainNavigationShell()),
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
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo Ring Header
                  Center(
                    child: Container(
                      width: 70,
                      height: 70,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [Color(0xFF3B82F6), Color(0xFF7C3AED)],
                        ),
                      ),
                      child: const Icon(
                        Icons.biotech,
                        size: 36,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _isSignUp ? "Create Account" : "Welcome Back",
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _isSignUp ? "Register to start scanning food" : "Sign in to track your dietary goals",
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white60,
                    ),
                  ),
                  const SizedBox(height: 32),

                  if (_isSignUp) ...[
                    // Full Name Input
                    TextFormField(
                      controller: _nameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration("Full Name", Icons.person),
                      validator: (val) => val == null || val.trim().isEmpty ? "Enter your name" : null,
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Email Input
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration("Email Address", Icons.email),
                    validator: (val) => val == null || !val.contains("@") ? "Enter a valid email" : null,
                  ),
                  const SizedBox(height: 16),

                  // Password Input
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscureText,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: "Password",
                      labelStyle: const TextStyle(color: Colors.white60),
                      prefixIcon: const Icon(Icons.lock, color: Colors.white50),
                      suffixIcon: IconButton(
                        icon: Icon(_obscureText ? Icons.visibility : Icons.visibility_off, color: Colors.white50),
                        onPressed: () => setState(() => _obscureText = !_obscureText),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: const BorderSide(color: Colors.white24),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: const BorderSide(color: Color(0xFF3B82F6)),
                      ),
                    ),
                    validator: (val) => val == null || val.length < 6 ? "Minimum 6 characters" : null,
                  ),
                  const SizedBox(height: 16),

                  if (_isSignUp) ...[
                    // Age Input
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _ageController,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(color: Colors.white),
                            decoration: _inputDecoration("Age", Icons.cake),
                            validator: (val) => val == null || int.tryParse(val) == null ? "Required" : null,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _selectedGender,
                            dropdownColor: const Color(0xFF1E293B),
                            style: const TextStyle(color: Colors.white),
                            decoration: _inputDecoration("Gender", Icons.wc),
                            items: ['Male', 'Female', 'Other'].map((g) {
                              return DropdownMenuItem(value: g, child: Text(g));
                            }).toList(),
                            onChanged: (val) => setState(() => _selectedGender = val ?? 'Male'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],

                  const SizedBox(height: 12),
                  // Submit Button
                  ElevatedButton(
                    onPressed: authProvider.isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3B82F6),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: authProvider.isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : Text(
                            _isSignUp ? "Create Account →" : "Sign In",
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                  ),
                  const SizedBox(height: 16),

                  // Divider
                  const Row(
                    children: [
                      Expanded(child: Divider(color: Colors.white24)),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text("OR", style: TextStyle(color: Colors.white38, fontSize: 12)),
                      ),
                      Expanded(child: Divider(color: Colors.white24)),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Google Button
                  OutlinedButton.icon(
                    onPressed: authProvider.isLoading ? null : _signInWithGoogle,
                    icon: const Icon(Icons.login, color: Colors.white),
                    label: const Text("Continue with Google", style: TextStyle(color: Colors.white)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: Colors.white30),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Mode Toggle Button
                  TextButton(
                    onPressed: () => setState(() => _isSignUp = !_isSignUp),
                    child: Text(
                      _isSignUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up",
                      style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white60),
      prefixIcon: Icon(icon, color: Colors.white50),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: Colors.white24),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: Color(0xFF3B82F6)),
      ),
    );
  }
}
