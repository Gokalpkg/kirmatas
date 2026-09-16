import 'package:flutter/material.dart';
import '../engine/game_controller.dart';
import '../engine/i18n.dart';
import '../models/game_state.dart';
import '../storage/save_manager.dart';
import 'aquarium_view.dart';
import 'eco_tank_background.dart';
import 'game_canvas.dart';
import 'hud_overlay.dart';
import 'pause_game_over.dart';
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
    setState(() {
      _activeGame = GameController()..startNewGame(mode);
    });
  }

  void _exitGameToMenu() {
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

                    // Sound Effects
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(I18n.tr('sfx'), style: const TextStyle(color: Colors.white)),
                      value: _save.sfxEnabled,
                      activeThumbColor: const Color(0xFFFFD54F),
                      onChanged: (val) => _save.setSfx(val),
                    ),

                    // Haptics
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(I18n.tr('haptics'), style: const TextStyle(color: Colors.white)),
                      value: _save.hapticsEnabled,
                      activeThumbColor: const Color(0xFFFFD54F),
                      onChanged: (val) => _save.setHaptics(val),
                    ),

                    const SizedBox(height: 12),

                    // Game Speed
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
                              ),
                              child: Text(
                                label,
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
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
                  ),

                  // Brand Title (Clean, no subtitle)
                  Text(
                    'KIRMATAŞ',
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
                                  mode: GameMode.tuft,
                                  title: I18n.tr('tuft'),
                                  desc: I18n.tr('tuft_desc'),
                                  icon: Icons.palette,
                                  color1: const Color(0xFFD4A373),
                                  color2: const Color(0xFFA98467),
                                  onTap: () => _launchGame(GameMode.tuft),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
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
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const AquariumView()),
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
    final canClaim = _save.canClaimDaily();

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
          onTap: () => _launchGame(GameMode.daily),
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
                        onTap: () async {
                          final reward = await _save.claimDailyReward();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('+$reward ${I18n.tr('coins')}!')),
                            );
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2A1800),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            I18n.tr('claim').toUpperCase(),
                            style: const TextStyle(
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
                      I18n.tr('daily'),
                      style: const TextStyle(
                        color: Color(0xFF2A1800),
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      canClaim ? I18n.tr('today_ready') : I18n.tr('today_done'),
                      style: const TextStyle(
                        color: Color(0xCC2A1800),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
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
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: const Color(0xFFFFD54F), size: 22),
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
