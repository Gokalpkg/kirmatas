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

class _ShopViewState extends State<ShopView> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
  }

  @override
  void dispose() {
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
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFD54F),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              '500 🪙 BÜYÜK ÖDÜL',
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
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
                    Container(
                      height: 28,
                      decoration: BoxDecoration(
                        color: style.accent.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.7)),
                        boxShadow: [BoxShadow(color: style.accent.withValues(alpha: 0.45), blurRadius: 8)],
                      ),
                    ),
                    const SizedBox(height: 12),
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
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: skin.mainColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: skin.glowColor, blurRadius: 14),
                        ],
                      ),
                    ),
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
                    Container(
                      width: 72,
                      height: 18,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [skin.color1, skin.color2]),
                        borderRadius: BorderRadius.circular(9),
                        boxShadow: [
                          BoxShadow(color: skin.glowColor, blurRadius: 10),
                        ],
                      ),
                    ),
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
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildCategoryCrateHeader(context, save, 'trails'),
        for (final trail in TrailSkin.allTrails) ...[
          Builder(
            builder: (context) {
              final owned = save.unlockedTrails.contains(trail.id);
              final equipped = save.activeTrail == trail.id;

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
                    const Icon(Icons.auto_awesome, color: Color(0xFFFFD54F), size: 28),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            trail.name,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14),
                          ),
                          Text(
                            trail.rarity.label,
                            style: TextStyle(color: trail.rarity.primaryColor, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    if (equipped)
                      Text(I18n.tr('equipped'), style: const TextStyle(color: Color(0xFF00E5FF), fontWeight: FontWeight.w900))
                    else if (owned)
                      OutlinedButton(
                        onPressed: () => save.equipTrail(trail.id),
                        style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
                        child: Text(I18n.tr('use')),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: trail.rarity.primaryColor.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.lock_outline, size: 13, color: trail.rarity.primaryColor),
                            const SizedBox(width: 4),
                            Text(
                              I18n.tr('from_crate'),
                              style: TextStyle(
                                color: trail.rarity.primaryColor,
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

  Widget _buildBackgroundsTab(BuildContext context, SaveManager save) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: BackgroundTheme.allThemes.length,
      itemBuilder: (context, index) {
        final theme = BackgroundTheme.allThemes[index];
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
    );
  }
}
