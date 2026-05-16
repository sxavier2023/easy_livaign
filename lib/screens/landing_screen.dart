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
    final logoAnimation = _interval(0.45, 0.8);
    final buttonAnimation = _interval(0.72, 1);

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: const Color(0xFFF8FAFC),
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
                      _AnimatedHandPair(
                        animation: _interval(0, 0.55),
                        begin: const Offset(-120, -86),
                        end: const Offset(-44, -34),
                        rotate: -0.7,
                      ),
                      _AnimatedHandPair(
                        animation: _interval(0.08, 0.63),
                        begin: const Offset(120, -86),
                        end: const Offset(44, -34),
                        rotate: 0.7,
                      ),
                      _AnimatedHandPair(
                        animation: _interval(0.16, 0.71),
                        begin: const Offset(-120, 86),
                        end: const Offset(-44, 34),
                        rotate: -2.4,
                      ),
                      _AnimatedHandPair(
                        animation: _interval(0.24, 0.79),
                        begin: const Offset(120, 86),
                        end: const Offset(44, 34),
                        rotate: 2.4,
                      ),
                      ScaleTransition(
                        scale: Tween<double>(
                          begin: 0.7,
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
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF172033),
                    ),
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

class _AnimatedHandPair extends StatelessWidget {
  final Animation<double> animation;
  final Offset begin;
  final Offset end;
  final double rotate;

  const _AnimatedHandPair({
    required this.animation,
    required this.begin,
    required this.end,
    required this.rotate,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final offset = Offset.lerp(begin, end, animation.value)!;
        final opacity = animation.value.clamp(0.0, 1.0);

        return Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: offset,
            child: Transform.rotate(
              angle: rotate,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.back_hand, size: 28, color: colors.primary),
                  const SizedBox(width: 5),
                  Icon(Icons.back_hand, size: 28, color: colors.tertiary),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SoftRing extends StatelessWidget {
  const _SoftRing();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      height: 220,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
      ),
    );
  }
}
