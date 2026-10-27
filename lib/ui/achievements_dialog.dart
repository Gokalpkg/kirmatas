import 'dart:math';
import 'package:flutter/material.dart';

import '../engine/achievement_manager.dart';
import '../engine/audio_manager.dart';
import '../engine/play_games_manager.dart';
import '../storage/save_manager.dart';

/// Modal dialog providing comprehensive browsing of all Google Play Games achievements.
class AchievementsDialog extends StatefulWidget {
  final SaveManager save;

  const AchievementsDialog({super.key, required this.save});

  static Future<void> show(BuildContext context, {required SaveManager save}) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AchievementsDialog(save: save),
    );
  }

  @override
  State<AchievementsDialog> createState() => _AchievementsDialogState();
}

class _AchievementsDialogState extends State<AchievementsDialog> {
  final AchievementManager _achievements = AchievementManager.instance;
  final PlayGamesManager _games = PlayGamesManager.instance;

  AchievementCategory? _selectedCategory;
  bool _syncing = false;

  SaveManager get save => widget.save;

  @override
  void initState() {
    super.initState();
    _achievements.evaluateLifetimeStats(save);
  }

  int get _unlockedCount => save.unlockedAchievements.length;

  int get _earnedPoints {
    int sum = 0;
    for (final id in save.unlockedAchievements) {
      final def = _achievements.getById(id);
      if (def != null) sum += def.pointValue;
    }
    return sum;
  }

  int get _earnedXp => _earnedPoints * 100;

  List<AchievementDefinition> get _filteredList {
    if (_selectedCategory == null) return AchievementManager.catalog;
    return AchievementManager.catalog.where((a) => a.category == _selectedCategory).toList();
  }

  String _getCategoryTitle(AchievementCategory cat) {
    switch (cat) {
      case AchievementCategory.firstSteps:
        return 'İlk Adımlar';
      case AchievementCategory.classicProgress:
        return 'Klasik Mod';
      case AchievementCategory.destruction:
        return 'Tuğla Maratonu';
      case AchievementCategory.skillAndCombo:
        return 'Kombo & Beceri';
      case AchievementCategory.economyAquarium:
        return 'Hazine & Akvaryum';
      case AchievementCategory.chaosMode:
        return 'Kaos Modu';
      case AchievementCategory.secretDiscoveries:
        return 'Gizli Keşifler';
    }
  }

  Future<void> _onPlayGamesAction() async {
    AudioManager.instance.playSfx(GameSfx.click);
    if (!_games.signedIn) {
      setState(() => _syncing = true);
      await _games.signIn();
      await _achievements.syncAllWithPlayGames();
      if (mounted) {
        setState(() => _syncing = false);
      }
    } else {
      await _games.showAchievements();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final dialogHeight = min(size.height * 0.88, 720.0);
    final dialogWidth = min(size.width * 0.94, 520.0);

    return Dialog(
      backgroundColor: const Color(0xF70C0F19),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: Color(0x3300E5FF), width: 1.5),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: dialogWidth,
        height: dialogHeight,
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
        child: Column(
          children: [
            // Header Bar
            _buildHeader(theme),
            const SizedBox(height: 12),

            // Summary Stats Card (Score, XP, Play Games button)
            _buildSummaryCard(),
            const SizedBox(height: 12),

            // Category Filter Pills
            _buildCategoryFilterBar(),
            const SizedBox(height: 10),

            // Achievement List
            Expanded(
              child: ListView.separated(
                physics: const BouncingScrollPhysics(),
                itemCount: _filteredList.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final item = _filteredList[index];
                  return _buildAchievementCard(item);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFFFFD700), Color(0xFFFF9100)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFFD700).withValues(alpha: 0.35),
                blurRadius: 10,
                spreadRadius: 1,
              ),
            ],
          ),
          child: const Icon(Icons.emoji_events_rounded, color: Color(0xFF101320), size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'BAŞARIMLAR',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
              Text(
                'Play Games Services • 42 Hedef',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.65),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () {
            AudioManager.instance.playSfx(GameSfx.click);
            Navigator.of(context).pop();
          },
          icon: const Icon(Icons.close_rounded, color: Colors.white70),
          splashRadius: 20,
        ),
      ],
    );
  }

  Widget _buildSummaryCard() {
    final progress = _unlockedCount / AchievementManager.catalog.length;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF151928),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x22FFFFFF)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '$_unlockedCount / ${AchievementManager.catalog.length}',
                          style: const TextStyle(
                            color: Color(0xFF00E5FF),
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '($_earnedPoints / ${AchievementManager.totalPoints} Puan)',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_earnedXp.toString()} / ${AchievementManager.totalXp} XP',
                      style: const TextStyle(
                        color: Color(0xFFFFD54F),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              // Play Games Sync / Show Button
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _syncing ? null : _onPlayGamesAction,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _games.signedIn
                          ? const Color(0x3300E676)
                          : const Color(0x2E00E5FF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _games.signedIn
                            ? const Color(0xFF00E676)
                            : const Color(0xFF00E5FF),
                        width: 1.0,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _games.signedIn
                              ? Icons.cloud_done_rounded
                              : Icons.play_arrow_rounded,
                          color: _games.signedIn
                              ? const Color(0xFF69F0AE)
                              : const Color(0xFF00E5FF),
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _games.signedIn ? 'Play Games' : 'Giriş Yap',
                          style: TextStyle(
                            color: _games.signedIn
                                ? const Color(0xFF69F0AE)
                                : const Color(0xFF00E5FF),
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: const Color(0xFF22293F),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00E5FF)),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilterBar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          _buildFilterChip('Tümü', isSelected: _selectedCategory == null, onTap: () {
            setState(() => _selectedCategory = null);
          }),
          for (final cat in AchievementCategory.values)
            _buildFilterChip(
              _getCategoryTitle(cat),
              isSelected: _selectedCategory == cat,
              onTap: () {
                setState(() => _selectedCategory = cat);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, {required bool isSelected, required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            AudioManager.instance.playSfx(GameSfx.click);
            onTap();
          },
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF00E5FF) : const Color(0xFF181E30),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected ? const Color(0xFF00E5FF) : const Color(0x33FFFFFF),
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? const Color(0xFF0C0F19) : Colors.white70,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAchievementCard(AchievementDefinition item) {
    final isUnlocked = save.unlockedAchievements.contains(item.id);
    final isSecretLocked = item.type == AchievementType.secret && !isUnlocked;
    final isIncremental = item.type == AchievementType.incremental;

    final currentSteps = save.achievementSteps[item.id] ?? 0;
    final clampedSteps = min(currentSteps, item.maxSteps);

    final title = isSecretLocked ? 'Gizli Başarım' : item.name;
    final desc = isSecretLocked
        ? 'Bu gizemli başarımı elde etmek için oyundaki sürprizleri keşfet.'
        : item.description;

    Color iconColor;
    IconData iconData;
    if (isUnlocked) {
      iconColor = const Color(0xFF00E676);
      iconData = Icons.check_circle_rounded;
    } else if (item.type == AchievementType.secret) {
      iconColor = const Color(0xFFBA68C8);
      iconData = Icons.auto_awesome_rounded;
    } else if (isIncremental) {
      iconColor = const Color(0xFF00E5FF);
      iconData = Icons.timelapse_rounded;
    } else {
      iconColor = const Color(0xFFFFD54F);
      iconData = Icons.lock_outline_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isUnlocked ? const Color(0x1F00E676) : const Color(0xFF131724),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isUnlocked
              ? const Color(0x6600E676)
              : (isSecretLocked ? const Color(0x33BA68C8) : const Color(0x1FFFFFFF)),
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: iconColor.withValues(alpha: 0.4)),
                ),
                child: Icon(iconData, color: iconColor, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              color: isUnlocked ? Colors.white : Colors.white.withValues(alpha: 0.85),
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0x2E00E5FF),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '+${item.pointValue} P (${item.xpValue} XP)',
                            style: const TextStyle(
                              color: Color(0xFF00E5FF),
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      desc,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 11,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Incremental Progress Bar
          if (isIncremental && !isUnlocked) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'İlerleme',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '$clampedSteps / ${item.maxSteps}',
                  style: const TextStyle(
                    color: Color(0xFF80D8FF),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: (clampedSteps / item.maxSteps).clamp(0.0, 1.0),
                backgroundColor: const Color(0xFF1E2436),
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00E5FF)),
                minHeight: 4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
