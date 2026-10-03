import 'package:flutter/material.dart';
import '../engine/game_controller.dart';
import '../engine/i18n.dart';
import '../models/game_state.dart';
import '../storage/save_manager.dart';
import '../engine/ad_manager.dart';
import '../engine/audio_manager.dart';

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
      child: Center(
        child: Container(
          width: 320,
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.all(24),
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
              const SizedBox(height: 18),

              if (!isPaused) ...[
                // Stats card
                Container(
                  padding: const EdgeInsets.all(16),
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
                          Text(
                            '${stats.score}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(I18n.tr('high_score'), style: const TextStyle(color: Colors.white70)),
                          Text(
                            '$bestScore',
                            style: const TextStyle(
                              color: Color(0xFFFFD54F),
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(I18n.tr('max_combo'), style: const TextStyle(color: Colors.white70)),
                          Text(
                            'x${stats.maxCombo}',
                            style: const TextStyle(
                              color: Color(0xFF00E5FF),
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(I18n.tr('bricks_broken'), style: const TextStyle(color: Colors.white70)),
                          Text(
                            '${stats.bricksBroken}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (isNewRecord) ...[
                  const SizedBox(height: 12),
                  Text(
                    I18n.tr('new_record'),
                    style: const TextStyle(
                      color: Color(0xFFFFD54F),
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
              ],

              if (isPaused)
                ListenableBuilder(
                  listenable: save,
                  builder: (context, _) {
                    return Column(
                      children: [
                        Text(
                          '${I18n.tr('sfx')}: ${save.sfxVolume}',
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
                        Text(
                          'Müzik (BGM): ${save.bgmVolume}',
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
                        Text(
                          '${I18n.tr('haptics')}: ${save.vibrationLevel}',
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
                ElevatedButton.icon(
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
              const SizedBox(height: 10),
              // Revive / Second Chance Ad Button (Only on Game Over and once per game)
              if (isGameOver && !controller.hasUsedRevive) ...[
                _buildReviveButton(context),
                const SizedBox(height: 12),
              ],
              ElevatedButton.icon(
                onPressed: onRestart,
                icon: const Icon(Icons.replay),
                label: Text(I18n.tr('restart')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFD54F),
                  foregroundColor: Colors.black,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
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
            ],
          ),
        ),
      ),
    );
      },
    );
  }

  Widget _buildReviveButton(BuildContext context) {
    final adManager = AdManager.instance;
    final isLoading = adManager.isLoading || adManager.isShowing;

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
                          content: const Row(
                            children: [
                              Icon(Icons.info_outline, color: Color(0xFFFF8A80), size: 22),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Ödülü kazanmak ve yeniden doğmak için reklamı sonuna kadar izlemelisiniz.',
                                  style: TextStyle(
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
                  const Text(
                    'Reklam Hazırlanıyor...',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.favorite, color: Color(0xFFFF1744), size: 16),
                  ),
                  const SizedBox(width: 10),
                  const Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'İKİNCİ ŞANS! (+1 CAN)',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        'Reklam İzle ve Devam Et',
                        style: TextStyle(
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
          ),
        ),
      ),
    );
  }
}

