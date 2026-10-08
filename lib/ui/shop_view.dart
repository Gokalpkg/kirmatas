import 'dart:math';
import 'package:flutter/material.dart';
import '../engine/i18n.dart';
import '../models/cosmetics.dart';
import '../storage/save_manager.dart';
import 'crate_opening_dialog.dart';
import 'fortune_wheel_dialog.dart';
import 'rewarded_ad_button.dart';

class ShopView extends StatefulWidget {
  const ShopView({super.key});

  @override
  State<ShopView> createState() => _ShopViewState();
}

class _ShopViewState extends State<ShopView> with TickerProviderStateMixin {
  late final TabController _tabController;
  late final AnimationController _animController;
  String? _selectedPreviewTrailId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _animController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final save = SaveManager.instance;

    return ListenableBuilder(
      listenable: save,
      builder: (context, _) {
        return Scaffold(
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
                    save.equipBrickStyle('brick_neon');
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
                        content: Text('🎲 Tüm kategoriler için Rastgele modu aktif edildi!'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                },
              ),
              Container(
                margin: const EdgeInsets.only(right: 16, top: 10, bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C2234),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0x33FFD54F)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.monetization_on, color: Color(0xFFFFD54F), size: 16),
                    const SizedBox(width: 6),
                    Text(
                      '${save.gold}',
                      style: const TextStyle(
                        color: Color(0xFFFFD54F),
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                  ],
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
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: crateInfo.primaryColor.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                  border: Border.all(color: crateInfo.primaryColor, width: 2),
                ),
                child: Icon(crateInfo.icon, color: crateInfo.primaryColor, size: 30),
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
              ElevatedButton(
                onPressed: canAfford
                    ? () async {
                        final ok = await save.spendGold(cost);
                        if (ok && context.mounted) {
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (_) => CrateOpeningDialog(categoryCrate: crateInfo),
                          );
                        }
                      }
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
                    Text(
                      '$cost',
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 10),

          // 2. Shards Progress & Guaranteed Redemption
          Row(
            children: [
              // Shard Progress Pips
              Row(
                children: [
                  const Icon(Icons.diamond, color: Color(0xFF00E5FF), size: 18),
                  const SizedBox(width: 6),
                  Text(
                    '${I18n.tr('shards')}: $shards / 3',
                    style: const TextStyle(
                      color: Color(0xFF00E5FF),
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 8),
                  for (int i = 0; i < 3; i++) ...[
                    Container(
                      width: 10,
                      height: 10,
                      margin: const EdgeInsets.only(right: 3),
                      decoration: BoxDecoration(
                        color: i < shards ? const Color(0xFF00E5FF) : Colors.white12,
                        shape: BoxShape.circle,
                        boxShadow: i < shards
                            ? [const BoxShadow(color: Color(0xFF00E5FF), blurRadius: 4)]
                            : null,
                      ),
                    ),
                  ],
                ],
              ),
              const Spacer(),
              if (shards >= 3)
                ElevatedButton(
                  onPressed: () async {
                    if (allOwned) {
                      final ok = await save.consumeShards(category, 3);
                      if (ok) {
                        save.addGold(1000);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('${I18n.tr('all_items_unlocked')} (+1000 🪙)')),
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
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  ),
                  child: Text(
                    allOwned ? I18n.tr('all_items_unlocked') : I18n.tr('use_shards_guaranteed'),
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11),
                  ),
                ),
            ],
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
                      child: Text(
                        'ŞANS',
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
                          const Text(
                            'ŞANS ÇARKI',
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
                      const Text(
                        'Reklam İzle & Sandık, Altın veya Parça Kazan!',
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
                      Text(
                        'ÇEVİR',
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

        for (final crate in CrateDef.allCrates) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  crate.primaryColor.withValues(alpha: 0.15),
                  const Color(0xFF141724),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: crate.primaryColor.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: crate.primaryColor.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                    border: Border.all(color: crate.primaryColor, width: 2),
                  ),
                  child: Icon(Icons.inventory_2, color: crate.primaryColor, size: 36),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        crate.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${crate.tier.label} ${I18n.tr('crate_tier_suffix')}',
                        style: TextStyle(
                          color: crate.primaryColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: (save.gold >= crate.cost)
                      ? () async {
                          final success = await save.spendGold(crate.cost);
                          if (success && context.mounted) {
                            showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (_) => CrateOpeningDialog(crate: crate),
                            );
                          }
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: crate.primaryColor,
                    foregroundColor: Colors.black,
                    disabledBackgroundColor: Colors.white12,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.monetization_on, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        '${crate.cost}',
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
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
            title: '🎲 RASTGELE BLOK',
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
            title: '🎲 RASTGELE TOP',
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
          title: '🎲 RASTGELE RAKET',
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
          title: '🎲 RASTGELE İZ',
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
                                        child: const Text(
                                          'CANLI',
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
                                    Text(
                                      '• ${trail.length} Segment',
                                      style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _getTrailShortBadge(trail.style),
                                  style: const TextStyle(color: Colors.white54, fontSize: 10),
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
          title: '🎲 RASTGELE ARKA PLAN',
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
                ElevatedButton(
                  onPressed: (save.gold >= theme.cost)
                      ? () async {
                          final ok = await save.unlockBackground(theme.id, theme.cost);
                          if (ok) {
                            save.selectBackground(theme.id);
                          }
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFD54F),
                    foregroundColor: Colors.black,
                    disabledBackgroundColor: Colors.white12,
                    disabledForegroundColor: Colors.white38,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    '${theme.cost} 🪙',
                    style: const TextStyle(fontWeight: FontWeight.w900),
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
                  Text(
                    'CANLI İZ SİMÜLASYONU: ${trail.name}',
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
                child: Text(
                  '${trail.rarity.label} • ${trail.length} Segment',
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
        return '✨ Starlight Takımyıldızı';
      case TrailStyle.spark:
        return '⚡ Elektrik & Şimşek';
      case TrailStyle.ghost:
        return '👻 Ruhani Eko & Sis';
      case TrailStyle.fire:
        return '🔥 Blazing Cehennem Alevi';
      case TrailStyle.rainbow:
        return '🌈 Prizmatik Aurora';
      case TrailStyle.plasma:
        return '⚛️ Kuantum Plazma Işını';
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
    const neonCyan = Color(0xFF00E5FF);
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0x5500E5FF), Color(0xCC07111D)],
      ).createShader(rect);
    canvas.drawRRect(rrect, bgPaint);

    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..color = const Color(0x5500E5FF);
    canvas.drawRRect(rrect, glowPaint);

    final tubePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..color = neonCyan;
    canvas.drawRRect(rrect, tubePaint);

    final corePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = Colors.white;
    canvas.drawRRect(rrect.deflate(0.4), corePaint);

    final cathPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = Colors.white;
    canvas.drawLine(Offset(rect.left + 8, rect.center.dy), Offset(rect.right - 8, rect.center.dy), cathPaint);

    final bracketPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = Colors.white;
    canvas.drawLine(Offset(rect.left + 3, rect.top + 7), Offset(rect.left + 3, rect.top + 3), bracketPaint);
    canvas.drawLine(Offset(rect.left + 3, rect.top + 3), Offset(rect.left + 7, rect.top + 3), bracketPaint);
    canvas.drawLine(Offset(rect.right - 7, rect.bottom - 3), Offset(rect.right - 3, rect.bottom - 3), bracketPaint);
    canvas.drawLine(Offset(rect.right - 3, rect.bottom - 3), Offset(rect.right - 3, rect.bottom - 7), bracketPaint);
  }

  void _paintPixel(Canvas canvas, Rect rect) {
    final borderPaint = Paint()..color = Colors.black;
    canvas.drawRect(rect, borderPaint);

    final bodyPaint = Paint()..color = const Color(0xFFFFD54F);
    canvas.drawRect(rect.deflate(2), bodyPaint);

    final lightPaint = Paint()..color = const Color(0xFFFFF9C4);
    canvas.drawRect(Rect.fromLTWH(rect.left + 2, rect.top + 2, rect.width - 5, 2.5), lightPaint);
    canvas.drawRect(Rect.fromLTWH(rect.left + 2, rect.top + 2, 2.5, rect.height - 5), lightPaint);

    final darkPaint = Paint()..color = const Color(0xFFE65100);
    canvas.drawRect(Rect.fromLTWH(rect.left + 4, rect.bottom - 4.5, rect.width - 6, 2.5), darkPaint);
    canvas.drawRect(Rect.fromLTWH(rect.right - 4.5, rect.top + 4, 2.5, rect.height - 6), darkPaint);

    final whitePaint = Paint()..color = Colors.white;
    canvas.drawRect(Rect.fromLTWH(rect.left + 5, rect.top + 5, 3.5, 3.5), whitePaint);

    final ditherPaint = Paint()..color = const Color(0x88E65100);
    canvas.drawRect(Rect.fromLTWH(rect.left + 6, rect.bottom - 7, 2, 2), ditherPaint);
    canvas.drawRect(Rect.fromLTWH(rect.right - 7, rect.top + 6, 2, 2), ditherPaint);
  }

  void _paintGloss(Canvas canvas, Rect rect, RRect rrect) {
    final shadowPaint = Paint()..color = const Color(0xFF880E4F);
    canvas.drawRRect(RRect.fromRectAndRadius(rect.translate(0, 2), const Radius.circular(5)), shadowPaint);

    final bodyPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFFF80AB), Color(0xFFFF4081), Color(0xFFC2185B)],
        stops: [0.0, 0.5, 1.0],
      ).createShader(rect);
    canvas.drawRRect(rrect, bodyPaint);

    final domeRect = Rect.fromLTWH(rect.left + 2, rect.top + 1.5, rect.width - 4, rect.height * 0.45);
    final domePaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xDDFFFFFF), Color(0x00FFFFFF)],
      ).createShader(domeRect);
    canvas.drawRRect(RRect.fromRectAndRadius(domeRect, const Radius.circular(3)), domePaint);

    final starPaint = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(rect.left + 7, rect.top + 5), 1.5, starPaint);

    final rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = const Color(0xAAFFFFFF);
    canvas.drawRRect(rrect, rimPaint);
  }

  void _paintNeu(Canvas canvas, Rect rect, RRect rrect) {
    canvas.save();
    canvas.translate(-1.5, -1.5);
    final lightGlow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = const Color(0x66ECEFF1);
    canvas.drawRRect(rrect, lightGlow);
    canvas.restore();

    canvas.save();
    canvas.translate(2.0, 2.0);
    final darkGlow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = const Color(0x66000000);
    canvas.drawRRect(rrect, darkGlow);
    canvas.restore();

    final bodyPaint = Paint()..color = const Color(0xFF78909C);
    canvas.drawRRect(rrect, bodyPaint);

    final innerRRect = rrect.deflate(2.0);
    final innerPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0x44263238), Color(0x44ECEFF1)],
      ).createShader(innerRRect.outerRect);
    canvas.drawRRect(innerRRect, innerPaint);

    final slotRect = Rect.fromCenter(center: rect.center, width: rect.width * 0.45, height: 3.0);
    final slotPaint = Paint()..color = const Color(0x88263238);
    canvas.drawRRect(RRect.fromRectAndRadius(slotRect, const Radius.circular(1.5)), slotPaint);
    final slotHighlight = Paint()
      ..strokeWidth = 0.8
      ..color = const Color(0xAAECEFF1);
    canvas.drawLine(Offset(slotRect.left + 1, slotRect.bottom), Offset(slotRect.right - 1, slotRect.bottom), slotHighlight);
  }

  void _paintCyber(Canvas canvas, Rect rect, RRect rrect) {
    final hullPaint = Paint()..color = const Color(0xFF0E1626);
    canvas.drawRRect(rrect, hullPaint);

    final innerRRect = rrect.deflate(1.2);
    final platePaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF263248), Color(0xFF0E1626), Color(0xFF133E54)],
      ).createShader(innerRRect.outerRect);
    canvas.drawRRect(innerRRect, platePaint);

    final techPaint = Paint()
      ..strokeWidth = 0.8
      ..color = const Color(0x3300E5FF);
    canvas.drawLine(Offset(rect.left + 8, rect.top + 3), Offset(rect.left + 15, rect.bottom - 3), techPaint);
    canvas.drawLine(Offset(rect.right - 15, rect.top + 3), Offset(rect.right - 8, rect.bottom - 3), techPaint);

    final conduitGlow = Paint()
      ..strokeWidth = 2.5
      ..color = const Color(0x5500E5FF);
    canvas.drawLine(Offset(rect.left + 8, rect.center.dy), Offset(rect.right - 8, rect.center.dy), conduitGlow);
    final conduitCore = Paint()
      ..strokeWidth = 1.2
      ..color = Colors.white;
    canvas.drawLine(Offset(rect.left + 10, rect.center.dy), Offset(rect.right - 10, rect.center.dy), conduitCore);

    final rivetPaint = Paint()..color = const Color(0xFF00E5FF);
    canvas.drawCircle(Offset(rect.left + 4, rect.top + 4), 1.2, rivetPaint);
    canvas.drawCircle(Offset(rect.right - 4, rect.top + 4), 1.2, rivetPaint);
    canvas.drawCircle(Offset(rect.left + 4, rect.bottom - 4), 1.2, rivetPaint);
    canvas.drawCircle(Offset(rect.right - 4, rect.bottom - 4), 1.2, rivetPaint);

    final rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = const Color(0x9900E5FF);
    canvas.drawRRect(rrect, rimPaint);
  }

  void _paintCosmic(Canvas canvas, Rect rect, RRect rrect) {
    final nebulaPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFE040FB),
          Color(0xFF240046),
          Color(0xFF7C4DFF),
          Color(0xFF00E5FF),
        ],
        stops: [0.0, 0.4, 0.75, 1.0],
      ).createShader(rect);
    canvas.drawRRect(rrect, nebulaPaint);

    final linePaint = Paint()
      ..strokeWidth = 1.0
      ..color = const Color(0x66FFFFFF);
    canvas.drawLine(Offset(rect.left + 8, rect.top + 2), Offset(rect.right - 8, rect.bottom - 2), linePaint);

    final c = rect.center;
    final starPaint = Paint()
      ..strokeWidth = 1.4
      ..color = Colors.white;
    canvas.drawLine(Offset(c.dx - 5, c.dy), Offset(c.dx + 5, c.dy), starPaint);
    canvas.drawLine(Offset(c.dx, c.dy - 5), Offset(c.dx, c.dy + 5), starPaint);

    final dotPaint = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(c.dx - 18, c.dy - 3), 1.0, dotPaint);
    canvas.drawCircle(Offset(c.dx + 18, c.dy + 3), 1.0, dotPaint);

    final auraPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = const Color(0xCC18FFFF);
    canvas.drawRRect(rrect, auraPaint);
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
