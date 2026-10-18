import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../engine/audio_manager.dart';
import '../engine/i18n.dart';
import '../storage/save_manager.dart';
import 'kaunos_ui.dart';

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
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white70),
                onPressed: () => Navigator.of(context).pop(),
                visualDensity: VisualDensity.compact,
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

                  const SizedBox(height: 16),

                  // SFX Volume
                  Text(
                    '${I18n.tr('sfx')}: ${save.sfxVolume}',
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

                  const SizedBox(height: 8),

                  // Music / BGM Volume
                  Text(
                    '${I18n.tr('music_bgm')}: ${save.bgmVolume == 0 ? I18n.tr('haptic_off') : save.bgmVolume}',
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

                  const SizedBox(height: 16),

                  // Metrics info
                  Text(
                    I18n.tr('metrics_title'),
                    style: const TextStyle(
                      color: Color(0xFFFFD54F),
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${I18n.tr('metric_sessions')}: ${save.metricSessions}\n'
                    '${I18n.tr('metric_day2')}: ${save.metricDay2 ? I18n.tr('metric_yes') : I18n.tr('metric_no')}\n'
                    '${I18n.tr('metric_leave')}: ${save.metricLevel1Leaves}\n'
                    '${I18n.tr('metric_ad')}: ${save.metricAdCloses}\n'
                    '${I18n.tr('metric_best')}: ${save.metricHighestClassicLevel}\n'
                    '${I18n.tr('metric_last')}: ${save.playEvents.isEmpty ? '-' : save.playEvents.last}',
                    style: const TextStyle(color: Colors.white60, fontSize: 12, height: 1.45),
                  ),

                  const SizedBox(height: 14),

                  // Progress Backup & Export/Import Section
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0x22FFFFFF),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: KaunosPalette.crystalBorderStarlight),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.cloud_sync_rounded, color: KaunosPalette.goldHighlight, size: 16),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                I18n.tr('progress_code').toUpperCase(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: KaunosPalette.goldHighlight,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${I18n.tr('progress_code')}: ${save.progressCode}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontFamily: 'monospace',
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Builder(
                          builder: (context) {
                            final isCompact = MediaQuery.sizeOf(context).width < 360;
                            final copyButton = ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1E2842),
                                foregroundColor: const Color(0xFFFFD54F),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                              ),
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: save.progressCode));
                                final messenger = ScaffoldMessenger.of(context);
                                messenger.hideCurrentSnackBar();
                                messenger.showSnackBar(
                                  const SnackBar(
                                    content: Text('İlerleme kodu kopyalandı!'),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.copy_rounded, size: 16),
                              label: Text(
                                I18n.tr('progress_copy'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            );

                            final pasteButton = ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1E2842),
                                foregroundColor: const Color(0xFFFFD54F),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                              ),
                              onPressed: () async {
                                final data = await Clipboard.getData(Clipboard.kTextPlain);
                                final applied = await save.applyProgressCode(data?.text ?? '');
                                if (!context.mounted) return;
                                final messenger = ScaffoldMessenger.of(context);
                                messenger.hideCurrentSnackBar();
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(applied
                                        ? I18n.tr('progress_restored')
                                        : I18n.tr('progress_invalid')),
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.paste_rounded, size: 16),
                              label: Text(
                                I18n.tr('progress_paste'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            );

                            if (isCompact) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  copyButton,
                                  const SizedBox(height: 8),
                                  pasteButton,
                                ],
                              );
                            }

                            return Row(
                              children: [
                                Expanded(child: copyButton),
                                const SizedBox(width: 8),
                                Expanded(child: pasteButton),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
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
