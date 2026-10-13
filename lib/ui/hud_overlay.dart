import 'package:flutter/material.dart';
import '../engine/audio_manager.dart';
import '../engine/game_controller.dart';
import '../engine/i18n.dart';
import '../models/game_state.dart';
import '../storage/save_manager.dart';
import 'pixel_art.dart';

bool _showFirstShot(GameController controller) {
  return controller.currentMode == GameMode.classic &&
      controller.stats.level <= 1 &&
      !SaveManager.instance.seenFirstShot;
}

class HudOverlay extends StatelessWidget {
  final GameController controller;
  final VoidCallback onPause;

  const HudOverlay({
    super.key,
    required this.controller,
    required this.onPause,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final stats = controller.stats;

        return SafeArea(
          child: Stack(
            children: [
              // Redesigned Top Frosted Glass HUD Bar
              Positioned(
                top: 8,
                left: 12,
                right: 12,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xCC161B30), Color(0xCC0D101E)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0x4D80D8FF)),
                      boxShadow: const [
                        BoxShadow(color: Color(0x66000000), blurRadius: 16, offset: Offset(0, 4)),
                      ],
                    ),
                    child: Row(
                      children: [
                        // Lives Pill
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0x33FF5252),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0x66FF5252)),
                          ),
                          child: Row(
                            children: [
                              const PixelHeart(size: 16),
                              const SizedBox(width: 4),
                              Text(
                                controller.currentMode == GameMode.zen ? '∞' : '${stats.lives}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 8),

                        // Stage / Mode Center Badge
                        Expanded(
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF2E334D), Color(0xFF1B1E30)],
                                ),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0x4DFFD54F)),
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  controller.currentMode == GameMode.classic
                                      ? '${I18n.tr('level').toUpperCase()} ${stats.level}' : controller.currentMode == GameMode.chaos
                                          ? '${I18n.tr('chaos').toUpperCase()} ${stats.level}' : I18n.tr(controller.currentMode.name).toUpperCase(),
                                  style: const TextStyle(
                                    color: Color(0xFFFFD54F),
                                    fontWeight: FontWeight.w900,
                                    fontSize: 13,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(width: 8),

                        // Smooth Rolling Score Counter
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0x2BFFFFFF),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0x22FFFFFF)),
                          ),
                          child: TweenAnimationBuilder<double>(
                            tween: Tween<double>(begin: 0.0, end: stats.score.toDouble()),
                            duration: const Duration(milliseconds: 350),
                            curve: Curves.easeOutCubic,
                            builder: (context, value, _) {
                              return Text(
                                value.round().toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                ),
                              );
                            },
                          ),
                        ),

                        const SizedBox(width: 6),

                        // Pause Button
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(18),
                            onTap: () {
                              AudioManager.instance.triggerHaptic(() async => AudioManager.instance.playSfx(GameSfx.click));
                              onPause();
                            },
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: const Color(0x44FFFFFF),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white24),
                              ),
                              child: const Icon(Icons.pause, color: Colors.white, size: 18),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Boss Health Bar Banner (Appears dynamically when Boss brick is alive)
              if (controller.activeBossBrick != null)
                Positioned(
                  top: 60,
                  left: 24,
                  right: 24,
                  child: IgnorePointer(
                    child: Builder(
                      builder: (context) {
                        final boss = controller.activeBossBrick!;
                        final hpRatio = (boss.hp / boss.maxHp).clamp(0.0, 1.0);
                        final isEnraged = hpRatio <= 0.5;
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xD912081C),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isEnraged ? const Color(0xFFFF1744) : const Color(0xFFFF9100),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: (isEnraged ? const Color(0xFFFF1744) : const Color(0xFFFF9100)).withValues(alpha: 0.35),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    isEnraged ? I18n.tr('boss_enraged_hud') : I18n.tr('boss_title_hud'),
                                    style: TextStyle(
                                      color: isEnraged ? const Color(0xFFFF5252) : const Color(0xFFFFD54F),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                  Text( '${boss.hp} / ${boss.maxHp} HP',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: LinearProgressIndicator(
                                  value: hpRatio,
                                  minHeight: 6,
                                  backgroundColor: Colors.white12,
                                  color: isEnraged ? const Color(0xFFFF1744) : const Color(0xFFFF9100),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),

              // Ready Launch Banner (Doesn't block gestures)
              if (controller.status == GameStatus.ready)
                IgnorePointer(
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      constraints: const BoxConstraints(maxWidth: 320),
                      decoration: BoxDecoration(
                        color: const Color(0xCC090A12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0x66FFD54F)),
                        boxShadow: const [
                          BoxShadow(color: Color(0x33FFD54F), blurRadius: 16),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _showFirstShot(controller)
                                ? I18n.tr('first_shot')
                                : (controller.currentMode == GameMode.chaos
                                    ? I18n.tr('chaos_aim')
                                    : I18n.tr('tap_to_launch')),
                            style: TextStyle(
                              color: const Color(0xFFFFD54F),
                              fontWeight: FontWeight.w900,
                              fontSize: _showFirstShot(controller) ? 14 : 15,
                              letterSpacing: _showFirstShot(controller) ? 0.2 : 1.0,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 3),
                          if (!_showFirstShot(controller))
                            Text(
                            I18n.tr('drag_hint'),
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // Bottom Active PowerUp Chips & Ulti Button
              if (controller.currentMode != GameMode.chaos || controller.activePowerUps.isNotEmpty)
                Positioned(
                  bottom: 12,
                  left: 14,
                  right: 14,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Active Powerups Row
                      Expanded(
                        child: IgnorePointer(
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: controller.activePowerUps.map((p) {
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: p.type.color.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: p.type.color.withValues(alpha: 0.6)),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Image.asset(p.type.assetPath, width: 14, height: 14, fit: BoxFit.contain),
                                        const SizedBox(width: 4),
                                        Text( '${p.timeLeft.toStringAsFixed(2)}s',
                                          style: TextStyle(
                                            color: p.type.color,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    SizedBox(
                                      width: 40,
                                      child: LinearProgressIndicator(
                                        value: p.progress,
                                        color: p.type.color,
                                        backgroundColor: Colors.black26,
                                        minHeight: 2.5,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),

                      // Ulti Button (Classic & Arcade modes only, hidden in Chaos)
                      if (controller.currentMode != GameMode.chaos)
                        GestureDetector(
                          onTap: () => controller.triggerUlti(),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              gradient: stats.ultiCharge >= 100.0
                                  ? const LinearGradient(colors: [Color(0xFF00E5FF), Color(0xFF0091EA)])
                                  : const LinearGradient(colors: [Color(0xFF263238), Color(0xFF1E242B)]),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: stats.ultiCharge >= 100.0
                                    ? const Color(0xFF00E5FF)
                                    : Colors.white12,
                                width: stats.ultiCharge >= 100.0 ? 2 : 1,
                              ),
                              boxShadow: stats.ultiCharge >= 100.0
                                  ? const [BoxShadow(color: Color(0x6600E5FF), blurRadius: 12)]
                                  : null,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.casino,
                                  color: stats.ultiCharge >= 100.0 ? Colors.white : const Color(0xFF00E5FF),
                                  size: 18,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  controller.isDiceRolling
                                      ? I18n.tr('dice_rolling_hud')
                                      : (controller.isDiceActive
                                          ? ' ${controller.diceTotal}X' : (stats.ultiCharge >= 100.0 ? I18n.tr('dice_roll_btn') : '%${stats.ultiCharge.toInt()}')),
                                  style: TextStyle(
                                    color: stats.ultiCharge >= 100.0 ? Colors.white : Colors.white70,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
