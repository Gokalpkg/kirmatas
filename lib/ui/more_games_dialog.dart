import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../engine/audio_manager.dart';
import '../engine/i18n.dart';
import 'kaunos_ui.dart';

/// Data model representing a Kaunos Games production game.
class KaunosGameEntry {
  final String id;
  final String title;
  final String genreTr;
  final String genreEn;
  final String packageName;
  final IconData icon;
  final Color accentColor;
  final Color badgeGlow;
  final bool isCurrent;

  const KaunosGameEntry({
    required this.id,
    required this.title,
    required this.genreTr,
    required this.genreEn,
    required this.packageName,
    required this.icon,
    required this.accentColor,
    required this.badgeGlow,
    this.isCurrent = false,
  });

  String get genre => I18n.bi(genreTr, genreEn);
}

/// Dedicated, stylish Kaunos UI modal dialog showcasing the 4 active
/// production games from Kaunos Games.
class MoreGamesDialog extends StatelessWidget {
  const MoreGamesDialog({super.key});

  /// The 4 active production games of Kaunos Games.
  static const List<KaunosGameEntry> games = [
    KaunosGameEntry(
      id: 'kirmatas',
      title: 'Kırmataş',
      genreTr: 'Blok Kırma & Tufting Arcade',
      genreEn: 'Brick Breaker & Tufting Arcade',
      packageName: 'com.kaunos.kirmatas',
      icon: Icons.grid_view_rounded,
      accentColor: Color(0xFFFFD54F),
      badgeGlow: Color(0xFFFFC107),
      isCurrent: true,
    ),
    KaunosGameEntry(
      id: 'planetmatch',
      title: 'Planet Match',
      genreTr: 'Kozmik Gezegen Eşleştirme',
      genreEn: 'Cosmic Planet Match 3',
      packageName: 'com.kaunos.planetmatch',
      icon: Icons.public_rounded,
      accentColor: Color(0xFFB388FF),
      badgeGlow: Color(0xFF7C4DFF),
      isCurrent: false,
    ),
    KaunosGameEntry(
      id: 'blockfreeze',
      title: 'Block Freeze',
      genreTr: 'Buzul Blok Bulmacası',
      genreEn: 'Frosty Block Puzzle',
      packageName: 'com.kaunos.blockfreeze',
      icon: Icons.ac_unit_rounded,
      accentColor: Color(0xFF00E5FF),
      badgeGlow: Color(0xFF00B0FF),
      isCurrent: false,
    ),
    KaunosGameEntry(
      id: 'neonspace',
      title: 'Neon Space',
      genreTr: 'Retro Neon Uzay Macerası',
      genreEn: 'Retro Neon Space Action',
      packageName: 'com.kaunos.neonspace',
      icon: Icons.rocket_launch_rounded,
      accentColor: Color(0xFFFF4081),
      badgeGlow: Color(0xFFE040FB),
      isCurrent: false,
    ),
  ];

  /// Launch store or fallback search URL via url_launcher.
  static Future<void> launchGameStore(String packageName) async {
    final isSearch = packageName.isEmpty;
    final marketUri = isSearch
        ? Uri.parse('market://search?q=pub:Kaunos+Games')
        : Uri.parse('market://details?id=$packageName');
    final webUri = isSearch
        ? Uri.parse('https://play.google.com/store/search?q=pub%3AKaunos%20Games&c=apps')
        : Uri.parse('https://play.google.com/store/apps/details?id=$packageName');
    final fallbackSearchUri =
        Uri.parse('https://play.google.com/store/search?q=pub%3AKaunos%20Games&c=apps');

    try {
      if (await canLaunchUrl(marketUri)) {
        await launchUrl(marketUri, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (_) {}

    try {
      if (await canLaunchUrl(webUri)) {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (_) {}

    if (!isSearch) {
      try {
        if (await canLaunchUrl(fallbackSearchUri)) {
          await launchUrl(fallbackSearchUri, mode: LaunchMode.externalApplication);
        }
      } catch (_) {}
    }
  }

  /// Displays the MoreGamesDialog with smooth fade animation.
  static Future<void> show(BuildContext context) {
    AudioManager.instance.playSfx(GameSfx.click);
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'MoreGames',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (dialogContext, animation, secondaryAnimation) =>
          const MoreGamesDialog(),
      transitionBuilder: (ctx, anim, _, child) =>
          FadeTransition(opacity: anim, child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: KaunosPalette.obsidianGlassSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: KaunosPalette.crystalBorderStarlight.withValues(alpha: 0.7),
          width: 1.2,
        ),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Dialog Header with Kaunos Games Logo and Close Button
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(
                      'assets/images/kaunos_games.png',
                      height: 32,
                      width: 32,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.sports_esports_rounded,
                        color: KaunosPalette.goldHighlight,
                        size: 26,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          I18n.tr('more_games').toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            letterSpacing: 1.0,
                            fontFamily: 'Rajdhani',
                          ),
                        ),
                        Text(
                          I18n.tr('more_games_subtitle'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.65),
                            fontWeight: FontWeight.w600,
                            fontSize: 11.5,
                            fontFamily: 'Rajdhani',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  KaunosCloseButton(
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // Game Cards List
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final game in games) ...[
                        _buildGameCard(context, game),
                        const SizedBox(height: 10),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // Footer: View All Games on Google Play
              InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () {
                  AudioManager.instance.playSfx(GameSfx.click);
                  launchGameStore('');
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                  decoration: BoxDecoration(
                    color: KaunosPalette.obsidianGlassElevated,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: KaunosPalette.goldBorder.withValues(alpha: 0.6),
                      width: 1.0,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.storefront_rounded,
                        color: KaunosPalette.goldHighlight,
                        size: 17,
                      ),
                      const SizedBox(width: 7),
                      Flexible(
                        child: Text(
                          I18n.tr('view_all_games'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: KaunosPalette.goldHighlight,
                            fontFamily: 'Rajdhani',
                            fontWeight: FontWeight.w800,
                            fontSize: 12.5,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.open_in_new_rounded,
                        color: KaunosPalette.goldHighlight.withValues(alpha: 0.8),
                        size: 13,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGameCard(BuildContext context, KaunosGameEntry game) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: game.isCurrent
            ? const Color(0x18FFD54F)
            : KaunosPalette.obsidianGlassElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: game.accentColor.withValues(alpha: game.isCurrent ? 0.65 : 0.45),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: game.badgeGlow.withValues(alpha: game.isCurrent ? 0.18 : 0.10),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Game Icon Container
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  game.accentColor.withValues(alpha: 0.28),
                  game.accentColor.withValues(alpha: 0.08),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: game.accentColor.withValues(alpha: 0.7),
                width: 1.2,
              ),
            ),
            child: Icon(
              game.icon,
              color: game.accentColor,
              size: 22,
            ),
          ),

          const SizedBox(width: 10),

          // Title & Genre Subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        game.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 14.5,
                          fontFamily: 'Rajdhani',
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  game.genre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // Action: Active Badge OR Install/Play Button
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 130),
            child: game.isCurrent
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0x2200E676),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFF00E676).withValues(alpha: 0.8),
                        width: 1.1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.check_circle_rounded,
                          color: Color(0xFF00E676),
                          size: 13,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              I18n.tr('currently_playing'),
                              style: const TextStyle(
                                color: Color(0xFF00E676),
                                fontWeight: FontWeight.w800,
                                fontSize: 11,
                                fontFamily: 'Rajdhani',
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : KaunosPressGlow(
                    borderRadius: 10,
                    waveColor: game.accentColor,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () {
                          AudioManager.instance.playSfx(GameSfx.click);
                          launchGameStore(game.packageName);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                game.accentColor.withValues(alpha: 0.85),
                                game.badgeGlow.withValues(alpha: 0.70),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: game.badgeGlow.withValues(alpha: 0.35),
                                blurRadius: 6,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.download_rounded,
                                color: Colors.black87,
                                size: 13,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    I18n.tr('install_or_play'),
                                    style: const TextStyle(
                                      color: Colors.black87,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 11,
                                      fontFamily: 'Rajdhani',
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
