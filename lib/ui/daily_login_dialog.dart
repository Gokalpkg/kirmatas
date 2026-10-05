import 'package:flutter/material.dart';
import '../engine/ad_manager.dart';
import '../engine/audio_manager.dart';
import '../storage/save_manager.dart';

class DailyLoginDialog extends StatefulWidget {
  const DailyLoginDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => const DailyLoginDialog(),
    );
  }

  @override
  State<DailyLoginDialog> createState() => _DailyLoginDialogState();
}

class _DailyLoginDialogState extends State<DailyLoginDialog> with SingleTickerProviderStateMixin {
  final SaveManager _save = SaveManager.instance;
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseScale;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseScale = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _claimReward({bool doubleWithAd = false}) async {
    final result = await _save.claimDailyLoginReward(doubleWithAd: doubleWithAd);
    if (!mounted) return;

    if (result['claimed'] == true) {
      AudioManager.instance.playSfx(GameSfx.victory);
      final gold = result['gold'];
      final food = result['food'] as int? ?? 0;
      final isDoubled = result['isDoubled'] == true;

      String message = '🎉 +$gold Altın';
      if (food > 0) message += ', +$food Balık Yemi 🌾';
      if (result['bonusItem'] != null) message += ' ve Özel Parça';
      message += ' Kazandınız!';
      if (isDoubled) message += ' (2X KATLANDI!)';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFFFFD54F)),
          ),
          backgroundColor: const Color(0xFF161A29),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFFFD54F), width: 1.5),
          ),
          duration: const Duration(seconds: 4),
        ),
      );
      setState(() {});
    }
  }

  void _watchAdToDouble() {
    AdManager.instance.watchAdForGold(
      context,
      onSuccess: (_) {
        _claimReward(doubleWithAd: true);
      },
      onDismissedEarly: () {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('2X ödülü almak için videoyu sonuna kadar izlemelisiniz.'),
            backgroundColor: Color(0xFF1E2438),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _save,
      builder: (context, _) {
        final canClaim = _save.canClaimDailyLogin();
        final currentDay = _save.dailyLoginStreak.clamp(1, 7);

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF16192E), Color(0xFF0F111E)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: const Color(0xFFFFD54F), width: 1.8),
              boxShadow: const [
                BoxShadow(color: Color(0x66FFD54F), blurRadius: 24, spreadRadius: 1),
                BoxShadow(color: Colors.black87, blurRadius: 30, offset: Offset(0, 10)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.calendar_month, color: Color(0xFFFFD54F), size: 26),
                        SizedBox(width: 8),
                        Text(
                          'GÜNLÜK GİRİŞ ÖDÜLÜ',
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
                  'Her gün oyuna gir, seriyi bozma ve büyük ödülleri topla!',
                  style: TextStyle(color: Colors.white60, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),

                // Days Grid (Days 1 to 6 in 2x3, Day 7 as bottom banner)
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 0.95,
                  children: List.generate(6, (index) {
                    final dayNum = index + 1;
                    return _buildDayCard(dayNum, currentDay, canClaim);
                  }),
                ),

                const SizedBox(height: 8),

                // Day 7 Grand Reward Card
                _buildDay7Card(currentDay, canClaim),

                const SizedBox(height: 18),

                // Action Buttons
                if (canClaim) ...[
                  Row(
                    children: [
                      // Normal Claim
                      Expanded(
                        flex: 4,
                        child: OutlinedButton(
                          onPressed: () => _claimReward(doubleWithAd: false),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.white24, width: 1.5),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: const Text(
                            'Normal Al',
                            style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w800, fontSize: 13),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // 2X Video Double
                      Expanded(
                        flex: 6,
                        child: ScaleTransition(
                          scale: _pulseScale,
                          child: ElevatedButton(
                            onPressed: _watchAdToDouble,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFFB300),
                              foregroundColor: const Color(0xFF2E1C00),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              elevation: 6,
                              shadowColor: const Color(0xFFFFB300).withValues(alpha: 0.6),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.play_circle_fill, size: 18, color: Color(0xFF2E1C00)),
                                SizedBox(width: 6),
                                Text(
                                  '2X KATLA & AL!',
                                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E2438),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle, color: Color(0xFF69F0AE), size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Bugünkü ödül alındı! Yarın tekrar gel.',
                          style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w800, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDayCard(int dayNum, int currentDay, bool canClaim) {
    final isPast = (dayNum < currentDay) || (dayNum == currentDay && !canClaim);
    final isToday = (dayNum == currentDay && canClaim);

    String rewardText = '';
    IconData icon = Icons.monetization_on;
    Color iconColor = const Color(0xFFFFD54F);

    switch (dayNum) {
      case 1:
        rewardText = '50 🪙';
        break;
      case 2:
        rewardText = '100🪙 + 2🌾';
        icon = Icons.set_meal;
        iconColor = const Color(0xFF4FC3F7);
        break;
      case 3:
        rewardText = '150🪙 + 🎁';
        icon = Icons.sports_volleyball;
        iconColor = const Color(0xFFFF80AB);
        break;
      case 4:
        rewardText = '200🪙 + ❤️';
        icon = Icons.favorite;
        iconColor = const Color(0xFFFF5252);
        break;
      case 5:
        rewardText = '300🪙 + 🛡️';
        icon = Icons.view_stream;
        iconColor = const Color(0xFF00E5FF);
        break;
      case 6:
        rewardText = '400🪙 + 3🌾';
        icon = Icons.set_meal;
        iconColor = const Color(0xFF69F0AE);
        break;
    }

    return Container(
      decoration: BoxDecoration(
        color: isToday
            ? const Color(0xFF261D00)
            : (isPast ? const Color(0x331E2438) : const Color(0xFF161A28)),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isToday
              ? const Color(0xFFFFD54F)
              : (isPast ? const Color(0x3369F0AE) : Colors.white12),
          width: isToday ? 2.0 : 1.0,
        ),
        boxShadow: isToday
            ? [
                BoxShadow(
                  color: const Color(0xFFFFD54F).withValues(alpha: 0.3),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$dayNum. GÜN',
            style: TextStyle(
              color: isToday ? const Color(0xFFFFD54F) : Colors.white54,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          if (isPast)
            const Icon(Icons.check_circle, color: Color(0xFF69F0AE), size: 22)
          else
            Icon(icon, color: iconColor, size: 22),
          const SizedBox(height: 4),
          Text(
            isPast ? 'Alındı' : rewardText,
            style: TextStyle(
              color: isPast ? const Color(0xFF69F0AE) : Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDay7Card(int currentDay, bool canClaim) {
    final isPast = (7 < currentDay) || (7 == currentDay && !canClaim);
    final isToday = (7 == currentDay && canClaim);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isToday
              ? [const Color(0xFFFFB300), const Color(0xFFFF8F00), const Color(0xFFE65100)]
              : [const Color(0xFF2A1C4E), const Color(0xFF1B1430)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isToday ? const Color(0xFFFFF9C4) : const Color(0xFFFFD54F),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF8F00).withValues(alpha: isToday ? 0.4 : 0.2),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isToday ? Colors.black26 : const Color(0x33FFD54F),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.stars,
              color: isToday ? Colors.white : const Color(0xFFFFD54F),
              size: 26,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '7. GÜN BÜYÜK ÖDÜL',
                      style: TextStyle(
                        color: isToday ? Colors.white : const Color(0xFFFFD54F),
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.redAccent,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'EFSANEVİ',
                        style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  isPast
                      ? '✓ Tamamlandı'
                      : '👑 600 Altın + 2x Efsanevi Kozmetik Parçası!',
                  style: TextStyle(
                    color: isToday ? const Color(0xFFFFFDE7) : Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          if (isPast)
            const Icon(Icons.check_circle, color: Color(0xFF69F0AE), size: 22),
        ],
      ),
    );
  }
}
