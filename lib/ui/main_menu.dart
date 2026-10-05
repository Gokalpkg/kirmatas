import 'package:flutter/material.dart';
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
import 'rewarded_ad_button.dart';
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

  void _launchGame(GameMode mode) {
    AudioManager.instance.isBgmAllowed = false;
    AudioManager.instance.pauseBgm();
    setState(() {
      _activeGame = GameController()..startNewGame(mode);
    });
  }

  void _exitGameToMenu() {
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
                                  Text(
                                    '(${lang.label})',
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

                    Text(
                      '${I18n.tr('sfx')}: ${_save.sfxVolume}',
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

                    Text(
                      'Müzik (BGM): ${_save.bgmVolume}',
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

                    Text(
                      '${I18n.tr('haptics')}: ${_save.vibrationLevel}',
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

                    const SizedBox(height: 8),

                    SwitchListTile(
                      title: const Text('Geliştirici Modu (Sınırsız Altın)', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 13)),
                      value: _save.devMode,
                      activeThumbColor: const Color(0xFFFFD54F),
                      contentPadding: EdgeInsets.zero,
                      onChanged: (val) {
                        if (val) {
                          _save.gold = 9999999;
                          _save.setDevMode(true);
                        } else {
                          _save.setDevMode(false);
                        }
                        setState(() {});
                      },
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
                onRestart: () => _activeGame!.startNewGame(_activeGame!.currentMode),
                onMainMenu: _exitGameToMenu,
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
                        Row(
                          children: [
                            IconButton(
                              icon: const Text('🎡', style: TextStyle(fontSize: 18)),
                              tooltip: 'Şans Çarkı',
                              style: IconButton.styleFrom(
                                backgroundColor: const Color(0x33FFB300),
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(36, 36),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  side: const BorderSide(color: Color(0x80FFD54F)),
                                ),
                              ),
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (_) => const FortuneWheelDialog(),
                                );
                              },
                            ),
                            const SizedBox(width: 8),
                            const RewardedGoldAdButton(isCompact: true),
                            const SizedBox(width: 8),
                            Container(
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
                                  Text(
                                    '${_save.gold}',
                                    style: const TextStyle(
                                      color: Color(0xFFFFD54F),
                                      fontWeight: FontWeight.w900,
                                      fontSize: 15,
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

                  // Brand Title (Clean, no subtitle)
                  Text(
                    'KIRMATAS',
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

                  const SizedBox(height: 12),

                  // Main Modes Section (Hero Classic + 2x2 Grid)
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: Column(
                        children: [
                          // HERO CLASSIC CARD
                          _buildClassicHeroCard(),

                          const SizedBox(height: 12),

                          // 2x2 ARCADE MATRIX
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
                              const SizedBox(width: 12),
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

                          const SizedBox(height: 12),

                          Row(
                            children: [
                              Expanded(
                                child: _buildDailyMiniCard(),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildArcadeMiniCard(
                                  mode: GameMode.shapes,
                                  title: I18n.tr('shapes'),
                                  desc: I18n.tr('shapes_desc'),
                                  icon: Icons.palette,
                                  color1: const Color(0xFFD4A373),
                                  color2: const Color(0xFFA98467),
                                  onTap: () => _launchGame(GameMode.shapes),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Fortune Wheel High-Yield Feature Card
                          _buildFortuneWheelCard(),
                          const SizedBox(height: 12),
                          // Game Speed Options moved under modes
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            decoration: BoxDecoration(
                              color: const Color(0x33FFFFFF),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  I18n.tr('speed'),
                                  style: const TextStyle(
                                    color: Colors.white70,
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
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),

                  // Rewarded Ad Gold Button
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                    child: RewardedGoldAdButton(isCompact: false),
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
                          badge: _save.currentAvailableFishGold > 0 ? '🪙' : (_save.isFishHungry ? '🌾' : null),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const AquariumView()),
                          ),
                        ),
                        _buildNavButton(
                          icon: Icons.assignment_turned_in,
                          label: 'Görevler',
                          badge: ((_save.questFishFed && !_save.claimedQuests.contains('feed_fish')) ||
                                  (_save.questBricksBroken >= 100 && !_save.claimedQuests.contains('break_bricks')) ||
                                  (_save.questAdOrWinDone && !_save.claimedQuests.contains('ad_or_win'))) ? '!' : null,
                          onTap: () => DailyQuestsDialog.show(context),
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

  Widget _buildFortuneWheelCard() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2E1065), Color(0xFF581C87), Color(0xFF701A75)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFFFD54F), width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66701A75),
            blurRadius: 18,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () {
            showDialog(
              context: context,
              builder: (_) => const FortuneWheelDialog(),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                // Wheel Icon / Badge with golden glow
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const RadialGradient(
                      colors: [Color(0xFFFFEE58), Color(0xFFF57F17)],
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x88FFD600),
                        blurRadius: 12,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text('🎡', style: TextStyle(fontSize: 26)),
                  ),
                ),
                const SizedBox(width: 14),
                // Text Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'ŞANS ÇARKI',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFFD54F), Color(0xFFFF9100)],
                              ),
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: const [
                                BoxShadow(color: Color(0x66FF9100), blurRadius: 6),
                              ],
                            ),
                            child: const Text(
                              '500 🪙 BÜYÜK İKRAMİYE',
                              style: TextStyle(
                                color: Color(0xFF2E1C00),
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Çevir & Sandık, Altın veya Parça Kazan!',
                        style: TextStyle(
                          color: Color(0xFFE1BEE7),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                // Play Icon Button Pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFF9C4), Color(0xFFFFD54F), Color(0xFFFF9800)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x88FFD54F),
                        blurRadius: 10,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'ÇEVİR',
                        style: TextStyle(
                          color: Color(0xFF2E1C00),
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                          letterSpacing: 0.5,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(Icons.play_arrow_rounded, color: Color(0xFF2E1C00), size: 14),
                    ],
                  ),
                ),
              ],
            ),
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
          onTap: () => _launchGame(GameMode.classic),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
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
                        Text(
                          '${I18n.tr('high_score')}: $best',
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
                        child: Text(
                          '$best',
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

  Widget _buildDailyMiniCard() {
    final canClaim = _save.canClaimDailyLogin();

    return Container(
      height: 115,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF5D27A), Color(0xFFFF9A4A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Color(0x33FF9A4A), blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => DailyLoginDialog.show(context),
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
                      child: const Icon(Icons.calendar_month, color: Color(0xFF2A1800), size: 20),
                    ),
                    if (canClaim)
                      GestureDetector(
                        onTap: () => DailyLoginDialog.show(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2A1800),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            'AL (7 GÜN)',
                            style: TextStyle(
                              color: Color(0xFFFFD54F),
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      )
                    else
                      const Icon(Icons.check_circle, color: Color(0xFF2A1800), size: 18),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_save.dailyLoginStreak}. GÜN ÖDÜLÜ',
                      style: const TextStyle(
                        color: Color(0xFF2A1800),
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      canClaim ? '🎁 Tıkla & Ödülü Al!' : '✓ Bugün Alındı',
                      style: const TextStyle(
                        color: Color(0xFF4A2800),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
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

