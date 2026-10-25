import 'dart:ui';
import 'package:flutter/material.dart';
import '../engine/audio_manager.dart';
import '../engine/i18n.dart';
import '../storage/save_manager.dart';
import 'kaunos_ui.dart';

/// Upgraded dual-tab Events & League dialog:
/// Tab 0: Weekly League (HAFTALIK LİG ŞAMPİYONASI)
/// Tab 1: Daily Quests & Blitz (GÜNLÜK GÖREVLER)
class TournamentDialog extends StatefulWidget {
  final SaveManager save;
  final VoidCallback? onJoinTournament;
  final int initialTab;

  const TournamentDialog({
    super.key,
    required this.save,
    this.onJoinTournament,
    this.initialTab = 0,
  });

  static Future<void> show(
    BuildContext context, {
    required SaveManager save,
    VoidCallback? onJoinTournament,
    int initialTab = 0,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => TournamentDialog(
        save: save,
        onJoinTournament: onJoinTournament,
        initialTab: initialTab,
      ),
    );
  }

  @override
  State<TournamentDialog> createState() => _TournamentDialogState();
}

class _TournamentDialogState extends State<TournamentDialog> {
  late int _selectedTab;
  final ScrollController _leagueScrollController = ScrollController();
  bool _leagueScrolled = false;

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialTab;
  }

  @override
  void dispose() {
    _leagueScrollController.dispose();
    super.dispose();
  }

  static String _fmtRemaining(Duration d) {
    if (d.inDays > 0) return '${d.inDays}g ${d.inHours % 24}sa';
    if (d.inHours > 0) return '${d.inHours}sa ${d.inMinutes % 60}dk';
    return '${d.inMinutes}dk';
  }

  static String _fmtNum(int v) {
    final s = v.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  void _claimQuest(String questId) async {
    final reward = await widget.save.claimQuestReward(questId);
    if (!mounted) return;
    if (reward > 0) {
      AudioManager.instance.playSfx(GameSfx.powerupBuff);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '+$reward ${I18n.tr('quest_gold')}',
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              color: Color(0xFFFFD54F),
            ),
          ),
          backgroundColor: const Color(0xFF161A29),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFFFD54F), width: 1.5),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final rivals = widget.save.getLeagueRivals();
    final playerRival = rivals.firstWhere(
      (r) => r.isPlayer,
      orElse: () => rivals.first,
    );
    final tierColor = widget.save.leagueTierColor;
    final screenHeight = MediaQuery.of(context).size.height;
    final isCompact = screenHeight < 650;

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
      child: Container(
        height: screenHeight * (isCompact ? 0.94 : 0.88),
        decoration: BoxDecoration(
          color: const Color(0xFF0E1322),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(
            color: tierColor.withValues(alpha: 0.35),
            width: 1.5,
          ),
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
            SizedBox(height: isCompact ? 6 : 10),

            // Dual Tab Selector Bar
            Container(
              margin: EdgeInsets.symmetric(horizontal: isCompact ? 16 : 20),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFF131828),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedTab = 0),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          vertical: isCompact ? 6 : 8,
                        ),
                        decoration: BoxDecoration(
                          gradient: _selectedTab == 0
                              ? LinearGradient(
                                  colors: [
                                    tierColor.withValues(alpha: 0.9),
                                    tierColor.withValues(alpha: 0.6),
                                  ],
                                )
                              : null,
                          color: _selectedTab == 0 ? null : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.military_tech_rounded,
                              size: isCompact ? 16 : 18,
                              color: _selectedTab == 0
                                  ? Colors.black
                                  : Colors.white70,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'HAFTALIK LİG',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: _selectedTab == 0
                                      ? Colors.black
                                      : Colors.white70,
                                  fontWeight: FontWeight.w900,
                                  fontSize: isCompact ? 11 : 12.5,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedTab = 1),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          vertical: isCompact ? 6 : 8,
                        ),
                        decoration: BoxDecoration(
                          gradient: _selectedTab == 1
                              ? const LinearGradient(
                                  colors: [
                                    Color(0xFF00E5FF),
                                    Color(0xFF00B0FF),
                                  ],
                                )
                              : null,
                          color: _selectedTab == 1 ? null : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.assignment_turned_in_rounded,
                              size: isCompact ? 16 : 18,
                              color: _selectedTab == 1
                                  ? Colors.black
                                  : Colors.white70,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'GÜNLÜK GÖREVLER',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: _selectedTab == 1
                                      ? Colors.black
                                      : Colors.white70,
                                  fontWeight: FontWeight.w900,
                                  fontSize: isCompact ? 11 : 12.5,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: isCompact ? 6 : 10),

            // Body based on active tab
            Expanded(
              child: _selectedTab == 0
                  ? _buildLeagueContent(
                      context,
                      rivals,
                      playerRival,
                      tierColor,
                      isCompact,
                    )
                  : _buildQuestsContent(context, isCompact),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeagueContent(
    BuildContext context,
    List<LeagueRival> rivals,
    LeagueRival playerRival,
    Color tierColor,
    bool isCompact,
  ) {
    final save = widget.save;
    final remaining = save.leagueTimeRemaining();
    final playerRank = playerRival.rank;
    final leaderScore = rivals.isEmpty ? 0 : rivals.first.score;
    final aboveRival = playerRank > 1 ? rivals[playerRank - 2] : null;
    final gapAbove = aboveRival == null
        ? 0
        : (aboveRival.score - playerRival.score + 1);
    String? zoneLine;
    double? zoneProgress;
    if (playerRank >= SaveManager.leagueDemotionStart) {
      final target = rivals[SaveManager.leagueDemotionStart - 2];
      final need = target.score - playerRival.score + 1;
      zoneLine = 'Güvenli bölgeye $need puan kaldı';
      zoneProgress = target.score > 0
          ? (playerRival.score / (target.score + 1)).clamp(0.0, 1.0)
          : 1.0;
    } else if (playerRank > SaveManager.leaguePromotionCutoff) {
      final target = rivals[SaveManager.leaguePromotionCutoff - 1];
      final need = target.score - playerRival.score + 1;
      zoneLine = 'Yükselme hattına $need puan kaldı';
      zoneProgress = target.score > 0
          ? (playerRival.score / (target.score + 1)).clamp(0.0, 1.0)
          : 1.0;
    } else {
      final lineScore = rivals.length >= SaveManager.leagueDemotionStart
          ? rivals[SaveManager.leagueDemotionStart - 1].score
          : 0;
      final margin = playerRival.score - lineScore;
      zoneLine = 'Düşme hattının $margin puan üstündesin';
      zoneProgress = null;
    }

    // Glide the list to the player's row once, shortly after opening —
    // but only when the player sits deep enough that the header would
    // stay reachable anyway.
    if (!_leagueScrolled) {
      _leagueScrolled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_leagueScrollController.hasClients) return;
        final idx = rivals.indexWhere((r) => r.isPlayer);
        if (idx <= 3) return;
        var offset = 430.0 + idx * 57.0;
        if (playerRank >= 4) offset += 24;
        if (playerRank >= 11) offset += 24;
        final max = _leagueScrollController.position.maxScrollExtent;
        _leagueScrollController.jumpTo((offset - 160).clamp(0.0, max));
      });
    }

    return Column(
      children: [
        // Header Row (fixed above the scroll area)
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
                child: Icon(
                  Icons.military_tech_rounded,
                  color: tierColor,
                  size: isCompact ? 20 : 24,
                ),
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
                      '15 Kişilik Lig Grubu  •  Bitişe ${_fmtRemaining(remaining)}',
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
              KaunosCloseButton(
                onTap: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),

        SizedBox(height: isCompact ? 6 : 10),

        Expanded(
          child: ListView(
            controller: _leagueScrollController,
            padding: const EdgeInsets.only(bottom: 8),
            children: [
              _buildTierBannerCard(save, tierColor, isCompact),
              SizedBox(height: isCompact ? 6 : 10),

              // Last week's settled result (reward already paid at rollover)
              if (save.hasUnseenLeagueResult) ...[
                Container(
                  margin: EdgeInsets.symmetric(horizontal: isCompact ? 16 : 20),
                  padding: EdgeInsets.symmetric(
                    horizontal: isCompact ? 10 : 12,
                    vertical: isCompact ? 8 : 10,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: save.leagueLastMovement > 0
                          ? const [Color(0xFF0D3B1E), Color(0xFF08170C)]
                          : (save.leagueLastMovement < 0
                                ? const [Color(0xFF3B0D14), Color(0xFF170608)]
                                : const [Color(0xFF232A3D), Color(0xFF10141F)]),
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: save.leagueLastMovement > 0
                          ? const Color(0xFF00E676)
                          : (save.leagueLastMovement < 0
                                ? const Color(0xFFFF5252)
                                : Colors.white24),
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        save.leagueLastMovement > 0
                            ? '🏆'
                            : (save.leagueLastMovement < 0 ? '📉' : '🏁'),
                        style: const TextStyle(fontSize: 20),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              save.leagueLastMovement > 0
                                  ? 'GEÇEN HAFTA #${save.leagueLastRank} → YÜKSELDİN!'
                                  : (save.leagueLastMovement < 0
                                        ? 'GEÇEN HAFTA #${save.leagueLastRank} → Bir kademe düştün'
                                        : 'GEÇEN HAFTA #${save.leagueLastRank} BİTİRDİN'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 12.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '+${save.leagueLastRewardGold} Altın'
                              '${save.leagueLastRewardPearls > 0 ? '  +  ${save.leagueLastRewardPearls} İnci' : ''}'
                              '  hesabına eklendi',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: KaunosPalette.goldHighlight,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          save.markLeagueResultSeen();
                          setState(() {});
                        },
                        child: const Text(
                          'TAMAM',
                          style: TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.w900,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: isCompact ? 6 : 10),
              ],

              // Podium for the top 3
              if (rivals.length >= 3)
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isCompact ? 16 : 20,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: _podiumColumn(
                          rivals[1],
                          tierColor,
                          isCompact,
                          2,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _podiumColumn(
                          rivals[0],
                          tierColor,
                          isCompact,
                          1,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _podiumColumn(
                          rivals[2],
                          tierColor,
                          isCompact,
                          3,
                        ),
                      ),
                    ],
                  ),
                ),
              if (rivals.length >= 3) SizedBox(height: isCompact ? 6 : 10),

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
                  border: Border.all(
                    color: tierColor.withValues(alpha: 0.6),
                    width: 1.5,
                  ),
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
                      child: Icon(
                        Icons.person_rounded,
                        color: Colors.white,
                        size: isCompact ? 22 : 28,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.save.seasonalTitle,
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
                            'Sıralama: #${playerRival.rank} / 15  •  ${widget.save.weeklyTournamentScore} Puan',
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
                      padding: EdgeInsets.symmetric(
                        horizontal: isCompact ? 7 : 10,
                        vertical: isCompact ? 4 : 6,
                      ),
                      decoration: BoxDecoration(
                        color: playerRival.rank <= 3
                            ? const Color(0xFF00E676).withValues(alpha: 0.2)
                            : (playerRival.rank > 10
                                  ? const Color(
                                      0xFFFF1744,
                                    ).withValues(alpha: 0.2)
                                  : Colors.white12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: playerRival.rank <= 3
                              ? const Color(0xFF00E676)
                              : (playerRival.rank > 10
                                    ? const Color(0xFFFF1744)
                                    : Colors.white24),
                        ),
                      ),
                      child: Text(
                        playerRival.rank <= 3
                            ? 'YÜKSELME ⬆️'
                            : (playerRival.rank > 10
                                  ? 'DÜŞME ⬇️'
                                  : 'GÜVENLİ 🛡️'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: playerRival.rank <= 3
                              ? const Color(0xFF00E676)
                              : (playerRival.rank > 10
                                    ? const Color(0xFFFF5252)
                                    : Colors.white70),
                          fontWeight: FontWeight.w900,
                          fontSize: isCompact ? 9.5 : 10.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: isCompact ? 6 : 10),

              // Player gap / zone status strip
              Container(
                margin: EdgeInsets.symmetric(horizontal: isCompact ? 16 : 20),
                padding: EdgeInsets.symmetric(
                  horizontal: isCompact ? 10 : 12,
                  vertical: isCompact ? 7 : 9,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF131828),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          playerRank == 1
                              ? Icons.emoji_events_rounded
                              : Icons.flag_rounded,
                          color: tierColor,
                          size: 15,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            playerRank == 1
                                ? 'Lidersin! Arkandakiyle fark: '
                                      '${playerRival.score - rivals[1].score} puan'
                                : 'Sıradaki rakibi geçmeye $gapAbove puan',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    ...[
                      const SizedBox(height: 3),
                      Text(
                        zoneLine,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: playerRank <= SaveManager.leaguePromotionCutoff
                              ? const Color(0xFF69F0AE)
                              : (playerRank >= SaveManager.leagueDemotionStart
                                    ? const Color(0xFFFF8A80)
                                    : Colors.white60),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    if (zoneProgress != null) ...[
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: zoneProgress,
                          minHeight: 5,
                          backgroundColor: Colors.white10,
                          valueColor: AlwaysStoppedAnimation<Color>(tierColor),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              SizedBox(height: isCompact ? 6 : 10),

              // Crystal Clear Weekly League Rewards Card
              _buildLeagueRewardsCard(save, tierColor, isCompact),

              SizedBox(height: isCompact ? 8 : 12),

              // Division Leaderboard Header
              Padding(
                padding: EdgeInsets.symmetric(horizontal: isCompact ? 20 : 24),
                child: Row(
                  children: const [
                    SizedBox(
                      width: 32,
                      child: Text(
                        '#',
                        style: TextStyle(
                          color: Colors.white38,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'OYUNCU',
                        style: TextStyle(
                          color: Colors.white38,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Text(
                      'PUAN',
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Divider(color: Colors.white12, height: isCompact ? 8 : 14),

              // Leaderboard rows
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    for (final r in rivals)
                      _leagueRow(r, tierColor, isCompact, leaderScore),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Pinned Player Ranking Bar (Always visible while scrolling)
        _buildPinnedPlayerRankBar(
          playerRival,
          tierColor,
          isCompact,
          leaderScore,
          rivals,
        ),

        // Footer Action Button
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isCompact ? 16 : 20,
            vertical: isCompact ? 8 : 12,
          ),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                if (widget.onJoinTournament != null) {
                  widget.onJoinTournament!();
                }
              },
              icon: Icon(
                Icons.play_arrow_rounded,
                color: Colors.black,
                size: isCompact ? 20 : 22,
              ),
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
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 6,
                shadowColor: tierColor.withValues(alpha: 0.5),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _leagueRow(
    LeagueRival r,
    Color tierColor,
    bool isCompact,
    int leaderScore,
  ) {
    final isPromotion = r.rank <= 3;
    final isDemotion = r.rank > 10;
    final isPlayer = r.isPlayer;

    Widget? zoneDivider;
    if (r.rank == 1) {
      zoneDivider = _zoneDivider(
        'YÜKSELME BÖLGESİ',
        const Color(0xFF00E676),
        isCompact,
      );
    } else if (r.rank == 4) {
      zoneDivider = _zoneDivider('GÜVENLİ BÖLGE', Colors.white38, isCompact);
    } else if (r.rank == SaveManager.leagueDemotionStart) {
      zoneDivider = _zoneDivider(
        'DÜŞME BÖLGESİ',
        const Color(0xFFFF5252),
        isCompact,
      );
    }

    final row = Container(
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
                          : (r.rank == 3
                                ? const Color(0xFFCD7F32)
                                : Colors.white54)),
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
          // Name + relative score bar
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isPlayer ? Colors.white : Colors.white70,
                    fontWeight: isPlayer ? FontWeight.w900 : FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 3),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: leaderScore > 0
                        ? (r.score / leaderScore).clamp(0.0, 1.0)
                        : 0,
                    minHeight: 3.5,
                    backgroundColor: Colors.white10,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isPlayer
                          ? tierColor
                          : Colors.white.withValues(alpha: 0.35),
                    ),
                  ),
                ),
              ],
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
                : (isDemotion
                      ? Icons.arrow_downward_rounded
                      : Icons.shield_outlined),
            size: 14,
            color: isPromotion
                ? const Color(0xFF00E676)
                : (isDemotion ? const Color(0xFFFF5252) : Colors.white24),
          ),
        ],
      ),
    );

    if (zoneDivider == null) return row;
    return Column(mainAxisSize: MainAxisSize.min, children: [zoneDivider, row]);
  }

  Widget _podiumColumn(
    LeagueRival r,
    Color tierColor,
    bool isCompact,
    int place,
  ) {
    final medal = place == 1 ? '🥇' : (place == 2 ? '🥈' : '🥉');
    final medalColor = place == 1
        ? const Color(0xFFFFD700)
        : (place == 2 ? const Color(0xFFC0C0C0) : const Color(0xFFCD7F32));
    final pedestalHeight = isCompact
        ? (place == 1 ? 34.0 : (place == 2 ? 26.0 : 20.0))
        : (place == 1 ? 44.0 : (place == 2 ? 33.0 : 25.0));
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(medal, style: TextStyle(fontSize: isCompact ? 18 : 22)),
        const SizedBox(height: 2),
        Container(
          width: isCompact ? 34 : 40,
          height: isCompact ? 34 : 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: r.isPlayer ? tierColor : medalColor,
              width: r.isPlayer ? 2.4 : 1.6,
            ),
            gradient: LinearGradient(
              colors: [
                (r.isPlayer ? tierColor : medalColor).withValues(alpha: 0.85),
                const Color(0xFF1E2640),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Icon(
            r.isPlayer ? Icons.stars_rounded : Icons.person_rounded,
            color: Colors.white,
            size: isCompact ? 17 : 20,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          r.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: r.isPlayer ? tierColor : Colors.white,
            fontWeight: r.isPlayer ? FontWeight.w900 : FontWeight.w700,
            fontSize: isCompact ? 10.5 : 11.5,
          ),
        ),
        Text(
          _fmtNum(r.score),
          style: TextStyle(
            color: r.isPlayer ? tierColor : Colors.white70,
            fontWeight: FontWeight.w900,
            fontSize: isCompact ? 11 : 12.5,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          height: pedestalHeight,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                medalColor.withValues(alpha: place == 1 ? 0.5 : 0.28),
                medalColor.withValues(alpha: 0.06),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            border: Border.all(color: medalColor.withValues(alpha: 0.45)),
          ),
          child: Center(
            child: Text(
              '$place',
              style: TextStyle(
                color: medalColor,
                fontFamily: 'Rajdhani',
                fontWeight: FontWeight.w900,
                fontSize: isCompact ? 15 : 18,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _zoneDivider(String label, Color color, bool isCompact) {
    return Padding(
      padding: EdgeInsets.only(
        top: isCompact ? 4 : 6,
        bottom: isCompact ? 4 : 6,
      ),
      child: Row(
        children: [
          Expanded(
            child: Divider(color: color.withValues(alpha: 0.4), height: 1),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 9.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Divider(color: color.withValues(alpha: 0.4), height: 1),
          ),
        ],
      ),
    );
  }

  void _scrollToPlayer(List<LeagueRival> rivals, int playerRank) {
    if (!_leagueScrollController.hasClients) return;
    final idx = rivals.indexWhere((r) => r.isPlayer);
    if (idx < 0) return;
    var offset = 380.0 + idx * 56.0;
    if (playerRank >= 4) offset += 24;
    if (playerRank >= 11) offset += 24;
    final max = _leagueScrollController.position.maxScrollExtent;
    _leagueScrollController.animateTo(
      (offset - 130).clamp(0.0, max),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  Widget _buildTierBannerCard(SaveManager save, Color tierColor, bool isCompact) {
    final tierNames = ['BRONZ LİGİ', 'GÜMÜŞ LİGİ', 'ALTIN LİGİ', 'PLATİN LİGİ', 'KAUNOS EFSANESİ'];
    final tierIdx = save.leagueTier.clamp(0, tierNames.length - 1);
    final tierTitle = tierNames[tierIdx];
    final tierIcons = ['🥉', '🥈', '🥇', '💎', '👑'];
    final tierIcon = tierIcons[tierIdx];

    return Container(
      margin: EdgeInsets.symmetric(horizontal: isCompact ? 16 : 20),
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: isCompact ? 10 : 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            tierColor.withValues(alpha: 0.28),
            const Color(0xFF13182B),
            const Color(0xFF0F121E),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tierColor.withValues(alpha: 0.65), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: tierColor.withValues(alpha: 0.20),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Tier Emblem Icon
          Container(
            width: isCompact ? 44 : 50,
            height: isCompact ? 44 : 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: tierColor.withValues(alpha: 0.20),
              border: Border.all(color: tierColor, width: 2),
            ),
            alignment: Alignment.center,
            child: Text(
              tierIcon,
              style: TextStyle(fontSize: isCompact ? 22 : 26),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        tierTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: tierColor,
                          fontWeight: FontWeight.w900,
                          fontSize: isCompact ? 13 : 15,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'KADEME ${save.leagueTier + 1}',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontWeight: FontWeight.bold,
                        fontSize: 9.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '15 Kişilik Haftalık Grup Mücadelesi',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: isCompact ? 11 : 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeagueRewardsCard(SaveManager save, Color tierColor, bool isCompact) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: isCompact ? 16 : 20),
      padding: EdgeInsets.all(isCompact ? 10 : 12),
      decoration: BoxDecoration(
        color: const Color(0xFF121727),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.emoji_events_rounded, color: KaunosPalette.goldHighlight, size: 16),
              const SizedBox(width: 6),
              const Flexible(
                child: Text(
                  'HAFTALIK LİG ÖDÜLLERİ',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Kademe ${save.leagueTier + 1}',
                style: TextStyle(
                  color: tierColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildCleanRewardItem(
                '🥇 1. Sıra',
                '${save.leagueRewardGoldForRank(1)} Altın',
                SaveManager.leaguePearlsForRank(1) > 0 ? '+${SaveManager.leaguePearlsForRank(1)} İnci' : null,
                const Color(0xFFFFD700),
                isCompact,
              ),
              const SizedBox(width: 6),
              _buildCleanRewardItem(
                '🥈 2. Sıra',
                '${save.leagueRewardGoldForRank(2)} Altın',
                SaveManager.leaguePearlsForRank(2) > 0 ? '+${SaveManager.leaguePearlsForRank(2)} İnci' : null,
                const Color(0xFFC0C0C0),
                isCompact,
              ),
              const SizedBox(width: 6),
              _buildCleanRewardItem(
                '🥉 3. Sıra',
                '${save.leagueRewardGoldForRank(3)} Altın',
                SaveManager.leaguePearlsForRank(3) > 0 ? '+${SaveManager.leaguePearlsForRank(3)} İnci' : null,
                const Color(0xFFCD7F32),
                isCompact,
              ),
              const SizedBox(width: 6),
              _buildCleanRewardItem(
                '🏅 4-10. Sıra',
                '${save.leagueRewardGoldForRank(5)} Altın',
                null,
                Colors.white70,
                isCompact,
              ),
            ],
          ),
          const SizedBox(height: 7),
          const Text(
            '⬆️ İlk 3 oyuncu üst lige terfi eder  •  ⬇️ Son 5 oyuncu alt lige düşer',
            style: TextStyle(
              color: Colors.white38,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCleanRewardItem(
    String rankTitle,
    String goldText,
    String? pearlText,
    Color accentColor,
    bool isCompact,
  ) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(vertical: isCompact ? 5 : 7, horizontal: 2),
        decoration: BoxDecoration(
          color: const Color(0xFF181F33),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: accentColor.withValues(alpha: 0.35)),
        ),
        child: Column(
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                rankTitle,
                maxLines: 1,
                style: TextStyle(
                  color: accentColor,
                  fontWeight: FontWeight.w900,
                  fontSize: isCompact ? 9.5 : 10.5,
                ),
              ),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                goldText,
                maxLines: 1,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: isCompact ? 9 : 10,
                ),
              ),
            ),
            if (pearlText != null) ...[
              const SizedBox(height: 1),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  pearlText,
                  maxLines: 1,
                  style: const TextStyle(
                    color: Color(0xFFEA80FC),
                    fontWeight: FontWeight.w900,
                    fontSize: 8.5,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPinnedPlayerRankBar(
    LeagueRival playerRival,
    Color tierColor,
    bool isCompact,
    int leaderScore,
    List<LeagueRival> rivals,
  ) {
    final isPromotion = playerRival.rank <= SaveManager.leaguePromotionCutoff;
    final isDemotion = playerRival.rank >= SaveManager.leagueDemotionStart;

    final zoneColor = isPromotion
        ? const Color(0xFF00E676)
        : (isDemotion ? const Color(0xFFFF5252) : const Color(0xFF00E5FF));

    final zoneBadgeText = isPromotion
        ? 'TERFİ ⬆️'
        : (isDemotion ? 'KÜME DÜŞME ⬇️' : 'GÜVENLİ HAT 🛡️');

    return Container(
      margin: EdgeInsets.symmetric(horizontal: isCompact ? 16 : 20, vertical: 4),
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: isCompact ? 7 : 9),
      decoration: BoxDecoration(
        color: const Color(0xFF141A2D),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tierColor.withValues(alpha: 0.75), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _scrollToPlayer(rivals, playerRival.rank),
        borderRadius: BorderRadius.circular(16),
        child: Row(
          children: [
            // Rank badge
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: zoneColor.withValues(alpha: 0.20),
                border: Border.all(color: zoneColor, width: 1.8),
              ),
              alignment: Alignment.center,
              child: Text(
                '#${playerRival.rank}',
                style: TextStyle(
                  color: zoneColor,
                  fontWeight: FontWeight.w900,
                  fontSize: 12.5,
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Player details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          'SENİN SIRALAMAN',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: isCompact ? 11 : 12,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: zoneColor.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: zoneColor.withValues(alpha: 0.6)),
                        ),
                        child: Text(
                          zoneBadgeText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 8.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${playerRival.score} Puan  •  ${widget.save.seasonalTitle}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            // Quick scroll pill button
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: tierColor.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: tierColor.withValues(alpha: 0.6)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.gps_fixed_rounded, color: tierColor, size: 13),
                  const SizedBox(width: 4),
                  Text(
                    'GÖSTER',
                    style: TextStyle(
                      color: tierColor,
                      fontWeight: FontWeight.w900,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestsContent(BuildContext context, bool isCompact) {
    return Column(
      children: [
        // Quests Header Row
        Padding(
          padding: EdgeInsets.symmetric(horizontal: isCompact ? 16 : 20),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(isCompact ? 6 : 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF00E5FF).withValues(alpha: 0.5),
                  ),
                ),
                child: Icon(
                  Icons.assignment_turned_in_rounded,
                  color: const Color(0xFF00E5FF),
                  size: isCompact ? 20 : 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'GÜNLÜK GÖREVLER',
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
                      'Görevleri Tamamla • Altın & Yem Kazan',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: const Color(0xFF00E5FF),
                        fontSize: isCompact ? 11 : 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              KaunosCloseButton(
                onTap: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),

        SizedBox(height: isCompact ? 8 : 12),

        // Quests Scroll List (eager column: only a handful of cards)
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                // Daily Blitz Summary Card
                Container(
                  padding: EdgeInsets.all(isCompact ? 10 : 12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF261805), Color(0xFF140D1E)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFFFF9100).withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF9100).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.bolt_rounded,
                          color: Color(0xFFFF9100),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'GÜNÜN OPERASYONU',
                              style: TextStyle(
                                color: Color(0xFFFFB74D),
                                fontWeight: FontWeight.w900,
                                fontSize: 12.5,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.save.isDailyBlitzCompletedToday
                                  ? 'Bugünkü ödül alındı!'
                                  : 'Özel günlük bölüm: 250G + 3İ + 1 Parça',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: widget.save.isDailyBlitzCompletedToday
                              ? const Color(0xFF00E676).withValues(alpha: 0.2)
                              : const Color(0xFFFF9100).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: widget.save.isDailyBlitzCompletedToday
                                ? const Color(0xFF00E676)
                                : const Color(0xFFFF9100),
                          ),
                        ),
                        child: Text(
                          widget.save.isDailyBlitzCompletedToday
                              ? 'TAMAM ✓'
                              : '250G + 3İ',
                          style: TextStyle(
                            color: widget.save.isDailyBlitzCompletedToday
                                ? const Color(0xFF00E676)
                                : const Color(0xFFFFB74D),
                            fontWeight: FontWeight.w900,
                            fontSize: 10.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // Quest 1: Feed Fish
                _buildQuestCard(
                  id: 'feed_fish',
                  title: I18n.tr('quest_feed'),
                  rewardText: '+60 Altın  + 1 ${I18n.tr('food_word')}',
                  current: widget.save.questFishFed ? 1 : 0,
                  target: 1,
                  icon: Icons.set_meal_rounded,
                  color: const Color(0xFF00E5FF),
                  isCompact: isCompact,
                ),
                const SizedBox(height: 10),

                // Quest 2: Break 100 Bricks
                _buildQuestCard(
                  id: 'break_bricks',
                  title: I18n.tr('quest_bricks'),
                  rewardText: '+120 Altın',
                  current: widget.save.questBricksBroken,
                  target: 100,
                  icon: Icons.view_module_rounded,
                  color: const Color(0xFFFFB300),
                  isCompact: isCompact,
                ),
                const SizedBox(height: 10),

                // Quest 3: Ad or Victory
                _buildQuestCard(
                  id: 'ad_or_win',
                  title: I18n.tr('quest_win'),
                  rewardText: '+150 Altın',
                  current: widget.save.questAdOrWinDone ? 1 : 0,
                  target: 1,
                  icon: Icons.star_rounded,
                  color: const Color(0xFFE040FB),
                  isCompact: isCompact,
                ),
                const SizedBox(height: 10),

                // Quest 4: Zen time
                _buildQuestCard(
                  id: 'zen_time',
                  title: 'Zen: 10 Dakika Huzur',
                  rewardText: '+80 Altın',
                  current: widget.save.questZenSeconds ~/ 60,
                  target: 10,
                  icon: Icons.spa_rounded,
                  color: const Color(0xFF81C784),
                  isCompact: isCompact,
                ),
                const SizedBox(height: 10),

                // Quest 5: Shapes clear
                _buildQuestCard(
                  id: 'shapes_clear',
                  title: 'Şekiller: 1 Figür Tamamla',
                  rewardText: '+100 Altın',
                  current: widget.save.questShapesClears,
                  target: 1,
                  icon: Icons.palette_rounded,
                  color: const Color(0xFFBA68C8),
                  isCompact: isCompact,
                ),
                const SizedBox(height: 10),

                // Quest 6: Descend survival rows
                _buildQuestCard(
                  id: 'descend_rows',
                  title: 'Descend: 10 Sıra Hayatta Kal',
                  rewardText: '+90 Altın',
                  current: widget.save.questDescendRows,
                  target: 10,
                  icon: Icons.keyboard_double_arrow_down_rounded,
                  color: const Color(0xFF9575CD),
                  isCompact: isCompact,
                ),
                const SizedBox(height: 12),

                const SizedBox(height: 14),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuestCard({
    required String id,
    required String title,
    required String rewardText,
    required int current,
    required int target,
    required IconData icon,
    required Color color,
    required bool isCompact,
  }) {
    final isClaimed = widget.save.claimedQuests.contains(id);
    final isCompleted = current >= target;
    final progress = (current / target).clamp(0.0, 1.0);

    return Container(
      padding: EdgeInsets.all(isCompact ? 10 : 12),
      decoration: BoxDecoration(
        color: const Color(0xFF151A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCompleted ? color : Colors.white12,
          width: isCompleted ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      rewardText,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              if (isClaimed)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0x3300E676),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF00E676)),
                  ),
                  child: const Text(
                    'TAMAMLANDI ✓',
                    style: TextStyle(
                      color: Color(0xFF00E676),
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                )
              else if (isCompleted)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    minimumSize: const Size(0, 32),
                  ),
                  onPressed: () => _claimQuest(id),
                  child: const Text(
                    'ÖDÜLÜ AL',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11),
                  ),
                )
              else
                Text(
                  '$current / $target',
                  style: const TextStyle(
                    color: Colors.white54,
                    fontWeight: FontWeight.bold,
                    fontSize: 11.5,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white10,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 5,
            ),
          ),
        ],
      ),
    );
  }
}
