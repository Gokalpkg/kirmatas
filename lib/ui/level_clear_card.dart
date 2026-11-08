import 'dart:math';
import 'package:flutter/material.dart';
import '../engine/i18n.dart';
import '../engine/in_app_review_manager.dart';
import 'kaunos_ui.dart';

/// Kaunos-styled badge displayed on flawless (3-star) level clear or victory.
class FlawlessVictoryBadge extends StatelessWidget {
  final double scale;

  const FlawlessVictoryBadge({super.key, this.scale = 1.0});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 400),
      curve: Curves.elasticOut,
      builder: (context, t, child) {
        return Transform.scale(
          scale: t * scale,
          child: child,
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFF041E28).withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFF00E5FF),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00E5FF).withValues(alpha: 0.4),
              blurRadius: 12,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.auto_awesome,
              color: Color(0xFF00E5FF),
              size: 13,
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                I18n.tr('flawless_victory_badge'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Rajdhani',
                  fontFamilyFallback: ['Segoe UI Emoji', 'Segoe UI Symbol'],
                  color: Color(0xFF00E5FF),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                  shadows: [
                    Shadow(
                      color: Color(0xFF00E5FF),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 5),
            const Icon(
              Icons.auto_awesome,
              color: Color(0xFF00E5FF),
              size: 13,
            ),
          ],
        ),
      ),
    );
  }
}

/// A standalone victory & level clear celebration card widget.
class LevelClearCard extends StatefulWidget {
  final int stars; // 1, 2, or 3
  final int level;
  final int score;
  final int goldEarned;
  final VoidCallback? onNextLevel;
  final VoidCallback? onRestart;
  final VoidCallback? onMainMenu;

  const LevelClearCard({
    super.key,
    required this.stars,
    required this.level,
    this.score = 0,
    this.goldEarned = 0,
    this.onNextLevel,
    this.onRestart,
    this.onMainMenu,
  });

  @override
  State<LevelClearCard> createState() => _LevelClearCardState();
}

class _LevelClearCardState extends State<LevelClearCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _popController;

  @override
  void initState() {
    super.initState();
    _popController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.stars >= 3 && (widget.level == 6 || (widget.level % 5 == 0 && widget.level > 5))) {
        InAppReviewManager.instance.checkAndRequestReview(
          context: context,
          level: widget.level,
          stars: widget.stars,
        );
      }
    });
  }

  @override
  void dispose() {
    _popController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final earnedStars = widget.stars.clamp(1, 3);
    final subtitleKey = earnedStars == 3
        ? 'stars_3_subtitle'
        : (earnedStars == 2 ? 'stars_2_subtitle' : 'stars_1_subtitle');

    return Container(
      width: 320,
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xF0101320),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: earnedStars == 3 ? const Color(0xFF00E5FF) : const Color(0xFFFFD54F),
          width: 1.8,
        ),
        boxShadow: [
          BoxShadow(
            color: (earnedStars == 3 ? const Color(0xFF00E5FF) : const Color(0xFFFFD54F))
                .withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Banner Title
            Text(
              '${I18n.tr('level_clear_banner')} (Lv.${widget.level})',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Rajdhani',
                color: Color(0xFFFFD54F),
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
                shadows: [
                  Shadow(
                    color: Color(0xFFFFD54F),
                    blurRadius: 10,
                  ),
                ],
              ),
            ),
          const SizedBox(height: 14),

          // 3 Bursting Golden Stars
          AnimatedBuilder(
            animation: _popController,
            builder: (context, _) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildBurstStar(1, 34, earnedStars >= 1, 0.0),
                  const SizedBox(width: 12),
                  _buildBurstStar(2, 44, earnedStars >= 2, 0.22),
                  const SizedBox(width: 12),
                  _buildBurstStar(3, 34, earnedStars >= 3, 0.44),
                ],
              );
            },
          ),
          const SizedBox(height: 10),

          // Subtitle Performance Text
          Text(
            I18n.tr(subtitleKey),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Rajdhani',
              fontFamilyFallback: const ['Segoe UI Emoji', 'Segoe UI Symbol'],
              color: earnedStars == 3 ? const Color(0xFF00E5FF) : const Color(0xFFFFD54F),
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),

          // Kusursuz Zafer Badge (if 3 stars earned)
          if (earnedStars == 3) ...[
            const SizedBox(height: 12),
            const FlawlessVictoryBadge(),
          ],

          const SizedBox(height: 16),

          // Stats row
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0x66181C2E),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    Text(
                      I18n.tr('score'),
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${widget.score}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                if (widget.goldEarned > 0)
                  Column(
                    children: [
                      Text(
                        I18n.tr('gold'),
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '+${widget.goldEarned}',
                        style: const TextStyle(
                          color: Color(0xFFFFD54F),
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),

          // Feature unlock badge for levels 3, 5, 10
          if (_buildFeatureUnlockBadge(widget.level) != null) ...[
            _buildFeatureUnlockBadge(widget.level)!,
          ],

          const SizedBox(height: 18),

          // Action Buttons
          if (widget.onNextLevel != null)
            KaunosTactileButton(
              onTap: widget.onNextLevel,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.play_arrow_rounded, color: Colors.black, size: 22),
                  const SizedBox(width: 6),
                  Text(
                    I18n.tr('next_level'),
                    style: const TextStyle(
                      fontFamily: 'Rajdhani',
                      color: Colors.black,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          if (widget.onMainMenu != null) ...[
            const SizedBox(height: 10),
            KaunosTactileButton(
              onTap: widget.onMainMenu,
              gradientColors: const [Color(0xFF263238), Color(0xFF1B2428)],
              borderColor: const Color(0xFF37474F),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.home_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 6),
                  Text(
                    I18n.tr('menu'),
                    style: const TextStyle(
                      fontFamily: 'Rajdhani',
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (widget.onRestart != null) ...[
            const SizedBox(height: 8),
            KaunosTactileButton(
              onTap: widget.onRestart,
              gradientColors: const [Color(0xFF1E242B), Color(0xFF14191E)],
              borderColor: const Color(0xFF2E3842),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.refresh_rounded, color: Colors.white70, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    I18n.tr('restart'),
                    style: const TextStyle(
                      fontFamily: 'Rajdhani',
                      color: Colors.white70,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    ),
  );
  }

  Widget _buildBurstStar(int index, double size, bool isEarned, double delayProgress) {
    final t = ((_popController.value - delayProgress) / 0.35).clamp(0.0, 1.0);
    final scale = t <= 0.0 ? 0.0 : (t < 1.0 ? (1.0 + sin(t * pi) * 0.45) : 1.0);
    // Vertical drop: starts 35px above and drops down with elastic bounce settling ("patlayarak dökülsün")
    final dropOffset = t <= 0.0 ? -35.0 : (1.0 - t) * -35.0;

    return Transform.translate(
      offset: Offset(0, dropOffset),
      child: Transform.scale(
        scale: scale,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            // Burst sparks radiating outwards when earned star impacts
            if (isEarned && t > 0.0 && t < 1.0)
              ...List.generate(6, (p) {
                final angle = p * pi / 3.0;
                final dist = 18.0 + (scale - 1.0) * 28.0;
                return Transform.translate(
                  offset: Offset(cos(angle) * dist, sin(angle) * dist),
                  child: Container(
                    width: 4,
                    height: 4,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFFFD54F),
                      boxShadow: [
                        BoxShadow(color: Color(0xFFFFD54F), blurRadius: 6),
                      ],
                    ),
                  ),
                );
              }),
            Container(
              decoration: isEarned
                  ? BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFFD54F).withValues(alpha: 0.65),
                          blurRadius: 18,
                          spreadRadius: 2,
                        ),
                      ],
                    )
                  : null,
              child: Icon(
                isEarned ? Icons.star_rounded : Icons.star_outline_rounded,
                color: isEarned ? const Color(0xFFFFD700) : Colors.white24,
                size: size,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget? _buildFeatureUnlockBadge(int level) {
    String? title;
    String? desc;
    IconData? icon;
    Color color = const Color(0xFFFFD700);

    if (level == 3) {
      title = 'YENİ ÖZELLİK AÇILDI!';
      desc = 'Kaunos Akvaryumu ve Şans Çarkı kilitleri kalktı!';
      icon = Icons.water_drop_rounded;
      color = const Color(0xFF00E5FF);
    } else if (level == 5) {
      title = 'YENİ ÖZELLİK AÇILDI!';
      desc = 'Kaos Modu kilitleri kalktı!';
      icon = Icons.flash_on_rounded;
      color = const Color(0xFFFF5252);
    } else if (level == 10) {
      title = 'YENİ ÖZELLİK AÇILDI!';
      desc = 'Haftalık Kaunos Turnuvası aktifleşti!';
      icon = Icons.military_tech_rounded;
      color = const Color(0xFFFFD700);
    }

    if (title == null) return null;

    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color, width: 1.6),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.28),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Rajdhani',
                    color: color,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    letterSpacing: 1.1,
                  ),
                ),
                Text(
                  desc!,
                  style: const TextStyle(
                    fontFamily: 'Rajdhani',
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
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
