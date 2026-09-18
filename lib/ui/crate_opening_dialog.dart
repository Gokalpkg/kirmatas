import 'dart:math';
import 'package:flutter/material.dart';
import '../engine/audio_manager.dart';
import '../engine/i18n.dart';
import '../models/cosmetics.dart';
import '../storage/save_manager.dart';

class CrateOpeningDialog extends StatefulWidget {
  final CrateDef crate;

  const CrateOpeningDialog({super.key, required this.crate});

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

    // Roll rarity based on crate weights + luck upgrade bonus
    final luckLevel = save.upgrades['luck'] ?? 0;
    final weights = Map<Rarity, double>.from(widget.crate.weights);
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

    // Pick reward from pool (Fish, Ball, Paddle, Trail, or Gold)
    final poolType = rand.nextInt(4);
    if (poolType == 0) {
      // Fish
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
    } else if (poolType == 1) {
      // Ball Skin
      final available = BallSkin.allSkins.where((s) => s.rarity == rolledRarity).toList();
      final skin = available.isNotEmpty ? available[rand.nextInt(available.length)] : BallSkin.allSkins.first;
      _reward = skin;
      _rewardTitle = skin.name;
      if (save.unlockedBalls.contains(skin.id)) {
        _isDuplicate = true;
        _duplicateGold = 120 + rand.nextInt(150);
        save.addGold(_duplicateGold);
        _rewardSubtitle = I18n.tr('duplicate_reward').replaceAll('{gold}', '$_duplicateGold');
      } else {
        _rewardSubtitle = I18n.tr('new_ball_unlocked');
        save.unlockBall(skin.id);
      }
    } else if (poolType == 2) {
      // Paddle Skin
      final available = PaddleSkin.allSkins.where((s) => s.rarity == rolledRarity).toList();
      final skin = available.isNotEmpty ? available[rand.nextInt(available.length)] : PaddleSkin.allSkins.first;
      _reward = skin;
      _rewardTitle = skin.name;
      if (save.unlockedPaddles.contains(skin.id)) {
        _isDuplicate = true;
        _duplicateGold = 150 + rand.nextInt(180);
        save.addGold(_duplicateGold);
        _rewardSubtitle = I18n.tr('duplicate_reward').replaceAll('{gold}', '$_duplicateGold');
      } else {
        _rewardSubtitle = I18n.tr('new_paddle_unlocked');
        save.unlockPaddle(skin.id);
      }
    } else {
      // Trail Skin
      final available = TrailSkin.allTrails.where((t) => t.rarity == rolledRarity).toList();
      final trail = available.isNotEmpty ? available[rand.nextInt(available.length)] : TrailSkin.allTrails.first;
      _reward = trail;
      _rewardTitle = trail.name;
      if (save.unlockedTrails.contains(trail.id)) {
        _isDuplicate = true;
        _duplicateGold = 100 + rand.nextInt(120);
        save.addGold(_duplicateGold);
        _rewardSubtitle = I18n.tr('duplicate_reward').replaceAll('{gold}', '$_duplicateGold');
      } else {
        _rewardSubtitle = I18n.tr('new_trail_unlocked');
        save.unlockTrail(trail.id);
      }
    }

    _controller.forward().then((_) {
      setState(() {
        _opened = true;
      });
      AudioManager.instance.playSfx(GameSfx.victory);
    });
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
                color: _opened ? _rewardRarity.primaryColor : widget.crate.primaryColor,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: (_opened ? _rewardRarity.primaryColor : widget.crate.primaryColor).withValues(alpha: 0.4),
                  blurRadius: 32,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _opened ? _rewardRarity.label.toUpperCase() : widget.crate.name.toUpperCase(),
                  style: TextStyle(
                    color: _opened ? _rewardRarity.primaryColor : widget.crate.primaryColor,
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
                            widget.crate.primaryColor.withValues(alpha: 0.5),
                            Colors.transparent,
                          ],
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.inventory_2,
                        size: 72,
                        color: widget.crate.primaryColor,
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
                          child: _isDuplicate
                              ? const Icon(Icons.monetization_on, size: 52, color: Color(0xFFFFD54F))
                              : (_reward is FishItem
                                  ? Image.asset((_reward as FishItem).assetPath, width: 64, height: 64, fit: BoxFit.contain)
                                  : Icon(
                                      _reward is BallSkin
                                          ? Icons.circle
                                          : (_reward is PaddleSkin ? Icons.horizontal_rule : Icons.auto_awesome),
                                      size: 52,
                                      color: _rewardRarity.primaryColor,
                                    )),
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
                          color: _isDuplicate ? const Color(0xFFFFD54F) : Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),

                const SizedBox(height: 24),
                if (_opened)
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
            ),
          );
        },
      ),
    );
  }
}
