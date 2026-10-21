import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../engine/ad_manager.dart';
import '../engine/audio_manager.dart';
import '../storage/save_manager.dart';
import 'daily_login_dialog.dart';
import 'kaunos_ui.dart';

/// Tüm ödülleri (Çark, 7 Günlük Giriş, Ücretsiz Hediye) tek çatı altında toplayan şık Ödül Merkezi
class RewardsHubDialog extends StatelessWidget {
  final SaveManager save;
  final VoidCallback onFortuneWheelTap;

  const RewardsHubDialog({
    super.key,
    required this.save,
    required this.onFortuneWheelTap,
  });

  static Future<void> show(BuildContext context, {
    required SaveManager save,
    required VoidCallback onFortuneWheelTap,
  }) {
    HapticFeedback.selectionClick();
    AudioManager.instance.playSfx(GameSfx.click);
    return showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F1322),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => RewardsHubDialog(
        save: save,
        onFortuneWheelTap: onFortuneWheelTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1322),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: const Color(0x33FFD54F), width: 1.2),
        boxShadow: const [
          BoxShadow(color: Colors.black87, blurRadius: 24, offset: Offset(0, -4)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Çekme Çubuğu
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Başlık
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFD54F), Color(0xFFFF8F00)],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF8F00).withValues(alpha: 0.4),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: const Icon(Icons.card_giftcard_rounded, color: Colors.black, size: 22),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ÖDÜL MERKEZİ',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    ),
                  ),
                  Text(
                    'Günlük hediyelerini topla, gücüne güç kat!',
                    style: TextStyle(color: Colors.white60, fontSize: 11.5),
                  ),
                ],
              ),
              const Spacer(),
              KaunosPressGlow(
                isCircle: true,
                child: IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white60),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // 1. Şans Çarkı Kartı
          ListenableBuilder(
            listenable: save,
            builder: (context, _) {
              final spinsLeft = save.remainingWheelSpins;
              final hasSpins = spinsLeft > 0;

              return _buildRewardTile(
                icon: Icons.motion_photos_on_rounded,
                iconGradient: [const Color(0xFF00E5FF), const Color(0xFFD500F9)],
                title: 'Şans Çarkı',
                subtitle: hasSpins
                    ? '$spinsLeft / ${SaveManager.maxDailyWheelSpins} Çevirme Hakkın Var!'
                    : 'Bugünkü tüm haklar kullanıldı',
                badgeText: hasSpins ? '$spinsLeft HAK' : 'BİTTİ',
                badgeColor: hasSpins ? const Color(0xFF00E5FF) : Colors.white24,
                buttonText: hasSpins ? 'ÇEVİR' : 'TAMAMLANDI',
                buttonColor: hasSpins ? const Color(0xFF00E5FF) : Colors.white12,
                textColor: hasSpins ? Colors.black : Colors.white38,
                onTap: () {
                  Navigator.of(context).pop();
                  onFortuneWheelTap();
                },
              );
            },
          ),

          const SizedBox(height: 12),

          // 2. 7 Günlük Giriş Serisi Kartı
          ListenableBuilder(
            listenable: save,
            builder: (context, _) {
              final canClaim = save.canClaimDailyLogin();
              final day = save.dailyLoginClaimedDay;

              return _buildRewardTile(
                icon: Icons.calendar_month_rounded,
                iconGradient: [const Color(0xFFFFD54F), const Color(0xFFFF6D00)],
                title: '7 Günlük Giriş Serisi',
                subtitle: canClaim ? 'Bugünün ödülü hazır!' : 'Gün $day tamamlandı',
                badgeText: canClaim ? 'HAZIR!' : 'GÜN $day',
                badgeColor: canClaim ? const Color(0xFFFFD54F) : Colors.white24,
                buttonText: canClaim ? 'AL' : 'GÖRÜNTÜLE',
                buttonColor: canClaim ? const Color(0xFFFFD54F) : const Color(0xFF1E2638),
                textColor: canClaim ? Colors.black : Colors.white70,
                onTap: () {
                  Navigator.of(context).pop();
                  DailyLoginDialog.show(context);
                },
              );
            },
          ),

          const SizedBox(height: 12),

          // 3. Ücretsiz Altın Hediyesi Kartı (AdMob)
          ListenableBuilder(
            listenable: AdManager.instance,
            builder: (context, _) {
              final cooldown = AdManager.instance.remainingCooldownSeconds;
              final onCooldown = cooldown > 0;
              final isLoading = AdManager.instance.isLoading || AdManager.instance.isShowing;
              final isReady = !onCooldown && !isLoading;

              String sub;
              if (isLoading) {
                sub = 'Hazırlanıyor...';
              } else if (onCooldown) {
                final m = cooldown ~/ 60;
                final s = cooldown % 60;
                sub = 'Kalan süre: ${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
              } else {
                sub = 'Kısa video izle, anında +100 Altın kazan!';
              }

              return _buildRewardTile(
                icon: Icons.monetization_on_rounded,
                iconGradient: [const Color(0xFF69F0AE), const Color(0xFF00E676)],
                title: 'Ücretsiz Altın Sandığı',
                subtitle: sub,
                badgeText: '+100 🟡',
                badgeColor: isReady ? const Color(0xFF00E676) : Colors.white24,
                buttonText: isReady ? 'KAZAN' : (onCooldown ? 'BEKLE' : '...'),
                buttonColor: isReady ? const Color(0xFF00E676) : Colors.white12,
                textColor: isReady ? Colors.black : Colors.white38,
                onTap: () {
                  if (isReady) {
                    Navigator.of(context).pop();
                    AdManager.instance.watchAdForGold(
                      context,
                      onSuccess: (reward) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(' +$reward Altın Hesabınıza Eklendi!'),
                            backgroundColor: const Color(0xFF161A29),
                          ),
                        );
                      },
                      onDismissedEarly: () {},
                    );
                  }
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRewardTile({
    required IconData icon,
    required List<Color> iconGradient,
    required String title,
    required String subtitle,
    required String badgeText,
    required Color badgeColor,
    required String buttonText,
    required Color buttonColor,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF151A2E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: iconGradient),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.black, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: badgeColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: badgeColor.withValues(alpha: 0.6)),
                      ),
                      child: Text(
                        badgeText,
                        style: TextStyle(
                          color: badgeColor,
                          fontSize: 8.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.white60, fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: buttonColor,
              foregroundColor: textColor,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              minimumSize: const Size(60, 36),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: onTap,
            child: Text(
              buttonText,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11.5),
            ),
          ),
        ],
      ),
    );
  }
}
