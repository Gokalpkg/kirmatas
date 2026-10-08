import 'dart:async';
import 'package:flutter/material.dart';
import '../engine/ad_manager.dart';
import '../engine/audio_manager.dart';
import '../engine/i18n.dart';
import '../models/cosmetics.dart';
import '../storage/save_manager.dart';
import 'eco_tank_background.dart';

class AquariumView extends StatefulWidget {
  const AquariumView({super.key});

  @override
  State<AquariumView> createState() => _AquariumViewState();
}

class _AquariumViewState extends State<AquariumView> with SingleTickerProviderStateMixin {
  final GlobalKey<EcoTankBackgroundState> _tankKey = GlobalKey<EcoTankBackgroundState>();
  final SaveManager _save = SaveManager.instance;
  Timer? _uiTimer;
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseScale;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);

    _pulseScale = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    // Refresh remaining duration countdown every second
    _uiTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _uiTimer?.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  String _formatDuration(int ms) {
    final totalSec = ms ~/ 1000;
    final h = totalSec ~/ 3600;
    final m = (totalSec % 3600) ~/ 60;
    final s = totalSec % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _onFeedPressed() async {
    if (_save.fishFood <= 0) {
      _showGetFoodDialog();
      return;
    }

    if (_save.currentAvailableFishGold > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Önce biriken altınları topla, ardından balıklara yeni yem verebilirsin!'),
          backgroundColor: Color(0xFF1E2438),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final success = await _save.feedFish();
    if (success) {
      _tankKey.currentState?.spawnFeast();
      AudioManager.instance.playSfx(GameSfx.powerupBuff);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.set_meal, color: Color(0xFF4FC3F7), size: 22),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '🌾 Balıklar doydu! 4 saat boyunca altın üretmeye başladılar.',
                    style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF151928),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xFF4FC3F7), width: 1.2),
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _onCollectPressed() async {
    final collected = await _save.collectFishGold();
    if (collected > 0) {
      AudioManager.instance.playSfx(GameSfx.victory);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.monetization_on, color: Color(0xFFFFD54F), size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '🪙 +$collected Altın Kasana Eklendi!\n(Balıklar tekrar acıktı, yeni üretim için yem ver)',
                    style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFFFFD54F)),
                  ),
                ),
              ],
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
      }
    }
  }

  void _showGetFoodDialog() {
    showDialog(
      context: context,
      builder: (dlgContext) => AlertDialog(
        backgroundColor: const Color(0xFF131726),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(26),
          side: const BorderSide(color: Color(0xFF4FC3F7), width: 1.5),
        ),
        title: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Color(0x334FC3F7),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.set_meal, color: Color(0xFF4FC3F7), size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Balık Yemi Temin Et',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Current inventory bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black45,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.set_meal, color: Color(0xFF4FC3F7), size: 16),
                      const SizedBox(width: 5),
                      Text('Yem: ${_save.fishFood}', style: const TextStyle(color: Color(0xFF4FC3F7), fontWeight: FontWeight.w900, fontSize: 13)),
                    ],
                  ),
                  Container(width: 1, height: 14, color: Colors.white24),
                  Row(
                    children: [
                      const Icon(Icons.monetization_on, color: Color(0xFFFFD54F), size: 16),
                      const SizedBox(width: 5),
                      Text('${_save.gold} 🪙', style: const TextStyle(color: Color(0xFFFFD54F), fontWeight: FontWeight.w900, fontSize: 13)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Balıkların acıktığında yem vererek altın üretimini başlatabilirsin:',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 14),

              // Option 1: Watch Ad (High Yield)
              Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFF176), Color(0xFFFFB300), Color(0xFFFF8F00)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF8F00).withValues(alpha: 0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      Navigator.of(dlgContext).pop();
                      AdManager.instance.watchHighYieldAd(
                        context,
                        onSuccess: () async {
                          await _save.addFishFood(3);
                          AudioManager.instance.playSfx(GameSfx.powerupBuff);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('🌾 +3 Balık Yemi Hesabınıza Eklendi!'),
                                backgroundColor: Color(0xFF161A29),
                              ),
                            );
                          }
                        },
                        onDismissedEarly: () {},
                      );
                    },
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: Row(
                        children: [
                          Icon(Icons.play_circle_fill, color: Color(0xFF2E1C00), size: 28),
                          SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Reklam İzle -> +3 Yem Al',
                                  style: TextStyle(color: Color(0xFF2E1C00), fontWeight: FontWeight.w900, fontSize: 13.5),
                                ),
                                Text(
                                  'Tamamen Ücretsiz!',
                                  style: TextStyle(color: Color(0xFF4E342E), fontWeight: FontWeight.w700, fontSize: 10.5),
                                ),
                              ],
                            ),
                          ),
                          Text('ÜCRETSİZ', style: TextStyle(color: Color(0xFF2E1C00), fontWeight: FontWeight.w900, fontSize: 11)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 14),
              const Row(
                children: [
                  Expanded(child: Divider(color: Colors.white24)),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text('VEYA ALTINLA AL', style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.w900)),
                  ),
                  Expanded(child: Divider(color: Colors.white24)),
                ],
              ),
              const SizedBox(height: 12),

              // Gold Package 1: 3 Food for 50 Gold
              _buildFoodBuyTile(
                dlgContext: dlgContext,
                count: 3,
                cost: 50,
                subtitle: 'Küçük Paket (50 🪙)',
              ),
              const SizedBox(height: 8),

              // Gold Package 2: 10 Food for 140 Gold (Discounted)
              _buildFoodBuyTile(
                dlgContext: dlgContext,
                count: 10,
                cost: 140,
                subtitle: 'Avantajlı Paket (140 🪙)',
                badge: 'İNDİRİMLİ',
              ),
              const SizedBox(height: 8),

              // Gold Package 3: 25 Food for 300 Gold (Super Value)
              _buildFoodBuyTile(
                dlgContext: dlgContext,
                count: 25,
                cost: 300,
                subtitle: 'Süper Paket (300 🪙)',
                badge: 'EN İYİ FİYAT',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFoodBuyTile({
    required BuildContext dlgContext,
    required int count,
    required int cost,
    required String subtitle,
    String? badge,
  }) {
    final canAfford = _save.gold >= cost;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () async {
          Navigator.of(dlgContext).pop();
          final bought = await _save.buyFishFoodWithGold(count: count, cost: cost);
          if (bought) {
            AudioManager.instance.playSfx(GameSfx.powerupBuff);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('🌾 +$count Balık Yemi Satın Alındı! (-$cost 🪙)'),
                  backgroundColor: const Color(0xFF161A29),
                ),
              );
            }
          } else if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Yeterli altınınız yok ($cost Altın gerekli).'),
                backgroundColor: const Color(0xFF1E2438),
              ),
            );
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: canAfford ? const Color(0x554FC3F7) : Colors.white12,
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.set_meal, color: Color(0xFF4FC3F7), size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('+$count Yem', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13)),
                        if (badge != null) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF5252),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              badge,
                              style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900),
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 10.5)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: canAfford ? const Color(0xFFFFD54F) : Colors.white12,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$cost 🪙',
                  style: TextStyle(
                    color: canAfford ? Colors.black : Colors.white38,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _save,
      builder: (context, _) {
        final isHungry = _save.isFishHungry;
        final availableGold = _save.currentAvailableFishGold;
        final hourlyRate = _save.totalFishGoldPerHour.toInt();
        final remainingMs = _save.remainingFedDurationMs;

        return Scaffold(
          body: EcoTankBackground(
            key: _tankKey,
            interactive: true,
            child: SafeArea(
              child: Stack(
                children: [
                  // Top Bar
                  Positioned(
                    top: 10,
                    left: 14,
                    right: 14,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
                          style: IconButton.styleFrom(backgroundColor: const Color(0x66000000)),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0x80000000),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0x334FC3F7)),
                          ),
                          child: Text(
                            I18n.tr('aquarium_title'),
                            style: const TextStyle(
                              color: Color(0xFF4FC3F7),
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            // Food badge
                            GestureDetector(
                              onTap: _showGetFoodDialog,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0x80000000),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0x444FC3F7)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.set_meal, color: Color(0xFF4FC3F7), size: 16),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${_save.fishFood}',
                                      style: const TextStyle(color: Color(0xFF4FC3F7), fontWeight: FontWeight.w900),
                                    ),
                                    const SizedBox(width: 2),
                                    const Icon(Icons.add_circle, color: Color(0xFF4FC3F7), size: 14),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            // Gold badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0x80000000),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0x33FFD54F)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.monetization_on, color: Color(0xFFFFD54F), size: 16),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${_save.gold}',
                                    style: const TextStyle(color: Color(0xFFFFD54F), fontWeight: FontWeight.w900),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Hay Day Production & Feeding Station HUD (Bottom Panel)
                  Positioned(
                    bottom: 20,
                    left: 14,
                    right: 14,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Main Feeding / Harvesting Card
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: isHungry
                                  ? [const Color(0xF0261313), const Color(0xF01A0D0D)]
                                  : [const Color(0xF0102422), const Color(0xF00D1A1A)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: isHungry ? const Color(0xFFFF5252) : const Color(0xFF69F0AE),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: (isHungry ? Colors.redAccent : Colors.tealAccent).withValues(alpha: 0.25),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Status Bar
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        isHungry ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                                        color: isHungry ? const Color(0xFFFF5252) : const Color(0xFF69F0AE),
                                        size: 18,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        isHungry ? '⚠️ BALIKLAR AÇ! (Üretim Durdu)' : '✅ TOK & ALTIN ÜRETİYOR',
                                        style: TextStyle(
                                          color: isHungry ? const Color(0xFFFF5252) : const Color(0xFF69F0AE),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: Colors.black38,
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: const Color(0x334FC3F7)),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.set_meal, color: Color(0xFF4FC3F7), size: 13),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Yem: ${_save.fishFood}',
                                              style: const TextStyle(
                                                color: Color(0xFF4FC3F7),
                                                fontWeight: FontWeight.w900,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '+$hourlyRate 🪙/saat',
                                        style: const TextStyle(
                                          color: Color(0xFFFFD54F),
                                          fontWeight: FontWeight.w900,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),

                              // Info row
                              if (!isHungry) ...[
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '⏳ Kalan Süre: ${_formatDuration(remainingMs)}',
                                      style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                                    ),
                                    Text(
                                      'Biriken: 🪙 +$availableGold',
                                      style: const TextStyle(
                                        color: Color(0xFFFFD54F),
                                        fontWeight: FontWeight.w900,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                              ] else ...[
                                const Text(
                                  'Hay Day Kuralı: Balıklarına yem ver; 4 saat tok kalsınlar ve altın üretsinler!',
                                  style: TextStyle(color: Colors.white70, fontSize: 11),
                                ),
                                const SizedBox(height: 10),
                              ],

                              // Buttons
                              Row(
                                children: [
                                  if (isHungry) ...[
                                    Expanded(
                                      child: ScaleTransition(
                                        scale: _pulseScale,
                                        child: ElevatedButton.icon(
                                          onPressed: _onFeedPressed,
                                          icon: Icon(
                                            _save.fishFood <= 0 ? Icons.add_shopping_cart : Icons.set_meal,
                                            size: 18,
                                          ),
                                          label: Text(
                                            _save.fishFood <= 0
                                                ? '🛒 YEM TÜKENDİ! (Yem Al / Reklam İzle)'
                                                : '🌾 BALIKLARI BESLE (-1 Yem / Kalan: ${_save.fishFood})',
                                            style: const TextStyle(fontWeight: FontWeight.w900),
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: _save.fishFood <= 0 ? const Color(0xFFFF9800) : const Color(0xFFFF7043),
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(vertical: 12),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                            elevation: 4,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ] else ...[
                                    // Collect Button
                                    if (availableGold > 0) ...[
                                      Expanded(
                                        child: ScaleTransition(
                                          scale: _pulseScale,
                                          child: ElevatedButton.icon(
                                            onPressed: _onCollectPressed,
                                            icon: const Icon(Icons.monetization_on, color: Color(0xFF2E1C00)),
                                            label: Text(
                                              '💰 ALTINLARI TOPLA (+ $availableGold 🪙)',
                                              style: const TextStyle(fontWeight: FontWeight.w900),
                                            ),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(0xFFFFD54F),
                                              foregroundColor: const Color(0xFF2E1C00),
                                              padding: const EdgeInsets.symmetric(vertical: 12),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ] else ...[
                                      Expanded(
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(vertical: 11),
                                          decoration: BoxDecoration(
                                            color: Colors.white10,
                                            borderRadius: BorderRadius.circular(16),
                                          ),
                                          child: const Center(
                                            child: Text(
                                              'Altın Üretiliyor... (Birazdan ilk altınlar hazır)',
                                              style: TextStyle(color: Colors.white60, fontSize: 12, fontWeight: FontWeight.w700),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 8),

                        // Secondary Strip (Collection drawer button & Get food button)
                        Row(
                          children: [
                            Expanded(
                              flex: 6,
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  showModalBottomSheet(
                                    context: context,
                                    isScrollControlled: true,
                                    backgroundColor: const Color(0xF00D0F18),
                                    shape: const RoundedRectangleBorder(
                                      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                                    ),
                                    builder: (_) => _buildFishSheet(context, _save),
                                  );
                                },
                                icon: const Icon(Icons.collections_bookmark, size: 16),
                                label: Text(
                                  '${I18n.tr('fish_collection')} (${_save.unlockedFish.length}/${FishItem.allFish.length})',
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11),
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white70,
                                  side: const BorderSide(color: Colors.white24),
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 4,
                              child: ElevatedButton.icon(
                                onPressed: _showGetFoodDialog,
                                icon: const Icon(Icons.add_shopping_cart, size: 15),
                                label: const Text('Yem Al', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF00ACC1),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFishSheet(BuildContext context, SaveManager save) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.72,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  I18n.tr('collected_species'),
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                ),
                Text(
                  '${save.unlockedFish.length} / ${FishItem.allFish.length}',
                  style: const TextStyle(color: Color(0xFF4FC3F7), fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: GridView.builder(
                physics: const BouncingScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 0.92,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: FishItem.allFish.length,
                itemBuilder: (context, index) {
                  final fish = FishItem.allFish[index];
                  final owned = save.unlockedFish.contains(fish.id);

                  return Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: owned ? const Color(0xFF161A28) : const Color(0x66161A28),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: owned ? fish.rarity.primaryColor : Colors.white10,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          height: 38,
                          child: owned
                              ? Image.asset(fish.assetPath, fit: BoxFit.contain)
                              : ColorFiltered(
                                  colorFilter: const ColorFilter.mode(Colors.black54, BlendMode.srcATop),
                                  child: Opacity(
                                    opacity: 0.35,
                                    child: Image.asset(fish.assetPath, fit: BoxFit.contain),
                                  ),
                                ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          fish.name,
                          style: TextStyle(
                            color: owned ? Colors.white : Colors.white38,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          owned ? fish.rarity.label : 'Kilitli',
                          style: TextStyle(
                            color: owned ? fish.rarity.primaryColor : Colors.white24,
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
