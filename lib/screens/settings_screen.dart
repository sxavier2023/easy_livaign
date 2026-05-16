import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import 'login_screen.dart';
import 'profile_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isLoggingOut = false;

  Future<void> _logout(BuildContext context) async {
    if (_isLoggingOut) return;

    setState(() => _isLoggingOut = true);

    try {
      await AuthService().logout();

      if (!context.mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!context.mounted) return;

      setState(() => _isLoggingOut = false);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Logout Error: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text("Settings")),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text("Profile"),
            subtitle: const Text("Avatar and display name"),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
            },
          ),
          const ListTile(
            leading: Icon(Icons.lock),
            title: Text("Privacy"),
            subtitle: Text("Account and data controls coming soon"),
          ),
          const Divider(),
          ListTile(
            leading: _isLoggingOut
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.logout, color: Colors.red),
            title: Text(_isLoggingOut ? "Logging out..." : "Logout"),
            textColor: Colors.red,
            onTap: () => _logout(context),
          ),
        ],
      ),
    );
  }
}
