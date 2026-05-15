import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Profile"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: user == null
            ? const Center(child: Text("No user logged in"))
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.account_circle, size: 90),
                  const SizedBox(height: 20),
                  Text(
                    user.displayName ?? "No name",
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    user.email ?? "No email",
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 30),
                  ListTile(
                    leading: const Icon(Icons.badge),
                    title: const Text("User ID"),
                    subtitle: Text(user.uid),
                  ),
                ],
              ),
      ),
    );
  }
}
