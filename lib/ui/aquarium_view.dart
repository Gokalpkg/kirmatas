import 'dart:math';
import 'package:flutter/material.dart';
import '../engine/ad_manager.dart';
import '../engine/audio_manager.dart';
import '../engine/i18n.dart';
import '../models/cosmetics.dart';
import '../storage/save_manager.dart';
import 'eco_tank_background.dart';
import 'fish_hoard_chest.dart';
import 'fish_rig.dart';
import 'kaunos_ui.dart';

enum AquariumTabMode {
  feed,
  finger,
}

class AquariumView extends StatefulWidget {
  final VoidCallback? onBackToMenu;
  const AquariumView({super.key, this.onBackToMenu});

  @override
  State<AquariumView> createState() => _AquariumViewState();
}

/// One gold coin floating from the hoard chest up to the gold pill.
class _FlyingCoin {
  final Offset from;
  final Offset to;
  final double delay; // 0..0.35 of the flight controller
  final double sway;

  const _FlyingCoin({required this.from, required this.to, required this.delay, required this.sway});
}

class _BubbleCoinItem {
  final Key id;
  final Offset from;
  final Offset to;
  final int gold;

  _BubbleCoinItem({
    required this.id,
    required this.from,
    required this.to,
    required this.gold,
  });
}

class _BubbleCoinWidget extends StatefulWidget {
  final _BubbleCoinItem item;
  final VoidCallback onComplete;

  const _BubbleCoinWidget({super.key, required this.item, required this.onComplete});

  @override
  State<_BubbleCoinWidget> createState() => _BubbleCoinWidgetState();
}

class _BubbleCoinWidgetState extends State<_BubbleCoinWidget> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 720));
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInQuad);
    _ctrl.forward().then((_) {
      if (mounted) widget.onComplete();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final t = _anim.value;
        final raw = _ctrl.value;

        // Quadratic Bezier arc outward toward target
        final control = Offset(
          min(widget.item.from.dx, widget.item.to.dx) - 24.0,
          min(widget.item.from.dy, widget.item.to.dy) - 36.0,
        );
        final oneMinusT = 1.0 - t;
        final currentPos = Offset(
          oneMinusT * oneMinusT * widget.item.from.dx +
              2 * oneMinusT * t * control.dx +
              t * t * widget.item.to.dx,
          oneMinusT * oneMinusT * widget.item.from.dy +
              2 * oneMinusT * t * control.dy +
              t * t * widget.item.to.dy,
        );

        final scale = (0.75 + 0.5 * sin(raw * pi)).clamp(0.4, 1.25);
        final opacity = raw > 0.88 ? ((1.0 - raw) / 0.12).clamp(0.0, 1.0) : 1.0;

        // Floating +1 gold text
        final textY = widget.item.from.dy - raw * 48.0;
        final textOpacity = (1.0 - (raw / 0.72)).clamp(0.0, 1.0);

        return Stack(
          children: [
            if (textOpacity > 0.01)
              Positioned(
                left: widget.item.from.dx - 18,
                top: textY - 10,
                child: Opacity(
                  opacity: textOpacity,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '+${widget.item.gold}',
                        style: const TextStyle(
                          color: Color(0xFFFFD54F),
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          shadows: [
                            Shadow(color: Colors.black, blurRadius: 4, offset: Offset(1, 1)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(Icons.star, color: Color(0xFFFFD54F), size: 12),
                    ],
                  ),
                ),
              ),
            Positioned(
              left: currentPos.dx - 9,
              top: currentPos.dy - 9,
              child: Opacity(
                opacity: opacity,
                child: Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const RadialGradient(
                        center: Alignment(-0.35, -0.35),
                        colors: [Color(0xFFFFF9C4), Color(0xFFFFD54F), Color(0xFFF57F17)],
                        stops: [0.0, 0.55, 1.0],
                      ),
                      border: Border.all(color: const Color(0xFFB8860B), width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFFD54F).withValues(alpha: 0.65),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(Icons.star, color: Color(0xFFFFFDE7), size: 10),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _AquariumViewState extends State<AquariumView> with TickerProviderStateMixin {
  final GlobalKey<EcoTankBackgroundState> _tankKey = GlobalKey<EcoTankBackgroundState>();
  final GlobalKey _stackKey = GlobalKey();
  final GlobalKey _goldPillKey = GlobalKey();
  final GlobalKey _chestKey = GlobalKey();
  final SaveManager _save = SaveManager.instance;
  AquariumTabMode _selectedMode = AquariumTabMode.feed;
  bool _isCameraZoomed = false;
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseScale;
  late final AnimationController _coinCtrl;
  final List<_FlyingCoin> _flyingCoins = [];
  final List<_BubbleCoinItem> _bubbleCoins = [];

  void _onOxygenBubblePopped(Offset worldPos, int gold) {
    final stackBox = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    if (stackBox == null || !stackBox.hasSize) return;

    final tankState = _tankKey.currentState;
    final w = stackBox.size.width;
    final h = stackBox.size.height;
    final z = tankState?.cameraZoom ?? 1.0;
    final pan = tankState?.camera.pan ?? Offset.zero;
    final screenX = w / 2.0 + (worldPos.dx - 205.0 + pan.dx) * (w / 410.0) * z;
    final screenY = h / 2.0 + (worldPos.dy - 400.0 + pan.dy) * (h / 800.0) * z;
    final screenPos = Offset(screenX, screenY);
    final to = _centerOf(_goldPillKey) ?? Offset(stackBox.size.width - 55, 30);

    setState(() {
      _bubbleCoins.add(
        _BubbleCoinItem(
          id: UniqueKey(),
          from: screenPos,
          to: to,
          gold: gold,
        ),
      );
    });
  }

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
    _coinCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          setState(() => _flyingCoins.clear());
        }
      });
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _coinCtrl.dispose();
    super.dispose();
  }

  Offset? _centerOf(GlobalKey key) {
    final box = key.currentContext?.findRenderObject() as RenderBox?;
    final stackBox = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || stackBox == null || !box.hasSize) return null;
    return stackBox.globalToLocal(box.localToGlobal(box.size.center(Offset.zero)));
  }

  /// Coins rise slowly from the chest like bubbles surfacing, then
  /// home into the gold pill at the top of the screen.
  void _launchFlyingCoins() {
    final from = _centerOf(_chestKey);
    final to = _centerOf(_goldPillKey);
    if (from == null || to == null) return;
    final rand = Random();
    setState(() {
      _flyingCoins.clear();
      for (var i = 0; i < 14; i++) {
        _flyingCoins.add(_FlyingCoin(
          from: from + Offset((rand.nextDouble() - 0.5) * 32, -8 - rand.nextDouble() * 12),
          to: to,
          delay: i * 0.038,
          sway: (rand.nextDouble() - 0.5) * 55,
        ));
      }
    });
    _coinCtrl.forward(from: 0);
  }

  /// One coin of the flight: phase A rises slowly from the chest like a
  /// bubble surfacing (gentle sine sway), phase B homes into the gold pill.
  Widget _flyingCoinWidget(_FlyingCoin coin) {
    const size = 15.0;
    final raw = ((_coinCtrl.value - coin.delay) / 0.62).clamp(0.0, 1.0);
    if (raw <= 0 || raw >= 1) return const SizedBox.shrink();
    final Offset pos;
    final double scale;
    if (raw < 0.55) {
      // Rising like a bubble toward the surface.
      final t = Curves.easeOut.transform(raw / 0.55);
      final top = coin.from.dy - 95;
      pos = Offset(
        coin.from.dx + sin(t * 5.2 + coin.sway) * 9 + coin.sway * t * 0.35,
        coin.from.dy + (top - coin.from.dy) * t,
      );
      scale = 0.75 + 0.25 * t;
    } else {
      // Homing into the gold counter, accelerating.
      final t = Curves.easeInQuad.transform((raw - 0.55) / 0.45);
      final riseEnd = Offset(
        coin.from.dx + sin(5.2 + coin.sway) * 9 + coin.sway * 0.35,
        coin.from.dy - 95,
      );
      pos = Offset.lerp(riseEnd, coin.to, t)!;
      scale = 1.0 - 0.35 * t;
    }
    final fadeIn = (raw / 0.08).clamp(0.0, 1.0);
    final fadeOut = raw > 0.88 ? (1 - (raw - 0.88) / 0.12) : 1.0;
    return Positioned(
      left: pos.dx - size / 2,
      top: pos.dy - size / 2,
      child: Opacity(
        opacity: fadeIn * fadeOut,
        child: Transform.scale(
          scale: scale,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(
                center: Alignment(-0.35, -0.35),
                colors: [Color(0xFFFFF59D), Color(0xFFFFD54F), Color(0xFFF9A825)],
                stops: [0.0, 0.55, 1.0],
              ),
              border: Border.all(color: const Color(0xFFB8860B), width: 1),
              boxShadow: [
                BoxShadow(color: const Color(0xFFFFD54F).withValues(alpha: 0.55), blurRadius: 7),
              ],
            ),
            child: const Center(
              child: Icon(Icons.star, color: Color(0xFFFFF8E1), size: 8),
            ),
          ),
        ),
      ),
    );
  }

  Widget _statusChip(IconData icon, Color color, String label) {
    return Flexible(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  /// Human-friendly remaining time: "5 sa 12 dk", "42 dk".
  String _fmtRemaining(int ms) {
    if (ms <= 0) return 'şimdi';
    final totalMin = (ms / 60000).ceil();
    final h = totalMin ~/ 60;
    final m = totalMin % 60;
    if (h > 0) return m > 0 ? '$h sa $m dk' : '$h sa';
    return '$m dk';
  }

  void _showGetFoodDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (dlgContext) => ListenableBuilder(
        listenable: _save,
        builder: (context, _) {
          return Container(
            decoration: const BoxDecoration(
              color: Color(0xFF131726),
              borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
              border: Border(top: BorderSide(color: Color(0xFF4FC3F7), width: 1.5)),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Drag handle
                      Center(
                        child: Container(
                          width: 46,
                          height: 4.5,
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
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
                        KaunosCloseButton(
                          onTap: () => Navigator.of(dlgContext).pop(),
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
                                  child: RollingNumberText(
                                    value: _save.gold,
                                    format: (v) => '$v ',
                                    style: const TextStyle(
                                      color: Color(0xFFFFD54F),
                                      fontWeight: FontWeight.w900,
                                      fontSize: 13,
                                    ),
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
                                            content: Text('VIP: +3 Balık Yemi Eklendi!'),
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
                                                ? (isVip ? 'VIP Yem: +3 Yem Al' : 'Kısa Reklam İzle -> +3 Yem Al')
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
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (widget.onBackToMenu != null) {
          widget.onBackToMenu!();
        } else if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      },
      child: ListenableBuilder(
        listenable: _save,
        builder: (context, _) {
          return Scaffold(
          body: EcoTankBackground(
            key: _tankKey,
            interactive: true,
            onBubblePopped: _onOxygenBubblePopped,
            onCameraZoomChanged: (isZoomed, zoom) {
              if (mounted && _isCameraZoomed != isZoomed) {
                setState(() => _isCameraZoomed = isZoomed);
              }
            },
            onOutOfFood: () {
              if (mounted) _showGetFoodDialog();
            },
            onAllFishFed: () {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Color(0x334FC3F7),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.info_outline_rounded, color: Color(0xFF4FC3F7), size: 18),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Bütün balıklar üretimde! Altın hazır olunca topla.',
                            style: TextStyle(
                              color: Color(0xFFE2F1FF),
                              fontWeight: FontWeight.w800,
                              fontSize: 12.5,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                    backgroundColor: const Color(0xEE0A1826),
                    behavior: SnackBarBehavior.floating,
                    elevation: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    duration: const Duration(seconds: 2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                      side: const BorderSide(color: Color(0x664FC3F7), width: 1.2),
                    ),
                  ),
                );
              }
            },
            child: SafeArea(
              child: Stack(
                key: _stackKey,
                children: [
                  // Top Bar: Back button, Lucky Fish Badge / Title, Gold Pill
                  Positioned(
                    top: 10,
                    left: 12,
                    right: 12,
                    child: Row(
                      children: [
                        SizedBox(
                          width: 38,
                          height: 38,
                          child: KaunosPressGlow(
                            isCircle: true,
                            waveColor: const Color(0xFF4FC3F7),
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
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _save.luckyFishId != null
                              ? Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                  decoration: BoxDecoration(
                                    color: const Color(0xDD1A1400),
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(color: const Color(0xFFFFD54F), width: 1.2),
                                    boxShadow: const [
                                      BoxShadow(color: Color(0x44FFD54F), blurRadius: 6),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.star_rounded, size: 15, color: Color(0xFFFFD54F)),
                                      const SizedBox(width: 5),
                                      Flexible(
                                        child: Text(
                                          '★ ${FishItem.getById(_save.luckyFishId!).name} (3x Altın)',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Color(0xFFFFE082),
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 0.3,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : Container(
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
                        // Gold Pill (flying coins land here)
                        Container(
                          key: _goldPillKey,
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
                              RollingNumberText(
                                value: _save.gold,
                                style: const TextStyle(color: Color(0xFFFFD54F), fontWeight: FontWeight.w900, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Floating Centered Control Capsule Bar [ Yem | Parmak | Katalog ]
                  Positioned(
                    top: 56,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: _buildAquariumControlTabs(),
                    ),
                  ),




                  // Flying coins: rise from the chest like bubbles, then
                  // home into the gold pill. Purely visual — the chest
                  // itself credits the gold.
                  Positioned.fill(
                    child: IgnorePointer(
                      child: AnimatedBuilder(
                        animation: _coinCtrl,
                        builder: (context, _) {
                          if (_flyingCoins.isEmpty) return const SizedBox.shrink();
                          return Stack(
                            children: [
                              for (final coin in _flyingCoins) _flyingCoinWidget(coin),
                            ],
                          );
                        },
                      ),
                    ),
                  ),

                  // Flying bubble pop coins with floating +1 gold badge
                  if (_bubbleCoins.isNotEmpty)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Stack(
                          children: [
                            for (final bCoin in _bubbleCoins)
                              _BubbleCoinWidget(
                                key: bCoin.id,
                                item: bCoin,
                                onComplete: () {
                                  if (mounted) {
                                    setState(() => _bubbleCoins.remove(bCoin));
                                  }
                                },
                              ),
                          ],
                        ),
                      ),
                    ),

                  // Bottom Sunken Aquarium Treasure Chest (Clean unobstructed seabed)
                  Positioned(
                    bottom: max(14.0, MediaQuery.of(context).padding.bottom + 6.0),
                    right: 18,
                    child: FishHoardChest(
                      key: _chestKey,
                      save: _save,
                      onCollectStart: _launchFlyingCoins,
                    ),
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

  void _showAquariumCatalogSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => ListenableBuilder(
        listenable: _save,
        builder: (context, _) {
          final sortedFish = [...FishItem.allFish]..sort((a, b) {
              final aOwned = _save.unlockedFish.contains(a.id) ? 0 : 1;
              final bOwned = _save.unlockedFish.contains(b.id) ? 0 : 1;
              if (aOwned != bOwned) return aOwned - bOwned;
              return a.rarity.index - b.rarity.index;
            });
          final ownedCount = _save.unlockedFish.length;
          final totalCount = FishItem.allFish.length;

          return Container(
            height: MediaQuery.of(sheetCtx).size.height * 0.82,
            decoration: const BoxDecoration(
              color: Color(0xF2091724),
              borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
              border: Border(top: BorderSide(color: Color(0xFF4FC3F7), width: 1.5)),
            ),
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4.5,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Header with Close Button
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Color(0x334FC3F7),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.collections_bookmark_rounded, color: Color(0xFF4FC3F7), size: 22),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'BALIK ENSTİTÜSÜ & KATALOG',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
                            ),
                            Text(
                              'Koleksiyon Durumu: $ownedCount / $totalCount Canlı',
                              style: const TextStyle(color: Color(0xFF4FC3F7), fontSize: 11, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                      KaunosCloseButton(onTap: () => Navigator.of(sheetCtx).pop()),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Finger Tool Banner
                  ScaleTransition(
                    scale: _pulseScale,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF006064), Color(0xFF00363A)],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF00E5FF), width: 1.2),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0x3300E5FF),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.touch_app_rounded, color: Color(0xFF00E5FF), size: 20),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'PARMAĞI SEÇ',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12),
                                ),
                                Text(
                                  'Ekrana dokunduğunda balıklar parmağına gelsin!',
                                  style: TextStyle(color: Color(0xFFB2EBF2), fontSize: 9.5),
                                ),
                              ],
                            ),
                          ),
                          KaunosTactileButton.cyan(
                            height: 32,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            onTap: () {
                              Navigator.of(sheetCtx).pop();
                              _tankKey.currentState?.setFingerMode(true);
                              setState(() {
                                _selectedMode = AquariumTabMode.finger;
                              });
                            },
                            child: const Text(
                              'SEÇ',
                              style: TextStyle(color: Color(0xFF00E5FF), fontWeight: FontWeight.w900, fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Ecosystem status chips row
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0x660A1218),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0x334FC3F7)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _statusChip(Icons.hourglass_bottom_rounded, const Color(0xFF4FC3F7),
                            '${_save.producingFishCount} üretimde'),
                        _statusChip(Icons.set_meal_rounded, const Color(0xFFAED581),
                            '${_save.waitingFishCount} bekliyor'),
                        GestureDetector(
                          onTap: () {
                            Navigator.of(sheetCtx).pop();
                            _showGetFoodDialog();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0x33FF9800),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0x66FF9800)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.grain, color: Color(0xFFFFB74D), size: 13),
                                const SizedBox(width: 4),
                                Text(
                                  'Yem: ${_save.fishFood} +',
                                  style: const TextStyle(color: Color(0xFFFFB74D), fontSize: 11, fontWeight: FontWeight.w900),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Progress Bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(5),
                    child: LinearProgressIndicator(
                      value: totalCount == 0 ? 0 : ownedCount / totalCount,
                      minHeight: 6,
                      backgroundColor: Colors.white10,
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4FC3F7)),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Grid
                  Expanded(
                    child: GridView.builder(
                      physics: const BouncingScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        childAspectRatio: 0.92,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      itemCount: sortedFish.length,
                      itemBuilder: (context, index) {
                        final fish = sortedFish[index];
                        final owned = _save.unlockedFish.contains(fish.id);
                        final count = _save.getFishCount(fish.id);
                        return Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: owned ? const Color(0xFF161A28) : const Color(0x66161A28),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: owned ? fish.rarity.primaryColor : Colors.white10,
                            ),
                          ),
                          child: Stack(
                            children: [
                              if (owned && count > 0)
                                Positioned(
                                  top: 0,
                                  right: 0,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: count >= 2 ? const Color(0xFFFFD54F) : const Color(0xFF4FC3F7),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'x$count',
                                      style: const TextStyle(
                                        color: Colors.black,
                                        fontSize: 8.5,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ),
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    height: 40,
                                    child: ProceduralFishPreview(
                                      fishId: fish.id,
                                      size: 40,
                                      lockedSilhouette: !owned,
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
                                    owned ? '${fish.rarity.label} • +${fish.goldReward}' : 'Kilitli',
                                    style: TextStyle(
                                      color: owned ? fish.rarity.primaryColor : Colors.white24,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (owned) ...[
                                    const SizedBox(height: 3),
                                    _fishStateChip(_save, fish.id),
                                  ],
                                ],
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
        },
      ),
    );
  }

  /// Per-fish care-state chip used in the collection sheet.
  Widget _fishStateChip(SaveManager save, String fishId) {
    final state = save.fishCareState(fishId);
    final Color color;
    final String label;
    switch (state) {
      case FishCareState.ready:
        color = const Color(0xFFFFD54F);
        label = 'Altını hazır';
      case FishCareState.producing:
        color = const Color(0xFF4FC3F7);
        label = 'Üretimde • ${_fmtRemaining(save.remainingFishPayoutMs(fishId))}';
      case FishCareState.waiting:
        color = const Color(0xFF90A4AE);
        label = 'Yem bekliyor';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.55), width: 0.7),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: color, fontSize: 7.5, fontWeight: FontWeight.w800),
      ),
    );
  }

  Widget _buildAquariumControlTabs() {
    final isFeed = _selectedMode == AquariumTabMode.feed;
    final isFinger = _selectedMode == AquariumTabMode.finger;

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xD9071520),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x444FC3F7), width: 1.1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. YEM SEKMESİ (Bastığında seçilir, ekrana basıldığında yem atar)
          _buildTabPill(
            isSelected: isFeed,
            icon: Icons.grain,
            label: _save.fishFood > 0 ? 'Yem (${_save.fishFood})' : 'Yem (0)',
            activeColor: const Color(0xFF00E676),
            activeBgColor: const Color(0xD9063820),
            glowColor: const Color(0x6600E676),
            onTap: () {
              if (!isFeed) {
                setState(() => _selectedMode = AquariumTabMode.feed);
                _tankKey.currentState?.setFingerMode(false);
                AudioManager.instance.playSfx(GameSfx.click);
              } else if (_save.fishFood <= 0) {
                _showGetFoodDialog();
              }
            },
          ),
          const SizedBox(width: 4),

          // 2. PARMAK MODU SEKMESİ (Bastığında seçilir, ekrana dokunulduğunda balıklar parmağa gelir)
          _buildTabPill(
            isSelected: isFinger,
            icon: Icons.touch_app_rounded,
            label: 'Parmak',
            activeColor: const Color(0xFF00E5FF),
            activeBgColor: const Color(0xD905333F),
            glowColor: const Color(0x6600E5FF),
            onTap: () {
              if (!isFinger) {
                setState(() => _selectedMode = AquariumTabMode.finger);
                _tankKey.currentState?.setFingerMode(true);
                AudioManager.instance.playSfx(GameSfx.click);
              }
            },
          ),
          const SizedBox(width: 4),

          // 3. KAMERA ZOOM MODU (Kuşbakışı 1.0x / Yakın Plan Detay 1.8x)
          _buildTabPill(
            isSelected: _isCameraZoomed,
            icon: _isCameraZoomed ? Icons.zoom_out_map_rounded : Icons.zoom_in_rounded,
            label: _isCameraZoomed ? '1.8x' : '1.0x',
            activeColor: const Color(0xFFFFD54F),
            activeBgColor: const Color(0xD9332600),
            glowColor: const Color(0x66FFD54F),
            onTap: () {
              _tankKey.currentState?.toggleCameraZoom();
              AudioManager.instance.playSfx(GameSfx.click);
            },
          ),
          const SizedBox(width: 4),

          // Ayraç çizgi
          Container(
            width: 1,
            height: 18,
            color: const Color(0x334FC3F7),
          ),
          const SizedBox(width: 4),

          // 4. KATALOG BUTONU
          _buildCatalogButton(),
        ],
      ),
    );
  }

  Widget _buildTabPill({
    required bool isSelected,
    required IconData icon,
    required String label,
    required Color activeColor,
    required Color activeBgColor,
    required Color glowColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? activeBgColor : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? activeColor : Colors.transparent,
            width: 1.2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: glowColor,
                    blurRadius: 6,
                    spreadRadius: 0.5,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? activeColor : const Color(0x88B0BEC5),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Rajdhani',
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                fontSize: 11,
                letterSpacing: 0.3,
                color: isSelected ? activeColor : const Color(0x99CFD8DC),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCatalogButton() {
    return GestureDetector(
      onTap: () {
        AudioManager.instance.playSfx(GameSfx.click);
        _showAquariumCatalogSheet();
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xD9081E2C),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0x664FC3F7),
            width: 1.1,
          ),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.collections_bookmark_rounded,
              color: Color(0xFF00E5FF),
              size: 14,
            ),
            SizedBox(width: 4),
            Text(
              'Katalog',
              style: TextStyle(
                fontFamily: 'Rajdhani',
                fontWeight: FontWeight.w900,
                fontSize: 11,
                letterSpacing: 0.3,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AquariumBouncingArrow extends StatefulWidget {
  const _AquariumBouncingArrow();

  @override
  State<_AquariumBouncingArrow> createState() => _AquariumBouncingArrowState();
}

class _AquariumBouncingArrowState extends State<_AquariumBouncingArrow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.0, end: 12.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) => Transform.translate(
        offset: Offset(0, _anim.value),
        child: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: const Color(0xFF00E5FF),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00E5FF).withValues(alpha: 0.8),
                blurRadius: 14,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Icon(
            Icons.arrow_downward_rounded,
            color: Color(0xFF05111B),
            size: 24,
          ),
        ),
      ),
    );
  }
}
