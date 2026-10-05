import 'package:flutter/material.dart';
import '../engine/audio_manager.dart';
import '../storage/save_manager.dart';

class DailyQuestsDialog extends StatefulWidget {
  const DailyQuestsDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => const DailyQuestsDialog(),
    );
  }

  @override
  State<DailyQuestsDialog> createState() => _DailyQuestsDialogState();
}

class _DailyQuestsDialogState extends State<DailyQuestsDialog> {
  final SaveManager _save = SaveManager.instance;

  void _claimQuest(String questId) async {
    final reward = await _save.claimQuestReward(questId);
    if (!mounted) return;
    if (reward > 0) {
      AudioManager.instance.playSfx(GameSfx.powerupBuff);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '🎉 +$reward Altın Hesabınıza Eklendi!',
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
                    const Row(
                      children: [
                        Icon(Icons.assignment_turned_in, color: Color(0xFF00E5FF), size: 24),
                        SizedBox(width: 8),
                        Text(
                          'GÜNLÜK GÖREVLER',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: () => Navigator.of(context).pop(),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Her gece yenilenen görevleri tamamla, kasana ekstra altın ve yem ekle!',
                  style: TextStyle(color: Colors.white60, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 18),

                // Quest 1: Feed Fish
                _buildQuestCard(
                  id: 'feed_fish',
                  title: 'Akvaryum Balıklarını Besle',
                  rewardText: '+60 🪙 + 1 Yem 🌾',
                  current: _save.questFishFed ? 1 : 0,
                  target: 1,
                  icon: Icons.set_meal,
                  color: const Color(0xFF00E5FF),
                ),
                const SizedBox(height: 12),

                // Quest 2: Break 100 Bricks
                _buildQuestCard(
                  id: 'break_bricks',
                  title: '100 Adet Tuğla Kır',
                  rewardText: '+120 🪙',
                  current: _save.questBricksBroken,
                  target: 100,
                  icon: Icons.view_module,
                  color: const Color(0xFFFFB300),
                ),
                const SizedBox(height: 12),

                // Quest 3: Ad or Victory
                _buildQuestCard(
                  id: 'ad_or_win',
                  title: 'Reklam İzle veya Bölüm Kazan',
                  rewardText: '+150 🪙',
                  current: _save.questAdOrWinDone ? 1 : 0,
                  target: 1,
                  icon: Icons.star,
                  color: const Color(0xFFE040FB),
                ),

                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Kapat', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold)),
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
        color: const Color(0xFF1B2032),
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
                    Text(
                      'Ödül: $rewardText',
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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'ALINDI',
                    style: TextStyle(color: Colors.white38, fontWeight: FontWeight.w900, fontSize: 11),
                  ),
                ),
              ] else if (isCompleted) ...[
                ElevatedButton(
                  onPressed: () => _claimQuest(id),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF69F0AE),
                    foregroundColor: const Color(0xFF003314),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text(
                    'ÖDÜLÜ AL',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11),
                  ),
                ),
              ] else ...[
                Text(
                  '$current / $target',
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
        ],
      ),
    );
  }
}
