import 'dart:ui';
import 'package:flutter/material.dart';
import '../engine/audio_manager.dart';
import '../engine/i18n.dart';
import '../storage/save_manager.dart';

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

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialTab;
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
            style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFFFFD54F)),
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
    final playerRival = rivals.firstWhere((r) => r.isPlayer, orElse: () => rivals.first);
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
                        padding: EdgeInsets.symmetric(vertical: isCompact ? 6 : 8),
                        decoration: BoxDecoration(
                          gradient: _selectedTab == 0
                              ? LinearGradient(
                                  colors: [tierColor.withValues(alpha: 0.9), tierColor.withValues(alpha: 0.6)],
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
                              color: _selectedTab == 0 ? Colors.black : Colors.white70,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'HAFTALIK LİG',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: _selectedTab == 0 ? Colors.black : Colors.white70,
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
                        padding: EdgeInsets.symmetric(vertical: isCompact ? 6 : 8),
                        decoration: BoxDecoration(
                          gradient: _selectedTab == 1
                              ? const LinearGradient(
                                  colors: [Color(0xFF00E5FF), Color(0xFF00B0FF)],
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
                              color: _selectedTab == 1 ? Colors.black : Colors.white70,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'GÜNLÜK GÖREVLER',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: _selectedTab == 1 ? Colors.black : Colors.white70,
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
                  ? _buildLeagueContent(context, rivals, playerRival, tierColor, isCompact)
                  : _buildQuestsContent(context, isCompact),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeagueContent(
    BuildContext context,
    List<dynamic> rivals,
    dynamic playerRival,
    Color tierColor,
    bool isCompact,
  ) {
    return Column(
      children: [
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

        SizedBox(height: isCompact ? 6 : 10),

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

        SizedBox(height: isCompact ? 6 : 10),

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
        Divider(color: Colors.white12, height: isCompact ? 8 : 14),

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
          padding: EdgeInsets.symmetric(horizontal: isCompact ? 16 : 20, vertical: isCompact ? 8 : 12),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                if (widget.onJoinTournament != null) {
                  widget.onJoinTournament!();
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
                  border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.5)),
                ),
                child: Icon(Icons.assignment_turned_in_rounded, color: const Color(0xFF00E5FF), size: isCompact ? 20 : 24),
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
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white70),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),

        SizedBox(height: isCompact ? 8 : 12),

        // Quests Scroll List
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
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
              const SizedBox(height: 12),

              // Daily Blitz Summary Card
              Container(
                padding: EdgeInsets.all(isCompact ? 10 : 12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF261805), Color(0xFF140D1E)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFF9100).withValues(alpha: 0.5)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF9100).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.bolt_rounded, color: Color(0xFFFF9100), size: 22),
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
                            style: const TextStyle(color: Colors.white70, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
                        widget.save.isDailyBlitzCompletedToday ? 'TAMAM ✓' : '250G + 3İ',
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
              const SizedBox(height: 14),
            ],
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
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0x3300E676),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF00E676)),
                  ),
                  child: const Text(
                    'TAMAMLANDI ✓',
                    style: TextStyle(color: Color(0xFF00E676), fontWeight: FontWeight.bold, fontSize: 10),
                  ),
                )
              else if (isCompleted)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                  style: const TextStyle(color: Colors.white54, fontWeight: FontWeight.bold, fontSize: 11.5),
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
