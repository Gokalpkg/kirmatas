import 'dart:async';
import 'package:flutter/material.dart';
import '../engine/ad_manager.dart';
import '../engine/audio_manager.dart';
import '../engine/game_controller.dart';
import '../engine/i18n.dart';
import '../models/game_state.dart';
import '../storage/save_manager.dart';
import 'aquarium_view.dart';
import 'eco_tank_background.dart';
import 'game_canvas.dart';
import 'hud_overlay.dart';
import 'pause_game_over.dart';
import 'fortune_wheel_dialog.dart';
import 'daily_login_dialog.dart';
import 'daily_quests_dialog.dart';
import 'shop_view.dart';
import 'upgrades_view.dart';

class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({super.key});

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen> {
  final SaveManager _save = SaveManager.instance;
  GameController? _activeGame;
  Timer? _cooldownRefreshTimer;

  static bool _hasAutoShownWheelThisSession = false;
  final GlobalKey _wheelButtonKey = GlobalKey();
  bool _highlightWheelButton = false;
  bool _showArcadeModes = false;

  @override
  void initState() {
    super.initState();
    _cooldownRefreshTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _activeGame == null && AdManager.instance.remainingCooldownSeconds > 0) {
        setState(() {});
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_hasAutoShownWheelThisSession && mounted) {
        _hasAutoShownWheelThisSession = true;
        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted && _activeGame == null) {
            _openFortuneWheelWithHero();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _cooldownRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _openFortuneWheelWithHero() async {
    final renderBox = _wheelButtonKey.currentContext?.findRenderObject() as RenderBox?;
    final screenSize = MediaQuery.of(context).size;
    final targetCenter = renderBox != null && renderBox.hasSize
        ? renderBox.localToGlobal(renderBox.size.center(Offset.zero))
        : Offset(screenSize.width / 2, 140);
    final screenCenter = Offset(screenSize.width / 2, screenSize.height / 2);

    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'FortuneWheel',
      barrierColor: Colors.black.withValues(alpha: 0.75),
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return const FortuneWheelDialog();
      },
      transitionBuilder: (dialogContext, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
          reverseCurve: Curves.easeInOutCubic,
        );

        final t = curved.value;
        final dx = (targetCenter.dx - screenCenter.dx) * (1.0 - t);
        final dy = (targetCenter.dy - screenCenter.dy) * (1.0 - t);
        final scale = 0.05 + 0.95 * t.clamp(0.0, 1.2);

        return Transform.translate(
          offset: Offset(dx, dy),
          child: Transform.scale(
            scale: scale,
            child: Opacity(
              opacity: animation.value.clamp(0.0, 1.0),
              child: child,
            ),
          ),
        );
      },
    );

    if (mounted) {
      setState(() => _highlightWheelButton = true);
      Future.delayed(const Duration(milliseconds: 900), () {
        if (mounted) setState(() => _highlightWheelButton = false);
      });
    }
  }

  void _startOrPromptResume(GameMode mode) {
    if ((mode == GameMode.classic || mode == GameMode.chaos) && _save.hasSavedGame(mode)) {
      _showContinueDialog(mode);
    } else {
      _launchGame(mode, isResume: false);
    }
  }

  void _launchGame(GameMode mode, {bool isResume = false}) {
    AudioManager.instance.isBgmAllowed = false;
    AudioManager.instance.pauseBgm();
    setState(() {
      _activeGame = GameController()..startNewGame(mode, isResume: isResume);
    });
  }

  void _showContinueDialog(GameMode mode) {
    final isClassic = mode == GameMode.classic;
    final level = isClassic ? (_save.classicSavedLevel ?? 1) : (_save.chaosSavedLevel ?? 1);
    final score = isClassic ? (_save.classicSavedScore ?? 0) : (_save.chaosSavedScore ?? 0);
    final extraStat = isClassic
        ? '${_save.classicSavedLives ?? 3} ️' : '${_save.chaosSavedStock ?? 3}  Top';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xF0101320),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: Color(0x3300E5FF), width: 1.5),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0x2200E5FF),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0x6600E5FF)),
                ),
                child: Icon(
                  isClassic ? Icons.play_arrow_rounded : Icons.flash_on_rounded,
                  color: const Color(0xFF00E5FF),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isClassic ? 'KLASİK OYUN' : 'KAOS MODU',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0x3300E5FF), Color(0x1100E5FF)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0x4400E5FF)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.bookmark_added_rounded, color: Color(0xFF00E5FF), size: 18),
                    SizedBox(width: 8),
                    Text( 'KAYITLI OYUNUN BULUNDU',
                      style: TextStyle(
                        color: Color(0xFF00E5FF),
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF161A28),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white10),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          children: [
                            const Text('BÖLÜM', style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text('$level', style: const TextStyle(color: Color(0xFFFFD54F), fontSize: 18, fontWeight: FontWeight.w900)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          children: [
                            const Text('SKOR', style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text('$score', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          children: [
                            Text(isClassic ? 'CAN' : 'TOP', style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text(extraStat, style: const TextStyle(color: Color(0xFF69F0AE), fontSize: 16, fontWeight: FontWeight.w900)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Option 1: DEVAM ET (Glowing Primary Button)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _launchGame(mode, isResume: true);
                  },
                  icon: const Icon(Icons.play_arrow_rounded, color: Colors.black, size: 22),
                  label: const Text( 'DEVAM ET',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                      letterSpacing: 1.0,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00E5FF),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 6,
                    shadowColor: const Color(0x6600E5FF),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // Option 2: YENİDEN BAŞLA (Secondary Outline Button)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _launchGame(mode, isResume: false);
                  },
                  icon: const Icon(Icons.refresh_rounded, color: Colors.white70, size: 20),
                  label: const Text( 'YENİDEN BAŞLA',
                    style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      letterSpacing: 0.8,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _exitGameToMenu() {
    if (_activeGame != null && (_activeGame!.status == GameStatus.playing || _activeGame!.status == GameStatus.ready)) {
      if (_activeGame!.currentMode == GameMode.classic && _activeGame!.stats.level <= 1) {
        _save.noteLevel1Left();
      }
      if (_activeGame!.currentMode == GameMode.classic) {
        _save.saveClassicSession(
          level: _activeGame!.stats.level,
          score: _activeGame!.stats.score,
          lives: _activeGame!.stats.lives,
        );
      } else if (_activeGame!.currentMode == GameMode.chaos) {
        _save.saveChaosSession(
          level: _activeGame!.stats.level,
          score: _activeGame!.stats.score,
          stock: _activeGame!.chaosStock,
        );
      }
    }

    AudioManager.instance.isBgmAllowed = true;
    if (AudioManager.instance.appInForeground) {
      AudioManager.instance.resumeBgm();
    }
    setState(() {
      _activeGame = null;
    });
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return ListenableBuilder(
          listenable: _save,
          builder: (context, _) {
            return AlertDialog(
              backgroundColor: const Color(0xF0101320),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: const BorderSide(color: Colors.white12),
              ),
              title: Text(
                I18n.tr('settings').toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.0,
                ),
              ),
              content: SingleChildScrollView(
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
                          value: _save.language,
                          isExpanded: true,
                          dropdownColor: const Color(0xFF161A29),
                          icon: const Icon(Icons.language, color: Color(0xFFFFD54F)),
                          items: I18n.supportedLanguages.map((lang) {
                            return DropdownMenuItem<String>(
                              value: lang.code,
                              child: Row(
                                children: [
                                  Text(
                                    lang.nativeLabel,
                                    style: TextStyle(
                                      color: _save.language == lang.code
                                          ? const Color(0xFFFFD54F)
                                          : Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text( '(${lang.label})',
                                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (newLang) {
                            if (newLang != null) {
                              _save.setLanguage(newLang);
                            }
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    const SizedBox(height: 16),

                    Text( '${I18n.tr('sfx')}: ${_save.sfxVolume}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Slider(
                      value: _save.sfxVolume.toDouble(),
                      min: 0,
                      max: 8,
                      divisions: 8,
                      activeColor: const Color(0xFFFFD54F),
                      onChanged: (val) {
                        _save.setSfxVolume(val.toInt());
                        AudioManager.instance.playSfx(GameSfx.hitBrick);
                      },
                    ),

                    const SizedBox(height: 8),

                    Text( '${I18n.tr('music_bgm')}: ${_save.bgmVolume}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Slider(
                      value: _save.bgmVolume.toDouble(),
                      min: 0,
                      max: 8,
                      divisions: 8,
                      activeColor: const Color(0xFFFFD54F),
                      onChanged: (val) {
                        _save.setBgmVolume(val.toInt());
                        AudioManager.instance.updateBgmVolume();
                      },
                    ),

                    const SizedBox(height: 8),

                    Text( '${I18n.tr('haptics')}: ${_save.vibrationLevel == 0 ? I18n.tr('off') : _save.vibrationLevel}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Slider(
                      value: _save.vibrationLevel.toDouble(),
                      min: 0,
                      max: 8,
                      divisions: 8,
                      activeColor: const Color(0xFFFFD54F),
                      onChanged: (val) {
                        _save.setVibrationLevel(val.toInt());
                        AudioManager.instance.playSfx(GameSfx.hitBrick);
                      },
                    ),

                    const SizedBox(height: 12),

                    // Game Speed Setting
                    Text(
                      I18n.tr('speed'),
                      style: const TextStyle(
                        color: Color(0xFFFFD54F),
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: SpeedSetting.values.map((s) {
                        final isSelected = _save.speed == s;
                        String label = s.label;
                        if (s == SpeedSetting.slow) label = I18n.tr('slow');
                        if (s == SpeedSetting.medium) label = I18n.tr('normal');
                        if (s == SpeedSetting.fast) label = I18n.tr('fast');

                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: OutlinedButton(
                              onPressed: () => _save.setSpeed(s),
                              style: OutlinedButton.styleFrom(
                                backgroundColor: isSelected ? const Color(0x33FFD54F) : Colors.transparent,
                                side: BorderSide(
                                  color: isSelected ? const Color(0xFFFFD54F) : Colors.white12,
                                ),
                                foregroundColor: isSelected ? const Color(0xFFFFD54F) : Colors.white60,
                                padding: const EdgeInsets.symmetric(vertical: 0),
                                minimumSize: const Size(0, 36),
                              ),
                              child: Text(
                                label,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 18),
                    Text(
                      I18n.tr('metrics_title'),
                      style: const TextStyle(
                        color: Color(0xFFFFD54F),
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text( '${I18n.tr('metric_sessions')}: ${_save.metricSessions}\n' '${I18n.tr('metric_day2')}: ${_save.metricDay2 ? I18n.tr('metric_yes') : I18n.tr('metric_no')}\n' '${I18n.tr('metric_leave')}: ${_save.metricLevel1Leaves}\n' '${I18n.tr('metric_ad')}: ${_save.metricAdCloses}',
                      style: const TextStyle(color: Colors.white60, fontSize: 12, height: 1.45),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    I18n.tr('close'),
                    style: const TextStyle(color: Color(0xFFFFD54F), fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_activeGame != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Positioned.fill(
              child: RepaintBoundary(
                child: GameCanvas(controller: _activeGame!),
              ),
            ),
            RepaintBoundary(
              child: HudOverlay(
                controller: _activeGame!,
                onPause: () => _activeGame!.pause(),
              ),
            ),
            RepaintBoundary(
              child: PauseGameOverOverlay(
                controller: _activeGame!,
                onResume: () => _activeGame!.resume(),
                onRestart: () {
                  final wasGameOverOrVictory = _activeGame!.status == GameStatus.gameOver || _activeGame!.status == GameStatus.victory;
                  final mode = _activeGame!.currentMode;
                  if (wasGameOverOrVictory) {
                    AdManager.instance.checkAndShowInterstitial(context, onComplete: () {
                      if (mounted && _activeGame != null) {
                        _activeGame!.startNewGame(mode);
                      }
                    });
                  } else {
                    _activeGame!.startNewGame(mode);
                  }
                },
                onMainMenu: () {
                  final wasGameOverOrVictory = _activeGame!.status == GameStatus.gameOver || _activeGame!.status == GameStatus.victory;
                  if (wasGameOverOrVictory) {
                    AdManager.instance.checkAndShowInterstitial(context, onComplete: () {
                      if (mounted) _exitGameToMenu();
                    });
                  } else {
                    _exitGameToMenu();
                  }
                },
              ),
            ),
          ],
        ),
      );
    }

    return ListenableBuilder(
      listenable: _save,
      builder: (context, _) {
        return Scaffold(
          body: EcoTankBackground(
            child: SafeArea(
              child: Column(
                children: [
                  // Top Header Bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.settings, color: Colors.white70),
                          style: IconButton.styleFrom(
                            backgroundColor: const Color(0x40000000),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: const BorderSide(color: Colors.white12),
                            ),
                          ),
                          onPressed: _showSettingsDialog,
                        ),
                        GestureDetector(
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const ShopView()),
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0x80101320),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0x4DFFD54F)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.monetization_on, color: Color(0xFFFFD54F), size: 18),
                                const SizedBox(width: 6),
                                Text( '${_save.gold}',
                                  style: const TextStyle(
                                    color: Color(0xFFFFD54F),
                                    fontWeight: FontWeight.w900,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.add_circle, color: Color(0xFFFFD54F), size: 14),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Brand Title (Clean, no subtitle)
                  Text( 'KIRMATAS',
                    style: TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3.0,
                      foreground: Paint()
                        ..shader = const LinearGradient(
                          colors: [Color(0xFFFFF6D8), Color(0xFFF5D27A), Color(0xFFE8A23A)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ).createShader(const Rect.fromLTWH(0, 0, 200, 50)),
                      shadows: const [
                        Shadow(color: Color(0x66E88C28), blurRadius: 20, offset: Offset(0, 4)),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),
                  _buildTopRewardsBar(),
                  const SizedBox(height: 12),

                  // Main Modes Section (Hero Classic + Chaos Card + Collapsible Extra Arcade Modes)
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: Column(
                        children: [
                          // HERO CLASSIC CARD
                          _buildClassicHeroCard(),

                          const SizedBox(height: 12),

                          _buildChaosHeroCard(),

                          const SizedBox(height: 12),

                          // COLLAPSIBLE EXTRA ARCADE MODES BUTTON & DRAWER
                          InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () {
                              setState(() {
                                _showArcadeModes = !_showArcadeModes;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0x33101320),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.white12),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    _showArcadeModes ? Icons.grid_view_rounded : Icons.sports_esports_rounded,
                                    color: const Color(0xFFFFD54F),
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _showArcadeModes ? I18n.tr('other_modes_hide') : I18n.tr('other_modes_show'),
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Icon(
                                    _showArcadeModes ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                                    color: Colors.white54,
                                    size: 18,
                                  ),
                                ],
                              ),
                            ),
                          ),

                          if (_showArcadeModes) ...[
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildArcadeMiniCard(
                                    mode: GameMode.zen,
                                    title: I18n.tr('zen'),
                                    desc: I18n.tr('zen_desc'),
                                    icon: Icons.spa,
                                    color1: const Color(0xFF00B4D8),
                                    color2: const Color(0xFF0077B6),
                                    onTap: () => _launchGame(GameMode.zen),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _buildArcadeMiniCard(
                                    mode: GameMode.descend,
                                    title: I18n.tr('descend'),
                                    desc: I18n.tr('descend_desc'),
                                    icon: Icons.keyboard_double_arrow_down,
                                    color1: const Color(0xFF9D4EDD),
                                    color2: const Color(0xFFC77DFF),
                                    onTap: () => _launchGame(GameMode.descend),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            _buildArcadeMiniCard(
                              mode: GameMode.shapes,
                              title: I18n.tr('shapes'),
                              desc: I18n.tr('shapes_desc'),
                              icon: Icons.palette,
                              color1: const Color(0xFFD4A373),
                              color2: const Color(0xFFA98467),
                              onTap: () => _launchGame(GameMode.shapes),
                            ),
                          ],

                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  ),

                  // Bottom Floating Navigation Dock
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xDD101320),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white12),
                      boxShadow: const [
                        BoxShadow(color: Colors.black54, blurRadius: 16, offset: Offset(0, 4)),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildNavButton(
                          icon: Icons.storefront,
                          label: I18n.tr('shop'),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const ShopView()),
                          ),
                        ),
                        _buildNavButton(
                          icon: Icons.water,
                          label: I18n.tr('aquarium'),
                          badge: _save.currentAvailableFishGold > 0 ? '' : null,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const AquariumView()),
                          ),
                        ),
                        _buildNavButton(
                          icon: Icons.assignment_turned_in,
                          label: I18n.tr('quests'),
                          badge: ((_save.questFishFed && !_save.claimedQuests.contains('feed_fish')) ||
                                  (_save.questBricksBroken >= 100 && !_save.claimedQuests.contains('break_bricks')) ||
                                  (_save.questAdOrWinDone && !_save.claimedQuests.contains('ad_or_win'))) ? '!' : null,
                          onTap: () => DailyQuestsDialog.show(
                            context,
                            onPlayToday: () => _launchGame(GameMode.daily),
                          ),
                        ),
                        _buildNavButton(
                          icon: Icons.auto_awesome,
                          label: I18n.tr('upgrades'),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const UpgradesView()),
                          ),
                        ),
                      ],
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

  Widget _buildTopRewardsBar() {
    final canClaimDaily = _save.canClaimDailyLogin();
    final canClaimAd = _save.canClaimDailyLoginAd();
    final hasAnyClaim = canClaimDaily || canClaimAd;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0x66101320),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          children: [
            // 1. 7 GÜNLÜK GİRİŞ (Compact Pill)
            Expanded(
              child: _buildFancyRewardButton(
                gradientColors: [const Color(0xFF261A08), const Color(0xFF161004)],
                borderColor: hasAnyClaim ? const Color(0xFFFFD54F) : Colors.white12,
                glowColor: const Color(0xFFFFA000),
                isGlowing: hasAnyClaim,
                iconGradient: const [Color(0xFFFFD54F), Color(0xFFFF8F00)],
                icon: Icons.calendar_month_rounded,
                iconColor: const Color(0xFF261500),
                title: 'GİRİŞ',
                titleColor: const Color(0xFFFFE082),
                subtitle: '${_save.currentDailyLoginDay}. Gün',
                subColor: const Color(0xFFFFB300),
                badgeText: canClaimDaily ? 'AL!' : (canClaimAd ? '2X' : null),
                badgeGradient: const [Color(0xFFFF5252), Color(0xFFFF1744)],
                onTap: () => DailyLoginDialog.show(context),
              ),
            ),
            const SizedBox(width: 6),

            // 2. ŞANS ÇARKI (Compact Pill)
            Expanded(
              child: KeyedSubtree(
                key: _wheelButtonKey,
                child: ListenableBuilder(
                  listenable: _save,
                  builder: (context, _) {
                    final spinsLeft = _save.remainingWheelSpins;
                    final hasSpins = spinsLeft > 0;

                    return _buildFancyRewardButton(
                      gradientColors: hasSpins
                          ? const [Color(0xFF0B2135), Color(0xFF160A29)]
                          : const [Color(0xFF141724), Color(0xFF1A1D2B)],
                      borderColor: _highlightWheelButton
                          ? const Color(0xFFFFFF00)
                          : (hasSpins ? const Color(0xFF00E5FF) : Colors.white12),
                      glowColor: _highlightWheelButton
                          ? const Color(0xFFFFD700)
                          : const Color(0xFF00E5FF),
                      isGlowing: hasSpins || _highlightWheelButton,
                      iconGradient: hasSpins
                          ? const [Color(0xFF00E5FF), Color(0xFFD500F9)]
                          : const [Color(0xFF455A64), Color(0xFF263238)],
                      icon: Icons.motion_photos_on_rounded,
                      iconColor: hasSpins ? Colors.white : Colors.white54,
                      title: 'ÇARK',
                      titleColor: hasSpins ? const Color(0xFF80D8FF) : Colors.white60,
                      subtitle: hasSpins ? '$spinsLeft/3' : 'Bitti',
                      subColor: hasSpins ? const Color(0xFF00E5FF) : Colors.white38,
                      badgeText: hasSpins ? '$spinsLeft' : null,
                      badgeGradient: hasSpins
                          ? const [Color(0xFF00E5FF), Color(0xFF7C4DFF)]
                          : null,
                      onTap: _openFortuneWheelWithHero,
                    );
                  },
                ),
              ),
            ),
            const SizedBox(width: 6),

            // 3. ÜCRETSİZ HEDİYE (Compact Pill)
            Expanded(
              child: ListenableBuilder(
                listenable: AdManager.instance,
                builder: (context, _) {
                  final cooldown = AdManager.instance.remainingCooldownSeconds;
                  final onCooldown = cooldown > 0;
                  final isLoading = AdManager.instance.isLoading || AdManager.instance.isShowing;
                  final isReady = !onCooldown && !isLoading;

                  String sub;
                  if (isLoading) {
                    sub = '...';
                  } else if (onCooldown) {
                    final m = cooldown ~/ 60;
                    final s = cooldown % 60;
                    sub = '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
                  } else {
                    sub = '+100';
                  }

                  return _buildFancyRewardButton(
                    gradientColors: [const Color(0xFF082B1C), const Color(0xFF061A1D)],
                    borderColor: isReady ? const Color(0xFF00E676) : Colors.white12,
                    glowColor: const Color(0xFF00E676),
                    isGlowing: isReady,
                    iconGradient: const [Color(0xFF69F0AE), Color(0xFF00B0FF)],
                    icon: Icons.card_giftcard_rounded,
                    iconColor: const Color(0xFF00331A),
                    title: 'HEDİYE',
                    titleColor: const Color(0xFFA7FFEB),
                    subtitle: sub,
                    subColor: const Color(0xFF69F0AE),
                    badgeText: isReady ? '+100' : null,
                    badgeGradient: isReady
                        ? const [Color(0xFF00E676), Color(0xFF00C853)]
                        : null,
                    onTap: () {
                      if (isReady) {
                        AdManager.instance.watchAdForGold(
                          context,
                          onSuccess: (reward) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(' +$reward Altın Hesabınıza Eklendi!'),
                                backgroundColor: const Color(0xFF161A29),
                              ),
                            );
                          },
                          onDismissedEarly: () {},
                        );
                      } else if (onCooldown) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Yeni hediye için kalan süre: $sub'),
                            backgroundColor: const Color(0xFF161A29),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFancyRewardButton({
    required List<Color> gradientColors,
    required Color borderColor,
    required Color glowColor,
    required bool isGlowing,
    required List<Color> iconGradient,
    required IconData icon,
    required Color iconColor,
    required String title,
    required Color titleColor,
    required String subtitle,
    required Color subColor,
    String? badgeText,
    List<Color>? badgeGradient,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: isGlowing ? 1.5 : 1.0),
            boxShadow: isGlowing
                ? [
                    BoxShadow(
                      color: glowColor.withValues(alpha: 0.4),
                      blurRadius: 10,
                      spreadRadius: 1,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: iconGradient,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: iconGradient.first.withValues(alpha: 0.6),
                          blurRadius: 6,
                          offset: const Offset(0, 1),
                        ),
                      ],
                      border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 1.2),
                    ),
                    child: Center(
                      child: Icon(icon, color: iconColor, size: 17),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            color: titleColor,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.4,
                            shadows: [
                              Shadow(
                                color: Colors.black.withValues(alpha: 0.8),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 1),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: subColor,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (badgeText != null)
                Positioned(
                  top: -8,
                  right: -3,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      gradient: badgeGradient != null
                          ? LinearGradient(colors: badgeGradient)
                          : null,
                      color: badgeGradient == null ? Colors.orange : null,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.9), width: 0.8),
                      boxShadow: [
                        BoxShadow(
                          color: (badgeGradient?.first ?? Colors.black).withValues(alpha: 0.6),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Text(
                      badgeText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildClassicHeroCard() {
    final best = _save.getHighScore(GameMode.classic);

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF5722), Color(0xFFFF9800), Color(0xFFFFB74D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(color: Color(0x66FF5722), blurRadius: 18, offset: Offset(0, 6)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () => _startOrPromptResume(GameMode.classic),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black26,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              I18n.tr('classic_desc'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (_save.hasSavedGame(GameMode.classic))
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xDD00E5FF),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text( 'BÖLÜM ${_save.classicSavedLevel} ',
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        I18n.tr('classic').toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                        ),
                      ),
                      if (best > 0) ...[
                        const SizedBox(height: 4),
                        Text( '${I18n.tr('high_score')}: $best',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  width: 58,
                  height: 58,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4)),
                    ],
                  ),
                  child: const Icon(Icons.play_arrow_rounded, color: Color(0xFFFF5722), size: 40),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChaosHeroCard() {
    final best = _save.getHighScore(GameMode.chaos);

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFD50000), Color(0xFFFF3D00), Color(0xFFFF6E40)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(color: Color(0x66FF1744), blurRadius: 18, offset: Offset(0, 6)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () => _startOrPromptResume(GameMode.chaos),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black26,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              I18n.tr('chaos_desc'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (_save.hasSavedGame(GameMode.chaos))
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xDDFFD54F),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text( 'BÖLÜM ${_save.chaosSavedLevel} ',
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Text(
                            I18n.tr('chaos').toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.flash_on_rounded, color: Color(0xFFFFD54F), size: 24),
                        ],
                      ),
                      if (best > 0) ...[
                        const SizedBox(height: 4),
                        Text( '${I18n.tr('high_score')}: $best',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  width: 58,
                  height: 58,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4)),
                    ],
                  ),
                  child: const Icon(Icons.bolt_rounded, color: Color(0xFFD50000), size: 38),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildArcadeMiniCard({
    required GameMode mode,
    required String title,
    required String desc,
    required IconData icon,
    required Color color1,
    required Color color2,
    required VoidCallback onTap,
  }) {
    final best = _save.getHighScore(mode);

    return Container(
      height: 115,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color1.withValues(alpha: 0.9), color2.withValues(alpha: 0.9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: color1.withValues(alpha: 0.25), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Colors.black26,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: Colors.white, size: 20),
                    ),
                    if (best > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text( '$best',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      desc,
                      style: const TextStyle(color: Colors.white70, fontSize: 10),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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

  Widget _buildNavButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    String? badge,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(icon, color: const Color(0xFFFFD54F), size: 22),
                if (badge != null)
                  Positioned(
                    top: -4,
                    right: -10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE53935),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: const [
                          BoxShadow(color: Colors.black45, blurRadius: 4, offset: Offset(0, 1)),
                        ],
                      ),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 14),
                      child: Center(
                        child: Text(
                          badge,
                          style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

