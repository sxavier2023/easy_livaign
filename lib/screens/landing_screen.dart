import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../widgets/brand_logo.dart';
import 'login_screen.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1900),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _openLogin() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  Animation<double> _interval(double begin, double end) {
    return CurvedAnimation(
      parent: _controller,
      curve: Interval(begin, end, curve: Curves.easeOutCubic),
    );
  }

  @override
  Widget build(BuildContext context) {
    final logoAnimation = _interval(0.18, 0.72);
    final buttonAnimation = _interval(0.72, 1);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 300,
                  height: 300,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      const _SoftRing(),
                      _OrbitDots(animation: _controller),
                      ScaleTransition(
                        scale: Tween<double>(
                          begin: 0.62,
                          end: 1,
                        ).animate(logoAnimation),
                        child: FadeTransition(
                          opacity: logoAnimation,
                          child: const BrandLogo(width: 132),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                FadeTransition(
                  opacity: logoAnimation,
                  child: const Text(
                    "Easy LivAIgn",
                    style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(height: 22),
                FadeTransition(
                  opacity: buttonAnimation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.4),
                      end: Offset.zero,
                    ).animate(buttonAnimation),
                    child: FilledButton.icon(
                      onPressed: _openLogin,
                      icon: const Icon(Icons.arrow_forward),
                      label: const Text("Get Started"),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 26,
                          vertical: 16,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OrbitDots extends StatelessWidget {
  final Animation<double> animation;

  const _OrbitDots({required this.animation});

  @override
  Widget build(BuildContext context) {
    const dots = [
      (Color(0xFF55BF91), 0.0),
      (Color(0xFFF7AD3D), 1.57),
      (Color(0xFF6B58D8), 3.14),
      (Color(0xFF4F7DDD), 4.71),
    ];

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final progress = Curves.easeOutCubic.transform(animation.value);
        final radius = 92 - (18 * progress);

        return Stack(
          alignment: Alignment.center,
          children: dots.map((dot) {
            final angle = dot.$2 + (animation.value * 1.4);

            return Transform.translate(
              offset: Offset(
                radius * math.sin(angle),
                radius * math.cos(angle),
              ),
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: dot.$1,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: dot.$1.withValues(alpha: 0.28),
                      blurRadius: 14,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _SoftRing extends StatelessWidget {
  const _SoftRing();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      width: 220,
      height: 220,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: colors.outlineVariant, width: 1.5),
      ),
    );
  }
}
