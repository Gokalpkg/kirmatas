import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../engine/i18n.dart';
import '../models/cosmetics.dart';
import '../storage/save_manager.dart';
import 'chest_widget.dart';
import 'crate_opening_dialog.dart';
import 'fortune_wheel_dialog.dart';
import 'rewarded_ad_button.dart';
import 'pixel_art.dart';

class ShopView extends StatefulWidget {
  const ShopView({super.key});

  @override
  State<ShopView> createState() => _ShopViewState();
}

class _ShopViewState extends State<ShopView> with TickerProviderStateMixin {
  late final TabController _tabController;
  late final AnimationController _animController;
  late final AnimationController _purchaseAnimController;
  final GlobalKey _appBarGoldKey = GlobalKey();
  final List<_FlyingCoin> _flyingCoins = [];
  final List<_ImpactSpark> _sparks = [];
  final Set<int> _sparkedCoinIndices = {};
  int? _displayGold;
  bool _isPurchasing = false;
  static const double _purchaseDurationSeconds = 0.95;
  String? _selectedPreviewTrailId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
    _purchaseAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    );
  }

  @override
  void dispose() {
    _purchaseAnimController.dispose();
    _animController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _startPurchaseAnimation({
    required BuildContext targetContext,
    required int cost,
    required Future<void> Function() onComplete,
  }) async {
    final save = SaveManager.instance;
    if (save.gold < cost || _isPurchasing) return;

    final startGold = save.gold;
    final targetGold = max(0, startGold - cost);

    // Get positions
    Offset startPos = const Offset(300, 50);
    final goldRender = _appBarGoldKey.currentContext?.findRenderObject() as RenderBox?;
    if (goldRender != null && goldRender.hasSize) {
      startPos = goldRender.localToGlobal(goldRender.size.center(Offset.zero));
    }

    Offset targetPos = Offset(
      MediaQuery.of(context).size.width / 2,
      MediaQuery.of(context).size.height / 2,
    );
    final targetRender = targetContext.findRenderObject() as RenderBox?;
    if (targetRender != null && targetRender.hasSize) {
      targetPos = targetRender.localToGlobal(targetRender.size.center(Offset.zero));
    }

    // Build coins
    _flyingCoins.clear();
    _sparks.clear();
    _sparkedCoinIndices.clear();

    final rand = Random();
    const count = 16;
    for (int i = 0; i < count; i++) {
      final delay = i * 0.026;
      final duration = 0.40 + rand.nextDouble() * 0.08;
      final midX = (startPos.dx + targetPos.dx) / 2 + (rand.nextDouble() * 110 - 55);
      final midY = min(startPos.dy, targetPos.dy) + (targetPos.dy - startPos.dy) * 0.38 - 35 - rand.nextDouble() * 40;

      _flyingCoins.add(
        _FlyingCoin(
          start: startPos,
          target: targetPos,
          control: Offset(midX, midY),
          delay: delay,
          duration: duration,
          spinSpeed: 16.0 + rand.nextDouble() * 10.0,
          scale: 0.85 + rand.nextDouble() * 0.3,
          initialAngle: rand.nextDouble() * pi * 2,
        ),
      );
    }

    setState(() {
      _isPurchasing = true;
      _displayGold = startGold;
    });

    void listener() {
      if (!mounted) return;
      final t = _purchaseAnimController.value;
      final newDisplay = (startGold - ((startGold - targetGold) * t)).round().clamp(targetGold, startGold);
      if (newDisplay != _displayGold) {
        setState(() {
          _displayGold = newDisplay;
        });
        HapticFeedback.selectionClick();
      }

      final elapsed = t * _purchaseDurationSeconds;
      for (int i = 0; i < _flyingCoins.length; i++) {
        final coin = _flyingCoins[i];
        if (coin.progress(elapsed) >= 1.0 && !_sparkedCoinIndices.contains(i)) {
          _sparkedCoinIndices.add(i);
          for (int k = 0; k < 5; k++) {
            final angle = rand.nextDouble() * pi * 2;
            final speed = 50.0 + rand.nextDouble() * 80.0;
            _sparks.add(
              _ImpactSpark(
                origin: coin.target,
                velocity: Offset(cos(angle) * speed, sin(angle) * speed),
                birthTime: elapsed,
                lifeTime: 0.22 + rand.nextDouble() * 0.12,
                color: k.isEven ? const Color(0xFFFFD54F) : const Color(0xFFFFF9C4),
                size: 2.0 + rand.nextDouble() * 2.0,
              ),
            );
          }
          HapticFeedback.lightImpact();
        }
      }
    }

    _purchaseAnimController.addListener(listener);
    _purchaseAnimController.reset();

    try {
      await _purchaseAnimController.forward();
    } finally {
      _purchaseAnimController.removeListener(listener);
      if (mounted) {
        setState(() {
          _displayGold = null;
          _isPurchasing = false;
          _flyingCoins.clear();
          _sparks.clear();
          _sparkedCoinIndices.clear();
        });
      }
    }

    await onComplete();
  }

  Future<void> _onPurchaseCategoryCrate(
    CategoryCrateInfo crateInfo,
    int cost,
    BuildContext btnContext,
  ) async {
    if (_isPurchasing) return;
    await _startPurchaseAnimation(
      targetContext: btnContext,
      cost: cost,
      onComplete: () async {
        final ok = await SaveManager.instance.spendGold(cost);
        if (ok && mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => CrateOpeningDialog(categoryCrate: crateInfo),
          );
        }
      },
    );
  }

  Future<void> _onPurchaseAquariumCrate(
    CrateDef crate,
    BuildContext btnContext,
  ) async {
    if (_isPurchasing) return;
    await _startPurchaseAnimation(
      targetContext: btnContext,
      cost: crate.cost,
      onComplete: () async {
        final ok = await SaveManager.instance.spendGold(crate.cost);
        if (ok && mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => CrateOpeningDialog(crate: crate),
          );
        }
      },
    );
  }

  Future<void> _onPurchaseBackground(
    BackgroundTheme theme,
    BuildContext btnContext,
  ) async {
    if (_isPurchasing) return;
    await _startPurchaseAnimation(
      targetContext: btnContext,
      cost: theme.cost,
      onComplete: () async {
        final ok = await SaveManager.instance.unlockBackground(theme.id, theme.cost);
        if (ok && mounted) {
          SaveManager.instance.selectBackground(theme.id);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final save = SaveManager.instance;

    return ListenableBuilder(
      listenable: save,
      builder: (context, _) {
        return Stack(
          children: [
            Scaffold(
              backgroundColor: const Color(0xFF0A0C14),
          appBar: AppBar(
            backgroundColor: const Color(0xFF0F121E),
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white70, size: 20),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Text(
              I18n.tr('shop_title'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.0,
              ),
            ),
            actions: [
              IconButton(
                tooltip: 'Tümünü Rastgele Kuşan',
                icon: const Icon(Icons.casino_rounded, color: Color(0xFFFFD54F), size: 24),
                onPressed: () {
                  final allRandom = save.activeBall == 'random' &&
                      save.activePaddle == 'random' &&
                      save.activeTrail == 'random' &&
                      save.activeBrickStyle == 'random' &&
                      save.activeBackground == 'random';
                  if (allRandom) {
                    save.equipBall('classic');
                    save.equipPaddle('pclassic');
                    save.equipTrail('t1');
                    save.equipBrickStyle('brick_gloss');
                    save.selectBackground('bg_default');
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Varsayılan kozmetiklere dönüldü!'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  } else {
                    save.equipBall('random');
                    save.equipPaddle('random');
                    save.equipTrail('random');
                    save.equipBrickStyle('random');
                    save.selectBackground('random');
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(' Tüm kategoriler için Rastgele modu aktif edildi!'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                },
              ),
              AnimatedScale(
                scale: _isPurchasing ? 1.10 : 1.0,
                duration: const Duration(milliseconds: 150),
                child: Container(
                  key: _appBarGoldKey,
                  margin: const EdgeInsets.only(right: 16, top: 10, bottom: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: _isPurchasing ? const Color(0xFF2C2212) : const Color(0xFF1C2234),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _isPurchasing ? const Color(0xFFFFD54F) : const Color(0x33FFD54F),
                      width: _isPurchasing ? 1.8 : 1.0,
                    ),
                    boxShadow: _isPurchasing
                        ? [
                            BoxShadow(
                              color: const Color(0xFFFFD54F).withValues(alpha: 0.45),
                              blurRadius: 12,
                              spreadRadius: 1.5,
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.monetization_on, color: Color(0xFFFFD54F), size: 16),
                      const SizedBox(width: 6),
                      Text( '${_displayGold ?? save.gold}',
                        style: TextStyle(
                          color: _isPurchasing ? const Color(0xFFFFF176) : const Color(0xFFFFD54F),
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              indicatorColor: const Color(0xFFFFD54F),
              labelColor: const Color(0xFFFFD54F),
              unselectedLabelColor: Colors.white54,
              labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
              tabs: [
                Tab(text: I18n.tr('crates')),
                Tab(text: I18n.tr('balls')),
                Tab(text: I18n.tr('paddles')),
                Tab(text: I18n.tr('trails')),
                Tab(text: I18n.tr('bricks')),
                Tab(text: I18n.tr('backgrounds')),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildCratesTab(context, save),
              _buildBallsTab(context, save),
              _buildPaddlesTab(context, save),
              _buildTrailsTab(context, save),
              _buildBricksTab(context, save),
              _buildBackgroundsTab(context, save),
            ],
          ),
        ),
        if (_isPurchasing || _flyingCoins.isNotEmpty)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _purchaseAnimController,
                builder: (context, _) {
                  return CustomPaint(
                    painter: _FlyingCoinsPainter(
                      coins: _flyingCoins,
                      sparks: _sparks,
                      elapsed: _purchaseAnimController.value * _purchaseDurationSeconds,
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  },
);
}

  Widget _buildCategoryCrateHeader(BuildContext context, SaveManager save, String category) {
    final crateInfo = CategoryCrateInfo.categoryCrates[category]!;
    final cost = crateInfo.cost;
    final canAfford = save.gold >= cost;
    final shards = save.getShards(category);

    bool allOwned = false;
    if (category == 'balls') {
      allOwned = save.unlockedBalls.length >= BallSkin.allSkins.length;
    } else if (category == 'paddles') {
      allOwned = save.unlockedPaddles.length >= PaddleSkin.allSkins.length;
    } else if (category == 'trails') {
      allOwned = save.unlockedTrails.length >= TrailSkin.allTrails.length;
    } else if (category == 'bricks') {
      allOwned = save.unlockedBrickStyles.length >= BrickStyle.all.length;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            crateInfo.primaryColor.withValues(alpha: 0.18),
            const Color(0xFF141724),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: crateInfo.primaryColor.withValues(alpha: 0.45), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: crateInfo.primaryColor.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // 1. Crate Opening Row
          Row(
            children: [
              ChestWidget(
                size: 58,
                primaryColor: crateInfo.primaryColor,
                secondaryColor: const Color(0xFF3E2723),
                showGlow: true,
                time: _animController.value * 2 * pi,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      crateInfo.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      I18n.tr('crate_desc_$category'),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Builder(
                builder: (btnContext) => ElevatedButton(
                  onPressed: (canAfford && !_isPurchasing)
                      ? () => _onPurchaseCategoryCrate(crateInfo, cost, btnContext)
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: crateInfo.primaryColor,
                    foregroundColor: Colors.black,
                    disabledBackgroundColor: Colors.white12,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.monetization_on, size: 15),
                      const SizedBox(width: 4),
                      Text( '$cost',
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 10),

          // 2. Shards Progress & Guaranteed Redemption
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF0C101C),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.25)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.diamond, color: Color(0xFF00E5FF), size: 16),
                        const SizedBox(width: 6),
                        Text(
                          '${I18n.tr('shards')}: $shards/3',
                          style: const TextStyle(
                            color: Color(0xFF00E5FF),
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      shards >= 3 ? 'GARANTİLİ YENİ EŞYA HAZIR!' : '(3 olunca Garantili Yeni Eşya!)',
                      style: TextStyle(
                        color: shards >= 3 ? const Color(0xFFFFD54F) : Colors.white70,
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: LinearProgressIndicator(
                    value: (shards / 3.0).clamp(0.0, 1.0),
                    minHeight: 6,
                    backgroundColor: Colors.white12,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      shards >= 3 ? const Color(0xFFFFD54F) : const Color(0xFF00E5FF),
                    ),
                  ),
                ),
                if (shards >= 3) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (allOwned) {
                          final ok = await save.consumeShards(category, 3);
                          if (ok) {
                            save.addGold(1000);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('${I18n.tr('all_items_unlocked')} (+1000 Altın)')),
                              );
                            }
                          }
                          return;
                        }
                        final ok = await save.consumeShards(category, 3);
                        if (ok && context.mounted) {
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (_) => CrateOpeningDialog(
                              isGuaranteedRedemption: true,
                              category: category,
                              categoryCrate: crateInfo,
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00E5FF),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      child: Text(
                        allOwned ? I18n.tr('all_items_unlocked') : I18n.tr('use_shards_guaranteed'),
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRandomOptionCard({
    required BuildContext context,
    required String title,
    required String desc,
    required IconData icon,
    required Color accentColor,
    required bool isEquipped,
    required VoidCallback onEquip,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            isEquipped ? accentColor.withValues(alpha: 0.22) : const Color(0xFF141724),
            const Color(0xFF0F111A),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isEquipped ? accentColor : Colors.white12,
          width: isEquipped ? 2.0 : 1.0,
        ),
        boxShadow: isEquipped
            ? [
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.25),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accentColor.withValues(alpha: 0.18),
              border: Border.all(color: accentColor, width: 1.5),
            ),
            child: Icon(icon, color: accentColor, size: 26),
          ),
          const SizedBox(width: 14),
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
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text( 'ŞANS',
                        style: TextStyle(
                          color: accentColor,
                          fontWeight: FontWeight.w900,
                          fontSize: 9,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  desc,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (isEquipped)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: accentColor, width: 1.2),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_rounded, color: accentColor, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    I18n.tr('equipped'),
                    style: TextStyle(
                      color: accentColor,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            )
          else
            ElevatedButton(
              onPressed: onEquip,
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                elevation: 0,
              ),
              child: Text(
                I18n.tr('use'),
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFortuneWheelBanner(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2E1065), Color(0xFF581C87), Color(0xFF701A75)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFFFD54F), width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66701A75),
            blurRadius: 18,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () {
            showDialog(
              context: context,
              builder: (_) => const FortuneWheelDialog(),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF00E5FF), Color(0xFF7C4DFF)],
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x6600E5FF),
                        blurRadius: 12,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(Icons.motion_photos_on_rounded, color: Colors.white, size: 26),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text( 'ŞANS ÇARKI',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Builder(
                            builder: (context) {
                              final spinsLeft = SaveManager.instance.remainingWheelSpins;
                              final hasSpins = spinsLeft > 0;
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: hasSpins ? const Color(0xFFFFD54F) : const Color(0xFF455A64),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  hasSpins ? '$spinsLeft/3 HAK' : 'YARIN GEL',
                                  style: TextStyle(
                                    color: hasSpins ? Colors.black : Colors.white70,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      const Text( 'Reklam İzle & Sandık, Altın veya Parça Kazan!',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD54F),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x66FFD54F),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text( 'ÇEVİR',
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward_ios, color: Colors.black, size: 11),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCratesTab(BuildContext context, SaveManager save) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // High-Yield Fortune Wheel Banner
        _buildFortuneWheelBanner(context),

        // Rewarded Ad Gold Banner Button
        const RewardedGoldAdButton(),
        const SizedBox(height: 16),

        // Aquarium Crates Header Banner
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0x3300E5FF), Color(0xFF141724)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0x4D00E5FF)),
          ),
          child: Row(
            children: [
              const Icon(Icons.water, color: Color(0xFF00E5FF), size: 32),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      I18n.tr('eco_crates_title'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      I18n.tr('eco_crates_desc'),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        for (final crate in CrateDef.allCrates)
          _buildCrateCard(context, save, crate),
      ],
    );
  }

  Widget _buildCrateCard(BuildContext context, SaveManager save, CrateDef crate) {
    final canAfford = save.gold >= crate.cost;
    final color = crate.primaryColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.18),
            const Color(0xFF141724),
            const Color(0xFF0F121E),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withValues(alpha: 0.45), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Realistic 3D Animated Chest
                ChestWidget(
                  size: 64,
                  primaryColor: color,
                  secondaryColor: crate.tier == Rarity.common
                      ? const Color(0xFF6D4C41)
                      : (crate.tier == Rarity.rare
                          ? const Color(0xFF006064)
                          : const Color(0xFF263238)),
                  showGlow: true,
                  time: _animController.value * 2 * pi,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              crate.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: color.withValues(alpha: 0.6)),
                            ),
                            child: Text(
                              crate.tier.label.toUpperCase(),
                              style: TextStyle(
                                color: color,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text( 'Akvaryum için deniz canlıları ve nadir balıklar içerir.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.65),
                          fontSize: 12,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // Drop Rates Preview Chips
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF0B0E18),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildDropRateChip('Yaygın', '${crate.weights[Rarity.common]?.toInt() ?? 0}%', Colors.white60),
                  Container(width: 1, height: 16, color: Colors.white12),
                  _buildDropRateChip('Nadir', '${crate.weights[Rarity.rare]?.toInt() ?? 0}%', const Color(0xFF00E5FF)),
                  Container(width: 1, height: 16, color: Colors.white12),
                  _buildDropRateChip('Destansı', '${crate.weights[Rarity.epic]?.toInt() ?? 0}%', const Color(0xFFE040FB)),
                  Container(width: 1, height: 16, color: Colors.white12),
                  _buildDropRateChip('Efsanevi', '${crate.weights[Rarity.legendary]?.toInt() ?? 0}%', const Color(0xFFFFD54F)),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: Builder(
                builder: (btnContext) => ElevatedButton(
                  onPressed: (canAfford && !_isPurchasing)
                      ? () => _onPurchaseAquariumCrate(crate, btnContext)
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.black,
                    disabledBackgroundColor: Colors.white12,
                    disabledForegroundColor: Colors.white30,
                    elevation: canAfford ? 4 : 0,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.monetization_on_rounded, size: 18),
                      const SizedBox(width: 6),
                      Text( '${crate.cost} ALTIN AÇ',
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 0.8),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropRateChip(String label, String pct, Color accent) {
    return Column(
      children: [
        Text(
          pct,
          style: TextStyle(color: accent, fontSize: 12, fontWeight: FontWeight.w900),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildBricksTab(BuildContext context, SaveManager save) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: CustomScrollView(
        slivers: [
        SliverToBoxAdapter(
          child: _buildCategoryCrateHeader(context, save, 'bricks'),
        ),
        SliverToBoxAdapter(
          child: _buildRandomOptionCard(
            context: context,
            title: ' RASTGELE BLOK',
            desc: 'Sahip olduğun blok stilleri arasından her oyunda rastgele biri seçilir.',
            icon: Icons.casino_rounded,
            accentColor: const Color(0xFFFFD54F),
            isEquipped: save.activeBrickStyle == 'random',
            onEquip: () => save.equipBrickStyle('random'),
          ),
        ),
        SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.82,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final style = BrickStyle.all[index];
              final owned = save.unlockedBrickStyles.contains(style.id);
              final equipped = save.activeBrickStyle == style.id;

              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF141724),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: equipped ? const Color(0xFF00E5FF) : (owned ? Colors.white24 : Colors.white10),
                    width: equipped ? 2 : 1,
                  ),
                ),
                child: Column(
                  children: [
                    _buildBrickStylePreview(style),
                    const SizedBox(height: 10),
                    Text(
                      style.name,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      style.rarity.label,
                      style: TextStyle(color: style.rarity.primaryColor, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    if (equipped)
                      Text(I18n.tr('equipped'), style: const TextStyle(color: Color(0xFF00E5FF), fontWeight: FontWeight.w900, fontSize: 11))
                    else if (owned)
                      TextButton(
                        onPressed: () => save.equipBrickStyle(style.id),
                        child: Text(I18n.tr('use'), style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w800)),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: style.rarity.primaryColor.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.lock_outline, size: 13, color: style.rarity.primaryColor),
                            const SizedBox(width: 4),
                            Text(
                              I18n.tr('from_crate'),
                              style: TextStyle(
                                color: style.rarity.primaryColor,
                                fontWeight: FontWeight.w800,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              );
            },
            childCount: BrickStyle.all.length,
          ),
        ),
      ],
    ),
  );
}

  Widget _buildBallsTab(BuildContext context, SaveManager save) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: CustomScrollView(
        slivers: [
        SliverToBoxAdapter(
          child: _buildCategoryCrateHeader(context, save, 'balls'),
        ),
        SliverToBoxAdapter(
          child: _buildRandomOptionCard(
            context: context,
            title: ' RASTGELE TOP',
            desc: 'Sahip olduğun tüm toplar arasından her oyunda rastgele biri seçilir.',
            icon: Icons.casino_rounded,
            accentColor: const Color(0xFF00E5FF),
            isEquipped: save.activeBall == 'random',
            onEquip: () => save.equipBall('random'),
          ),
        ),
        SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.85,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final skin = BallSkin.allSkins[index];
              final owned = save.unlockedBalls.contains(skin.id);
              final equipped = save.activeBall == skin.id;

              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF141724),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: equipped
                        ? const Color(0xFF00E5FF)
                        : (owned ? Colors.white24 : Colors.white10),
                    width: equipped ? 2 : 1,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildBallPreview(skin),
                    const SizedBox(height: 12),
                    Text(
                      skin.name,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      skin.rarity.label,
                      style: TextStyle(color: skin.rarity.primaryColor, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    if (equipped)
                      Text(I18n.tr('equipped'), style: const TextStyle(color: Color(0xFF00E5FF), fontWeight: FontWeight.w900, fontSize: 11))
                    else if (owned)
                      TextButton(
                        onPressed: () => save.equipBall(skin.id),
                        child: Text(I18n.tr('use'), style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w800)),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: skin.rarity.primaryColor.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.lock_outline, size: 13, color: skin.rarity.primaryColor),
                            const SizedBox(width: 4),
                            Text(
                              I18n.tr('from_crate'),
                              style: TextStyle(
                                color: skin.rarity.primaryColor,
                                fontWeight: FontWeight.w800,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              );
            },
            childCount: BallSkin.allSkins.length,
          ),
        ),
      ],
    ),
  );
}

  Widget _buildPaddlesTab(BuildContext context, SaveManager save) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildCategoryCrateHeader(context, save, 'paddles'),
        _buildRandomOptionCard(
          context: context,
          title: ' RASTGELE RAKET',
          desc: 'Sahip olduğun tüm raketler arasından her oyunda rastgele biri seçilir.',
          icon: Icons.casino_rounded,
          accentColor: const Color(0xFF7C4DFF),
          isEquipped: save.activePaddle == 'random',
          onEquip: () => save.equipPaddle('random'),
        ),
        for (final skin in PaddleSkin.allSkins) ...[
          Builder(
            builder: (context) {
              final owned = save.unlockedPaddles.contains(skin.id);
              final equipped = save.activePaddle == skin.id;

              return Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF141724),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: equipped ? const Color(0xFF00E5FF) : Colors.white12,
                    width: equipped ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    _buildPaddlePreview(skin),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            skin.name,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14),
                          ),
                          Text(
                            skin.rarity.label,
                            style: TextStyle(color: skin.rarity.primaryColor, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    if (equipped)
                      Text(I18n.tr('equipped'), style: const TextStyle(color: Color(0xFF00E5FF), fontWeight: FontWeight.w900))
                    else if (owned)
                      OutlinedButton(
                        onPressed: () => save.equipPaddle(skin.id),
                        style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
                        child: Text(I18n.tr('use')),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: skin.rarity.primaryColor.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.lock_outline, size: 13, color: skin.rarity.primaryColor),
                            const SizedBox(width: 4),
                            Text(
                              I18n.tr('from_crate'),
                              style: TextStyle(
                                color: skin.rarity.primaryColor,
                                fontWeight: FontWeight.w800,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ],
    );
  }

  Widget _buildTrailsTab(BuildContext context, SaveManager save) {
    final previewTrailId = _selectedPreviewTrailId ?? save.activeTrail;
    final previewTrail = TrailSkin.allTrails.firstWhere(
      (t) => t.id == previewTrailId,
      orElse: () => TrailSkin.allTrails.first,
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildCategoryCrateHeader(context, save, 'trails'),
        _buildRandomOptionCard(
          context: context,
          title: ' RASTGELE İZ',
          desc: 'Sahip olduğun tüm iz stilleri arasından her oyunda rastgele biri seçilir.',
          icon: Icons.casino_rounded,
          accentColor: const Color(0xFFFF4081),
          isEquipped: save.activeTrail == 'random',
          onEquip: () => save.equipTrail('random'),
        ),
        // Large Live Trail Simulation Arena
        _buildLiveTrailShowcase(context, save, previewTrail),
        for (final trail in TrailSkin.allTrails) ...[
          Builder(
            builder: (context) {
              final owned = save.unlockedTrails.contains(trail.id);
              final equipped = save.activeTrail == trail.id;
              final isPreviewing = trail.id == previewTrailId;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF141724),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: equipped
                        ? const Color(0xFF00E5FF)
                        : (isPreviewing ? trail.rarity.primaryColor : Colors.white12),
                    width: (equipped || isPreviewing) ? 2 : 1,
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () {
                      setState(() {
                        _selectedPreviewTrailId = trail.id;
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          // Miniature live preview
                          _buildTrailMiniPreview(trail),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        trail.name,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 13.5,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (isPreviewing && !equipped) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: const Color(0x3300E5FF),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Text( 'CANLI',
                                          style: TextStyle(color: Color(0xFF00E5FF), fontSize: 9, fontWeight: FontWeight.w900),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Row(
                                  children: [
                                    Text(
                                      trail.rarity.label,
                                      style: TextStyle(
                                        color: trail.rarity.primaryColor,
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text( '• ${trail.length} Segment',
                                      style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    PixelIcon(
                                      trail.style == TrailStyle.dot
                                          ? 'starlight' : (trail.style == TrailStyle.spark
                                              ? 'spark' : (trail.style == TrailStyle.ghost
                                                  ? 'ghost' : (trail.style == TrailStyle.fire
                                                      ? 'fire' : (trail.style == TrailStyle.rainbow ? 'rainbow' : 'plasma')))),
                                      size: 11,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      _getTrailShortBadge(trail.style),
                                      style: const TextStyle(color: Colors.white54, fontSize: 10),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (equipped)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0x2200E5FF),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFF00E5FF)),
                              ),
                              child: Text(
                                I18n.tr('equipped').toUpperCase(),
                                style: const TextStyle(color: Color(0xFF00E5FF), fontWeight: FontWeight.w900, fontSize: 11),
                              ),
                            )
                          else if (owned)
                            ElevatedButton(
                              onPressed: () {
                                save.equipTrail(trail.id);
                                setState(() {
                                  _selectedPreviewTrailId = trail.id;
                                });
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF00E5FF),
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: Text(I18n.tr('use'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11)),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: trail.rarity.primaryColor.withValues(alpha: 0.4)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.lock_outline, size: 12, color: trail.rarity.primaryColor),
                                  const SizedBox(width: 4),
                                  Text(
                                    I18n.tr('from_crate'),
                                    style: TextStyle(
                                      color: trail.rarity.primaryColor,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 10.5,
                                    ),
                                  ),
                                ],
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
        ],
      ],
    );
  }

  Widget _buildBackgroundsTab(BuildContext context, SaveManager save) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildRandomOptionCard(
          context: context,
          title: ' RASTGELE ARKA PLAN',
          desc: 'Sahip olduğun tüm arka planlar arasından her oyunda rastgele biri seçilir.',
          icon: Icons.casino_rounded,
          accentColor: const Color(0xFFE040FB),
          isEquipped: save.activeBackground == 'random',
          onEquip: () => save.selectBackground('random'),
        ),
        for (final theme in BackgroundTheme.allThemes)
          Builder(
            builder: (context) {
              final owned = save.unlockedBackgrounds.contains(theme.id);
              final equipped = save.activeBackground == theme.id;

              return Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF141724),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: equipped ? const Color(0xFF00E5FF) : Colors.white12,
              width: equipped ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [theme.primaryColor, theme.secondaryColor],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: theme.accentColor, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: theme.accentColor.withValues(alpha: 0.3),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Icon(theme.icon, color: theme.accentColor, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      I18n.tr(theme.nameKey),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      I18n.tr(theme.descKey),
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              if (equipped)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0x2200E5FF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF00E5FF)),
                  ),
                  child: Text(
                    I18n.tr('selected').toUpperCase(),
                    style: const TextStyle(
                      color: Color(0xFF00E5FF),
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                )
              else if (owned)
                OutlinedButton(
                  onPressed: () => save.selectBackground(theme.id),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white38),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(I18n.tr('select')),
                )
              else
                Builder(
                  builder: (btnContext) => ElevatedButton(
                    onPressed: (save.gold >= theme.cost && !_isPurchasing)
                        ? () => _onPurchaseBackground(theme, btnContext)
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFD54F),
                      foregroundColor: Colors.black,
                      disabledBackgroundColor: Colors.white12,
                      disabledForegroundColor: Colors.white38,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text( '${theme.cost} ',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    ],
  );
}

  Widget _buildBrickStylePreview(BrickStyle style) {
    return Container(
      height: 38,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF0C0E17),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: style.accent.withValues(alpha: 0.35)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Center(
        child: SizedBox(
          height: 24,
          width: 84,
          child: CustomPaint(
            painter: _BrickPreviewPainter(style: style),
          ),
        ),
      ),
    );
  }

  Widget _buildBallPreview(BallSkin skin) {
    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        color: const Color(0xFF0C0E1A),
        shape: BoxShape.circle,
        border: Border.all(color: skin.rarity.primaryColor.withValues(alpha: 0.35), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: skin.glowColor.withValues(alpha: 0.25),
            blurRadius: 10,
          ),
        ],
      ),
      child: AnimatedBuilder(
        animation: _animController,
        builder: (context, _) {
          return CustomPaint(
            painter: _BallPreviewPainter(
              skin: skin,
              time: _animController.value * 2 * pi,
            ),
          );
        },
      ),
    );
  }

  Widget _buildPaddlePreview(PaddleSkin skin) {
    return Container(
      width: 76,
      height: 20,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(color: skin.glowColor.withValues(alpha: 0.35), blurRadius: 10),
        ],
      ),
      child: AnimatedBuilder(
        animation: _animController,
        builder: (context, _) {
          return CustomPaint(
            painter: _PaddlePreviewPainter(
              skin: skin,
              time: _animController.value * 2 * pi,
            ),
          );
        },
      ),
    );
  }

  Widget _buildTrailMiniPreview(TrailSkin trail) {
    return Container(
      width: 94,
      height: 54,
      decoration: BoxDecoration(
        color: const Color(0xFF090B14),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: trail.rarity.primaryColor.withValues(alpha: 0.4), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: trail.rarity.primaryColor.withValues(alpha: 0.12),
            blurRadius: 8,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: AnimatedBuilder(
          animation: _animController,
          builder: (context, _) {
            return CustomPaint(
              painter: _TrailMiniPreviewPainter(
                trail: trail,
                time: _animController.value * 2 * pi,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildLiveTrailShowcase(BuildContext context, SaveManager save, TrailSkin trail) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            trail.rarity.primaryColor.withValues(alpha: 0.16),
            const Color(0xFF101322),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: trail.rarity.primaryColor.withValues(alpha: 0.5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: trail.rarity.primaryColor.withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.play_circle_filled, color: Color(0xFF00E5FF), size: 16),
                  const SizedBox(width: 6),
                  Text( 'CANLI İZ SİMÜLASYONU: ${trail.name}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: trail.rarity.primaryColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: trail.rarity.primaryColor.withValues(alpha: 0.4)),
                ),
                child: Text( '${trail.rarity.label} • ${trail.length} Segment',
                  style: TextStyle(
                    color: trail.rarity.primaryColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Container(
              height: 84,
              width: double.infinity,
              color: const Color(0xFF080A12),
              child: AnimatedBuilder(
                animation: _animController,
                builder: (context, _) {
                  return CustomPaint(
                    painter: _TrailArenaPreviewPainter(
                      trail: trail,
                      time: _animController.value * 2 * pi,
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _getTrailDescription(trail.style),
            style: const TextStyle(color: Colors.white60, fontSize: 11),
          ),
        ],
      ),
    );
  }

  String _getTrailDescription(TrailStyle style) {
    switch (style) {
      case TrailStyle.dot:
        return 'Yıldız takımyıldızı gibi parıldayan, uca doğru zarifçe incelen starlight izi.';
      case TrailStyle.spark:
        return 'Yüksek gerilimli elektrik arkları ve etrafa saçılan şimşek kıvılcımları.';
      case TrailStyle.ghost:
        return 'Topun arkasında süzülen ruhani hayalet yansımaları ve ektoplazma sisi.';
      case TrailStyle.fire:
        return 'Kızgın alev dilleri, akkor sarı çekirdek ve havada süzülen ateş közleri.';
      case TrailStyle.rainbow:
        return 'Gökyüzündeki kuzey ışıkları gibi tüm tayfı tarayan prizmatik aurora şeridi.';
      case TrailStyle.plasma:
        return 'İki zıt sarmal kuantum ışını ve manyetik plazma halkalarıyla kozmik demet.';
    }
  }

  String _getTrailShortBadge(TrailStyle style) {
    switch (style) {
      case TrailStyle.dot:
        return 'Starlight Takımyıldızı';
      case TrailStyle.spark:
        return 'Elektrik & Şimşek';
      case TrailStyle.ghost:
        return 'Ruhani Eko & Sis';
      case TrailStyle.fire:
        return 'Blazing Cehennem Alevi';
      case TrailStyle.rainbow:
        return 'Prizmatik Aurora';
      case TrailStyle.plasma:
        return 'Kuantum Plazma Işını';
    }
  }
}

class _BrickPreviewPainter extends CustomPainter {
  final BrickStyle style;
  _BrickPreviewPainter({required this.style});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(5.0));

    switch (style.id) {
      case 'brick_pixel':
        _paintPixel(canvas, rect);
        break;
      case 'brick_gloss':
        _paintGloss(canvas, rect, rrect);
        break;
      case 'brick_neu':
        _paintNeu(canvas, rect, rrect);
        break;
      case 'brick_cyber':
        _paintCyber(canvas, rect, rrect);
        break;
      case 'brick_cosmic':
        _paintCosmic(canvas, rect, rrect);
        break;
      case 'brick_neon':
      default:
        _paintNeon(canvas, rect, rrect);
        break;
    }
  }

  void _paintNeon(Canvas canvas, Rect rect, RRect rrect) {
    // "Neon Tabela": 3D Arcade Glass Neon Tube Signboard
    const neonCyan = Color(0xFF00E5FF);
    final darkShadow = Paint()..color = const Color(0xFF04060C);
    canvas.drawRRect(RRect.fromRectAndRadius(rect.translate(0, 2), const Radius.circular(5.0)), darkShadow);

    final bgPaint = Paint()
      ..shader = const RadialGradient(
        center: Alignment.center,
        radius: 0.95,
        colors: [Color(0xFF0A485C), Color(0xFF060A14)],
      ).createShader(rect);
    canvas.drawRRect(rrect, bgPaint);

    // Left & right metal electrode holders
    final capPaint = Paint()..color = const Color(0xFF263238);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(rect.left + 3.2, rect.center.dy), width: 3.0, height: 6.5), const Radius.circular(1)),
      capPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(rect.right - 3.2, rect.center.dy), width: 3.0, height: 6.5), const Radius.circular(1)),
      capPaint,
    );

    final tubeRRect = rrect.deflate(1.8);
    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.2
      ..color = const Color(0x5A00E5FF);
    canvas.drawRRect(tubeRRect, glowPaint);

    final tubePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.1
      ..color = neonCyan;
    canvas.drawRRect(tubeRRect, tubePaint);

    final corePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.85
      ..color = Colors.white;
    canvas.drawRRect(tubeRRect, corePaint);

    // Inner floating neon filament capsule
    final innerCapsule = RRect.fromRectAndRadius(
      Rect.fromCenter(center: rect.center, width: rect.width - 14.0, height: rect.height - 9.5),
      const Radius.circular(3.0),
    );
    final innerNeon = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..color = const Color(0xAA00E5FF);
    canvas.drawRRect(innerCapsule, innerNeon);
  }

  void _paintPixel(Canvas canvas, Rect rect) {
    final shadowPaint = Paint()..color = const Color(0xAA000000);
    canvas.drawRect(rect.translate(2.0, 2.0), shadowPaint);

    final borderPaint = Paint()..color = const Color(0xFF050508);
    canvas.drawRect(rect, borderPaint);

    final deepDarkPaint = Paint()..color = const Color(0xFF8C3100);
    canvas.drawRect(rect.deflate(1.8), deepDarkPaint);

    final bodyPaint = Paint()..color = const Color(0xFFFFD54F);
    canvas.drawRect(rect.deflate(3.5), bodyPaint);

    final lightPaint = Paint()..color = const Color(0xFFFFF9C4);
    canvas.drawRect(Rect.fromLTWH(rect.left + 2, rect.top + 2, rect.width - 5.5, 2.2), lightPaint);
    canvas.drawRect(Rect.fromLTWH(rect.left + 2, rect.top + 2, 2.2, rect.height - 5.5), lightPaint);

    final darkPaint = Paint()..color = const Color(0xFFE65100);
    canvas.drawRect(Rect.fromLTWH(rect.left + 3.5, rect.bottom - 4.2, rect.width - 5.5, 2.2), darkPaint);
    canvas.drawRect(Rect.fromLTWH(rect.right - 4.2, rect.top + 3.5, 2.2, rect.height - 5.5), darkPaint);

    // Diagonal 8-bit sheen steps
    final sheenPaint = Paint()..color = const Color(0xFFFFECB3);
    for (int step = 0; step < 3; step++) {
      canvas.drawRect(Rect.fromLTWH(rect.left + 10 + step * 3.5, rect.top + 4.5 + step * 2.2, 4.5, 2.2), sheenPaint);
    }

    final whitePaint = Paint()..color = Colors.white;
    canvas.drawRect(Rect.fromLTWH(rect.left + 4.5, rect.top + 4.5, 3.0, 3.0), whitePaint);
  }

  void _paintGloss(Canvas canvas, Rect rect, RRect rrect) {
    // "Siber Cam": 5-Facet Cut Crystal Gemstone
    final shadowPaint = Paint()..color = const Color(0xFF4A0020);
    canvas.drawRRect(RRect.fromRectAndRadius(rect.translate(0, 2), const Radius.circular(6.5)), shadowPaint);

    final gemRRect = RRect.fromRectAndRadius(rect, const Radius.circular(6.5));
    final bodyPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFFB2CE), Color(0xFFFF4081), Color(0xFFC2185B), Color(0xFF7B0B42)],
        stops: [0.0, 0.30, 0.70, 1.0],
      ).createShader(rect);
    canvas.drawRRect(gemRRect, bodyPaint);

    const insetX = 6.0;
    const insetY = 4.2;

    // Top crown facet
    final topFacet = Path()
      ..moveTo(rect.left + 3, rect.top + 1)
      ..lineTo(rect.right - 3, rect.top + 1)
      ..lineTo(rect.right - insetX, rect.top + insetY)
      ..lineTo(rect.left + insetX, rect.top + insetY)
      ..close();
    canvas.drawPath(topFacet, Paint()..color = Colors.white.withValues(alpha: 0.42));

    // Bottom pavilion facet
    final bottomFacet = Path()
      ..moveTo(rect.left + insetX, rect.bottom - insetY)
      ..lineTo(rect.right - insetX, rect.bottom - insetY)
      ..lineTo(rect.right - 3, rect.bottom - 1)
      ..lineTo(rect.left + 3, rect.bottom - 1)
      ..close();
    canvas.drawPath(bottomFacet, Paint()..color = const Color(0x774A0020));

    // Central raised jewel table
    final tableRect = Rect.fromLTRB(rect.left + insetX, rect.top + insetY, rect.right - insetX, rect.bottom - insetY);
    final tableRRect = RRect.fromRectAndRadius(tableRect, const Radius.circular(3.0));
    final tablePaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFFF9EC2), Color(0xFFFF4081), Color(0xFFC2185B)],
      ).createShader(tableRect);
    canvas.drawRRect(tableRRect, tablePaint);
    canvas.drawRRect(
      tableRRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9
        ..color = Colors.white.withValues(alpha: 0.55),
    );

    // Specular 4-point diamond star sparkle on top-left facet vertex
    final starPaint = Paint()..color = Colors.white;
    final sc = Offset(rect.left + insetX + 1.5, rect.top + insetY + 1.0);
    canvas.drawCircle(sc, 1.4, starPaint);
    final spLine = Paint()
      ..strokeWidth = 0.9
      ..color = Colors.white;
    canvas.drawLine(Offset(sc.dx - 3.5, sc.dy), Offset(sc.dx + 3.5, sc.dy), spLine);
    canvas.drawLine(Offset(sc.dx, sc.dy - 3.5), Offset(sc.dx, sc.dy + 3.5), spLine);

    final rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = const Color(0x99FFFFFF);
    canvas.drawRRect(gemRRect, rimPaint);
  }

  void _paintNeu(Canvas canvas, Rect rect, RRect rrect) {
    // "Yumuşak Puf" (Stil 1): Jöle / Şeker Yastık (Plush Squishy Gummy Pillow)
    final pillowRRect = RRect.fromRectAndRadius(rect, const Radius.circular(9.5));

    // Soft 3D base cushion shadow
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.translate(0, 2.5), const Radius.circular(9.5)),
      Paint()..color = const Color(0xD9003B42),
    );

    // Main plump radial body with warm subsurface glow & bottom bounce rim light
    final bodyPaint = Paint()
      ..shader = const RadialGradient(
        center: Alignment(-0.28, -0.45),
        radius: 1.15,
        colors: [
          Color(0xFFD2F8FD),
          Color(0xFF26C6DA),
          Color(0xFF006D7A),
          Color(0xFF62DAE8),
        ],
        stops: [0.0, 0.38, 0.82, 1.0],
      ).createShader(rect);
    canvas.drawRRect(pillowRRect, bodyPaint);

    // Inner warm subsurface core glow
    final innerRect = rect.deflate(2.0);
    final innerPaint = Paint()
      ..shader = const RadialGradient(
        center: Alignment(0.0, 0.25),
        radius: 0.75,
        colors: [
          Color(0x8CA6F1FA),
          Colors.transparent,
        ],
      ).createShader(innerRect);
    canvas.drawRRect(RRect.fromRectAndRadius(innerRect, const Radius.circular(8.0)), innerPaint);

    // Thick curved liquid-jelly highlight pill along top-left shoulder
    final jellyPill = Path()
      ..moveTo(rect.left + 6.5, rect.top + 2.6)
      ..quadraticBezierTo(rect.center.dx, rect.top + 1.8, rect.right - 14.0, rect.top + 3.0)
      ..quadraticBezierTo(rect.right - 11.0, rect.top + 4.5, rect.right - 15.0, rect.top + 5.2)
      ..quadraticBezierTo(rect.center.dx - 2.0, rect.top + 4.2, rect.left + 7.2, rect.top + 5.8)
      ..quadraticBezierTo(rect.left + 4.5, rect.top + 4.2, rect.left + 6.5, rect.top + 2.6)
      ..close();
    final jellyPaint = Paint()..color = const Color(0xD1FFFFFF);
    canvas.drawPath(jellyPill, jellyPaint);

    // Secondary specular jelly dot on top-right
    canvas.drawCircle(Offset(rect.right - 9.5, rect.top + 4.2), 1.5, jellyPaint);

    // Soft glossy outer contour
    canvas.drawRRect(
      pillowRRect.deflate(0.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..color = const Color(0x8CFFFFFF),
    );
  }

  void _paintCyber(Canvas canvas, Rect rect, RRect rrect) {
    // "Siberpunk 2099" (Stil A): Kesik Köşeli Meka Reaktör, Yan Plazma Izgaraları (///) ve Tarayıcı Lazer
    const cyberAccent = Color(0xFF00E5FF);
    const lightAccent = Color(0xFF84FFFF);
    const c = 4.5;

    Path chamfer(Rect r) {
      return Path()
        ..moveTo(r.left + c, r.top)
        ..lineTo(r.right - c, r.top)
        ..lineTo(r.right, r.top + c)
        ..lineTo(r.right, r.bottom - c)
        ..lineTo(r.right - c, r.bottom)
        ..lineTo(r.left + c, r.bottom)
        ..lineTo(r.left, r.bottom - c)
        ..lineTo(r.left, r.top + c)
        ..close();
    }

    canvas.drawPath(chamfer(rect.translate(0, 2.4)), Paint()..color = const Color(0xFF03050B));

    final hullPath = chamfer(rect);
    final hullPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF144E68), Color(0xFF0F1726), Color(0xFF070B14)],
        stops: [0.0, 0.50, 1.0],
      ).createShader(rect);
    canvas.drawPath(hullPath, hullPaint);

    // Glowing Side Plasma Vents (/// gills on left & right wings)
    final ventPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.6
      ..color = lightAccent;
    for (int v = 0; v < 2; v++) {
      final lx = rect.left + 6.5 + v * 4.2;
      canvas.drawLine(Offset(lx + 1.8, rect.top + 4.5), Offset(lx, rect.bottom - 4.5), ventPaint);
      final rx = rect.right - 6.5 - v * 4.2;
      canvas.drawLine(Offset(rx - 1.8, rect.top + 4.5), Offset(rx, rect.bottom - 4.5), ventPaint);
    }

    // Central Hexagonal Plasma Reactor Window
    final cx = rect.center.dx;
    final cy = rect.center.dy;
    const cw = 13.0;
    final ch = rect.height / 2 - 3.0;
    final hexPath = Path()
      ..moveTo(cx - cw + 3.5, cy - ch)
      ..lineTo(cx + cw - 3.5, cy - ch)
      ..lineTo(cx + cw, cy)
      ..lineTo(cx + cw - 3.5, cy + ch)
      ..lineTo(cx - cw + 3.5, cy + ch)
      ..lineTo(cx - cw, cy)
      ..close();
    final coreRect = Rect.fromCenter(center: rect.center, width: cw * 2, height: ch * 2);
    canvas.drawPath(
      hexPath,
      Paint()
        ..shader = const RadialGradient(
          colors: [Colors.white, lightAccent, cyberAccent],
          stops: [0.0, 0.45, 1.0],
        ).createShader(coreRect),
    );
    canvas.drawPath(
      hexPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..color = Colors.white,
    );

    // Scanning horizontal laser beam inside reactor
    canvas.drawLine(
      Offset(cx - cw + 3.0, cy),
      Offset(cx + cw - 3.0, cy),
      Paint()
        ..color = Colors.white
        ..strokeWidth = 1.4,
    );

    // Top & Bottom tactical HUD notches
    final notchPaint = Paint()..color = cyberAccent;
    canvas.drawRect(Rect.fromLTWH(cx - 8.0, rect.top, 16.0, 1.8), notchPaint);
    canvas.drawRect(Rect.fromLTWH(cx - 8.0, rect.bottom - 1.8, 16.0, 1.8), notchPaint);

    // Chamfered Neon Armor Rim
    canvas.drawPath(
      hullPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3
        ..color = cyberAccent,
    );
  }

  void _paintCosmic(Canvas canvas, Rect rect, RRect rrect) {
    // "Kozmik Kristal": Organic deep space window with swirling cosmic nebula,
    // Milky Way stardust clouds, sparkling micro-star clusters, and crystal refraction.
    const deepVoid = Color(0xFF070114);
    const abyss = Color(0xFF110324);
    const magenta = Color(0xFFE040FB);
    const cyan = Color(0xFF00E5FF);
    const violet = Color(0xFF7C4DFF);

    final dropShadow = Paint()..color = const Color(0xFF06010D);
    canvas.drawRRect(RRect.fromRectAndRadius(rect.translate(0, 2), const Radius.circular(5)), dropShadow);

    final halfW = rect.width / 2;
    final halfH = rect.height / 2;
    final c = rect.center;

    canvas.save();
    canvas.clipRRect(rrect);

    // Deep cosmic space void background
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [deepVoid, abyss, deepVoid],
        stops: [0.0, 0.55, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, bgPaint);

    // Nebula Cloud A: Violet Galactic Halo
    final haloRect = Rect.fromCenter(center: Offset(c.dx - halfW * 0.10, c.dy), width: halfW * 2.2, height: halfH * 2.4);
    final haloPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          violet.withValues(alpha: 0.55),
          violet.withValues(alpha: 0.20),
          Colors.transparent,
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(haloRect);
    canvas.drawOval(haloRect, haloPaint);

    // Nebula Cloud B: Magenta / Rose Cosmic Gas Filament
    final magRect = Rect.fromCenter(center: Offset(c.dx - halfW * 0.38, c.dy - halfH * 0.25), width: halfW * 1.5, height: halfH * 1.6);
    final magPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          magenta.withValues(alpha: 0.60),
          magenta.withValues(alpha: 0.22),
          Colors.transparent,
        ],
        stops: const [0.0, 0.48, 1.0],
      ).createShader(magRect);
    canvas.drawOval(magRect, magPaint);

    // Nebula Cloud C: Celestial Cyan Gas Veil
    final cyanRect = Rect.fromCenter(center: Offset(c.dx + halfW * 0.35, c.dy + halfH * 0.22), width: halfW * 1.6, height: halfH * 1.7);
    final cyanPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          cyan.withValues(alpha: 0.55),
          cyan.withValues(alpha: 0.18),
          Colors.transparent,
        ],
        stops: const [0.0, 0.50, 1.0],
      ).createShader(cyanRect);
    canvas.drawOval(cyanRect, cyanPaint);

    // Nebula Cloud D: Hot Luminous Stellar Nursery Core
    final nurseryRect = Rect.fromCenter(center: Offset(c.dx - halfW * 0.05, c.dy + halfH * 0.05), width: halfW * 0.85, height: halfH * 0.95);
    final nurseryPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: 0.70),
          cyan.withValues(alpha: 0.35),
          Colors.transparent,
        ],
        stops: const [0.0, 0.35, 1.0],
      ).createShader(nurseryRect);
    canvas.drawOval(nurseryRect, nurseryPaint);

    // Milky Way Galactic Stardust Band
    final streamPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment(-0.85, -0.9),
        end: Alignment(0.85, 0.9),
        colors: [
          Colors.transparent,
          Color(0x407C4DFF),
          Color(0x60FFFFFF),
          Color(0x4000E5FF),
          Colors.transparent,
        ],
        stops: [0.0, 0.30, 0.50, 0.70, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, streamPaint);

    // Natural Cosmic Micro-Star Clusters & Stardust
    const starOffsets = [
      Offset(-0.72, -0.42),
      Offset(-0.54, 0.50),
      Offset(-0.35, -0.65),
      Offset(-0.22, 0.25),
      Offset(-0.06, -0.28),
      Offset(0.12, 0.58),
      Offset(0.28, -0.48),
      Offset(0.45, 0.15),
      Offset(0.62, -0.35),
      Offset(0.74, 0.42),
      Offset(0.04, -0.10),
    ];
    final starPaint = Paint()..style = PaintingStyle.fill;
    for (int i = 0; i < starOffsets.length; i++) {
      final off = Offset(c.dx + halfW * starOffsets[i].dx, c.dy + halfH * starOffsets[i].dy);
      final r = (i == 4 || i == 10) ? 1.3 : (i.isEven ? 0.9 : 0.6);
      starPaint.color = i % 3 == 0
          ? Colors.white
          : (i % 3 == 1 ? const Color(0xFFE1BEE7) : const Color(0xFFB2EBF2));
      canvas.drawCircle(off, r, starPaint);
    }

    // Telescope Diffraction-Spike Primary Star
    final majorStarPos = Offset(c.dx - halfW * 0.20, c.dy - halfH * 0.18);
    starPaint.color = Colors.white;
    canvas.drawCircle(majorStarPos, 1.6, starPaint);

    final spikePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9
      ..color = Colors.white.withValues(alpha: 0.85);
    canvas.drawLine(Offset(majorStarPos.dx - 5.0, majorStarPos.dy), Offset(majorStarPos.dx + 5.0, majorStarPos.dy), spikePaint);
    canvas.drawLine(Offset(majorStarPos.dx, majorStarPos.dy - 3.8), Offset(majorStarPos.dx, majorStarPos.dy + 3.8), spikePaint);

    // Crystal Glass Sheen & Refraction
    final sheenPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0x55FFFFFF),
          Color(0x14FFFFFF),
          Colors.transparent,
        ],
        stops: [0.0, 0.40, 1.0],
      ).createShader(Rect.fromLTWH(rect.left, rect.top, rect.width, halfH * 0.85));
    canvas.drawRect(Rect.fromLTWH(rect.left, rect.top, rect.width, halfH * 0.85), sheenPaint);

    canvas.restore();

    // Prismatic Iridescent Crystal Rim
    final rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xF000E5FF),
          Color(0xE6E040FB),
          Color(0xCC7C4DFF),
          Color(0xE600E5FF),
        ],
        stops: [0.0, 0.35, 0.70, 1.0],
      ).createShader(rect);
    canvas.drawRRect(rrect, rimPaint);
  }

  @override
  bool shouldRepaint(covariant _BrickPreviewPainter oldDelegate) => oldDelegate.style.id != style.id;
}

// ==========================================
// LIVE PREVIEW PAINTERS FOR TRAILS, BALLS & PADDLES
// ==========================================

class _TrailMiniPreviewPainter extends CustomPainter {
  final TrailSkin trail;
  final double time;

  _TrailMiniPreviewPainter({required this.trail, required this.time});

  @override
  void paint(Canvas canvas, Size size) {
    _paintTrailSimulation(canvas, size, trail, time, isMini: true);
  }

  @override
  bool shouldRepaint(covariant _TrailMiniPreviewPainter oldDelegate) => true;
}

class _TrailArenaPreviewPainter extends CustomPainter {
  final TrailSkin trail;
  final double time;

  _TrailArenaPreviewPainter({required this.trail, required this.time});

  @override
  void paint(Canvas canvas, Size size) {
    _paintTrailSimulation(canvas, size, trail, time, isMini: false);
  }

  @override
  bool shouldRepaint(covariant _TrailArenaPreviewPainter oldDelegate) => true;
}

void _paintTrailSimulation(
  Canvas canvas,
  Size size,
  TrailSkin trail,
  double time, {
  required bool isMini,
}) {
  final w = size.width;
  final h = size.height;
  final cx = w * 0.5;
  final cy = h * 0.5;
  final rx = w * (isMini ? 0.36 : 0.40);
  final ry = h * (isMini ? 0.28 : 0.30);

  // Background ambient grid stars
  final bgPaint = Paint()..color = const Color(0x33FFFFFF);
  if (!isMini) {
    for (int s = 0; s < 5; s++) {
      final sx = (cx - rx + s * (rx * 0.5)) % w;
      final sy = (cy - ry + (s * 19) % (h * 0.6));
      canvas.drawCircle(Offset(sx, sy), 0.8, bgPaint);
    }
  }

  // Generate parametric trajectory points (infinity figure-8 loop)
  final count = isMini ? min(trail.length, 20) : min(trail.length, 34);
  final pts = <Offset>[];
  final dt = isMini ? 0.055 : 0.045;

  for (int i = 0; i < count; i++) {
    final t = time - i * dt;
    final px = cx + cos(t) * rx;
    final py = cy + sin(2 * t) * ry;
    pts.add(Offset(px, py));
  }

  if (pts.length < 2) return;

  final ballR = isMini ? 4.2 : 5.8;
  final stroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  final fill = Paint()..style = PaintingStyle.fill;

  // Render trail based on style
  switch (trail.style) {
    case TrailStyle.dot:
      final dotColor = (trail.id == 't2') ? const Color(0xFF00E5FF) : const Color(0xFF80D8FF);
      final coreColor = (trail.id == 't2') ? const Color(0xFF69F0AE) : Colors.white;

      // Connecting undulating filament
      for (int i = 0; i < pts.length - 1; i++) {
        final progress = (i + 0.5) / (pts.length - 1);
        final taper = (1.0 - progress).clamp(0.0, 1.0);
        stroke
          ..strokeWidth = (ballR * 0.5 * taper).clamp(0.4, ballR)
          ..color = dotColor.withValues(alpha: 0.45 * taper);
        canvas.drawLine(pts[i], pts[i + 1], stroke);
      }

      // Shimmering starlight beads
      for (int i = 0; i < pts.length; i++) {
        final progress = i / (pts.length - 1);
        final taper = (1.0 - progress).clamp(0.0, 1.0);
        final shimmer = 0.82 + 0.18 * sin(time * 10 + i * 0.7);
        final r = ballR * taper * shimmer;
        if (r <= 0.3) continue;

        // Halo
        fill.color = dotColor.withValues(alpha: 0.25 * taper);
        canvas.drawCircle(pts[i], r * 1.5, fill);
        // Bead
        fill.color = coreColor.withValues(alpha: 0.85 * taper);
        canvas.drawCircle(pts[i], r, fill);
        // Star glint
        fill.color = Colors.white.withValues(alpha: 0.95 * taper);
        canvas.drawCircle(pts[i], r * 0.4, fill);

        // 4-point micro cross glint on alternating beads
        if (i % 3 == 0 && r > 1.8) {
          final slen = r * 1.5;
          stroke
            ..strokeWidth = 0.8
            ..color = Colors.white.withValues(alpha: 0.75 * taper);
          canvas.drawLine(Offset(pts[i].dx - slen, pts[i].dy), Offset(pts[i].dx + slen, pts[i].dy), stroke);
          canvas.drawLine(Offset(pts[i].dx, pts[i].dy - slen), Offset(pts[i].dx, pts[i].dy + slen), stroke);
        }
      }
      break;

    case TrailStyle.spark:
      final sparkBase = const Color(0xFFFFD54F);
      final sparkGlow = const Color(0xFFFF9100);

      // Compute jagged lightning offsets
      final sparkPts = <Offset>[pts[0]];
      for (int i = 0; i < pts.length - 1; i++) {
        final p1 = pts[i];
        final p2 = pts[i + 1];
        final progress = i / (pts.length - 1);
        final taper = (1.0 - progress).clamp(0.0, 1.0);
        final dx = p2.dx - p1.dx;
        final dy = p2.dy - p1.dy;
        final segLen = sqrt(dx * dx + dy * dy);
        if (segLen > 0.001) {
          final nx = -dy / segLen;
          final ny = dx / segLen;
          final jitter = sin(time * 26 + i * 4.3) * (ballR * 0.7 * taper);
          sparkPts.add(Offset((p1.dx + p2.dx) * 0.5 + nx * jitter, (p1.dy + p2.dy) * 0.5 + ny * jitter));
        }
        sparkPts.add(p2);
      }

      // Outer electric bloom
      for (int i = 0; i < sparkPts.length - 1; i++) {
        final progress = (i + 0.5) / (sparkPts.length - 1);
        final taper = (1.0 - progress).clamp(0.0, 1.0);
        stroke
          ..strokeWidth = (ballR * 2.2 * taper).clamp(0.8, ballR * 2.2)
          ..color = sparkGlow.withValues(alpha: 0.3 * taper);
        canvas.drawLine(sparkPts[i], sparkPts[i + 1], stroke);
      }

      // Main lightning bolt
      for (int i = 0; i < sparkPts.length - 1; i++) {
        final progress = (i + 0.5) / (sparkPts.length - 1);
        final taper = (1.0 - progress).clamp(0.0, 1.0);
        stroke
          ..strokeWidth = (ballR * 1.1 * taper).clamp(0.6, ballR * 1.1)
          ..color = sparkBase.withValues(alpha: 0.88 * taper);
        canvas.drawLine(sparkPts[i], sparkPts[i + 1], stroke);
      }

      // White electric core
      for (int i = 0; i < sparkPts.length - 1; i++) {
        final progress = (i + 0.5) / (sparkPts.length - 1);
        final taper = (1.0 - progress).clamp(0.0, 1.0);
        stroke
          ..strokeWidth = (ballR * 0.42 * taper).clamp(0.4, ballR * 0.42)
          ..color = Colors.white.withValues(alpha: 0.95 * taper);
        canvas.drawLine(sparkPts[i], sparkPts[i + 1], stroke);
      }
      break;

    case TrailStyle.ghost:
      final ghostBase = const Color(0xFFB388FF);
      final ghostGlow = const Color(0xFF7C4DFF);

      // Flowing ethereal spirit ribbon
      for (int i = 0; i < pts.length - 1; i++) {
        final progress = (i + 0.5) / (pts.length - 1);
        final taper = (1.0 - progress).clamp(0.0, 1.0);
        stroke
          ..strokeWidth = (ballR * 1.8 * taper).clamp(0.6, ballR * 1.8)
          ..color = ghostGlow.withValues(alpha: 0.25 * taper);
        canvas.drawLine(pts[i], pts[i + 1], stroke);

        stroke
          ..strokeWidth = (ballR * 0.8 * taper).clamp(0.4, ballR * 0.8)
          ..color = ghostBase.withValues(alpha: 0.55 * taper);
        canvas.drawLine(pts[i], pts[i + 1], stroke);
      }

      // Spectral phantom echoes
      for (int i = 1; i < pts.length; i += 2) {
        final progress = i / (pts.length - 1);
        final taper = (1.0 - progress).clamp(0.0, 1.0);
        final gr = ballR * taper;
        if (gr <= 0.4) continue;
        fill.color = ghostBase.withValues(alpha: 0.35 * taper);
        canvas.drawCircle(pts[i], gr, fill);
        stroke
          ..strokeWidth = 1.0
          ..color = Colors.white.withValues(alpha: 0.55 * taper);
        canvas.drawCircle(pts[i], gr, stroke);
      }
      break;

    case TrailStyle.fire:
      // Billowing flame heat haze
      for (int i = 0; i < pts.length - 1; i++) {
        final progress = (i + 0.5) / (pts.length - 1);
        final taper = (1.0 - progress).clamp(0.0, 1.0);
        stroke
          ..strokeWidth = (ballR * 2.8 * taper).clamp(0.8, ballR * 2.8)
          ..color = const Color(0xFFFF1744).withValues(alpha: 0.30 * taper);
        canvas.drawLine(pts[i], pts[i + 1], stroke);
      }

      // Roaring orange/amber flame ribbon
      for (int i = 0; i < pts.length - 1; i++) {
        final progress = (i + 0.5) / (pts.length - 1);
        final taper = (1.0 - progress).clamp(0.0, 1.0);
        stroke
          ..strokeWidth = (ballR * 1.4 * taper).clamp(0.6, ballR * 1.4)
          ..color = const Color(0xFFFF6D00).withValues(alpha: 0.85 * taper);
        canvas.drawLine(pts[i], pts[i + 1], stroke);
      }

      // Incandescent yellow core
      for (int i = 0; i < pts.length - 1; i++) {
        final progress = (i + 0.5) / (pts.length - 1);
        final taper = (1.0 - progress).clamp(0.0, 1.0);
        stroke
          ..strokeWidth = (ballR * 0.55 * taper).clamp(0.4, ballR * 0.55)
          ..color = const Color(0xFFFFF9C4).withValues(alpha: 0.95 * taper);
        canvas.drawLine(pts[i], pts[i + 1], stroke);
      }

      // Ember sparks
      for (int i = 0; i < pts.length; i += 2) {
        final progress = i / (pts.length - 1);
        final taper = (1.0 - progress).clamp(0.0, 1.0);
        final emberSize = ballR * (0.55 + 0.25 * sin(time * 14 + i)) * taper;
        if (emberSize <= 0.4) continue;
        fill.color = (i % 4 == 0 ? const Color(0xFFFFEB3B) : const Color(0xFFFF3D00)).withValues(alpha: 0.9 * taper);
        canvas.drawCircle(Offset(pts[i].dx, pts[i].dy - emberSize), emberSize, fill);
      }
      break;

    case TrailStyle.rainbow:
      // Prismatic aurora borealis ribbon
      for (int i = 0; i < pts.length - 1; i++) {
        final progress = (i + 0.5) / (pts.length - 1);
        final taper = (1.0 - progress).clamp(0.0, 1.0);
        final hue = (time * 120 + i * 16) % 360;
        final color = HSLColor.fromAHSL(1.0, hue, 1.0, 0.55).toColor();

        // Chromatic bloom
        stroke
          ..strokeWidth = (ballR * 2.5 * taper).clamp(0.8, ballR * 2.5)
          ..color = color.withValues(alpha: 0.25 * taper);
        canvas.drawLine(pts[i], pts[i + 1], stroke);

        // Aurora ribbon
        stroke
          ..strokeWidth = (ballR * 1.3 * taper).clamp(0.6, ballR * 1.3)
          ..color = color.withValues(alpha: 0.88 * taper);
        canvas.drawLine(pts[i], pts[i + 1], stroke);

        // Luminous core filament
        stroke
          ..strokeWidth = (ballR * 0.4 * taper).clamp(0.4, ballR * 0.4)
          ..color = Colors.white.withValues(alpha: 0.92 * taper);
        canvas.drawLine(pts[i], pts[i + 1], stroke);
      }
      break;

    case TrailStyle.plasma:
      // Cosmic coronal glow
      for (int i = 0; i < pts.length - 1; i++) {
        final progress = (i + 0.5) / (pts.length - 1);
        final taper = (1.0 - progress).clamp(0.0, 1.0);
        stroke
          ..strokeWidth = (ballR * 2.8 * taper).clamp(0.8, ballR * 2.8)
          ..color = const Color(0xFF00E5FF).withValues(alpha: 0.28 * taper);
        canvas.drawLine(pts[i], pts[i + 1], stroke);
      }

      // Twin helical streamers
      for (int i = 0; i < pts.length - 1; i++) {
        final progress = (i + 0.5) / (pts.length - 1);
        final taper = (1.0 - progress).clamp(0.0, 1.0);
        final p1 = pts[i];
        final p2 = pts[i + 1];
        final dx = p2.dx - p1.dx;
        final dy = p2.dy - p1.dy;
        final segLen = sqrt(dx * dx + dy * dy);
        if (segLen > 0.001) {
          final nx = -dy / segLen;
          final ny = dx / segLen;
          final helix = sin(time * 16.0 + i * 0.8) * (ballR * 0.85 * taper);
          final h1 = Offset(p1.dx + nx * helix, p1.dy + ny * helix);
          final h2 = Offset(p2.dx + nx * helix, p2.dy + ny * helix);
          stroke
            ..strokeWidth = (ballR * 0.55 * taper).clamp(0.4, ballR * 0.55)
            ..color = const Color(0xFF18FFFF).withValues(alpha: 0.85 * taper);
          canvas.drawLine(h1, h2, stroke);

          final o1 = Offset(p1.dx - nx * helix, p1.dy - ny * helix);
          final o2 = Offset(p2.dx - nx * helix, p2.dy - ny * helix);
          stroke.color = const Color(0xFFB388FF).withValues(alpha: 0.85 * taper);
          canvas.drawLine(o1, o2, stroke);
        }
      }

      // Core beam
      for (int i = 0; i < pts.length - 1; i++) {
        final progress = (i + 0.5) / (pts.length - 1);
        final taper = (1.0 - progress).clamp(0.0, 1.0);
        stroke
          ..strokeWidth = (ballR * 0.45 * taper).clamp(0.4, ballR * 0.45)
          ..color = Colors.white.withValues(alpha: 0.95 * taper);
        canvas.drawLine(pts[i], pts[i + 1], stroke);
      }
      break;
  }

  // Lead Ball at head (pts[0])
  final head = pts[0];
  fill.color = trail.rarity.primaryColor.withValues(alpha: 0.35);
  canvas.drawCircle(head, ballR + 2.5, fill);

  fill.color = trail.rarity.primaryColor;
  canvas.drawCircle(head, ballR, fill);

  fill.color = Colors.white.withValues(alpha: 0.85);
  canvas.drawCircle(Offset(head.dx - ballR * 0.28, head.dy - ballR * 0.28), ballR * 0.35, fill);
}

class _BallPreviewPainter extends CustomPainter {
  final BallSkin skin;
  final double time;

  _BallPreviewPainter({required this.skin, required this.time});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.5, size.height * 0.5);
    final r = size.width * 0.36;

    final fill = Paint()..style = PaintingStyle.fill;
    final stroke = Paint()..style = PaintingStyle.stroke;

    // Outer glow halo
    fill.color = skin.glowColor.withValues(alpha: 0.35);
    canvas.drawCircle(center, r + 4.5, fill);

    // 3D base body gradient
    fill.shader = RadialGradient(
      center: const Alignment(-0.35, -0.35),
      radius: 0.95,
      colors: [skin.mainColor, skin.darkColor],
    ).createShader(Rect.fromCircle(center: center, radius: r));
    canvas.drawCircle(center, r, fill);
    fill.shader = null;

    // Signature cosmetic effects
    switch (skin.id) {
      case 'kara_delik_top':
        // Accretion disk
        stroke
          ..strokeWidth = 2.0
          ..color = const Color(0xFFD500F9);
        canvas.save();
        canvas.translate(center.dx, center.dy);
        canvas.rotate(time * 2.0);
        canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: r * 2.6, height: r * 0.65), stroke);
        fill.color = Colors.black;
        canvas.drawCircle(Offset.zero, r * 0.7, fill);
        canvas.restore();
        break;

      case 'elmas_top':
        stroke
          ..strokeWidth = 1.0
          ..color = const Color(0xFF80D8FF);
        canvas.drawLine(Offset(center.dx - r * 0.7, center.dy), Offset(center.dx + r * 0.7, center.dy), stroke);
        canvas.drawLine(Offset(center.dx, center.dy - r * 0.7), Offset(center.dx, center.dy + r * 0.7), stroke);
        // Star glint
        final slen = r * 0.8;
        stroke.color = Colors.white;
        canvas.drawLine(Offset(center.dx - slen, center.dy), Offset(center.dx + slen, center.dy), stroke);
        canvas.drawLine(Offset(center.dx, center.dy - slen), Offset(center.dx, center.dy + slen), stroke);
        break;

      case 'altin':
        stroke
          ..strokeWidth = 1.2
          ..color = const Color(0xFFFFF9C4);
        canvas.drawCircle(center, r + 1.5, stroke);
        fill.color = Colors.white.withValues(alpha: 0.6);
        canvas.drawCircle(Offset(center.dx + r * 0.35, center.dy - r * 0.35), 1.5, fill);
        break;

      case 'isilti':
        // Epic Celestial Starlight Preview
        final sa = time * 2.2;
        final pulse = 0.85 + sin(time * 6.0) * 0.15;
        // Halo
        stroke
          ..strokeWidth = 1.2
          ..color = const Color(0xFFFFE082).withValues(alpha: 0.70 * pulse);
        canvas.drawCircle(center, r * 1.15, stroke);
        // Primary 4-point flare
        final rayLen1 = r * 1.5 * pulse;
        stroke
          ..strokeWidth = 1.8
          ..color = const Color(0xFFFFFDE7);
        canvas.drawLine(Offset(center.dx - cos(sa) * rayLen1, center.dy - sin(sa) * rayLen1), Offset(center.dx + cos(sa) * rayLen1, center.dy + sin(sa) * rayLen1), stroke);
        canvas.drawLine(Offset(center.dx - cos(sa + pi / 2) * rayLen1, center.dy - sin(sa + pi / 2) * rayLen1), Offset(center.dx + cos(sa + pi / 2) * rayLen1, center.dy + sin(sa + pi / 2) * rayLen1), stroke);
        // Diagonal 4-point flare
        final rayLen2 = r * 0.85 * pulse;
        stroke
          ..strokeWidth = 1.1
          ..color = const Color(0xFFFFD54F);
        canvas.drawLine(Offset(center.dx - cos(sa + pi / 4) * rayLen2, center.dy - sin(sa + pi / 4) * rayLen2), Offset(center.dx + cos(sa + pi / 4) * rayLen2, center.dy + sin(sa + pi / 4) * rayLen2), stroke);
        canvas.drawLine(Offset(center.dx - cos(sa + 3 * pi / 4) * rayLen2, center.dy - sin(sa + 3 * pi / 4) * rayLen2), Offset(center.dx + cos(sa + 3 * pi / 4) * rayLen2, center.dy + sin(sa + 3 * pi / 4) * rayLen2), stroke);
        // Orbiting stardust
        for (int i = 0; i < 4; i++) {
          final oa = -time * 3.0 + i * (pi / 2);
          final od = r * (0.65 + 0.15 * sin(time * 4.0 + i));
          fill.color = (i.isEven) ? const Color(0xFFFFF9C4) : const Color(0xFFFFCA28);
          canvas.drawCircle(Offset(center.dx + cos(oa) * od, center.dy + sin(oa) * od), 1.2, fill);
        }
        break;

      case 'ates':
        stroke
          ..strokeWidth = 1.5
          ..color = const Color(0xFFFFD54F);
        for (int i = 0; i < 4; i++) {
          final a = time * 4 + i * (pi / 2);
          canvas.drawLine(
            Offset(center.dx + cos(a) * r, center.dy + sin(a) * r),
            Offset(center.dx + cos(a) * (r + 3.5), center.dy + sin(a) * (r + 3.5)),
            stroke,
          );
        }
        break;

      case 'plazma':
        stroke
          ..strokeWidth = 1.4
          ..color = const Color(0xFF18FFFF);
        canvas.drawCircle(center, r * 0.65, stroke);
        break;

      default:
        break;
    }

    // Specular shine
    fill.color = Colors.white.withValues(alpha: 0.7);
    canvas.drawCircle(Offset(center.dx - r * 0.32, center.dy - r * 0.32), r * 0.32, fill);
    fill.color = Colors.white;
    canvas.drawCircle(Offset(center.dx - r * 0.42, center.dy - r * 0.42), r * 0.14, fill);
  }

  @override
  bool shouldRepaint(covariant _BallPreviewPainter oldDelegate) => true;
}

class _PaddlePreviewPainter extends CustomPainter {
  final PaddleSkin skin;
  final double time;

  _PaddlePreviewPainter({required this.skin, required this.time});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(size.height * 0.5));

    final fill = Paint()..style = PaintingStyle.fill;
    final stroke = Paint()..style = PaintingStyle.stroke;

    // Body gradient
    fill.shader = LinearGradient(
      colors: [skin.color1, skin.color2],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ).createShader(rect);
    canvas.drawRRect(rrect, fill);
    fill.shader = null;

    // Specular top highlight line
    stroke
      ..strokeWidth = 1.2
      ..color = Colors.white.withValues(alpha: 0.55);
    canvas.drawLine(Offset(rect.left + 8, rect.top + 2.5), Offset(rect.right - 8, rect.top + 2.5), stroke);

    // Side thruster nodes
    fill.color = skin.glowColor;
    canvas.drawCircle(Offset(rect.left + 5, rect.center.dy), 2.2, fill);
    canvas.drawCircle(Offset(rect.right - 5, rect.center.dy), 2.2, fill);
    fill.color = Colors.white;
    canvas.drawCircle(Offset(rect.left + 5, rect.center.dy), 1.0, fill);
    canvas.drawCircle(Offset(rect.right - 5, rect.center.dy), 1.0, fill);

    // Rim
    stroke
      ..strokeWidth = 1.0
      ..color = skin.glowColor.withValues(alpha: 0.6);
    canvas.drawRRect(rrect, stroke);
  }

  @override
  bool shouldRepaint(covariant _PaddlePreviewPainter oldDelegate) => false;
}

/// Particle model representing a flying gold coin in the purchase stream.
class _FlyingCoin {
  final Offset start;
  final Offset target;
  final Offset control;
  final double delay; // seconds
  final double duration; // seconds
  final double spinSpeed;
  final double scale;
  final double initialAngle;

  _FlyingCoin({
    required this.start,
    required this.target,
    required this.control,
    required this.delay,
    required this.duration,
    required this.spinSpeed,
    required this.scale,
    required this.initialAngle,
  });

  double progress(double elapsed) {
    if (elapsed < delay) return -1.0;
    return ((elapsed - delay) / duration).clamp(0.0, 1.0);
  }

  Offset position(double t) {
    final inv = 1.0 - t;
    return start * (inv * inv) + control * (2.0 * inv * t) + target * (t * t);
  }
}

/// Burst spark particle spawned when a coin strikes the destination chest/button.
class _ImpactSpark {
  final Offset origin;
  final Offset velocity;
  final double birthTime;
  final double lifeTime;
  final Color color;
  final double size;

  _ImpactSpark({
    required this.origin,
    required this.velocity,
    required this.birthTime,
    required this.lifeTime,
    required this.color,
    required this.size,
  });
}

/// CustomPainter rendering smooth curved flying coins and impact spark bursts.
class _FlyingCoinsPainter extends CustomPainter {
  final List<_FlyingCoin> coins;
  final List<_ImpactSpark> sparks;
  final double elapsed;

  _FlyingCoinsPainter({
    required this.coins,
    required this.sparks,
    required this.elapsed,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw impact sparks
    for (final s in sparks) {
      final sparkAge = elapsed - s.birthTime;
      if (sparkAge < 0 || sparkAge > s.lifeTime) continue;
      final progress = sparkAge / s.lifeTime;
      final pos = s.origin + s.velocity * sparkAge;
      final alpha = (1.0 - progress).clamp(0.0, 1.0);
      final r = s.size * (1.0 - progress * 0.5);
      final paint = Paint()..color = s.color.withValues(alpha: alpha);
      canvas.drawCircle(pos, r, paint);
    }

    // 2. Draw flying coins
    final coinPaint = Paint()..style = PaintingStyle.fill;
    final rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;

    for (final coin in coins) {
      final t = coin.progress(elapsed);
      if (t < 0.0 || t >= 1.0) continue;

      final pos = coin.position(t);
      final coinScale = coin.scale * (sin(t * pi) * 0.4 + 0.85);
      final spin = coin.initialAngle + elapsed * coin.spinSpeed;
      final spinCos = cos(spin);

      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.scale(spinCos.abs().clamp(0.12, 1.0) * coinScale, coinScale);

      const radius = 10.0;
      final rect = Rect.fromCircle(center: Offset.zero, radius: radius);

      // Gold base fill
      coinPaint.shader = const LinearGradient(
        colors: [Color(0xFFFFF9C4), Color(0xFFFFD54F), Color(0xFFFF8F00)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(rect);
      canvas.drawCircle(Offset.zero, radius, coinPaint);

      // Outer rim
      rimPaint.color = const Color(0xFFFFF59D).withValues(alpha: 0.95);
      canvas.drawCircle(Offset.zero, radius - 1.2, rimPaint);

      // Center embossed star/circle emblem
      final centerPaint = Paint()..color = const Color(0xFFFFF8E1);
      canvas.drawCircle(Offset.zero, 3.2, centerPaint);

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _FlyingCoinsPainter oldDelegate) => true;
}
