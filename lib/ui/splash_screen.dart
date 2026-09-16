import 'dart:math';
import 'package:flutter/material.dart';
import '../engine/i18n.dart';
import 'main_menu.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );

    _scaleAnimation = Tween<double>(begin: 0.82, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.65, curve: Curves.easeOutBack),
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.45, curve: Curves.easeIn),
      ),
    );

    _animController.forward();

    // Auto navigate after delay
    Future.delayed(const Duration(milliseconds: 2600), () {
      _goToMenu();
    });
  }

  void _goToMenu() {
    if (_navigated || !mounted) return;
    _navigated = true;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 550),
        pageBuilder: (context, anim, secAnim) => const MainMenuScreen(),
        transitionsBuilder: (context, animation, secAnim, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _goToMenu,
      child: Scaffold(
        backgroundColor: const Color(0xFF090B14),
        body: Stack(
          children: [
            // Background cosmic vignette with golden aura
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(0, -0.05),
                    radius: 0.95,
                    colors: [
                      Color(0xFF1B182B),
                      Color(0xFF101222),
                      Color(0xFF07080F),
                    ],
                  ),
                ),
              ),
            ),

            // Subtle animated backdrop stars
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _animController,
                builder: (context, _) {
                  return CustomPaint(
                    painter: _SplashAuraPainter(_animController.value),
                  );
                },
              ),
            ),

            // Kaunos Games Studio Logo
            Center(
              child: AnimatedBuilder(
                animation: _animController,
                builder: (context, child) {
                  return Opacity(
                    opacity: _fadeAnimation.value,
                    child: Transform.scale(
                      scale: _scaleAnimation.value,
                      child: child,
                    ),
                  );
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Shield + controller logo
                    Container(
                      constraints: const BoxConstraints(maxWidth: 310, maxHeight: 310),
                      padding: const EdgeInsets.all(12),
                      child: Image.asset(
                        'assets/images/kaunos_games.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Studio subtitle with pulse
                    AnimatedBuilder(
                      animation: _animController,
                      builder: (context, _) {
                        final pulse = (sin(_animController.value * pi * 3) * 0.3 + 0.7).clamp(0.0, 1.0);
                        return Opacity(
                          opacity: _fadeAnimation.value * pulse,
                          child: const Text(
                            'S U N A R',
                            style: TextStyle(
                              color: Color(0xFFFFD54F),
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 8.0,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

            // Tap to skip hint at bottom
            Positioned(
              bottom: 32,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  I18n.tr('tap_to_skip'),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.35),
                    fontSize: 11,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SplashAuraPainter extends CustomPainter {
  final double progress;
  _SplashAuraPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    // Warm radial core glow behind shield
    final center = Offset(size.width / 2, size.height / 2 - 20);
    final glowRadius = 140.0 + sin(progress * pi * 2) * 15.0;
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0x33FFB300),
          const Color(0x11FF6D00),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: glowRadius));
    canvas.drawCircle(center, glowRadius, glowPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
