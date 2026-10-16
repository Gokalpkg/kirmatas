import 'dart:ui';
import 'package:flutter/material.dart';
import '../storage/save_manager.dart';

class TournamentDialog extends StatelessWidget {
  final SaveManager save;
  final VoidCallback? onJoinTournament;

  const TournamentDialog({
    super.key,
    required this.save,
    this.onJoinTournament,
  });

  static Future<void> show(
    BuildContext context, {
    required SaveManager save,
    VoidCallback? onJoinTournament,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => TournamentDialog(
        save: save,
        onJoinTournament: onJoinTournament,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rivals = save.getLeagueRivals();
    final playerRival = rivals.firstWhere((r) => r.isPlayer, orElse: () => rivals.first);
    final tierColor = save.leagueTierColor;
    final screenHeight = MediaQuery.of(context).size.height;
    final isCompact = screenHeight < 650;

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
      child: Container(
        height: screenHeight * (isCompact ? 0.92 : 0.85),
        decoration: BoxDecoration(
          color: const Color(0xFF0E1322),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: tierColor.withValues(alpha: 0.35), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: tierColor.withValues(alpha: 0.25),
              blurRadius: 24,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          children: [
            // Handle bar
            SizedBox(height: isCompact ? 8 : 12),
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(height: isCompact ? 8 : 12),

            // Header Row
            Padding(
              padding: EdgeInsets.symmetric(horizontal: isCompact ? 16 : 20),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(isCompact ? 6 : 8),
                    decoration: BoxDecoration(
                      color: tierColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(color: tierColor.withValues(alpha: 0.5)),
                    ),
                    child: Icon(Icons.military_tech_rounded, color: tierColor, size: isCompact ? 20 : 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'HAFTALIK LİG ŞAMPİYONASI',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isCompact ? 14 : 16,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '15 Kişilik Lig Grubu  •  3 Gün Kaldı',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: tierColor,
                            fontSize: isCompact ? 11 : 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white70),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            SizedBox(height: isCompact ? 8 : 14),

            // Player Profile Header Pill
            Container(
              margin: EdgeInsets.symmetric(horizontal: isCompact ? 16 : 20),
              padding: EdgeInsets.all(isCompact ? 10 : 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    tierColor.withValues(alpha: 0.20),
                    const Color(0xFF141A2D),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: tierColor.withValues(alpha: 0.6), width: 1.5),
              ),
              child: Row(
                children: [
                  // Framed avatar
                  Container(
                    width: isCompact ? 40 : 48,
                    height: isCompact ? 40 : 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: tierColor, width: 2.0),
                      boxShadow: [
                        BoxShadow(
                          color: tierColor.withValues(alpha: 0.4),
                          blurRadius: 10,
                        ),
                      ],
                      gradient: LinearGradient(
                        colors: [tierColor, const Color(0xFF1E2640)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Icon(Icons.person_rounded, color: Colors.white, size: isCompact ? 22 : 28),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          save.seasonalTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: tierColor,
                            fontWeight: FontWeight.w900,
                            fontSize: isCompact ? 13 : 15,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Sıralama: #${playerRival.rank} / 15  •  ${save.weeklyTournamentScore} Puan',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: isCompact ? 11 : 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: isCompact ? 7 : 10, vertical: isCompact ? 4 : 6),
                    decoration: BoxDecoration(
                      color: playerRival.rank <= 3
                          ? const Color(0xFF00E676).withValues(alpha: 0.2)
                          : (playerRival.rank > 10
                              ? const Color(0xFFFF1744).withValues(alpha: 0.2)
                              : Colors.white12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: playerRival.rank <= 3
                            ? const Color(0xFF00E676)
                            : (playerRival.rank > 10 ? const Color(0xFFFF1744) : Colors.white24),
                      ),
                    ),
                    child: Text(
                      playerRival.rank <= 3
                          ? 'YÜKSELME ⬆️'
                          : (playerRival.rank > 10 ? 'DÜŞME ⬇️' : 'GÜVENLİ 🛡️'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: playerRival.rank <= 3
                            ? const Color(0xFF00E676)
                            : (playerRival.rank > 10 ? const Color(0xFFFF5252) : Colors.white70),
                        fontWeight: FontWeight.w900,
                        fontSize: isCompact ? 9.5 : 10.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: isCompact ? 8 : 12),

            // Division Leaderboard Header
            Padding(
              padding: EdgeInsets.symmetric(horizontal: isCompact ? 20 : 24),
              child: Row(
                children: const [
                  SizedBox(width: 32, child: Text('#', style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold))),
                  Expanded(child: Text('OYUNCU', style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold))),
                  Text('PUAN', style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            Divider(color: Colors.white12, height: isCompact ? 10 : 16),

            // Leaderboard List
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: rivals.length,
                itemBuilder: (context, index) {
                  final r = rivals[index];
                  final isPromotion = r.rank <= 3;
                  final isDemotion = r.rank > 10;
                  final isPlayer = r.isPlayer;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isPlayer
                          ? tierColor.withValues(alpha: 0.18)
                          : const Color(0xFF13182A),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isPlayer
                            ? tierColor
                            : (isPromotion
                                ? const Color(0x3300E676)
                                : (isDemotion ? const Color(0x33FF1744) : Colors.white10)),
                        width: isPlayer ? 1.5 : 1.0,
                      ),
                    ),
                    child: Row(
                      children: [
                        // Rank badge
                        SizedBox(
                          width: 28,
                          child: Text(
                            '${r.rank}',
                            style: TextStyle(
                              color: r.rank == 1
                                  ? const Color(0xFFFFD700)
                                  : (r.rank == 2
                                      ? const Color(0xFFC0C0C0)
                                      : (r.rank == 3 ? const Color(0xFFCD7F32) : Colors.white54)),
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        // Avatar indicator
                        Icon(
                          isPlayer ? Icons.stars_rounded : Icons.person_outline_rounded,
                          color: isPlayer ? tierColor : Colors.white54,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        // Name
                        Expanded(
                          child: Text(
                            r.name,
                            style: TextStyle(
                              color: isPlayer ? Colors.white : Colors.white70,
                              fontWeight: isPlayer ? FontWeight.w900 : FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        // Score
                        Text(
                          '${r.score}',
                          style: TextStyle(
                            color: isPlayer ? tierColor : Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 4),
                        // Zone icon
                        Icon(
                          isPromotion
                              ? Icons.arrow_upward_rounded
                              : (isDemotion ? Icons.arrow_downward_rounded : Icons.shield_outlined),
                          size: 14,
                          color: isPromotion
                              ? const Color(0xFF00E676)
                              : (isDemotion ? const Color(0xFFFF5252) : Colors.white24),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Footer Action Button
            Padding(
              padding: EdgeInsets.symmetric(horizontal: isCompact ? 16 : 20, vertical: isCompact ? 8 : 14),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    if (onJoinTournament != null) {
                      onJoinTournament!();
                    }
                  },
                  icon: Icon(Icons.play_arrow_rounded, color: Colors.black, size: isCompact ? 20 : 22),
                  label: Text(
                    'MÜCADELEYE KATIL',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w900,
                      fontSize: isCompact ? 13 : 14,
                      letterSpacing: 0.8,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: tierColor,
                    padding: EdgeInsets.symmetric(vertical: isCompact ? 10 : 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 6,
                    shadowColor: tierColor.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
