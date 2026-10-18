import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../engine/ad_manager.dart';
import '../engine/audio_manager.dart';
import '../engine/game_controller.dart';
import '../engine/i18n.dart';
import '../engine/remove_ads_billing.dart';
import '../models/game_state.dart';
import '../storage/save_manager.dart';
import 'aquarium_view.dart';
import 'eco_tank_background.dart';
import 'game_canvas.dart';
import 'hud_overlay.dart';
import 'pause_game_over.dart';
import 'fortune_wheel_dialog.dart';
import 'daily_quests_dialog.dart';
import 'daily_login_dialog.dart';
import 'shop_view.dart';
import 'upgrades_view.dart';
import 'sector_map_view.dart';
import 'pixel_art.dart';
import 'tournament_dialog.dart';
import 'kaunos_ui.dart';

class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({super.key});

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen> {
  final SaveManager _save = SaveManager.instance;
  GameController? _activeGame;
  bool _levelAdBusy = false;
  bool _offerBusy = false;
  Timer? _cooldownRefreshTimer;
  Timer? _autoWheelTimer;

  static bool _hasAutoShownWheelThisSession = false;
  final GlobalKey _wheelButtonKey = GlobalKey();
  bool _highlightWheelButton = false;
  bool _showArcadeModes = false;
  late final PageController _pageController;
  int _currentPage = 1;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 1);
    _cooldownRefreshTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _activeGame == null && AdManager.instance.remainingCooldownSeconds > 0) {
        setState(() {});
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_hasAutoShownWheelThisSession && mounted && _save.isShopUnlocked) {
        _hasAutoShownWheelThisSession = true;
        _autoWheelTimer = Timer(const Duration(milliseconds: 600), () {
          if (mounted && _activeGame == null) {
            _openFortuneWheelWithHero();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _autoWheelTimer?.cancel();
    _pageController.dispose();
    _cooldownRefreshTimer?.cancel();
    _activeGame?.removeListener(_onActiveGameTick);
    super.dispose();
  }

  void _showLockedFeedback(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.lock_rounded, color: Color(0xFFFFD54F), size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF161A29),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _goToPage(int page) {
    if (page == 0 && !_save.isShopUnlocked) {
      _showLockedFeedback('Bu özellik Bölüm 2 seviyesinde açılır.');
      return;
    }
    if (page == 2 && !_save.isAquariumUnlocked) {
      _showLockedFeedback('Bu özellik Bölüm 5 seviyesinde açılır.');
      return;
    }
    if (page == 3 && !_save.isWorkshopUnlocked) {
      _showLockedFeedback('Bu özellik Bölüm 3 seviyesinde açılır.');
      return;
    }
    if (_pageController.hasClients) {
      _pageController.animateToPage(
        page,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Widget _buildPageDot(int index, bool isActive) {
    return GestureDetector(
      onTap: () => _goToPage(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: isActive ? 16 : 6,
        height: 6,
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFFFD54F) : Colors.white24,
          borderRadius: BorderRadius.circular(3),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: const Color(0xFFFFD54F).withValues(alpha: 0.6),
                    blurRadius: 6,
                  )
                ]
              : null,
        ),
      ),
    );
  }

  void _onActiveGameTick() {
    final game = _activeGame;
    if (game != null && game.pendingLevelInterstitial && !_levelAdBusy) {
      game.pendingLevelInterstitial = false;
      _levelAdBusy = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          _levelAdBusy = false;
          return;
        }
        AdManager.instance.showLevelInterstitial(context, onComplete: () {
          _levelAdBusy = false;
          _maybeOfferRemoveAds();
        });
      });
      return;
    }
    _maybeOfferRemoveAds();
  }

  void _maybeOfferRemoveAds() {
    if (!mounted || _offerBusy || _levelAdBusy) return;
    if (!SaveManager.instance.shouldOfferRemoveAds) return;
    final game = _activeGame;
    if (game != null && game.status != GameStatus.ready && game.status != GameStatus.victory) return;
    _offerBusy = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _showRemoveAdsOffer());
  }

  Future<void> _showRemoveAdsOffer() async {
    if (!mounted) return;
    await SaveManager.instance.markRemoveAdsOfferSeen();
    if (!mounted) return;
    final price = RemoveAdsBilling.instance.priceLabel;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
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
                child: const PixelIcon('no_ads', size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  I18n.tr('remove_ads_offer_title'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                    fontSize: 17,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                I18n.tr('remove_ads_offer_body'),
                style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0x2200E5FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0x4400E5FF)),
                ),
                child: Text(
                  price,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF00E5FF),
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(
                I18n.tr('remove_ads_later'),
                style: const TextStyle(color: Colors.white54, fontWeight: FontWeight.bold),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00E5FF),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              ),
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                final opened = await RemoveAdsBilling.instance.buy();
                if (!opened && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(I18n.tr('remove_ads_unavailable'))),
                  );
                }
              },
              child: Text(
                I18n.tr('remove_ads_buy'),
                style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.6),
              ),
            ),
          ],
        );
      },
    );
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

  void _launchGame(GameMode mode, {bool isResume = false, int? explicitStartLevel}) {
    AudioManager.instance.isBgmAllowed = false;
    AudioManager.instance.pauseBgm();
    setState(() {
      _activeGame?.removeListener(_onActiveGameTick);
      _activeGame = GameController()..startNewGame(mode, isResume: isResume, explicitStartLevel: explicitStartLevel);
      _activeGame!.addListener(_onActiveGameTick);
    });
  }

  void _launchDailyBlitz() {
    AudioManager.instance.isBgmAllowed = false;
    AudioManager.instance.pauseBgm();
    setState(() {
      _activeGame?.removeListener(_onActiveGameTick);
      _activeGame = GameController()..startDailyBlitz();
      _activeGame!.addListener(_onActiveGameTick);
    });
  }

  void _openSectorMap() {
    HapticFeedback.selectionClick();
    AudioManager.instance.playSfx(GameSfx.click);
    Navigator.of(context).push<int>(
      MaterialPageRoute(
        builder: (_) => SectorMapView(
          save: _save,
          onStartSectorLevel: (level) {
            _launchGame(GameMode.classic, explicitStartLevel: level);
          },
        ),
      ),
    ).then((level) {
      if (level != null && mounted && _activeGame == null) {
        _launchGame(GameMode.classic, explicitStartLevel: level);
      }
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

    _activeGame?.removeListener(_onActiveGameTick);
    AudioManager.instance.isBgmAllowed = true;
    AudioManager.instance.playDuck = 1.0;
    AudioManager.instance.updateBgmVolume();
    setState(() {
      _activeGame = null;
    });
  }

  void _showSettingsDialog() {
    AudioManager.instance.isBgmAllowed = true;
    AudioManager.instance.playDuck = 1.0;
    AudioManager.instance.updateBgmVolume();
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

                    Text( '${I18n.tr('music_bgm')}: ${_save.bgmVolume == 0 ? I18n.tr('haptic_off') : _save.bgmVolume}',
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

                    const SizedBox(height: 16),
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
                        '${I18n.tr('metric_sessions')}: ${_save.metricSessions}\n'
                        '${I18n.tr('metric_day2')}: ${_save.metricDay2 ? I18n.tr('metric_yes') : I18n.tr('metric_no')}\n'
                        '${I18n.tr('metric_leave')}: ${_save.metricLevel1Leaves}\n'
                        '${I18n.tr('metric_ad')}: ${_save.metricAdCloses}\n'
                        '${I18n.tr('metric_best')}: ${_save.metricHighestClassicLevel}\n'
                        '${I18n.tr('metric_last')}: ${_save.playEvents.isEmpty ? '-' : _save.playEvents.last}\n'
                        '${I18n.tr('progress_code')}: ${_save.progressCode}',
                      style: const TextStyle(color: Colors.white60, fontSize: 12, height: 1.45),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: _save.progressCode));
                            },
                            child: Text(I18n.tr('progress_copy'), style: const TextStyle(color: Color(0xFFFFD54F), fontSize: 12)),
                          ),
                        ),
                        Expanded(
                          child: TextButton(
                            onPressed: () async {
                              final data = await Clipboard.getData(Clipboard.kTextPlain);
                              final applied = await _save.applyProgressCode(data?.text ?? '');
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(applied ? I18n.tr('progress_restored') : I18n.tr('progress_invalid'))),
                              );
                            },
                            child: Text(I18n.tr('progress_paste'), style: const TextStyle(color: Color(0xFFFFD54F), fontSize: 12)),
                          ),
                        ),
                      ],
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
                        final resumeBand = mode == GameMode.classic &&
                            _activeGame!.status == GameStatus.gameOver &&
                            _save.hasSavedGame(GameMode.classic);
                        _activeGame!.startNewGame(mode, isResume: resumeBand);
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
          backgroundColor: Colors.black,
          body: PopScope(
            canPop: _currentPage == 1,
            onPopInvokedWithResult: (didPop, result) {
              if (!didPop && _currentPage != 1) {
                _goToPage(1);
              }
            },
            child: PageView(
              controller: _pageController,
              onPageChanged: (index) {
                if (index == 0 && !_save.isShopUnlocked) {
                  _goToPage(1);
                  _showLockedFeedback('Bu özellik Bölüm 2 seviyesinde açılır.');
                  return;
                }
                if (index == 2 && !_save.isAquariumUnlocked) {
                  _goToPage(1);
                  _showLockedFeedback('Bu özellik Bölüm 5 seviyesinde açılır.');
                  return;
                }
                if (index == 3 && !_save.isWorkshopUnlocked) {
                  _goToPage(1);
                  _showLockedFeedback('Bu özellik Bölüm 3 seviyesinde açılır.');
                  return;
                }
                if (_currentPage != index) {
                  setState(() {
                    _currentPage = index;
                  });
                }
              },
              physics: const ClampingScrollPhysics(),
              children: [
                // 0: Mağaza
                ShopView(
                  onBackToMenu: () => _goToPage(1),
                ),

                // 1: Ana Menü
                _buildMainMenuHome(),

                // 2: Akvaryum
                AquariumView(
                  onBackToMenu: () => _goToPage(1),
                ),

                // 3: Yükseltmeler
                UpgradesView(
                  onBackToMenu: () => _goToPage(1),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMainMenuHome() {
    return EcoTankBackground(
      child: SafeArea(
        child: Column(
          children: [
                  // Top Header Bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: KaunosPalette.obsidianGlassElevated,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: KaunosPalette.crystalBorderStarlight.withValues(alpha: 0.6),
                              width: 1.2,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0xFF020308),
                                offset: Offset(0, 3),
                                blurRadius: 0,
                              ),
                              BoxShadow(
                                color: Color(0x25FFFFFF),
                                offset: Offset(0, 1),
                                blurRadius: 0,
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: _showSettingsDialog,
                              child: const Center(
                                child: Icon(Icons.settings_rounded, color: KaunosPalette.goldHighlight, size: 20),
                              ),
                            ),
                          ),
                        ),

                        // Seasonal Title & League Avatar Frame Badge
                        Flexible(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: GestureDetector(
                              onTap: () {
                                if (!_save.isLeagueUnlocked) {
                                  _showLockedFeedback('Haftalık Lig Bölüm 7 seviyesinde açılır.');
                                  return;
                                }
                                TournamentDialog.show(
                                  context,
                                  save: _save,
                                  onJoinTournament: () => _launchGame(GameMode.classic),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                decoration: BoxDecoration(
                                  color: KaunosPalette.obsidianGlassElevated,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: _save.leagueTierColor, width: 1.4),
                                  boxShadow: [
                                    const BoxShadow(
                                      color: Color(0xFF020308),
                                      offset: Offset(0, 3),
                                      blurRadius: 0,
                                    ),
                                    const BoxShadow(
                                      color: Color(0x30FFFFFF),
                                      offset: Offset(0, 1),
                                      blurRadius: 0,
                                    ),
                                    BoxShadow(
                                      color: _save.leagueTierColor.withValues(alpha: 0.35),
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    KaunosEmblem.crest(size: 15, crestColor: _save.leagueTierColor),
                                    const SizedBox(width: 5),
                                    Flexible(
                                      child: Text(
                                        _save.seasonalTitle,
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                        style: TextStyle(
                                          color: _save.leagueTierColor,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 12,
                                          letterSpacing: 0.5,
                                          fontFamily: 'Rajdhani',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),

                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: KaunosPalette.obsidianGlassElevated,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: KaunosPalette.goldBorder.withValues(alpha: 0.6), width: 1.2),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0xFF451A03),
                                offset: Offset(0, 3),
                                blurRadius: 0,
                              ),
                              BoxShadow(
                                color: Color(0x35FFFFFF),
                                offset: Offset(0, 1),
                                blurRadius: 0,
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const KaunosEmblem.coin(size: 16),
                              const SizedBox(width: 5),
                              Text(
                                '${_save.gold}',
                                style: const TextStyle(
                                  color: KaunosPalette.goldHighlight,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                  fontFamily: 'Rajdhani',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Brand Title Crest (Handcrafted carved amber-gold crest with crystal ornaments)
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                      decoration: BoxDecoration(
                        color: KaunosPalette.obsidianGlassElevated.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: KaunosPalette.crystalBorderStarlight.withValues(alpha: 0.5),
                          width: 1.0,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0xFF020308),
                            offset: Offset(0, 3),
                            blurRadius: 0,
                          ),
                          BoxShadow(
                            color: Color(0x30FFFFFF),
                            offset: Offset(0, 1),
                            blurRadius: 0,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const KaunosEmblem.crest(size: 18, crestColor: KaunosPalette.goldHighlight),
                          const SizedBox(width: 10),
                          Text(
                            'KIRMATAS',
                            style: TextStyle(
                              fontSize: 38,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 4.0,
                              fontFamily: 'Rajdhani',
                              foreground: Paint()
                                ..shader = const LinearGradient(
                                  colors: [
                                    KaunosPalette.goldGlint,
                                    KaunosPalette.goldHighlight,
                                    KaunosPalette.goldPrimary,
                                    KaunosPalette.goldDeep,
                                  ],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ).createShader(const Rect.fromLTWH(0, 0, 240, 50)),
                              shadows: const [
                                Shadow(color: Color(0x99451A03), blurRadius: 12, offset: Offset(0, 3)),
                                Shadow(color: Color(0x66F59E0B), blurRadius: 20, offset: Offset(0, 4)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          const KaunosEmblem.crest(size: 18, crestColor: KaunosPalette.goldHighlight),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

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

                          // COLLAPSIBLE ARCADE MODES BUTTON
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
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
                                    Flexible(
                                      child: Text(
                                        _showArcadeModes ? I18n.tr('other_modes_hide') : I18n.tr('other_modes_show'),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.5,
                                        ),
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
                                    icon: Icons.spa_rounded,
                                    color1: const Color(0xFF00B4D8),
                                    color2: const Color(0xFF0077B6),
                                    badge: !_save.isLeagueUnlocked ? '🔒 Bölüm 7' : null,
                                    onTap: () {
                                      if (!_save.isLeagueUnlocked) {
                                        _showLockedFeedback('Bu özellik Bölüm 7 seviyesinde açılır.');
                                        return;
                                      }
                                      _launchGame(GameMode.zen);
                                    },
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _buildArcadeMiniCard(
                                    mode: GameMode.descend,
                                    title: I18n.tr('descend'),
                                    desc: I18n.tr('descend_desc'),
                                    icon: Icons.keyboard_double_arrow_down_rounded,
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
                              title: '${I18n.tr('shapes').toUpperCase()} • 38 FİGÜR',
                              desc: 'Rastgele piksel figürler, özel desenler ve yüksek tempo',
                              icon: Icons.palette_rounded,
                              color1: const Color(0xFFE040FB),
                              color2: const Color(0xFF7C4DFF),
                              onTap: () => _launchGame(GameMode.shapes),
                            ),
                            const SizedBox(height: 10),
                            _buildArcadeMiniCard(
                              mode: GameMode.daily,
                              title: 'GÜNÜN OPERASYONU • GÜNLÜK MÜCADELE',
                              desc: _save.isDailyBlitzCompletedToday
                                  ? 'Bugünkü görev tamamlandı! 250 Altın + 3 İnci + 1 Parça alındı.'
                                  : 'Özel günlük tohumlu bölüm: 250 Altın + 3 İnci + 1 Parça',
                              icon: Icons.bolt_rounded,
                              color1: const Color(0xFFFF9100),
                              color2: const Color(0xFFFF5252),
                              badge: !_save.isLeagueUnlocked
                                  ? '🔒 Bölüm 7'
                                  : (_save.isDailyBlitzCompletedToday ? 'TAMAMLANDI ✓' : '250G + 3İ'),
                              onTap: () {
                                if (!_save.isLeagueUnlocked) {
                                  _showLockedFeedback('Günün Operasyonu Bölüm 7 seviyesinde açılır.');
                                  return;
                                }
                                _launchDailyBlitz();
                              },
                            ),
                            const SizedBox(height: 10),
                            _buildArcadeMiniCard(
                              mode: GameMode.classic,
                              title: 'HAFTALIK LİG ŞAMPİYONASI',
                              desc: '${_save.seasonalTitle} • 15 Kişilik Lig Grubu & Sıralama',
                              icon: Icons.military_tech_rounded,
                              color1: _save.leagueTierColor,
                              color2: const Color(0xFF1E88E5),
                              badge: !_save.isLeagueUnlocked ? '🔒 Bölüm 7' : 'LİG SEZONU',
                              onTap: () {
                                if (!_save.isLeagueUnlocked) {
                                  _showLockedFeedback('Haftalık Lig Bölüm 7 seviyesinde açılır.');
                                  return;
                                }
                                TournamentDialog.show(
                                  context,
                                  save: _save,
                                  onJoinTournament: () => _launchGame(GameMode.classic),
                                );
                              },
                            ),
                          ],

                          const SizedBox(height: 14),
                        ],
                      ),
                    ),
                  ),

                  // SWIPE HINT & PAGE DOTS
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        GestureDetector(
                          onTap: () => _goToPage(0),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.arrow_back_ios_rounded, color: Colors.white38, size: 10),
                              SizedBox(width: 2),
                              Text(
                                'MAĞAZA',
                                style: TextStyle(
                                  color: Colors.white38,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildPageDot(0, _currentPage == 0),
                            const SizedBox(width: 5),
                            _buildPageDot(1, _currentPage == 1),
                            const SizedBox(width: 5),
                            _buildPageDot(2, _currentPage == 2),
                            const SizedBox(width: 5),
                            _buildPageDot(3, _currentPage == 3),
                          ],
                        ),
                        GestureDetector(
                          onTap: () => _goToPage(2),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'AKVARYUM',
                                style: TextStyle(
                                  color: Color(0x994FC3F7),
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              SizedBox(width: 2),
                              Icon(Icons.arrow_forward_ios_rounded, color: Color(0x994FC3F7), size: 10),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // MODERN CONSOLIDATED FLOATING BOTTOM NAVIGATION DOCK
                  _buildBottomDock(),
                ],
              ),
            ),
          );
  }

  Widget _buildBottomDock() {
    return KaunosPanel(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      backgroundColor: KaunosPalette.obsidianGlassSurface,
      borderColor: KaunosPalette.crystalBorderStarlight,
      bottomBevelDepth: 4.0,
      bevelColor: KaunosPalette.crystalBevelShadow,
      borderRadius: 22,
      showSpecularRim: true,
      showCornerBrackets: true,
      child: Column(
        children: [
          _buildTopRewardsBar(),
          const SizedBox(height: 6),
          Container(
            height: 1,
            margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  KaunosPalette.crystalBorderStarlight,
                  Colors.transparent,
                ],
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: _buildNavButton(
                  emblem: const KaunosEmblem.pearl(size: 20),
                  icon: Icons.storefront_rounded,
                  label: I18n.tr('shop'),
                  badge: !_save.isShopUnlocked ? '🔒 Bölüm 2' : null,
                  onTap: () => _goToPage(0),
                ),
              ),
              Expanded(
                child: _buildNavButton(
                  emblem: const KaunosEmblem.astrolabe(
                    size: 20,
                    ringColor: Color(0xFF38BDF8),
                    starColor: Color(0xFF4FC3F7),
                  ),
                  icon: Icons.water_drop_rounded,
                  label: I18n.tr('aquarium'),
                  badge: !_save.isAquariumUnlocked
                      ? '🔒 Bölüm 5'
                      : (_save.currentAvailableFishGold > 0 ? '' : null),
                  onTap: () => _goToPage(2),
                ),
              ),
              Expanded(
                child: _buildNavButton(
                  emblem: const KaunosEmblem.wheel(size: 20, wheelColor: KaunosPalette.goldHighlight),
                  icon: Icons.assignment_turned_in_rounded,
                  label: I18n.tr('quests'),
                  badge: ((_save.questFishFed && !_save.claimedQuests.contains('feed_fish')) ||
                          (_save.questBricksBroken >= 100 && !_save.claimedQuests.contains('break_bricks')) ||
                          (_save.questAdOrWinDone && !_save.claimedQuests.contains('ad_or_win'))) ? '!' : null,
                  onTap: () => DailyQuestsDialog.show(
                    context,
                    onPlayToday: () => _launchGame(GameMode.daily),
                  ),
                ),
              ),
              Expanded(
                child: _buildNavButton(
                  emblem: const KaunosEmblem.anvil(size: 20, steelColor: KaunosPalette.goldHighlight),
                  icon: Icons.auto_awesome_rounded,
                  label: I18n.tr('upgrades'),
                  badge: !_save.isWorkshopUnlocked ? '🔒 Bölüm 3' : null,
                  onTap: () => _goToPage(3),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTopRewardsBar() {
    final canClaimDaily = _save.canClaimDailyLogin();
    final canClaimAd = _save.canClaimDailyLoginAd();
    final hasAnyClaim = canClaimDaily || canClaimAd;

    return Row(
      children: [
        // 1. 7 GÜNLÜK GİRİŞ (Compact Pill)
        Expanded(
          child: _buildFancyRewardButton(
            gradientColors: [const Color(0xFF261A08), const Color(0xFF161004)],
            borderColor: hasAnyClaim ? const Color(0xFFFFD54F) : Colors.white12,
            glowColor: const Color(0xFFFFA000),
            isGlowing: hasAnyClaim,
            iconGradient: const [Color(0xFFFFD54F), Color(0xFFFF8F00)],
            emblem: const KaunosEmblem.crest(size: 16, crestColor: Color(0xFF261500)),
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
                final isLocked = !_save.isShopUnlocked;

                return _buildFancyRewardButton(
                  gradientColors: isLocked
                      ? const [Color(0xFF141724), Color(0xFF1A1D2B)]
                      : (hasSpins
                          ? const [Color(0xFF0B2135), Color(0xFF160A29)]
                          : const [Color(0xFF141724), Color(0xFF1A1D2B)]),
                  borderColor: isLocked
                      ? Colors.white12
                      : (_highlightWheelButton
                          ? const Color(0xFFFFFF00)
                          : (hasSpins ? const Color(0xFF00E5FF) : Colors.white12)),
                  glowColor: _highlightWheelButton
                      ? const Color(0xFFFFD700)
                      : const Color(0xFF00E5FF),
                  isGlowing: !isLocked && (hasSpins || _highlightWheelButton),
                  iconGradient: isLocked
                      ? const [Color(0xFF455A64), Color(0xFF263238)]
                      : (hasSpins
                          ? const [Color(0xFF00E5FF), Color(0xFFD500F9)]
                          : const [Color(0xFF455A64), Color(0xFF263238)]),
                  emblem: isLocked
                      ? const KaunosEmblem.padlock(size: 15, bodyColor: Colors.white70)
                      : (hasSpins
                          ? const KaunosEmblem.wheel(size: 16, wheelColor: Colors.white)
                          : const KaunosEmblem.wheel(size: 16, wheelColor: Colors.white54)),
                  icon: isLocked ? Icons.lock_rounded : Icons.motion_photos_on_rounded,
                  iconColor: isLocked ? Colors.white54 : (hasSpins ? Colors.white : Colors.white54),
                  title: 'ÇARK',
                  titleColor: isLocked ? Colors.white60 : (hasSpins ? const Color(0xFF80D8FF) : Colors.white60),
                  subtitle: isLocked ? 'Kilitli' : (hasSpins ? '$spinsLeft/3' : 'Bitti'),
                  subColor: isLocked ? Colors.white38 : (hasSpins ? const Color(0xFF00E5FF) : Colors.white38),
                  badgeText: isLocked ? '🔒 Bölüm 2' : (hasSpins ? '$spinsLeft' : null),
                  badgeGradient: isLocked
                      ? const [Color(0xFF455A64), Color(0xFF37474F)]
                      : (hasSpins
                          ? const [Color(0xFF00E5FF), Color(0xFF7C4DFF)]
                          : null),
                  onTap: () {
                    if (isLocked) {
                      _showLockedFeedback('Bu özellik Bölüm 2 seviyesinde açılır.');
                      return;
                    }
                    _openFortuneWheelWithHero();
                  },
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
                emblem: const KaunosEmblem.coin(size: 16),
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
    );
  }

  Widget _buildFancyRewardButton({
    Widget? emblem,
    IconData? icon,
    required List<Color> gradientColors,
    required Color borderColor,
    required Color glowColor,
    required bool isGlowing,
    required List<Color> iconGradient,
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
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor, width: isGlowing ? 1.4 : 1.0),
            boxShadow: [
              // 1.3 Physical bottom bevel depth (3.5px zero-blur shadow)
              const BoxShadow(
                color: Color(0xFF020308),
                offset: Offset(0, 3.5),
                blurRadius: 0,
              ),
              // Top inner specular rim
              const BoxShadow(
                color: Color(0x30FFFFFF),
                offset: Offset(0, 1),
                blurRadius: 0,
              ),
              if (isGlowing)
                BoxShadow(
                  color: glowColor.withValues(alpha: 0.45),
                  blurRadius: 10,
                  spreadRadius: 1,
                  offset: const Offset(0, 2),
                ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: iconGradient,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: iconGradient.first.withValues(alpha: 0.5),
                          blurRadius: 5,
                          offset: const Offset(0, 1),
                        ),
                      ],
                      border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 1.0),
                    ),
                    child: Center(
                      child: emblem ?? Icon(icon, color: iconColor, size: 16),
                    ),
                  ),
                  const SizedBox(width: 5),
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
                            fontFamily: 'Rajdhani',
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
                            fontFamily: 'Rajdhani',
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
                        fontFamily: 'Rajdhani',
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
    final isNewPlayer = _save.highestLevel < 2;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          colors: [
            KaunosPalette.classicSunsetTop,
            KaunosPalette.terracottaPrimary,
            KaunosPalette.classicSunsetBottom,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: isNewPlayer ? KaunosPalette.goldHighlight : KaunosPalette.terracottaBorder,
          width: isNewPlayer ? 2.0 : 1.4,
        ),
        boxShadow: [
          // 1.3 Physical bottom depth: 5px zero-blur extruded bevel shadow
          const BoxShadow(
            color: Color(0xFF4A1808),
            offset: Offset(0, 5),
            blurRadius: 0,
            spreadRadius: 0,
          ),
          // Top inner specular highlight ridge
          const BoxShadow(
            color: Color(0x38FFFFFF),
            offset: Offset(0, 1.2),
            blurRadius: 0,
          ),
          // Ambient warm terracotta glow
          BoxShadow(
            color: const Color(0xFF96381B).withValues(alpha: isNewPlayer ? 0.45 : 0.28),
            blurRadius: isNewPlayer ? 20 : 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () => _startOrPromptResume(GameMode.classic),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (isNewPlayer)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF00E676), Color(0xFF00B0FF)],
                                ),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFE8F5E9), width: 1.0),
                                boxShadow: const [
                                  BoxShadow(color: Color(0x6600E676), blurRadius: 6, offset: Offset(0, 1)),
                                ],
                              ),
                              child: const Text(
                                '⭐ MACERAYA BAŞLA!',
                                style: TextStyle(
                                  color: Color(0xFF051B11),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                  fontFamily: 'Rajdhani',
                                ),
                              ),
                            ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: KaunosPalette.obsidianGlassElevated,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: KaunosPalette.crystalBorderStarlight.withValues(alpha: 0.4), width: 1.0),
                            ),
                            child: Text(
                              I18n.tr('classic_desc'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Rajdhani',
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
                              child: Text(
                                'BÖLÜM ${_save.classicSavedLevel} ',
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                  fontFamily: 'Rajdhani',
                                ),
                              ),
                            ),
                          GestureDetector(
                            onTap: _openSectorMap,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: KaunosPalette.obsidianGlassElevated,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: KaunosPalette.goldHighlight.withValues(alpha: 0.7), width: 1.0),
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const KaunosEmblem.astrolabe(
                                      size: 11,
                                      ringColor: KaunosPalette.goldHighlight,
                                      starColor: KaunosPalette.goldPrimary,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _save.prestigeTier > 0
                                          ? 'PRESTİJ ${_save.prestigeTier} • SEKTÖR 14/14 🌌'
                                          : 'SEKTÖR ${_save.highestUnlockedSector}/14 🗺️',
                                      style: const TextStyle(
                                        color: KaunosPalette.goldHighlight,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.5,
                                        fontFamily: 'Rajdhani',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          I18n.tr('classic').toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                            fontFamily: 'Rajdhani',
                            shadows: [
                              Shadow(
                                color: Color(0x66000000),
                                offset: Offset(0, 2),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (best > 0) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: KaunosPalette.obsidianGlassElevated,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: KaunosPalette.goldBorder.withValues(alpha: 0.4), width: 1.0),
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const KaunosEmblem.coin(size: 12),
                                const SizedBox(width: 5),
                                Text(
                                  '${I18n.tr('high_score')}: $best',
                                  style: const TextStyle(
                                    color: KaunosPalette.goldHighlight,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: 'Rajdhani',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    KaunosHeroPlayButton(
                      size: 56.0,
                      onTap: () => _startOrPromptResume(GameMode.classic),
                    ),
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: _openSectorMap,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: KaunosPalette.obsidianGlassElevated,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: KaunosPalette.goldHighlight.withValues(alpha: 0.6), width: 1.0),
                          boxShadow: const [
                            BoxShadow(color: Color(0xFF020308), offset: Offset(0, 2), blurRadius: 0),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            KaunosEmblem.astrolabe(
                              size: 11,
                              ringColor: KaunosPalette.goldHighlight,
                              starColor: KaunosPalette.goldPrimary,
                            ),
                            SizedBox(width: 3),
                            Text(
                              'HARİTA',
                              style: TextStyle(
                                color: KaunosPalette.goldHighlight,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                                fontFamily: 'Rajdhani',
                              ),
                            ),
                          ],
                        ),
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

  Widget _buildChaosHeroCard() {
    final best = _save.getHighScore(GameMode.chaos);
    final isLocked = !_save.isChaosUnlocked;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: isLocked
            ? const LinearGradient(
                colors: [Color(0xFF111923), Color(0xFF090E17), Color(0xFF05080E)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : const LinearGradient(
                colors: [
                  KaunosPalette.chaosJadeTop,
                  KaunosPalette.deepJadePrimary,
                  KaunosPalette.chaosJadeBottom,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        border: Border.all(
          color: isLocked
              ? KaunosPalette.deepJadeBorder.withValues(alpha: 0.25)
              : KaunosPalette.deepJadeBorder,
          width: 1.4,
        ),
        boxShadow: [
          // Physical bottom depth: 5px zero-blur bevel
          BoxShadow(
            color: isLocked ? const Color(0xFF020306) : const Color(0xFF091C20),
            offset: const Offset(0, 5),
            blurRadius: 0,
            spreadRadius: 0,
          ),
          // Top inner specular rim
          BoxShadow(
            color: isLocked ? const Color(0x1AFFFFFF) : const Color(0x3848A9A6),
            offset: const Offset(0, 1.2),
            blurRadius: 0,
          ),
          // Ambient glow
          if (!isLocked)
            BoxShadow(
              color: const Color(0xFF1E4D58).withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () {
            if (isLocked) {
              _showLockedFeedback('Bu özellik Bölüm 5 seviyesinde açılır.');
              return;
            }
            _startOrPromptResume(GameMode.chaos);
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (isLocked)
                            KaunosBadge.lock(
                              text: '🔒 BÖLÜM 5',
                              borderColor: const Color(0xFFEF5350).withValues(alpha: 0.6),
                            )
                          else ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: KaunosPalette.obsidianGlassElevated,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: KaunosPalette.deepJadeBorder.withValues(alpha: 0.4), width: 1.0),
                              ),
                              child: Text(
                                I18n.tr('chaos_desc'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Rajdhani',
                                ),
                              ),
                            ),
                            if (_save.hasSavedGame(GameMode.chaos))
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xDDFFD54F),
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: const [
                                    BoxShadow(color: Color(0x44FFD54F), blurRadius: 4, offset: Offset(0, 1)),
                                  ],
                                ),
                                child: Text(
                                  'BÖLÜM ${_save.chaosSavedLevel} ',
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                    fontFamily: 'Rajdhani',
                                  ),
                                ),
                              ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              I18n.tr('chaos').toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isLocked ? Colors.white60 : Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.0,
                                fontFamily: 'Rajdhani',
                                shadows: isLocked
                                    ? null
                                    : const [
                                        Shadow(
                                          color: Color(0x80000000),
                                          offset: Offset(0, 2),
                                          blurRadius: 4,
                                        ),
                                      ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            isLocked ? Icons.lock_rounded : Icons.flash_on_rounded,
                            color: isLocked ? Colors.white38 : KaunosPalette.goldHighlight,
                            size: 24,
                          ),
                        ],
                      ),
                      if (best > 0) ...[
                        const SizedBox(height: 4),
                        Text(
                          '${I18n.tr('high_score')}: $best',
                          style: TextStyle(
                            color: isLocked ? Colors.white38 : Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Rajdhani',
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                // Tactile action trigger (Locked socket vs Unlocked amber trigger)
                isLocked
                    ? SizedBox(
                        width: 56,
                        height: 56 + 4.0,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Positioned(
                              top: 4.0,
                              bottom: 0,
                              left: 0,
                              right: 0,
                              child: Container(
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Color(0xFF04060A),
                                ),
                              ),
                            ),
                            Positioned.fill(
                              bottom: 4.0,
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0x33101826),
                                  border: Border.all(
                                    color: const Color(0x3348A9A6),
                                    width: 1.5,
                                  ),
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.lock_rounded,
                                    color: Colors.white54,
                                    size: 28,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : KaunosHeroPlayButton(
                        size: 56.0,
                        onTap: () => _startOrPromptResume(GameMode.chaos),
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
    String? badge,
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
                    if (badge != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE53935),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          badge,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      )
                    else if (best > 0)
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
    Widget? emblem,
    IconData? icon,
    required String label,
    required VoidCallback onTap,
    String? badge,
  }) {
    return KaunosJuicyInteractive(
      borderRadius: 16,
      waveColor: KaunosPalette.crystalBorderStarlight,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF141A2E), Color(0xFF0A0E1A)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    border: Border.all(
                      color: KaunosPalette.crystalBorderStarlight.withValues(alpha: 0.5),
                      width: 1.0,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x66000000),
                        blurRadius: 3,
                        offset: Offset(0, 1.5),
                      ),
                    ],
                  ),
                  child: Center(
                    child: emblem ?? Icon(icon, color: const Color(0xFFFFD54F), size: 20),
                  ),
                ),
                if (badge != null)
                  Positioned(
                    top: -5,
                    right: -10,
                    child: badge.isEmpty
                        ? Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: KaunosPalette.goldPrimary,
                              boxShadow: [
                                BoxShadow(color: KaunosPalette.goldHighlight, blurRadius: 4),
                              ],
                            ),
                          )
                        : (badge == '!'
                            ? Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFFFF1744), Color(0xFFD50000)],
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.white, width: 0.8),
                                  boxShadow: const [
                                    BoxShadow(color: Colors.black45, blurRadius: 4, offset: Offset(0, 1)),
                                  ],
                                ),
                                child: const Text(
                                  '!',
                                  style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900),
                                ),
                              )
                            : Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: const Color(0xE6140D05),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: KaunosPalette.goldBorder, width: 0.9),
                                  boxShadow: const [
                                    BoxShadow(color: KaunosPalette.goldBevelBottom, blurRadius: 3, offset: Offset(0, 1)),
                                  ],
                                ),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    badge,
                                    style: const TextStyle(
                                      color: KaunosPalette.goldHighlight,
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.w900,
                                      fontFamily: 'Rajdhani',
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ),
                              )),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'Rajdhani',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

