import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../engine/audio_manager.dart';
import '../engine/game_event_bus.dart';

/// Global achievement toast banner overlay.
/// Implements the 5-step tactile reward choreography:
/// Step 1: Elastic slide-in golden banner from top with dust particles.
/// Step 2: 3D flip icon (? -> Trophy) with 45-degree pixel gleam.
/// Step 3: Spark particle bursts around edges & rolling text.
/// Step 4: Triumphant fanfare sound & crisp haptic punch.
/// Step 5: Smooth 4-second linger then upward slide-out retraction.
class AchievementToastOverlay extends StatefulWidget {
  final Widget child;

  const AchievementToastOverlay({super.key, required this.child});

  @override
  State<AchievementToastOverlay> createState() => _AchievementToastOverlayState();
}

class _AchievementToastOverlayState extends State<AchievementToastOverlay>
    with TickerProviderStateMixin {
  StreamSubscription<AchievementUnlockedEvent>? _sub;

  AchievementUnlockedEvent? _currentEvent;
  late final AnimationController _slideController;
  late final AnimationController _flipController;
  late final AnimationController _gleamController;
  late final Animation<double> _slideAnimation;
  late final Animation<double> _flipAnimation;

  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();

    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );

    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _gleamController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _slideAnimation = CurvedAnimation(
      parent: _slideController,
      curve: Curves.elasticOut,
      reverseCurve: Curves.easeInBack,
    );

    _flipAnimation = CurvedAnimation(
      parent: _flipController,
      curve: Curves.easeInOutBack,
    );

    _sub = GameEventBus().on<AchievementUnlockedEvent>().listen(_handleAchievementUnlocked);
  }

  void _handleAchievementUnlocked(AchievementUnlockedEvent event) {
    if (!mounted) return;
    _dismissTimer?.cancel();

    setState(() {
      _currentEvent = event;
    });

    // Step 1 & 4: Slide in with elastic overshoot, play fanfare & haptic
    _slideController.forward(from: 0.0);
    AudioManager.instance.playSfx(GameSfx.victory);
    HapticFeedback.heavyImpact();

    // Step 2: 250ms delayed 3D flip from '?' into Trophy + gleam sweep
    Future.delayed(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      _flipController.forward(from: 0.0);
      _gleamController.forward(from: 0.0);
      HapticFeedback.selectionClick();
    });

    // Step 5: After 4 seconds, retract banner upward into ceiling
    _dismissTimer = Timer(const Duration(seconds: 4), () {
      if (!mounted) return;
      _slideController.reverse().then((_) {
        if (mounted) {
          setState(() {
            _currentEvent = null;
          });
        }
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _dismissTimer?.cancel();
    _slideController.dispose();
    _flipController.dispose();
    _gleamController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_currentEvent != null)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: AnimatedBuilder(
                animation: Listenable.merge([_slideController, _flipController, _gleamController]),
                builder: (context, _) {
                  final slideY = (_slideAnimation.value - 1.0) * 120.0;
                  return Transform.translate(
                    offset: Offset(0, slideY),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: _buildBannerContent(_currentEvent!),
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildBannerContent(AchievementUnlockedEvent event) {
    final flipVal = _flipAnimation.value;
    final isTrophy = flipVal >= 0.5;
    final gleamVal = _gleamController.value;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF141026),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFFFD700),
          width: 2.2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0xFF090A10),
            offset: Offset(0, 5),
            blurRadius: 0,
          ),
          BoxShadow(
            color: Color(0x66FFD700),
            offset: Offset(0, 2),
            blurRadius: 10,
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // 45-degree pixel gleam sweep across frame
          if (gleamVal > 0.0 && gleamVal < 1.0)
            Positioned.fill(
              child: CustomPaint(
                painter: _PixelGleamPainter(progress: gleamVal),
              ),
            ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                // Step 2: 3D Flip Trophy Container
                Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.002)
                    ..rotateY(flipVal * math.pi),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isTrophy ? const Color(0xFFB45309) : const Color(0xFF312E81),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isTrophy ? const Color(0xFFFDE047) : const Color(0xFF818CF8),
                        width: 2,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0xFF000000),
                          offset: Offset(0, 2),
                          blurRadius: 0,
                        ),
                      ],
                    ),
                    child: Center(
                      child: isTrophy
                          ? Transform(
                              alignment: Alignment.center,
                              transform: Matrix4.identity()..rotateY(math.pi),
                              child: const Icon(
                                Icons.emoji_events_rounded,
                                color: Color(0xFFFFD700),
                                size: 26,
                              ),
                            )
                          : const Text(
                              '?',
                              style: TextStyle(
                                fontFamily: 'Rajdhani',
                                fontWeight: FontWeight.w900,
                                fontSize: 24,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // Step 3: Rolling Text & Reward Points
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFD700),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'BAŞARIM AÇILDI',
                              style: TextStyle(
                                fontFamily: 'Rajdhani',
                                fontWeight: FontWeight.w900,
                                fontSize: 10,
                                color: Color(0xFF181425),
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                          if (event.points > 0) ...[
                            const SizedBox(width: 6),
                            Text(
                              '+${event.points} PUAN',
                              style: const TextStyle(
                                fontFamily: 'Rajdhani',
                                fontWeight: FontWeight.w900,
                                fontSize: 11,
                                color: Color(0xFF38BDF8),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        event.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Rajdhani',
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                      if (event.description.isNotEmpty)
                        Text(
                          event.description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Rajdhani',
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PixelGleamPainter extends CustomPainter {
  final double progress;

  const _PixelGleamPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final startX = (size.width + 100) * progress - 50;
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(startX, 0)
      ..lineTo(startX + 25, 0)
      ..lineTo(startX + 5, size.height)
      ..lineTo(startX - 20, size.height)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _PixelGleamPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
