import 'package:flutter/material.dart';
import '../engine/audio_manager.dart';
import '../engine/i18n.dart';
import '../storage/save_manager.dart';
import 'kaunos_ui.dart';

class DailyQuestsDialog extends StatefulWidget {
  final VoidCallback? onPlayToday;

  const DailyQuestsDialog({super.key, this.onPlayToday});

  static Future<void> show(BuildContext context, {VoidCallback? onPlayToday}) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => DailyQuestsDialog(onPlayToday: onPlayToday),
    );
  }

  @override
  State<DailyQuestsDialog> createState() => _DailyQuestsDialogState();
}

class _DailyQuestsDialogState extends State<DailyQuestsDialog> {
  final SaveManager _save = SaveManager.instance;
  String? _justClaimedId;
  bool _isClaiming = false;

  void _claimQuest(String questId) async {
    if (_isClaiming) return;
    _isClaiming = true;
    try {
      final reward = await _save.claimQuestReward(questId);
      if (!mounted) return;
      if (reward > 0) {
        _justClaimedId = questId;
        AudioManager.instance.playSfx(GameSfx.powerupBuff, playbackRate: 1.0);
        AudioManager.instance.playSfx(GameSfx.bubble, playbackRate: 1.25);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text( ' +$reward ${I18n.tr('quest_gold')}',
              style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFFFFD54F)),
            ),
            backgroundColor: const Color(0xFF161A29),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xFFFFD54F), width: 1.5),
            ),
            duration: const Duration(seconds: 3),
          ),
        );
        setState(() {});
      }
    } finally {
      _isClaiming = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _save,
      builder: (context, _) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF151928), Color(0xFF0F121C)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: const Color(0xFF00E5FF), width: 1.5),
              boxShadow: const [
                BoxShadow(color: Color(0x4400E5FF), blurRadius: 20, spreadRadius: 1),
                BoxShadow(color: Colors.black87, blurRadius: 30, offset: Offset(0, 8)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.assignment_turned_in, color: Color(0xFF00E5FF), size: 24),
                        const SizedBox(width: 8),
                        Text(
                          I18n.tr('quests_title'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                    KaunosPressGlow(
                      isCircle: true,
                      child: IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70),
                        onPressed: () => Navigator.of(context).pop(),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  I18n.tr('quests_desc'),
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),

                if (_save.isAquariumUnlocked) ...[
                  // Quest 1: Feed Fish
                  _buildQuestCard(
                    id: 'feed_fish',
                    title: I18n.tr('quest_feed'),
                    rewardText: '+60 ${I18n.tr('quest_gold')} + 1 ${I18n.tr('food_word')}',
                    current: _save.questFishFed ? 1 : 0,
                    target: 1,
                    icon: Icons.set_meal,
                    color: const Color(0xFF00E5FF),
                  ),
                  const SizedBox(height: 12),
                ],

                // Quest 2: Break 100 Bricks
                _buildQuestCard(
                  id: 'break_bricks',
                  title: I18n.tr('quest_bricks'),
                  rewardText: '+120 ${I18n.tr('quest_gold')}',
                  current: _save.questBricksBroken,
                  target: 100,
                  icon: Icons.view_module,
                  color: const Color(0xFFFFB300),
                ),
                const SizedBox(height: 12),

                // Quest 3: Ad or Victory
                _buildQuestCard(
                  id: 'ad_or_win',
                  title: I18n.tr('quest_win'),
                  rewardText: '+150 ${I18n.tr('quest_gold')}',
                  current: _save.questAdOrWinDone ? 1 : 0,
                  target: 1,
                  icon: Icons.star,
                  color: const Color(0xFFE040FB),
                ),

                if (!_save.isAquariumUnlocked) ...[
                  const SizedBox(height: 12),
                  _buildQuestCard(
                    id: 'feed_fish',
                    title: I18n.tr('quest_feed'),
                    rewardText: '+60 ${I18n.tr('quest_gold')} + 1 ${I18n.tr('food_word')} • Bölüm 5',
                    current: _save.questFishFed ? 1 : 0,
                    target: 1,
                    icon: Icons.set_meal,
                    color: const Color(0xFF00E5FF),
                  ),
                ],

                const SizedBox(height: 16),
                KaunosPressGlow(
                  borderRadius: 12,
                  waveColor: Colors.white54,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(I18n.tr('close'), style: const TextStyle(color: Colors.white54, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
  }) {
    final isClaimed = _save.claimedQuests.contains(id);
    final isCompleted = current >= target;
    final progress = (current / target).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isClaimed ? const Color(0xFF12151F) : const Color(0xFF1B2032),
        borderRadius: BorderRadius.circular(18),
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
                    Text( 'Ödül: $rewardText',
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (isClaimed) ...[
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: _justClaimedId == id ? 1.9 : 1.0, end: 1.0),
                  duration: const Duration(milliseconds: 420),
                  curve: Curves.elasticOut,
                  builder: (context, scale, child) {
                    return Transform.rotate(
                      angle: -0.06,
                      child: Transform.scale(scale: scale, child: child),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _justClaimedId == id ? const Color(0x33FFD54F) : Colors.white10,
                      borderRadius: BorderRadius.circular(12),
                      border: _justClaimedId == id
                          ? Border.all(color: const Color(0xFFFFD54F), width: 1.2)
                          : null,
                    ),
                    child: Text(
                      I18n.tr('quest_claimed'),
                      style: TextStyle(
                        color: _justClaimedId == id ? const Color(0xFFFFD54F) : Colors.white38,
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
              ] else if (isCompleted) ...[
                KaunosPressGlow(
                  borderRadius: 12,
                  waveColor: const Color(0xFF69F0AE),
                  child: ElevatedButton(
                    onPressed: () => _claimQuest(id),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF69F0AE),
                      foregroundColor: const Color(0xFF003314),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      visualDensity: VisualDensity.compact,
                    ),
                    child: Text(
                      I18n.tr('quest_claim'),
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11),
                    ),
                  ),
                ),
              ] else ...[
                Text( '$current / $target',
                  style: const TextStyle(color: Colors.white54, fontWeight: FontWeight.w800, fontSize: 12),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 5,
              backgroundColor: Colors.white10,
              valueColor: AlwaysStoppedAnimation<Color>(isCompleted ? const Color(0xFF69F0AE) : color),
            ),
          ),
          if (_justClaimedId == id) ...[
            const SizedBox(height: 7),
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 550),
              curve: Curves.elasticOut,
              builder: (context, t, child) {
                return Opacity(
                  opacity: t.clamp(0.0, 1.0),
                  child: Transform.scale(scale: 0.5 + 0.5 * t, child: child),
                );
              },
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.star, color: Color(0xFFFFD54F), size: 15),
                  SizedBox(width: 5),
                  Icon(Icons.star, color: Color(0xFFFFF9C4), size: 19),
                  SizedBox(width: 5),
                  Icon(Icons.star, color: Color(0xFFFFD54F), size: 15),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
