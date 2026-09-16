import 'package:flutter/material.dart';
import '../engine/i18n.dart';
import '../models/cosmetics.dart';
import '../storage/save_manager.dart';
import 'crate_opening_dialog.dart';

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
    _tabController = TabController(length: 5, vsync: this);
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
              _buildBackgroundsTab(context, save),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCratesTab(BuildContext context, SaveManager save) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: CrateDef.allCrates.length,
      itemBuilder: (context, index) {
        final crate = CrateDef.allCrates[index];
        final canAfford = save.gold >= crate.cost;

        return Container(
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
                onPressed: canAfford
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
        );
      },
    );
  }

  Widget _buildBallsTab(BuildContext context, SaveManager save) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.85,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
      ),
      itemCount: BallSkin.allSkins.length,
      itemBuilder: (context, index) {
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
                ElevatedButton(
                  onPressed: save.gold >= skin.cost
                      ? () async {
                          final ok = await save.spendGold(skin.cost);
                          if (ok) {
                            save.unlockBall(skin.id);
                            save.equipBall(skin.id);
                          }
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFD54F),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('${skin.cost} 🪙', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11)),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPaddlesTab(BuildContext context, SaveManager save) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: PaddleSkin.allSkins.length,
      itemBuilder: (context, index) {
        final skin = PaddleSkin.allSkins[index];
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
                ElevatedButton(
                  onPressed: save.gold >= skin.cost
                      ? () async {
                          final ok = await save.spendGold(skin.cost);
                          if (ok) {
                            save.unlockPaddle(skin.id);
                            save.equipPaddle(skin.id);
                          }
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFD54F),
                    foregroundColor: Colors.black,
                  ),
                  child: Text('${skin.cost} 🪙', style: const TextStyle(fontWeight: FontWeight.w900)),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTrailsTab(BuildContext context, SaveManager save) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: TrailSkin.allTrails.length,
      itemBuilder: (context, index) {
        final trail = TrailSkin.allTrails[index];
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
                ElevatedButton(
                  onPressed: save.gold >= trail.cost
                      ? () async {
                          final ok = await save.spendGold(trail.cost);
                          if (ok) {
                            save.unlockTrail(trail.id);
                            save.equipTrail(trail.id);
                          }
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFD54F),
                    foregroundColor: Colors.black,
                  ),
                  child: Text('${trail.cost} 🪙', style: const TextStyle(fontWeight: FontWeight.w900)),
                ),
            ],
          ),
        );
      },
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
                  onPressed: save.gold >= theme.cost
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
