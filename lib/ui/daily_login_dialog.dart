import 'package:flutter/material.dart';
import '../engine/ad_manager.dart';
import '../engine/audio_manager.dart';
import '../storage/save_manager.dart';
import 'kaunos_ui.dart';

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

  bool _isClaiming = false;

  void _claimNormalReward() async {
    if (_isClaiming || !_save.canClaimDailyLogin()) return;
    _isClaiming = true;
    try {
      final result = await _save.claimDailyLoginReward(doubleWithAd: false);
      if (!mounted) return;

      if (result['claimed'] == true) {
        AudioManager.instance.playSfx(GameSfx.victory);
        setState(() {});
        _showClaimReveal(result, doubled: false);
      }
    } finally {
      _isClaiming = false;
    }
  }

  /// Shared prize celebration (same shell as the fortune wheel) with
  /// one line per granted reward.
  void _showClaimReveal(Map<String, dynamic> result, {required bool doubled}) {
    final gold = result['gold'];
    final food = result['food'] as int? ?? 0;
    showKaunosRewardReveal(
      context: context,
      accent: KaunosPalette.goldPrimary,
      headline: doubled ? '2X KATLANDI!' : 'GÜNLÜK ÖDÜL!',
      spectacle: doubled,
      visualBuilder: (_) => Container(
        width: 92,
        height: 92,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const RadialGradient(
            colors: [Color(0xFFFFF9C4), Color(0xFFFFB300)],
          ),
          border: Border.all(color: Colors.white70, width: 1.6),
          boxShadow: [
            BoxShadow(color: KaunosPalette.goldPrimary.withValues(alpha: 0.65), blurRadius: 18),
          ],
        ),
        child: const Icon(Icons.card_giftcard_rounded, color: Color(0xFF4E2C00), size: 46),
      ),
      lines: [
        KaunosRewardLine(icon: Icons.monetization_on, color: KaunosPalette.goldBorder, text: '+$gold Altın'),
        if (food > 0)
          KaunosRewardLine(icon: Icons.set_meal, color: const Color(0xFF4FC3F7), text: '+$food Balık Yemi'),
        if (result['bonusItem'] != null)
          const KaunosRewardLine(icon: Icons.diamond_rounded, color: Color(0xFFE040FB), text: 'Özel Parça Kazandın!'),
      ],
      footnote: doubled ? '2X ödülün tamamı hesabına geçti!' : 'Seriyi bozma, yarın yine gel!',
      buttonLabel: 'HARİKA!',
    );
  }

  void _watchAdToClaim() {
    AdManager.instance.watchSkippableAd(
      context,
      onSuccess: () async {
        if (!mounted) return;
        Map<String, dynamic> result;
        final alreadyClaimedBase = !_save.canClaimDailyLogin();
        if (alreadyClaimedBase) {
          result = await _save.claimDailyLoginAdBonus();
        } else {
          result = await _save.claimDailyLoginReward(doubleWithAd: true);
        }

        if (!mounted) return;
        if (result['claimed'] == true) {
          AudioManager.instance.playSfx(GameSfx.victory);
          setState(() {});
          _showClaimReveal(result, doubled: true);
        }
      },
      onDismissedEarly: () {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('2X ödülü almak için reklamı tamamlamalısınız.'),
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
        final canClaimBase = _save.canClaimDailyLogin();
        final canClaimAd = _save.canClaimDailyLoginAd();
        final currentDay = _save.currentDailyLoginDay;

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
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Top Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_month, color: Color(0xFFFFD54F), size: 26),
                            const SizedBox(width: 8),
                            Expanded(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: const Text(
                                  'GÜNLÜK GİRİŞ ÖDÜLÜ',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.8,
                                  ),
                                ),
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
                    return _buildDayCard(dayNum, currentDay, canClaimBase);
                  }),
                ),

                const SizedBox(height: 8),

                // Day 7 Grand Reward Card
                _buildDay7Card(currentDay, canClaimBase),

                const SizedBox(height: 10),

                // Helpful Tap Tip when normal reward is available
                if (canClaimBase)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 6),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.touch_app_rounded, size: 14, color: Color(0xFFFFD54F)),
                          SizedBox(width: 4),
                          Text(
                            'Normal almak için bugünkü gün kutusuna dokunun',
                            style: TextStyle(color: Color(0xFFFFD54F), fontSize: 11, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: 8),

                // Action Buttons Area
                if (canClaimAd) ...[
                  Builder(
                    builder: (context) {
                      final baseGold = _save.getBaseGoldForDailyDay(currentDay);
                      final isComplementing = !canClaimBase; // already claimed base, now getting remaining 1x
                      final buttonGoldText = isComplementing ? '+$baseGold ' : '${baseGold * 2} ';
                      final buttonTitle = isComplementing ? ' 2X ÖDÜL AL: $buttonGoldText' : ' 2X KATLA & AL: $buttonGoldText';
                      final buttonSubtitle = isComplementing
                          ? 'Kısa Video İzle, Bugünkü Ödülü 2X\'e Tamamla!' : 'Kısa Video İzle, Bugünkü Ödülü 2\'ye Katla!';

                      return Column(
                        children: [
                          // 2X Video Double Button (Primary, glowing)
                          ScaleTransition(
                            scale: _pulseScale,
                            child: Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFFFD54F), Color(0xFFFFB300), Color(0xFFFF8F00)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: const Color(0xFFFFF9C4), width: 1.5),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFFF8F00).withValues(alpha: 0.5),
                                    blurRadius: 18,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(20),
                                  onTap: _watchAdToClaim,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    child: Column(
                                       children: [
                                        FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(5),
                                                decoration: const BoxDecoration(
                                                  color: Color(0xFF2E1C00),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(Icons.play_arrow_rounded, color: Color(0xFFFFD54F), size: 18),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                buttonTitle,
                                                style: const TextStyle(
                                                  color: Color(0xFF2E1C00),
                                                  fontWeight: FontWeight.w900,
                                                  fontSize: 16,
                                                  letterSpacing: 0.3,
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFD50000),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: const Text( '+2X',
                                                  style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          buttonSubtitle,
                                          style: const TextStyle(
                                            color: Color(0xFF3E2723),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
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
                      );
                    },
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
                        Text( 'Bugünkü ödül alındı! Yarın tekrar gel.',
                          style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w800, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
      },
    );
  }

  Widget _buildDayCard(int dayNum, int currentDay, bool canClaimBase) {
    final isPast = (dayNum < currentDay) || (dayNum == currentDay && !canClaimBase);
    final isToday = (dayNum == currentDay && canClaimBase);

    String rewardText = '';
    IconData icon = Icons.monetization_on;
    Color iconColor = const Color(0xFFFFD54F);

    switch (dayNum) {
      case 1:
        rewardText = '50 ';
        break;
      case 2:
        rewardText = '100 + 2';
        icon = Icons.set_meal;
        iconColor = const Color(0xFF4FC3F7);
        break;
      case 3:
        rewardText = '150 + ';
        icon = Icons.sports_volleyball;
        iconColor = const Color(0xFFFF80AB);
        break;
      case 4:
        rewardText = '200 + ️';
        icon = Icons.favorite;
        iconColor = const Color(0xFFFF5252);
        break;
      case 5:
        rewardText = '300 + ️';
        icon = Icons.view_stream;
        iconColor = const Color(0xFF00E5FF);
        break;
      case 6:
        rewardText = '400 + 3';
        icon = Icons.set_meal;
        iconColor = const Color(0xFF69F0AE);
        break;
    }

    final cardContent = Container(
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
                  color: const Color(0xFFFFD54F).withValues(alpha: 0.35),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text( '$dayNum. GÜN',
                    style: TextStyle(
                      color: isToday ? const Color(0xFFFFD54F) : Colors.white54,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (isToday) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF8F00),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('AL', style: TextStyle(color: Colors.black, fontSize: 8, fontWeight: FontWeight.w900)),
                    ),
                  ],
                ],
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
                color: isPast ? const Color(0xFF69F0AE) : (isToday ? const Color(0xFFFFD54F) : Colors.white),
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );

    if (isToday) {
      return KaunosJuicyInteractive(
        borderRadius: 16,
        waveColor: const Color(0xFFFFD54F),
        onTap: _claimNormalReward,
        child: cardContent,
      );
    }
    return cardContent;
  }

  Widget _buildDay7Card(int currentDay, bool canClaimBase) {
    final isPast = (7 < currentDay) || (7 == currentDay && !canClaimBase);
    final isToday = (7 == currentDay && canClaimBase);

    final cardContent = Container(
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
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    children: [
                      Text( '7. GÜN BÜYÜK ÖDÜL',
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
                        child: const Text( 'EFSANEVİ',
                          style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isPast
                      ? ' Tamamlandı' : ' 600 Altın + 2x Efsanevi Kozmetik Parçası!',
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
            const Icon(Icons.check_circle, color: Color(0xFF69F0AE), size: 22)
          else if (isToday)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
              ),
              child: const Text( 'AL ',
                style: TextStyle(color: Color(0xFFE65100), fontWeight: FontWeight.w900, fontSize: 11),
              ),
            ),
        ],
      ),
    );

    if (isToday) {
      return KaunosJuicyInteractive(
        borderRadius: 18,
        waveColor: const Color(0xFFFFB300),
        isHighStakes: true,
        onTap: _claimNormalReward,
        child: cardContent,
      );
    }
    return cardContent;
  }
}
