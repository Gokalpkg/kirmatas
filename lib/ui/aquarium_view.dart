import 'dart:math';
import 'package:flutter/material.dart';
import '../engine/ad_manager.dart';
import '../engine/audio_manager.dart';
import '../engine/i18n.dart';
import '../models/cosmetics.dart';
import '../models/fish_synergy.dart';
import '../storage/save_manager.dart';
import 'eco_tank_background.dart';
import 'fish_hoard_chest.dart';

class AquariumView extends StatefulWidget {
  final VoidCallback? onBackToMenu;
  const AquariumView({super.key, this.onBackToMenu});

  @override
  State<AquariumView> createState() => _AquariumViewState();
}

class _AquariumViewState extends State<AquariumView> with SingleTickerProviderStateMixin {
  final GlobalKey<EcoTankBackgroundState> _tankKey = GlobalKey<EcoTankBackgroundState>();
  final SaveManager _save = SaveManager.instance;
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseScale;
  bool _isHudExpanded = false; // Start collapsed so the full beautiful aquarium tank is clearly visible!

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
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _onFeedPressed() {
    if (_save.fishFood <= 0) {
      _showGetFoodDialog();
      return;
    }

    _tankKey.currentState?.dropSinglePellet();
  }

  void _showGetFoodDialog() {
    showDialog(
      context: context,
      builder: (dlgContext) => ListenableBuilder(
        listenable: _save,
        builder: (context, _) {
          return Dialog(
            backgroundColor: const Color(0xFF131726),
            insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(26),
              side: const BorderSide(color: Color(0xFF4FC3F7), width: 1.5),
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: Color(0x334FC3F7),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.grain, color: Color(0xFF4FC3F7), size: 22),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text( 'Balık Yemi Mağazası',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 17),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(dlgContext).pop(),
                          icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Current inventory bar
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.grain, color: Color(0xFF4FC3F7), size: 16),
                                const SizedBox(width: 5),
                                Flexible(
                                  child: Text( 'Yem: ${_save.fishFood}',
                                    style: const TextStyle(
                                      color: Color(0xFF4FC3F7),
                                      fontWeight: FontWeight.w900,
                                      fontSize: 13,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(width: 1, height: 16, color: Colors.white24),
                          Expanded(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.monetization_on, color: Color(0xFFFFD54F), size: 16),
                                const SizedBox(width: 5),
                                Flexible(
                                  child: Text( '${_save.gold} ',
                                    style: const TextStyle(
                                      color: Color(0xFFFFD54F),
                                      fontWeight: FontWeight.w900,
                                      fontSize: 13,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Option 1: Watch Ad (Daily 1-per-day Limit)
                    Builder(
                      builder: (ctx) {
                        final canClaim = _save.canClaimDailyFishFoodAd;
                        final isVip = _save.adsRemoved;

                        return Container(
                          decoration: BoxDecoration(
                            gradient: canClaim
                                ? const LinearGradient(
                                    colors: [Color(0xFFFFF176), Color(0xFFFFB300), Color(0xFFFF8F00)],
                                  )
                                : const LinearGradient(
                                    colors: [Color(0xFF263238), Color(0xFF1E272E)],
                                  ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: canClaim ? Colors.transparent : Colors.white12,
                            ),
                            boxShadow: canClaim
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFFFF8F00).withValues(alpha: 0.35),
                                      blurRadius: 10,
                                      offset: const Offset(0, 3),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: !canClaim
                                  ? () {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Günlük yem hakkını zaten aldın. Yarın tekrar gel!'),
                                          backgroundColor: Color(0xFF161A29),
                                        ),
                                      );
                                    }
                                  : () {
                                      final messenger = ScaffoldMessenger.of(context);
                                      Navigator.of(dlgContext).pop();

                                      if (isVip) {
                                        // VIP Instant Claim without ad
                                        _save.recordDailyFishFoodAdClaimed();
                                        _save.addFishFood(3);
                                        AudioManager.instance.playSfx(GameSfx.powerupBuff);
                                        messenger.showSnackBar(
                                          const SnackBar(
                                            content: Text('👑 Reklamsız VIP: +3 Balık Yemi Eklendi!'),
                                            backgroundColor: Color(0xFF00E5FF),
                                          ),
                                        );
                                        return;
                                      }

                                      AdManager.instance.watchSkippableAd(
                                        context,
                                        onSuccess: () async {
                                          await _save.recordDailyFishFoodAdClaimed();
                                          await _save.addFishFood(3);
                                          AudioManager.instance.playSfx(GameSfx.powerupBuff);
                                          if (mounted) {
                                            messenger.showSnackBar(
                                              const SnackBar(
                                                content: Text(' +3 Balık Yemi Hesabınıza Eklendi!'),
                                                backgroundColor: Color(0xFF161A29),
                                              ),
                                            );
                                          }
                                        },
                                        onDismissedEarly: () {},
                                      );
                                    },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                child: Row(
                                  children: [
                                    Icon(
                                      canClaim
                                          ? (isVip ? Icons.workspace_premium_rounded : Icons.fast_forward_rounded)
                                          : Icons.check_circle_outline_rounded,
                                      color: canClaim ? const Color(0xFF2E1C00) : Colors.white38,
                                      size: 28,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            canClaim
                                                ? (isVip ? '👑 VIP Yem: +3 Yem Al' : 'Kısa Reklam İzle -> +3 Yem Al')
                                                : 'Bugünkü Yem Ödülü Alındı',
                                            style: TextStyle(
                                              color: canClaim ? const Color(0xFF2E1C00) : Colors.white54,
                                              fontWeight: FontWeight.w900,
                                              fontSize: 13.5,
                                            ),
                                          ),
                                          Text(
                                            canClaim
                                                ? (isVip ? 'Günde 1 Kez • Reklamsız Anında!' : 'Günde 1 Kez • Geçilebilir Reklam')
                                                : 'Günde 1 kez alınabilir • Yarın tekrar gel!',
                                            style: TextStyle(
                                              color: canClaim ? const Color(0xFF4E342E) : Colors.white30,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 10.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      canClaim ? (isVip ? 'VIP AL' : 'ÜCRETSİZ') : 'ALINDI',
                                      style: TextStyle(
                                        color: canClaim ? const Color(0xFF2E1C00) : Colors.white38,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
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

                    _buildFoodBuyTile(
                      dlgContext: dlgContext,
                      count: 3,
                      cost: 50,
                      subtitle: 'Küçük Paket (50 )',
                    ),
                    const SizedBox(height: 8),
                    _buildFoodBuyTile(
                      dlgContext: dlgContext,
                      count: 10,
                      cost: 140,
                      subtitle: 'Avantajlı Paket (140 )',
                      badge: 'İNDİRİMLİ',
                    ),
                    const SizedBox(height: 8),
                    _buildFoodBuyTile(
                      dlgContext: dlgContext,
                      count: 25,
                      cost: 300,
                      subtitle: 'Süper Paket (300 )',
                      badge: 'EN İYİ FİYAT',
                    ),
                  ],
                ),
              ),
            ),
          );
        },
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
          final bought = await _save.buyFishFoodWithGold(count: count, cost: cost);
          if (bought) {
            AudioManager.instance.playSfx(GameSfx.powerupBuff);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(' +$count Balık Yemi Satın Alındı! (-$cost )'),
                  backgroundColor: const Color(0xFF161A29),
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          } else if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Yeterli altınınız yok ($cost Altın gerekli).'),
                backgroundColor: const Color(0xFF1E2438),
                duration: const Duration(seconds: 2),
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
              const Icon(Icons.grain, color: Color(0xFF4FC3F7), size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text( '+$count Yem',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
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
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: canAfford ? const Color(0xFFFFD54F) : Colors.white12,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text( '$cost ',
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
        final fedCount = _save.fedFishCount;
        final totalFish = _save.unlockedFish.length;

        return Scaffold(
          body: EcoTankBackground(
            key: _tankKey,
            interactive: true,
            child: SafeArea(
              child: Stack(
                children: [
                  // Top Bar (Overflow-safe)
                  Positioned(
                    top: 10,
                    left: 12,
                    right: 12,
                    child: Row(
                      children: [
                        SizedBox(
                          width: 38,
                          height: 38,
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
                            style: IconButton.styleFrom(backgroundColor: const Color(0x80000000)),
                            onPressed: () {
                              if (widget.onBackToMenu != null) {
                                widget.onBackToMenu!();
                              } else if (Navigator.of(context).canPop()) {
                                Navigator.of(context).pop();
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0x80000000),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: const Color(0x334FC3F7)),
                            ),
                            child: Text(
                              I18n.tr('aquarium_title'),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF4FC3F7),
                                fontWeight: FontWeight.w900,
                                fontSize: 12,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Food Pill
                        GestureDetector(
                          onTap: _showGetFoodDialog,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0x990D1B2A),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0x664FC3F7)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.grain, color: Color(0xFF4FC3F7), size: 15),
                                const SizedBox(width: 4),
                                Text( '${_save.fishFood}',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12),
                                ),
                                const SizedBox(width: 3),
                                const Icon(Icons.add_circle, color: Color(0xFF4FC3F7), size: 14),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        // Gold Pill
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0x990D1B2A),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0x55FFD54F)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.monetization_on, color: Color(0xFFFFD54F), size: 15),
                              const SizedBox(width: 4),
                              Text( '${_save.gold}',
                                style: const TextStyle(color: Color(0xFFFFD54F), fontWeight: FontWeight.w900, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Bottom Sunken Aquarium Treasure Chest (Resting on sand seabed)
                  Positioned(
                    bottom: max(8.0, MediaQuery.of(context).padding.bottom + 2.0),
                    right: 12,
                    child: FishHoardChest(save: _save),
                  ),

                  // Bottom Compact Floating Toolbar & Optional Expanded Detail Drawer
                  Positioned(
                    bottom: max(12.0, MediaQuery.of(context).padding.bottom + 6.0),
                    left: 12,
                    right: 98,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Collapsible Information & Detail Card (Only visible when user toggles or wants details)
                        AnimatedCrossFade(
                          duration: const Duration(milliseconds: 250),
                          crossFadeState: _isHudExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                          firstChild: const SizedBox.shrink(),
                          secondChild: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xCC0B151C),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: const Color(0x444FC3F7), width: 1.2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.35),
                                  blurRadius: 12,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.water_drop_rounded, color: Color(0xFF4FC3F7), size: 16),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text( 'Beslenen Balık: $fedCount / $totalFish',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900),
                                      ),
                                    ),
                                  ],
                                ),
                                Builder(
                                  builder: (_) {
                                    final buffs = FishSynergyBuffs.calculate(_save);
                                    if (buffs.activeBuffDescriptions.isEmpty) {
                                      return const SizedBox.shrink();
                                    }
                                    return Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const SizedBox(height: 8),
                                        const Divider(color: Colors.white24, height: 1),
                                        const SizedBox(height: 6),
                                        const Row(
                                          children: [
                                            Icon(Icons.auto_awesome, color: Color(0xFFFFD54F), size: 14),
                                            SizedBox(width: 5),
                                            Text(
                                              'Aktif Oyun Sinerjileri:',
                                              style: TextStyle(
                                                color: Color(0xFFFFD54F),
                                                fontWeight: FontWeight.w900,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        ...buffs.activeBuffDescriptions.map(
                                          (desc) => Padding(
                                            padding: const EdgeInsets.only(left: 4, top: 2),
                                            child: Text(
                                              '• $desc',
                                              style: const TextStyle(
                                                color: Colors.white70,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Ultra-Compact Translucent Floating Bottom Pill Bar (Does NOT block the aquarium!)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0x880A1218),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: const Color(0x334FC3F7), width: 1.0),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              // 1. Info / Status Toggle Pill
                              GestureDetector(
                                onTap: () => setState(() => _isHudExpanded = !_isHudExpanded),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                  decoration: BoxDecoration(
                                    color: _isHudExpanded ? const Color(0x334FC3F7) : Colors.black38,
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(color: _isHudExpanded ? const Color(0x884FC3F7) : Colors.white12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        _isHudExpanded ? Icons.keyboard_arrow_down : Icons.info_outline_rounded,
                                        color: const Color(0xFF4FC3F7),
                                        size: 16,
                                      ),
                                      const SizedBox(width: 4),
                                      Text( '$fedCount/$totalFish ',
                                        style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w800),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),

                              // 2. Feed Action Button (Main Hero)
                              Expanded(
                                flex: 6,
                                child: ScaleTransition(
                                  scale: _pulseScale,
                                  child: ElevatedButton.icon(
                                    onPressed: _onFeedPressed,
                                    icon: Icon(
                                      _save.fishFood <= 0 ? Icons.add_shopping_cart : Icons.grain,
                                      size: 15,
                                    ),
                                    label: Text(
                                      _save.fishFood <= 0 ? 'Yem Al' : 'Yem At (${_save.fishFood})',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11.5),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _save.fishFood <= 0 ? const Color(0xD9FF9800) : const Color(0xCC00ACC1),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                      elevation: 0,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),

                              // 3. Compact Fish Encyclopedia Button
                              IconButton(
                                tooltip: 'Balık Koleksiyonu',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.black38,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    side: const BorderSide(color: Colors.white12),
                                  ),
                                ),
                                icon: const Icon(Icons.collections_bookmark_rounded, color: Colors.white70, size: 17),
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
                              ),
                            ],
                          ),
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
                Text( '${save.unlockedFish.length} / ${FishItem.allFish.length}',
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
                          owned ? '${fish.rarity.label} • +${fish.goldReward} ' : 'Kilitli',
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
