import 'package:flutter/material.dart';
import '../engine/ad_manager.dart';
import '../engine/audio_manager.dart';
import '../engine/i18n.dart';
import '../storage/save_manager.dart';
import 'kaunos_ui.dart';

/// Interactive Piggy Bank ("Altın Kumbara") collection dialog.
/// Accumulates gold coin-by-coin as bricks are destroyed in gameplay.
class PiggyBankDialog extends StatefulWidget {
  final SaveManager save;

  const PiggyBankDialog({super.key, required this.save});

  static Future<void> show(BuildContext context, {SaveManager? save}) {
    final s = save ?? SaveManager.instance;
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => PiggyBankDialog(save: s),
    );
  }

  @override
  State<PiggyBankDialog> createState() => _PiggyBankDialogState();
}

class _PiggyBankDialogState extends State<PiggyBankDialog> with SingleTickerProviderStateMixin {
  late final AnimationController _bounceController;
  bool _isClaiming = false;

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _bounceController.dispose();
    super.dispose();
  }

  Future<void> _handleClaim({bool doubleWithAd = false}) async {
    if (_isClaiming) return;
    setState(() => _isClaiming = true);

    if (doubleWithAd) {
      await AdManager.instance.watchHighYieldAd(
        context,
        onSuccess: () async {
          final awarded = await widget.save.smashPiggyBank(doubleReward: true);
          AudioManager.instance.playSfx(GameSfx.explosion);
          AudioManager.instance.playSfx(GameSfx.victory);
          _finishClaim(awarded);
        },
        onDismissedEarly: () {
          if (mounted) setState(() => _isClaiming = false);
        },
      );
      return;
    }

    final awarded = await widget.save.smashPiggyBank(doubleReward: false);
    AudioManager.instance.playSfx(GameSfx.explosion);
    AudioManager.instance.playSfx(GameSfx.victory);
    _finishClaim(awarded);
  }

  void _finishClaim(int awarded) {
    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.savings_rounded, color: KaunosPalette.goldHighlight, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  I18n.bi(
                    'Kumbara kırıldı! +$awarded Altın kazandın!',
                    'Piggy bank smashed! You won +$awarded Gold!',
                  ),
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Rajdhani',
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF10192A),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: KaunosPalette.goldHighlight, width: 1.2),
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final save = widget.save;
    final currentGold = save.piggyBankGold;
    const maxGold = SaveManager.piggyBankMax;
    final progress = (currentGold / maxGold).clamp(0.0, 1.0);
    final canSmash = save.canSmashPiggyBank;
    final isFull = save.isPiggyBankFull;

    return Dialog(
      backgroundColor: const Color(0xFF101422),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: BorderSide(
          color: isFull ? KaunosPalette.goldHighlight : KaunosPalette.goldBorder.withValues(alpha: 0.6),
          width: 1.6,
        ),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 380),
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: const LinearGradient(
            colors: [Color(0xFF171C2E), Color(0xFF0F121E)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          boxShadow: [
            BoxShadow(
              color: isFull ? const Color(0x66FFD54F) : const Color(0x33000000),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header Bar with Close Button
              Row(
                children: [
                  const Icon(Icons.savings_rounded, color: KaunosPalette.goldHighlight, size: 24),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        I18n.bi('ALTIN KUMBARA', 'PIGGY BANK'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'Rajdhani',
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 22),
                    onPressed: () => Navigator.of(context).pop(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            const SizedBox(height: 16),

            // Animated Bouncing Piggy Visual
            AnimatedBuilder(
              animation: _bounceController,
              builder: (context, child) {
                final dy = isFull ? (_bounceController.value * -6.0) : 0.0;
                return Transform.translate(
                  offset: Offset(0, dy),
                  child: child,
                );
              },
              child: Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      KaunosPalette.goldHighlight.withValues(alpha: 0.35),
                      KaunosPalette.goldDeep.withValues(alpha: 0.05),
                    ],
                  ),
                  border: Border.all(
                    color: isFull ? KaunosPalette.goldHighlight : KaunosPalette.goldBorder,
                    width: 2.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: KaunosPalette.goldHighlight.withValues(alpha: isFull ? 0.45 : 0.20),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.savings_rounded,
                    color: KaunosPalette.goldHighlight,
                    size: 50,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Description slogan
            Text(
              I18n.bi(
                'Kırdığın her tuğla kumbarana altın ekler!',
                'Every brick broken saves gold into your vault!',
              ),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 18),

            // Progress Bar and Counter
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      I18n.bi('BİRİKEN ALTIN', 'SAVED GOLD'),
                      style: const TextStyle(
                        color: Colors.white60,
                        fontFamily: 'Rajdhani',
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const KaunosEmblem.coin(size: 14),
                    const SizedBox(width: 4),
                    Text(
                      '$currentGold / $maxGold',
                      style: const TextStyle(
                        color: KaunosPalette.goldHighlight,
                        fontFamily: 'Rajdhani',
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                height: 12,
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: const Color(0xFF090D18),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isFull ? const Color(0xFF00E676) : KaunosPalette.goldHighlight,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Smash Action Buttons
            if (canSmash) ...[
              // Standard Smash Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isClaiming ? null : () => _handleClaim(doubleWithAd: false),
                  icon: const Icon(Icons.flash_on_rounded, color: Colors.black, size: 20),
                  label: Text(
                    I18n.bi(
                      'KUMBARAYI KIR & $currentGold ALTIN AL',
                      'SMASH & COLLECT $currentGold GOLD',
                    ),
                    style: const TextStyle(
                      color: Colors.black,
                      fontFamily: 'Rajdhani',
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: KaunosPalette.goldHighlight,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 5,
                    shadowColor: KaunosPalette.goldHighlight.withValues(alpha: 0.4),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // 2X Rewarded Ad Smash Button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isClaiming ? null : () => _handleClaim(doubleWithAd: true),
                  icon: const Icon(Icons.video_library_rounded, color: Color(0xFF00E5FF), size: 18),
                  label: Text(
                    I18n.bi(
                      '2X İLE BOŞALT: +${currentGold * 2} ALTIN (REKLAM)',
                      'COLLECT 2X: +${currentGold * 2} GOLD (AD)',
                    ),
                    style: const TextStyle(
                      color: Color(0xFF00E5FF),
                      fontFamily: 'Rajdhani',
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.4,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF00E5FF), width: 1.3),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ] else ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white12),
                ),
                child: Center(
                  child: Text(
                    I18n.bi(
                      'Tuğla kırmaya devam et! (En az 50 Altın birikmeli)',
                      'Keep smashing bricks! (Needs at least 50 Gold)',
                    ),
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
}
