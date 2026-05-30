import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'package:easy_livaign/screens/home_screen.dart';
import 'package:easy_livaign/screens/landing_screen.dart';
import 'package:easy_livaign/screens/login_screen.dart';
import 'package:easy_livaign/services/notification_service.dart';
import 'package:easy_livaign/services/theme_service.dart';
import 'package:easy_livaign/widgets/doodle_background.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await NotificationService().initialize();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppThemeChoice>(
      valueListenable: ThemeService.selectedTheme,
      builder: (context, selectedTheme, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeService.themeData(selectedTheme),
          builder: (context, child) {
            return DoodleBackground(
              theme: selectedTheme,
              child: child ?? const SizedBox.shrink(),
            );
          },
          home: const AuthGate(),
          routes: {
            '/landing': (context) => const LandingScreen(),
            '/login': (context) => const LoginScreen(),
            '/home': (context) => const HomeScreen(),
          },
        );
      },
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData) {
          return const HomeScreen();
        }

        return const LandingScreen();
      },
    );
  }
}
