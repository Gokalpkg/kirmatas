import 'package:flutter/material.dart';
import '../engine/audio_manager.dart';
import '../engine/i18n.dart';
import '../storage/save_manager.dart';
import 'kaunos_ui.dart';
import 'stats_dialog.dart';

/// Dedicated Settings dialog for audio, haptics, language, game tour,
/// and isolated progress code backup/restore.
class SettingsDialog extends StatelessWidget {
  final SaveManager save;
  final VoidCallback? onOpenTour;

  SettingsDialog({
    super.key,
    SaveManager? save,
    this.onOpenTour,
  }) : save = save ?? SaveManager.instance;

  static Future<void> show(
    BuildContext context, {
    VoidCallback? onOpenTour,
    SaveManager? save,
  }) {
    final s = save ?? SaveManager.instance;
    AudioManager.instance.isBgmAllowed = true;
    AudioManager.instance.playDuck = 1.0;
    AudioManager.instance.updateBgmVolume();

    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Settings',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 150),
      pageBuilder: (dialogContext, animation, secondaryAnimation) => SettingsDialog(
        save: s,
        onOpenTour: onOpenTour,
      ),
      transitionBuilder: (ctx, anim, _, child) => FadeTransition(opacity: anim, child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: save,
      builder: (context, _) {
        return AlertDialog(
          backgroundColor: const Color(0xF2101320),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: KaunosPalette.crystalBorderStarlight),
          ),
          contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.settings_rounded, color: KaunosPalette.goldHighlight, size: 22),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        I18n.tr('settings').toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              KaunosCloseButton(
                onTap: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Language Selector
                  Text(
                    I18n.tr('language'),
                    style: const TextStyle(
                      color: Color(0xFFFFD54F),
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color(0x33FFFFFF),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: save.language,
                        isExpanded: true,
                        dropdownColor: const Color(0xFF161A29),
                        icon: const Icon(Icons.language, color: Color(0xFFFFD54F)),
                        items: I18n.supportedLanguages.map((lang) {
                          return DropdownMenuItem<String>(
                            value: lang.code,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  flex: 3,
                                  child: Text(
                                    lang.nativeLabel,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: save.language == lang.code
                                          ? const Color(0xFFFFD54F)
                                          : Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  flex: 2,
                                  child: Text(
                                    '(${lang.label})',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (newLang) {
                          if (newLang != null) {
                            save.setLanguage(newLang);
                          }
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Tour trigger button
                  InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () {
                      Navigator.of(context).pop();
                      onOpenTour?.call();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF261A08), Color(0xFF140D04)],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: KaunosPalette.goldHighlight.withValues(alpha: 0.6),
                          width: 1.2,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x33FFD54F),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.explore_rounded, color: KaunosPalette.goldHighlight, size: 20),
                          SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'OYUN REHBERİ (NASIL OYNANIR)',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: KaunosPalette.goldHighlight,
                                fontFamily: 'Rajdhani',
                                fontWeight: FontWeight.w900,
                                fontSize: 13.0,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Stats + Play Games trigger button
                  InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () {
                      Navigator.of(context).pop();
                      StatsDialog.show(context, save: save);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0D2B1A), Color(0xFF07170E)],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: const Color(0xFF66BB6A).withValues(alpha: 0.7),
                          width: 1.2,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x3343A047),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.bar_chart_rounded, color: Color(0xFFA5D6A7), size: 20),
                          SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'OYUN İSTATİSTİKLERİ',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Color(0xFFA5D6A7),
                                fontFamily: 'Rajdhani',
                                fontWeight: FontWeight.w900,
                                fontSize: 13.0,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // SFX Volume
                  Text(
                    '${I18n.tr('sfx')}: ${save.sfxVolume == 0 ? I18n.tr('off') : save.sfxVolume}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Slider(
                    value: save.sfxVolume.toDouble(),
                    min: 0,
                    max: 8,
                    divisions: 8,
                    activeColor: const Color(0xFFFFD54F),
                    onChanged: (val) {
                      save.setSfxVolume(val.toInt());
                      AudioManager.instance.playSfx(GameSfx.hitBrick);
                    },
                  ),

                  // Sub-mixer for Paddle, Ball, and Bricks
                  if (save.sfxVolume > 0)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12, top: 2),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.sports_tennis_rounded, size: 14, color: Color(0xFF80D8FF)),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Raket Vuruş Sesi: ${save.paddleVolume == 0 ? I18n.tr('off') : save.paddleVolume}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Color(0xFF80D8FF), fontSize: 11.5, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          Slider(
                            value: save.paddleVolume.toDouble(),
                            min: 0,
                            max: 8,
                            divisions: 8,
                            activeColor: const Color(0xFF00E5FF),
                            onChanged: (val) {
                              save.setPaddleVolume(val.toInt());
                              AudioManager.instance.playSfx(GameSfx.hitPaddle);
                            },
                          ),
                          Row(
                            children: [
                              const Icon(Icons.circle_outlined, size: 14, color: Color(0xFFFFD54F)),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Top Sekme Sesi: ${save.ballVolume == 0 ? I18n.tr('off') : save.ballVolume}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Color(0xFFFFD54F), fontSize: 11.5, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          Slider(
                            value: save.ballVolume.toDouble(),
                            min: 0,
                            max: 8,
                            divisions: 8,
                            activeColor: const Color(0xFFFFD54F),
                            onChanged: (val) {
                              save.setBallVolume(val.toInt());
                              AudioManager.instance.playSfx(GameSfx.hitWall);
                            },
                          ),
                          Row(
                            children: [
                              const Icon(Icons.grid_view_rounded, size: 14, color: Color(0xFFFF8A80)),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Blok Kırma Sesi: ${save.brickVolume == 0 ? I18n.tr('off') : save.brickVolume}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Color(0xFFFF8A80), fontSize: 11.5, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          Slider(
                            value: save.brickVolume.toDouble(),
                            min: 0,
                            max: 8,
                            divisions: 8,
                            activeColor: const Color(0xFFFF5252),
                            onChanged: (val) {
                              save.setBrickVolume(val.toInt());
                              AudioManager.instance.playSfx(GameSfx.breakBrick);
                            },
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 8),

                  // Music / BGM Volume
                  Text(
                    '${I18n.tr('music_bgm')}: ${save.bgmVolume == 0 ? I18n.tr('off') : save.bgmVolume}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Slider(
                    value: save.bgmVolume.toDouble(),
                    min: 0,
                    max: 8,
                    divisions: 8,
                    activeColor: const Color(0xFFFFD54F),
                    onChanged: (val) {
                      save.setBgmVolume(val.toInt());
                      AudioManager.instance.updateBgmVolume();
                    },
                  ),

                  const SizedBox(height: 8),

                  // Haptics Level
                  Text(
                    '${I18n.tr('haptics')}: ${save.vibrationLevel == 0 ? I18n.tr('off') : save.vibrationLevel}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Slider(
                    value: save.vibrationLevel.toDouble(),
                    min: 0,
                    max: 8,
                    divisions: 8,
                    activeColor: const Color(0xFFFFD54F),
                    onChanged: (val) {
                      save.setVibrationLevel(val.toInt());
                      AudioManager.instance.playSfx(GameSfx.hitBrick);
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                I18n.tr('close'),
                style: const TextStyle(
                  color: Color(0xFFFFD54F),
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
