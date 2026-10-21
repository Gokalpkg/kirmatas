import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../engine/game_controller.dart';
import '../engine/i18n.dart';
import '../models/game_state.dart';
import '../storage/save_manager.dart';
import '../engine/ad_manager.dart';
import '../engine/audio_manager.dart';
import 'kaunos_ui.dart';

class PauseGameOverOverlay extends StatelessWidget {
  final GameController controller;
  final VoidCallback onResume;
  final VoidCallback onRestart;
  final VoidCallback onMainMenu;

  const PauseGameOverOverlay({
    super.key,
    required this.controller,
    required this.onResume,
    required this.onRestart,
    required this.onMainMenu,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (controller.status == GameStatus.playing || controller.status == GameStatus.ready) {
          return const SizedBox.shrink();
        }

        final isPaused = controller.status == GameStatus.paused;
        final isVictory = controller.status == GameStatus.victory;
        final isGameOver = controller.status == GameStatus.gameOver;

        final stats = controller.stats;
        final save = SaveManager.instance;
        final bestScore = save.getHighScore(controller.currentMode);
        final isNewRecord = stats.score > bestScore;

        return Container(
          color: const Color(0xCC05060A),
          child: Stack(
            children: [
              Center(
            child: SingleChildScrollView(
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 650),
                curve: Curves.elasticOut,
                builder: (context, t, child) {
                  return Transform.translate(
                    offset: Offset(0, -46.0 * (1.0 - t)),
                    child: Opacity(opacity: t.clamp(0.0, 1.0), child: child),
                  );
                },
                child: Container(
                width: 320,
                margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: const Color(0xF0101320),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: isVictory
                        ? const Color(0xFFFFD54F)
                        : (isGameOver ? const Color(0xFFFF5252) : Colors.white24),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (isVictory
                              ? const Color(0xFFFFD54F)
                              : (isGameOver ? const Color(0xFFFF5252) : Colors.black))
                          .withValues(alpha: 0.35),
                      blurRadius: 36,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Title
                    Text(
                      isPaused
                          ? I18n.tr('paused')
                          : (isVictory ? I18n.tr('victory') : I18n.tr('game_over')),
                      style: TextStyle(
                        color: isVictory
                            ? const Color(0xFFFFD54F)
                            : (isGameOver ? const Color(0xFFFF5252) : Colors.white),
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 16),

                    if (!isPaused) ...[
                      // Stats card
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0x66181C2E),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(I18n.tr('score'), style: const TextStyle(color: Colors.white70)),
                                TweenAnimationBuilder<double>(
                                  tween: Tween<double>(begin: 0.0, end: stats.score.toDouble()),
                                  duration: const Duration(milliseconds: 700),
                                  curve: Curves.easeOutCubic,
                                  builder: (context, value, _) {
                                    return Text(
                                      '${value.round()}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 18,
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(I18n.tr('high_score'), style: const TextStyle(color: Colors.white70)),
                                Text( '$bestScore',
                                  style: const TextStyle(
                                    color: Color(0xFFFFD54F),
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(I18n.tr('max_combo'), style: const TextStyle(color: Colors.white70)),
                                Text( 'x${stats.maxCombo}',
                                  style: const TextStyle(
                                    color: Color(0xFF00E5FF),
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(I18n.tr('bricks_broken'), style: const TextStyle(color: Colors.white70)),
                                Text( '${stats.bricksBroken}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(I18n.tr('gold_earned'), style: const TextStyle(color: Colors.white70)),
                                Row(
                                  children: [
                                    const Icon(Icons.monetization_on, color: Color(0xFFFFD54F), size: 16),
                                    const SizedBox(width: 4),
                                    Text( '+${stats.goldCollected}',
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
                          ],
                        ),
                      ),
                      if (isNewRecord) ...[
                        const SizedBox(height: 10),
                        TweenAnimationBuilder<double>(
                          tween: Tween<double>(begin: 2.2, end: 1.0),
                          duration: const Duration(milliseconds: 450),
                          curve: Curves.elasticOut,
                          builder: (context, scale, child) {
                            return Transform.rotate(
                              angle: -0.07,
                              child: Transform.scale(scale: scale, child: child),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFFFD54F), width: 2),
                              boxShadow: const [
                                BoxShadow(color: Color(0x66FFD600), blurRadius: 14),
                              ],
                            ),
                            child: Text(
                              I18n.tr('new_record'),
                              style: const TextStyle(
                                color: Color(0xFFFFD54F),
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                    ],

                    if (isPaused)
                      ListenableBuilder(
                        listenable: save,
                        builder: (context, _) {
                          return Column(
                            children: [
                              Text( '${I18n.tr('sfx')}: ${save.sfxVolume}',
                                style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold),
                              ),
                              Slider(
                                value: save.sfxVolume.toDouble(),
                                min: 0,
                                max: 8,
                                divisions: 8,
                                activeColor: const Color(0xFFFFD54F),
                                onChanged: (v) {
                                  save.setSfxVolume(v.toInt());
                                  AudioManager.instance.playSfx(GameSfx.hitBrick);
                                },
                              ),
                              Text( '${I18n.tr('music_bgm')}: ${save.bgmVolume == 0 ? I18n.tr('haptic_off') : save.bgmVolume}',
                                style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold),
                              ),
                              Slider(
                                value: save.bgmVolume.toDouble(),
                                min: 0,
                                max: 8,
                                divisions: 8,
                                activeColor: const Color(0xFFFFD54F),
                                onChanged: (v) {
                                  save.setBgmVolume(v.toInt());
                                  AudioManager.instance.updateBgmVolume();
                                },
                              ),
                              Text( '${I18n.tr('haptics')}: ${save.vibrationLevel == 0 ? I18n.tr('off') : save.vibrationLevel}',
                                style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold),
                              ),
                              Slider(
                                value: save.vibrationLevel.toDouble(),
                                min: 0,
                                max: 8,
                                divisions: 8,
                                activeColor: const Color(0xFFFFD54F),
                                onChanged: (v) {
                                  save.setVibrationLevel(v.toInt());
                                  AudioManager.instance.playSfx(GameSfx.hitBrick);
                                },
                              ),
                            ],
                          );
                        },
                      ),
                    if (isPaused) const SizedBox(height: 16),
                    // Actions
                    if (isPaused)
                      KaunosPressGlow(
                        borderRadius: 16,
                        waveColor: const Color(0xFF00E5FF),
                        child: ElevatedButton.icon(
                          onPressed: onResume,
                          icon: const Icon(Icons.play_arrow),
                          label: Text(I18n.tr('resume')),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00E5FF),
                            foregroundColor: Colors.black,
                            minimumSize: const Size.fromHeight(48),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    KaunosPressGlow(
                      borderRadius: 16,
                      waveColor: const Color(0xFFFFD54F),
                      child: ElevatedButton.icon(
                        onPressed: onRestart,
                        icon: const Icon(Icons.replay),
                        label: Text(
                          isGameOver && controller.currentMode == GameMode.classic
                              ? I18n.tr('continue_band').replaceAll('{level}', '${controller.classicCheckpointLevel}')
                              : I18n.tr('restart'),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFD54F),
                          foregroundColor: Colors.black,
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (isGameOver && controller.canRevive) ...[
                      _buildReviveButton(context),
                      const SizedBox(height: 10),
                    ],
                    if (isGameOver || isVictory) ...[
                      _EndGameDiceMultiplierCard(controller: controller),
                      const SizedBox(height: 12),
                    ],
                    KaunosPressGlow(
                      borderRadius: 16,
                      waveColor: Colors.white70,
                      child: OutlinedButton.icon(
                        onPressed: onMainMenu,
                        icon: const Icon(Icons.home),
                        label: Text(I18n.tr('main_menu')),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white70,
                          minimumSize: const Size.fromHeight(48),
                          side: const BorderSide(color: Colors.white24),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ),
                  ],
                ),
                ),
              ),
              ),
              ),
              if (isNewRecord && !isPaused)
                const Positioned.fill(
                  child: IgnorePointer(
                    child: _RecordConfetti(),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildReviveButton(BuildContext context) {
    final adManager = AdManager.instance;
    final isLoading = adManager.isShowing;

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF1744), Color(0xFFFF5252), Color(0xFFFF8A80)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFF8A80), width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66FF1744),
            blurRadius: 18,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: isLoading
              ? null
              : () {
                  adManager.watchAdForRevive(
                    context,
                    onReviveSuccess: () {
                      controller.reviveWithOneLife();
                    },
                    onDismissedEarly: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              const Icon(Icons.info_outline, color: Color(0xFFFF8A80), size: 22),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  I18n.tr('watch_ad_to_revive_hint'),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          backgroundColor: const Color(0xFF1E2438),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: const BorderSide(color: Color(0xFFFF8A80), width: 1),
                          ),
                          duration: const Duration(seconds: 3),
                        ),
                      );
                    },
                  );
                },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Glossy sheen sweep across the revive action
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: -1.2, end: 2.2),
                      duration: const Duration(milliseconds: 1500),
                      builder: (context, pos, _) {
                        return FractionalTranslation(
                          translation: Offset(pos, 0),
                          child: Container(
                            width: 46,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.white.withValues(alpha: 0.0),
                                  Colors.white.withValues(alpha: 0.30),
                                  Colors.white.withValues(alpha: 0.0),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                Row(
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
                    I18n.tr('ad_preparing'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                  ),
                ] else ...[
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 1.7, end: 1.0),
                    duration: const Duration(milliseconds: 650),
                    curve: Curves.elasticOut,
                    builder: (context, scale, child) {
                      return Transform.scale(scale: scale, child: child);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withValues(alpha: 0.5),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.favorite, color: Color(0xFFFF1744), size: 18),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text( '️ ${I18n.tr('save_record_title')}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${I18n.tr('extra_life_badge')} (${controller.revivesUsed + 1}/${GameController.maxRevivesPerGame})',
                            style: const TextStyle(
                              color: Color(0xFFFFEB3B),
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        I18n.tr('save_record_sub'),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
                ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Finite confetti cannons from both bottom corners for a new record.
/// Runs once and stops, so it never blocks page settling.
class _RecordConfetti extends StatefulWidget {
  const _RecordConfetti();

  @override
  State<_RecordConfetti> createState() => _RecordConfettiState();
}

class _RecordConfettiState extends State<_RecordConfetti> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2300))..forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return CustomPaint(
          painter: _RecordConfettiPainter(_ctrl.value),
          size: Size.infinite,
        );
      },
    );
  }
}

class _RecordConfettiPainter extends CustomPainter {
  final double t;
  _RecordConfettiPainter(this.t);

  static const _colors = [
    Color(0xFFFFD600),
    Color(0xFF00E5FF),
    Color(0xFFFF4081),
    Color(0xFF69F0AE),
    Color(0xFFFF9100),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (t >= 1.0) return;
    final paint = Paint()..style = PaintingStyle.fill;
    for (int i = 0; i < 36; i++) {
      final fromLeft = i.isEven;
      final seed = (i * 37 % 100) / 100.0;
      final seed2 = (i * 53 % 100) / 100.0;
      final originX = fromLeft ? 12.0 : size.width - 12.0;
      final dir = fromLeft ? 1.0 : -1.0;
      final vx = dir * (50.0 + seed * 130.0);
      final vy = -(260.0 + seed2 * 220.0);
      final elapsed = t * 2.3;
      final x = originX + vx * elapsed;
      final y = size.height - 10 + vy * elapsed + 340.0 * elapsed * elapsed;
      if (y > size.height + 12 || y < -12) continue;
      paint.color = _colors[i % _colors.length].withValues(alpha: (1.0 - t * 0.7).clamp(0.0, 1.0));
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(seed * 6.28 + t * (4.0 + seed * 6.0));
      canvas.drawRect(const Rect.fromLTWH(-3.4, -2.0, 6.8, 4.0), paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _RecordConfettiPainter oldDelegate) => oldDelegate.t != t;
}

class _EndGameDiceMultiplierCard extends StatefulWidget {
  final GameController controller;

  const _EndGameDiceMultiplierCard({required this.controller});

  @override
  State<_EndGameDiceMultiplierCard> createState() => _EndGameDiceMultiplierCardState();
}

class _EndGameDiceMultiplierCardState extends State<_EndGameDiceMultiplierCard> {
  static const List<String> _diceGlyphs = ['', '', '', '', '', ''];
  bool _isRolling = false;
  int _previewFace = 6;
  Timer? _rollTimer;

  @override
  void dispose() {
    _rollTimer?.cancel();
    super.dispose();
  }

  void _startDiceRollSequence() {
    if (_isRolling || widget.controller.hasClaimedVictoryBonus) return;
    setState(() {
      _isRolling = true;
    });

    final rand = Random();
    int ticks = 0;
    _rollTimer = Timer.periodic(const Duration(milliseconds: 95), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      ticks++;
      if (ticks < 10) {
        setState(() {
          _previewFace = 1 + rand.nextInt(6);
        });
        AudioManager.instance.playSfx(GameSfx.hitBrick);
      } else {
        timer.cancel();
        widget.controller.rollEndGameGoldDice();
        if (mounted) {
          setState(() {
            _isRolling = false;
          });
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    // In Chaos mode, gold multiplier feature is disabled per request
    if (c.isChaosMode) {
      return const SizedBox.shrink();
    }
    final adManager = AdManager.instance;
    final isAdBusy = adManager.isShowing;

    if (c.hasClaimedVictoryBonus) {
      final rolled = c.endGameRolledDice.clamp(1, 6);
      final glyph = _diceGlyphs[rolled - 1];
      final mult = c.endGameMultiplier > 0 ? c.endGameMultiplier : 3;
      final bonus = c.endGameBonusGoldAdded > 0 ? c.endGameBonusGoldAdded : 200;

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1B5E20), Color(0xFF0D3312)],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFF69F0AE), width: 1.5),
          boxShadow: const [
            BoxShadow(color: Color(0x4400E676), blurRadius: 12),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(glyph, style: const TextStyle(fontSize: 24, color: Color(0xFFFFD54F))),
            const SizedBox(width: 8),
            Flexible(
              child: Text( 'ZAR $rolled GELDİ  ${mult}X ALTIN (+$bonus  EKLENDİ!)',
                style: const TextStyle(
                  color: Color(0xFFB9F6CA),
                  fontWeight: FontWeight.w900,
                  fontSize: 11.5,
                  letterSpacing: 0.3,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      );
    }

    final baseGold = c.endGameMultiplierBaseGold;
    final gold2x = baseGold * 2;
    final gold3x = baseGold * 3;

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFB300), Color(0xFFFF8F00), Color(0xFFE65100)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFFFF9C4), width: 1.8),
        boxShadow: const [
          BoxShadow(
            color: Color(0x77FF8F00),
            blurRadius: 18,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: (isAdBusy || _isRolling)
              ? null
              : () {
                  adManager.watchHighYieldAd(
                    context,
                    onSuccess: _startDiceRollSequence,
                    onDismissedEarly: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              const Icon(Icons.info_outline, color: Color(0xFFFFD54F), size: 22),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  I18n.tr('watch_ad_for_victory_hint'),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          backgroundColor: const Color(0xFF1E2438),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: const BorderSide(color: Color(0xFFFFD54F), width: 1),
                          ),
                          duration: const Duration(seconds: 3),
                        ),
                      );
                    },
                  );
                },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Tag Banner
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0x44000000),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.casino_rounded, color: Color(0xFFFFEB3B), size: 13),
                      SizedBox(width: 4),
                      Text( 'ŞANS ZARINI AT: 2X VEYA 3X ALTIN!',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 9.5,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                if (_isRolling)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _diceGlyphs[_previewFace - 1],
                        style: const TextStyle(fontSize: 28, color: Colors.white),
                      ),
                      const SizedBox(width: 10),
                      const Text( ' ZAR ATILIYOR...',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  )
                else if (isAdBusy)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        I18n.tr('ad_preparing'),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14),
                      ),
                    ],
                  )
                else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFFD54F).withValues(alpha: 0.6),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.casino, color: Color(0xFFE65100), size: 20),
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text( '$baseGold ',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.85),
                                    fontWeight: FontWeight.w800,
                                    fontSize: 11.5,
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                                Flexible(
                                  child: Text( ' $gold2x - $gold3x ',
                                    style: const TextStyle(
                                      color: Color(0xFFFFFDE7),
                                      fontWeight: FontWeight.w900,
                                      fontSize: 14,
                                      shadows: [
                                        Shadow(color: Colors.black45, blurRadius: 4, offset: Offset(0, 1)),
                                      ],
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            const Text( 'Reklam İzle & Zar At (1-3: 2X | 4-6: 3X)',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 10.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

