import 'package:easy_livaign/screens/home_screen.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../widgets/brand_logo.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool isSignUp = false;
  bool _isSubmitting = false;

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_isSubmitting) return;

    setState(() => _isSubmitting = true);

    try {
      final auth = AuthService();

      final user = await auth.login(
        emailController.text.trim(),
        passwordController.text.trim(),
      );

      if (user == null) return;

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Login successful")));

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Login Error: $e")));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _signUp() async {
    if (_isSubmitting) return;

    setState(() => _isSubmitting = true);

    try {
      final name = nameController.text.trim();
      final email = emailController.text.trim();
      final password = passwordController.text.trim();

      if (name.isEmpty || email.isEmpty || password.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Please fill all fields")));
        return;
      }

      final auth = AuthService();
      final user = await auth.signUp(
        name: name,
        email: email,
        password: password,
      );

      if (user == null) {
        throw Exception("Could not create user");
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Account created successfully")),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Sign Up Error: $e")));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final actionText = isSignUp ? "Create Account" : "Login";

    return Scaffold(
      appBar: AppBar(title: Text(isSignUp ? "Sign Up" : "Login")),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _DoodleAuthFrame(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Center(child: BrandLogo(width: 76)),
                        const SizedBox(height: 18),
                        if (isSignUp) ...[
                          TextField(
                            controller: nameController,
                            decoration: const InputDecoration(
                              labelText: "Name",
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],
                        TextField(
                          controller: emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: "Email",
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: passwordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: "Password",
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 20),
                        FilledButton(
                          onPressed: _isSubmitting
                              ? null
                              : isSignUp
                              ? _signUp
                              : _login,
                          child: _isSubmitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(actionText),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: _isSubmitting
                              ? null
                              : () {
                                  setState(() {
                                    isSignUp = !isSignUp;
                                  });
                                },
                          child: Text(
                            isSignUp
                                ? "Already have an account? Login"
                                : "Don't have an account? Sign Up",
                          ),
                        ),
                      ],
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
}

class _DoodleAuthFrame extends StatelessWidget {
  final Widget child;

  const _DoodleAuthFrame({required this.child});

  static const _items = [
    _DoodleIcon(Icons.sentiment_satisfied_alt, Alignment(-0.95, -0.95), -0.2),
    _DoodleIcon(Icons.directions_run, Alignment(0.95, -0.88), 0.18),
    _DoodleIcon(Icons.delete_outline, Alignment(-0.98, 0.05), 0.24),
    _DoodleIcon(Icons.cleaning_services_outlined, Alignment(0.98, 0.16), -0.18),
    _DoodleIcon(Icons.shopping_cart_outlined, Alignment(-0.85, 0.86), -0.1),
    _DoodleIcon(Icons.shopping_bag_outlined, Alignment(0.86, 0.9), 0.15),
    _DoodleIcon(Icons.home_outlined, Alignment(0.05, -1.0), 0.08),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: Stack(
              children: _items.map((item) {
                return Align(
                  alignment: item.alignment,
                  child: Transform.rotate(
                    angle: item.rotation,
                    child: Icon(
                      item.icon,
                      size: 34,
                      color: colors.primary.withValues(alpha: 0.28),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 28),
          child: child,
        ),
      ],
    );
  }
}

class _DoodleIcon {
  final IconData icon;
  final Alignment alignment;
  final double rotation;

  const _DoodleIcon(this.icon, this.alignment, this.rotation);
}
