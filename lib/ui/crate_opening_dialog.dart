import 'dart:math';
import 'package:flutter/material.dart';
import '../engine/audio_manager.dart';
import '../engine/i18n.dart';
import '../models/cosmetics.dart';
import '../storage/save_manager.dart';

class CrateOpeningDialog extends StatefulWidget {
  final CrateDef? crate;
  final CategoryCrateInfo? categoryCrate;
  final bool isGuaranteedRedemption;
  final String? category;

  const CrateOpeningDialog({
    super.key,
    this.crate,
    this.categoryCrate,
    this.isGuaranteedRedemption = false,
    this.category,
  }) : assert(crate != null || categoryCrate != null || isGuaranteedRedemption);

  @override
  State<CrateOpeningDialog> createState() => _CrateOpeningDialogState();
}

class _CrateOpeningDialogState extends State<CrateOpeningDialog> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _opened = false;
  dynamic _reward;
  String _rewardTitle = '';
  String _rewardSubtitle = '';
  Rarity _rewardRarity = Rarity.common;
  bool _isDuplicate = false;
  int _duplicateGold = 0;
  bool _isShardReward = false;

  Color get _primaryColor {
    if (widget.crate != null) return widget.crate!.primaryColor;
    if (widget.categoryCrate != null) return widget.categoryCrate!.primaryColor;
    return const Color(0xFF00E5FF);
  }

  String get _crateName {
    if (widget.isGuaranteedRedemption) {
      return I18n.tr('guaranteed_item_unlocked');
    }
    if (widget.crate != null) return widget.crate!.name;
    if (widget.categoryCrate != null) return widget.categoryCrate!.name;
    return 'CRATE';
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _openCrate();
  }

  void _openCrate() {
    final save = SaveManager.instance;
    final rand = Random();

    if (widget.isGuaranteedRedemption) {
      // Guaranteed unowned item redemption from 3 shards
      final cat = widget.category ?? widget.categoryCrate?.category ?? 'balls';
      _handleGuaranteedRedemption(save, cat, rand);
    } else if (widget.categoryCrate != null) {
      // Specific Category Crate (Balls, Paddles, Trails, Bricks)
      final cat = widget.categoryCrate!.category;
      _handleCategoryCrate(save, cat, rand);
    } else {
      // General Crates tab: ONLY aquarium fish/creatures drop from these crates!
      _handleAquariumCrate(save, rand);
    }

    _controller.forward().then((_) {
      setState(() {
        _opened = true;
      });
      AudioManager.instance.playSfx(GameSfx.victory);
    });
  }

  void _handleAquariumCrate(SaveManager save, Random rand) {
    final luckLevel = save.upgrades['luck'] ?? 0;
    final weights = Map<Rarity, double>.from(widget.crate!.weights);
    weights[Rarity.legendary] = (weights[Rarity.legendary] ?? 1.0) * (1.0 + luckLevel * 0.35);
    weights[Rarity.epic] = (weights[Rarity.epic] ?? 5.0) * (1.0 + luckLevel * 0.25);

    double totalWeight = weights.values.fold(0, (a, b) => a + b);
    double roll = rand.nextDouble() * totalWeight;
    Rarity rolledRarity = Rarity.common;

    for (final entry in weights.entries) {
      if (roll <= entry.value) {
        rolledRarity = entry.key;
        break;
      }
      roll -= entry.value;
    }
    _rewardRarity = rolledRarity;

    // ONLY Aquarium Fish drop from the general crates tab
    final available = FishItem.allFish.where((f) => f.rarity == rolledRarity).toList();
    final fish = available.isNotEmpty ? available[rand.nextInt(available.length)] : FishItem.allFish.first;
    _reward = fish;
    _rewardTitle = fish.name;

    if (save.unlockedFish.contains(fish.id)) {
      _isDuplicate = true;
      _duplicateGold = 120 + rand.nextInt(160);
      save.addGold(_duplicateGold);
      _rewardSubtitle = I18n.tr('duplicate_reward').replaceAll('{gold}', '$_duplicateGold');
    } else {
      _rewardSubtitle = I18n.tr('new_fish_unlocked');
      save.addFish(fish.id);
    }
  }

  void _handleCategoryCrate(SaveManager save, String category, Random rand) {
    final luckLevel = save.upgrades['luck'] ?? 0;
    final weights = Map<Rarity, double>.from(CategoryCrateInfo.rarityWeights);
    // Legendary is extremely rare (~3%) as requested
    weights[Rarity.legendary] = (weights[Rarity.legendary] ?? 3.0) * (1.0 + luckLevel * 0.25);
    weights[Rarity.epic] = (weights[Rarity.epic] ?? 12.0) * (1.0 + luckLevel * 0.20);

    double totalWeight = weights.values.fold(0, (a, b) => a + b);
    double roll = rand.nextDouble() * totalWeight;
    Rarity rolledRarity = Rarity.common;

    for (final entry in weights.entries) {
      if (roll <= entry.value) {
        rolledRarity = entry.key;
        break;
      }
      roll -= entry.value;
    }
    _rewardRarity = rolledRarity;

    switch (category) {
      case 'balls':
        final list = BallSkin.allSkins.where((s) => s.rarity == rolledRarity).toList();
        final skin = list.isNotEmpty ? list[rand.nextInt(list.length)] : BallSkin.allSkins[rand.nextInt(BallSkin.allSkins.length)];
        _reward = skin;
        _rewardTitle = skin.name;
        if (save.unlockedBalls.contains(skin.id)) {
          _isDuplicate = true;
          _isShardReward = true;
          save.addShard(category, 1);
          _rewardSubtitle = I18n.tr('duplicate_shard_reward').replaceAll('{count}', '${save.getShards(category)}');
        } else {
          _rewardSubtitle = I18n.tr('new_ball_unlocked');
          save.unlockBall(skin.id);
        }
        break;

      case 'paddles':
        final list = PaddleSkin.allSkins.where((s) => s.rarity == rolledRarity).toList();
        final skin = list.isNotEmpty ? list[rand.nextInt(list.length)] : PaddleSkin.allSkins[rand.nextInt(PaddleSkin.allSkins.length)];
        _reward = skin;
        _rewardTitle = skin.name;
        if (save.unlockedPaddles.contains(skin.id)) {
          _isDuplicate = true;
          _isShardReward = true;
          save.addShard(category, 1);
          _rewardSubtitle = I18n.tr('duplicate_shard_reward').replaceAll('{count}', '${save.getShards(category)}');
        } else {
          _rewardSubtitle = I18n.tr('new_paddle_unlocked');
          save.unlockPaddle(skin.id);
        }
        break;

      case 'trails':
        final list = TrailSkin.allTrails.where((s) => s.rarity == rolledRarity).toList();
        final skin = list.isNotEmpty ? list[rand.nextInt(list.length)] : TrailSkin.allTrails[rand.nextInt(TrailSkin.allTrails.length)];
        _reward = skin;
        _rewardTitle = skin.name;
        if (save.unlockedTrails.contains(skin.id)) {
          _isDuplicate = true;
          _isShardReward = true;
          save.addShard(category, 1);
          _rewardSubtitle = I18n.tr('duplicate_shard_reward').replaceAll('{count}', '${save.getShards(category)}');
        } else {
          _rewardSubtitle = I18n.tr('new_trail_unlocked');
          save.unlockTrail(skin.id);
        }
        break;

      case 'bricks':
        final list = BrickStyle.all.where((s) => s.rarity == rolledRarity).toList();
        final style = list.isNotEmpty ? list[rand.nextInt(list.length)] : BrickStyle.all[rand.nextInt(BrickStyle.all.length)];
        _reward = style;
        _rewardTitle = style.name;
        if (save.unlockedBrickStyles.contains(style.id)) {
          _isDuplicate = true;
          _isShardReward = true;
          save.addShard(category, 1);
          _rewardSubtitle = I18n.tr('duplicate_shard_reward').replaceAll('{count}', '${save.getShards(category)}');
        } else {
          _rewardSubtitle = I18n.tr('new_brick_unlocked');
          save.unlockBrickStyle(style.id);
        }
        break;
    }
  }

  void _handleGuaranteedRedemption(SaveManager save, String category, Random rand) {
    _isDuplicate = false;
    _isShardReward = false;

    switch (category) {
      case 'balls':
        final unowned = BallSkin.allSkins.where((s) => !save.unlockedBalls.contains(s.id)).toList();
        if (unowned.isNotEmpty) {
          final chosen = unowned[rand.nextInt(unowned.length)];
          _reward = chosen;
          _rewardTitle = chosen.name;
          _rewardRarity = chosen.rarity;
          _rewardSubtitle = I18n.tr('guaranteed_item_unlocked');
          save.unlockBall(chosen.id);
        } else {
          _rewardRarity = Rarity.legendary;
          _rewardTitle = I18n.tr('all_items_unlocked');
          _rewardSubtitle = '+1000 Gold';
          save.addGold(1000);
        }
        break;

      case 'paddles':
        final unowned = PaddleSkin.allSkins.where((p) => !save.unlockedPaddles.contains(p.id)).toList();
        if (unowned.isNotEmpty) {
          final chosen = unowned[rand.nextInt(unowned.length)];
          _reward = chosen;
          _rewardTitle = chosen.name;
          _rewardRarity = chosen.rarity;
          _rewardSubtitle = I18n.tr('guaranteed_item_unlocked');
          save.unlockPaddle(chosen.id);
        } else {
          _rewardRarity = Rarity.legendary;
          _rewardTitle = I18n.tr('all_items_unlocked');
          _rewardSubtitle = '+1000 Gold';
          save.addGold(1000);
        }
        break;

      case 'trails':
        final unowned = TrailSkin.allTrails.where((t) => !save.unlockedTrails.contains(t.id)).toList();
        if (unowned.isNotEmpty) {
          final chosen = unowned[rand.nextInt(unowned.length)];
          _reward = chosen;
          _rewardTitle = chosen.name;
          _rewardRarity = chosen.rarity;
          _rewardSubtitle = I18n.tr('guaranteed_item_unlocked');
          save.unlockTrail(chosen.id);
        } else {
          _rewardRarity = Rarity.legendary;
          _rewardTitle = I18n.tr('all_items_unlocked');
          _rewardSubtitle = '+1000 Gold';
          save.addGold(1000);
        }
        break;

      case 'bricks':
        final unowned = BrickStyle.all.where((b) => !save.unlockedBrickStyles.contains(b.id)).toList();
        if (unowned.isNotEmpty) {
          final chosen = unowned[rand.nextInt(unowned.length)];
          _reward = chosen;
          _rewardTitle = chosen.name;
          _rewardRarity = chosen.rarity;
          _rewardSubtitle = I18n.tr('guaranteed_item_unlocked');
          save.unlockBrickStyle(chosen.id);
        } else {
          _rewardRarity = Rarity.legendary;
          _rewardTitle = I18n.tr('all_items_unlocked');
          _rewardSubtitle = '+1000 Gold';
          save.addGold(1000);
        }
        break;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xF00D0F18),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: _opened ? _rewardRarity.primaryColor : _primaryColor,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: (_opened ? _rewardRarity.primaryColor : _primaryColor).withValues(alpha: 0.4),
                  blurRadius: 32,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _opened ? _rewardRarity.label.toUpperCase() : _crateName.toUpperCase(),
                  style: TextStyle(
                    color: _opened ? _rewardRarity.primaryColor : _primaryColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 20),

                // Chest animation or Reward reveal
                if (!_opened)
                  Transform.rotate(
                    angle: sin(_controller.value * pi * 8) * 0.08 * (1.0 - _controller.value),
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          colors: [
                            _primaryColor.withValues(alpha: 0.5),
                            Colors.transparent,
                          ],
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        widget.categoryCrate?.icon ?? Icons.inventory_2,
                        size: 72,
                        color: _primaryColor,
                      ),
                    ),
                  )
                else
                  Column(
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: _rewardRarity.darkColor.withValues(alpha: 0.6),
                          shape: BoxShape.circle,
                          border: Border.all(color: _rewardRarity.primaryColor, width: 2),
                          boxShadow: [
                            BoxShadow(color: _rewardRarity.primaryColor.withValues(alpha: 0.5), blurRadius: 20),
                          ],
                        ),
                        child: Center(
                          child: _buildRewardIcon(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _rewardTitle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _rewardSubtitle,
                        style: TextStyle(
                          color: _isShardReward
                              ? const Color(0xFF00E5FF)
                              : (_isDuplicate ? const Color(0xFFFFD54F) : Colors.white70),
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),

                if (_opened) ...[
                  if (_isShardReward && SaveManager.instance.getShards(widget.category ?? widget.categoryCrate?.category ?? 'balls') >= 3)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final cat = widget.category ?? widget.categoryCrate?.category ?? 'balls';
                          final ok = await SaveManager.instance.consumeShards(cat, 3);
                          if (ok && context.mounted) {
                            Navigator.of(context).pop();
                            showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (_) => CrateOpeningDialog(
                                isGuaranteedRedemption: true,
                                category: cat,
                                categoryCrate: widget.categoryCrate,
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.diamond, size: 16),
                        label: Text(
                          I18n.tr('use_shards_guaranteed'),
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00E5FF),
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                      ),
                    ),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _rewardRarity.primaryColor,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    ),
                    child: Text(I18n.tr('claim_and_close'), style: const TextStyle(fontWeight: FontWeight.w900)),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildRewardIcon() {
    if (_isShardReward) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.diamond, size: 48, color: Color(0xFF00E5FF)),
          SizedBox(height: 2),
          Text(
            '+1 SHARD',
            style: TextStyle(color: Color(0xFF00E5FF), fontSize: 10, fontWeight: FontWeight.w900),
          ),
        ],
      );
    }
    if (_isDuplicate) {
      return const Icon(Icons.monetization_on, size: 52, color: Color(0xFFFFD54F));
    }
    if (_reward is FishItem) {
      return Image.asset((_reward as FishItem).assetPath, width: 64, height: 64, fit: BoxFit.contain);
    }
    if (_reward is BallSkin) {
      final b = _reward as BallSkin;
      return Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: b.mainColor,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: b.glowColor, blurRadius: 12)],
        ),
      );
    }
    if (_reward is PaddleSkin) {
      final p = _reward as PaddleSkin;
      return Container(
        width: 60,
        height: 22,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [p.color1, p.color2]),
          borderRadius: BorderRadius.circular(11),
          boxShadow: [BoxShadow(color: p.glowColor, blurRadius: 10)],
        ),
      );
    }
    if (_reward is BrickStyle) {
      final br = _reward as BrickStyle;
      if (br.id == 'brick_cosmic') {
        return Container(
          width: 54,
          height: 24,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFFE040FB), Color(0xFF00E5FF)]),
            borderRadius: BorderRadius.circular(5),
            boxShadow: const [BoxShadow(color: Color(0xFFE040FB), blurRadius: 14)],
          ),
          child: const Center(
            child: Icon(Icons.auto_awesome, size: 14, color: Colors.white),
          ),
        );
      }
      return Container(
        width: 54,
        height: 24,
        decoration: BoxDecoration(
          color: br.accent,
          borderRadius: BorderRadius.circular(5),
          boxShadow: [BoxShadow(color: br.accent.withValues(alpha: 0.6), blurRadius: 10)],
        ),
      );
    }
    if (_reward is TrailSkin) {
      final t = _reward as TrailSkin;
      Color trailColor = const Color(0xFFFFD54F);
      IconData icon = Icons.auto_awesome;
      if (t.style == TrailStyle.fire) {
        trailColor = const Color(0xFFFF3D00);
        icon = Icons.local_fire_department;
      } else if (t.style == TrailStyle.plasma) {
        trailColor = const Color(0xFF00E5FF);
        icon = Icons.electric_bolt;
      } else if (t.style == TrailStyle.rainbow) {
        trailColor = const Color(0xFFE040FB);
        icon = Icons.looks;
      } else if (t.style == TrailStyle.ghost) {
        trailColor = const Color(0xFFBA68C8);
        icon = Icons.lens_blur;
      }
      return Icon(icon, size: 48, color: trailColor);
    }
    return const Icon(Icons.check_circle, size: 48, color: Colors.white);
  }
}
