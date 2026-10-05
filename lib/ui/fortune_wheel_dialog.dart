import 'dart:math';
import 'package:flutter/material.dart';
import '../engine/ad_manager.dart';
import '../engine/audio_manager.dart';
import '../models/cosmetics.dart';
import '../storage/save_manager.dart';
import 'crate_opening_dialog.dart';

class WheelReward {
  final String label;
  final String subtitle;
  final IconData icon;
  final Color primaryColor;
  final Color secondaryColor;
  final void Function(BuildContext context, SaveManager save) onClaim;

  const WheelReward({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.primaryColor,
    required this.secondaryColor,
    required this.onClaim,
  });
}

class FortuneWheelDialog extends StatefulWidget {
  const FortuneWheelDialog({super.key});

  @override
  State<FortuneWheelDialog> createState() => _FortuneWheelDialogState();
}

class _FortuneWheelDialogState extends State<FortuneWheelDialog> with SingleTickerProviderStateMixin {
  late final AnimationController _spinController;
  late Animation<double> _spinAnimation;

  double _currentRotation = 0.0;
  bool _isSpinning = false;

  final List<WheelReward> _rewards = [
    WheelReward(
      label: '500 🪙',
      subtitle: 'JACKPOT!',
      icon: Icons.diamond,
      primaryColor: const Color(0xFFFFD700),
      secondaryColor: const Color(0xFFFF8F00),
      onClaim: (context, save) => save.addGold(500),
    ),
    WheelReward(
      label: 'SANDIK',
      subtitle: 'Gizemli Ödül',
      icon: Icons.inventory_2,
      primaryColor: const Color(0xFFE040FB),
      secondaryColor: const Color(0xFF7C4DFF),
      onClaim: (context, save) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => CrateOpeningDialog(
            crate: CrateDef.allCrates.first,
          ),
        );
      },
    ),
    WheelReward(
      label: 'PARÇA',
      subtitle: '+1 Shard',
      icon: Icons.hexagon,
      primaryColor: const Color(0xFF00E5FF),
      secondaryColor: const Color(0xFF00B0FF),
      onClaim: (context, save) {
        final categories = ['balls', 'paddles', 'trails', 'bricks'];
        final cat = categories[Random().nextInt(categories.length)];
        save.addShard(cat, 1);
      },
    ),
    WheelReward(
      label: '250 🪙',
      subtitle: 'Büyük Ödül',
      icon: Icons.monetization_on,
      primaryColor: const Color(0xFFFF9100),
      secondaryColor: const Color(0xFFFF6D00),
      onClaim: (context, save) => save.addGold(250),
    ),
    WheelReward(
      label: '150 🪙',
      subtitle: 'Altın',
      icon: Icons.stars,
      primaryColor: const Color(0xFFFFD54F),
      secondaryColor: const Color(0xFFFFB300),
      onClaim: (context, save) => save.addGold(150),
    ),
    WheelReward(
      label: '+1 CAN',
      subtitle: 'Can Boostu',
      icon: Icons.favorite,
      primaryColor: const Color(0xFFFF1744),
      secondaryColor: const Color(0xFFD50000),
      onClaim: (context, save) => save.addBoostStock('life', 1),
    ),
    WheelReward(
      label: '100 🪙',
      subtitle: 'Altın',
      icon: Icons.toll,
      primaryColor: const Color(0xFF26A69A),
      secondaryColor: const Color(0xFF00897B),
      onClaim: (context, save) => save.addGold(100),
    ),
    WheelReward(
      label: '75 🪙',
      subtitle: 'Altın',
      icon: Icons.monetization_on,
      primaryColor: const Color(0xFFAB47BC),
      secondaryColor: const Color(0xFF8E24AA),
      onClaim: (context, save) => save.addGold(75),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4600),
    );
  }

  @override
  void dispose() {
    _spinController.dispose();
    super.dispose();
  }

  void _triggerWheelSpin() {
    if (_isSpinning) return;
    setState(() {
      _isSpinning = true;
    });

    final rand = Random();
    // Weighted selection: higher prizes slightly rarer, smaller prizes more frequent
    // Indexes: 0: 500g, 1: crate, 2: shard, 3: 250g, 4: 100g, 5: life, 6: 75g, 7: 50g
    final weights = [4.0, 7.0, 9.0, 14.0, 20.0, 10.0, 18.0, 18.0];
    final totalWeight = weights.reduce((a, b) => a + b);
    double roll = rand.nextDouble() * totalWeight;
    int targetIndex = 0;
    for (int i = 0; i < weights.length; i++) {
      if (roll <= weights[i]) {
        targetIndex = i;
        break;
      }
      roll -= weights[i];
    }

    final sectorAngle = (2 * pi) / _rewards.length;
    // Pointer is at the TOP (-pi/2 or 3*pi/2).
    // Sector i center is at angle i * sectorAngle + sectorAngle / 2.
    // To align sector i under top pointer:
    final targetAngleOffset = (3 * pi / 2) - (targetIndex * sectorAngle + sectorAngle / 2);
    final fullRotations = (5 + rand.nextInt(3)) * 2 * pi;
    final finalRotation = _currentRotation + fullRotations + (targetAngleOffset - (_currentRotation % (2 * pi)));

    _spinAnimation = Tween<double>(
      begin: _currentRotation,
      end: finalRotation,
    ).animate(
      CurvedAnimation(parent: _spinController, curve: Curves.easeOutCubic),
    );

    int lastTickSector = -1;
    _spinAnimation.addListener(() {
      setState(() {
        _currentRotation = _spinAnimation.value;
      });

      // Sound effect ticks when crossing sector dividers
      final currentSector = ((_currentRotation / sectorAngle).floor()) % _rewards.length;
      if (currentSector != lastTickSector) {
        lastTickSector = currentSector;
        AudioManager.instance.playSfx(GameSfx.hitBrick);
      }
    });

    _spinController.forward(from: 0.0).then((_) {
      final selectedReward = _rewards[targetIndex];
      setState(() {
        _isSpinning = false;
      });

      AudioManager.instance.playSfx(GameSfx.ulti);

      // Claim reward into save
      selectedReward.onClaim(context, SaveManager.instance);

      _showPrizeDialog(selectedReward);
    });
  }

  void _onWatchAdAndSpin() {
    AdManager.instance.watchHighYieldAd(
      context,
      onSuccess: () {
        if (!mounted) return;
        _triggerWheelSpin();
      },
      onDismissedEarly: () {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.info_outline, color: Color(0xFFFFD54F), size: 22),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Şans çarkını çevirmek için reklamı sonuna kadar izlemelisiniz.',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF1E2438),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        );
      },
    );
  }

  void _showPrizeDialog(WheelReward reward) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xF0101320),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: reward.primaryColor, width: 2),
        ),
        title: Column(
          children: [
            Icon(reward.icon, color: reward.primaryColor, size: 54),
            const SizedBox(height: 12),
            const Text(
              'TEBRİKLER! 👑',
              style: TextStyle(color: Color(0xFFFFD54F), fontWeight: FontWeight.w900, fontSize: 20),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              reward.label,
              style: TextStyle(
                color: reward.primaryColor,
                fontWeight: FontWeight.w900,
                fontSize: 26,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              reward.subtitle,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 14),
            const Text(
              'Ödül hesabınıza aktarıldı!',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
        actions: [
          Center(
            child: ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: reward.primaryColor,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
              ),
              child: const Text('HARİKA!', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final adManager = AdManager.instance;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFA0F1322),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: const Color(0xFFFFD54F), width: 2),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFFB300).withValues(alpha: 0.35),
              blurRadius: 36,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(width: 32),
                const Row(
                  children: [
                    Icon(Icons.stars, color: Color(0xFFFFD54F), size: 24),
                    SizedBox(width: 8),
                    Text(
                      'ŞANS ÇARKI',
                      style: TextStyle(
                        color: Color(0xFFFFD54F),
                        fontWeight: FontWeight.w900,
                        fontSize: 20,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: _isSpinning ? null : () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: Colors.white70),
                ),
              ],
            ),
            const Text(
              'Her Çevirmede Büyük Ödüller!',
              style: TextStyle(color: Colors.white60, fontSize: 12),
            ),
            const SizedBox(height: 16),

            // Animated Wheel with top pointer
            SizedBox(
              width: 270,
              height: 270,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Outer Glow & Wheel Painter
                  Transform.rotate(
                    angle: _currentRotation,
                    child: CustomPaint(
                      size: const Size(270, 270),
                      painter: _WheelPainter(rewards: _rewards),
                    ),
                  ),

                  // Center Pin Hub
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const RadialGradient(
                        colors: [Color(0xFFFFF9C4), Color(0xFFFFD54F), Color(0xFFFF8F00)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.6),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(Icons.star, color: Color(0xFF3E2723), size: 24),
                    ),
                  ),

                  // Top Indicator Arrow
                  Positioned(
                    top: 0,
                    child: CustomPaint(
                      size: const Size(26, 26),
                      painter: _PointerArrowPainter(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Action Button: Watch High-Yield Ad & Spin
            ListenableBuilder(
              listenable: adManager,
              builder: (context, _) {
                final isLoading = adManager.isLoadingHighYield || _isSpinning;

                return ElevatedButton(
                  onPressed: isLoading ? null : _onWatchAdAndSpin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFB300),
                    foregroundColor: const Color(0xFF2E1C00),
                    disabledBackgroundColor: const Color(0x33FFB300),
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    elevation: 6,
                    shadowColor: const Color(0xFFFF8F00).withValues(alpha: 0.5),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (isLoading) ...[
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          _isSpinning ? 'Çark Dönüyor...' : 'Reklam Hazırlanıyor...',
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                        ),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Color(0xFF2E1C00),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.play_arrow_rounded, color: Color(0xFFFFD54F), size: 16),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          '🎬 REKLAM İZLE & ÇEVİR!',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _WheelPainter extends CustomPainter {
  final List<WheelReward> rewards;
  _WheelPainter({required this.rewards});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;
    final sectorAngle = (2 * pi) / rewards.length;

    // Outer Rim
    final rimPaint = Paint()
      ..color = const Color(0xFFFFD54F)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7;
    canvas.drawCircle(center, radius + 4, rimPaint);

    final sectorPaint = Paint()..style = PaintingStyle.fill;
    final dividerPaint = Paint()
      ..color = const Color(0x80FFFFFF)
      ..strokeWidth = 2;

    for (int i = 0; i < rewards.length; i++) {
      final reward = rewards[i];
      final startAngle = i * sectorAngle;

      // Draw Sector
      sectorPaint.shader = LinearGradient(
        colors: [reward.primaryColor, reward.secondaryColor],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromCircle(center: center, radius: radius));

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sectorAngle,
        true,
        sectorPaint,
      );

      // Draw Divider
      final divX = center.dx + cos(startAngle) * radius;
      final divY = center.dy + sin(startAngle) * radius;
      canvas.drawLine(center, Offset(divX, divY), dividerPaint);

      // Draw Sector Label & Icon
      final midAngle = startAngle + sectorAngle / 2;
      final textRadius = radius * 0.68;
      final tx = center.dx + cos(midAngle) * textRadius;
      final ty = center.dy + sin(midAngle) * textRadius;

      canvas.save();
      canvas.translate(tx, ty);
      canvas.rotate(midAngle + pi / 2);

      final textSpan = TextSpan(
        text: reward.label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 12,
          shadows: [Shadow(color: Colors.black87, blurRadius: 4, offset: Offset(0, 1))],
        ),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();

      textPainter.paint(canvas, Offset(-textPainter.width / 2, -textPainter.height / 2));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _PointerArrowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFFF1744)
      ..style = PaintingStyle.fill;

    final shadowPaint = Paint()
      ..color = const Color(0xFFB71C1C)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();

    canvas.drawPath(path, paint);
    canvas.drawPath(path, shadowPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
