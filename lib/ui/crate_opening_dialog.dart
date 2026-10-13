import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../engine/audio_manager.dart';
import '../engine/i18n.dart';
import '../models/cosmetics.dart';
import '../storage/save_manager.dart';
import 'chest_widget.dart';

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

class _CrateOpeningDialogState extends State<CrateOpeningDialog> with TickerProviderStateMixin {
  late final AnimationController _dropController;
  late final Animation<double> _dropAnimation;
  late final AnimationController _shakeController;
  late final AnimationController _openController;
  late final AnimationController _flashController;
  late final AnimationController _auraController;
  late final AnimationController _shockwaveController;
  late final AnimationController _revealController;

  int _tapCount = 0; // 0 (start), 1, 2, 3 (open)
  Rarity _currentRarity = Rarity.common;
  bool _isShaking = false;
  bool _isOpening = false;
  bool _opened = false;

  dynamic _reward;
  String _rewardTitle = '';
  String _rewardSubtitle = '';
  Rarity _rewardRarity = Rarity.common;
  bool _isDuplicate = false;
  int _duplicateGold = 0;
  bool _isShardReward = false;
  bool _isFoodBonus = false;

  double get _chestScale {
    switch (_currentRarity) {
      case Rarity.common:
        return 1.0;
      case Rarity.rare:
        return 1.14;
      case Rarity.epic:
        return 1.28;
      case Rarity.legendary:
        return 1.44;
    }
  }

  Color get _currentPrimaryColor {
    switch (_currentRarity) {
      case Rarity.common:
        return widget.crate?.primaryColor ?? const Color(0xFF90A4AE);
      case Rarity.rare:
        return const Color(0xFF00E5FF);
      case Rarity.epic:
        return const Color(0xFFE040FB);
      case Rarity.legendary:
        return const Color(0xFFFFD54F);
    }
  }

  Color get _currentSecondaryColor {
    switch (_currentRarity) {
      case Rarity.common:
        return const Color(0xFF5D4037);
      case Rarity.rare:
        return const Color(0xFF006064);
      case Rarity.epic:
        return const Color(0xFF4A148C);
      case Rarity.legendary:
        return const Color(0xFFE65100);
    }
  }

  String get _currentRarityLabel {
    switch (_currentRarity) {
      case Rarity.common:
        return 'SIRADAN';
      case Rarity.rare:
        return 'ENDER';
      case Rarity.epic:
        return 'DESTANSI';
      case Rarity.legendary:
        return ' EFSANEVİ ';
    }
  }

  String get _tapPromptText {
    if (_tapCount == 0) return 'Sandığa Dokun (1/3)';
    if (_tapCount == 1) return 'Tekrar Dokun (2/3)';
    return 'Açmak İçin Dokun! (3/3)';
  }

  @override
  void initState() {
    super.initState();
    _dropController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _dropAnimation = CurvedAnimation(
      parent: _dropController,
      curve: Curves.bounceOut,
    );

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );

    _openController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _flashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );

    _auraController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();

    _shockwaveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _revealController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );

    _rollReward();

    _dropController.forward().then((_) {
      if (mounted) {
        AudioManager.instance.playSfx(GameSfx.hitPaddle);
        HapticFeedback.mediumImpact();
      }
    });
  }

  @override
  void dispose() {
    _dropController.dispose();
    _shakeController.dispose();
    _openController.dispose();
    _flashController.dispose();
    _auraController.dispose();
    _shockwaveController.dispose();
    _revealController.dispose();
    super.dispose();
  }

  Future<void> _handleChestTap() async {
    if (_opened || _isShaking || _isOpening || _dropController.value < 0.80) return;

    if (_tapCount == 0) {
      // 1. Dokunuş: Sıradan -> Ender kontrolü
      _isShaking = true;
      _tapCount = 1;
      _shockwaveController.forward(from: 0.0);
      final willUpgrade = _rewardRarity.index >= Rarity.rare.index;
      await _shakeController.forward(from: 0.0);
      if (willUpgrade) {
        setState(() {
          _currentRarity = Rarity.rare;
        });
        AudioManager.instance.playSfx(GameSfx.powerupBuff);
        HapticFeedback.heavyImpact();
      } else {
        AudioManager.instance.playSfx(GameSfx.hitPaddle);
        HapticFeedback.mediumImpact();
      }
      _isShaking = false;
      setState(() {});
    } else if (_tapCount == 1) {
      // 2. Dokunuş: Ender -> Destansı kontrolü
      _isShaking = true;
      _tapCount = 2;
      _shockwaveController.forward(from: 0.0);
      final willUpgrade = _rewardRarity.index >= Rarity.epic.index;
      await _shakeController.forward(from: 0.0);
      if (willUpgrade) {
        setState(() {
          _currentRarity = Rarity.epic;
        });
        AudioManager.instance.playSfx(GameSfx.powerupBuff);
        HapticFeedback.heavyImpact();
      } else {
        AudioManager.instance.playSfx(GameSfx.hitPaddle);
        HapticFeedback.mediumImpact();
      }
      _isShaking = false;
      setState(() {});
    } else if (_tapCount == 2) {
      // 3. Dokunuş: Destansı -> Efsanevi kontrolü & AÇILIŞ!
      _tapCount = 3;
      _isOpening = true;
      _shockwaveController.forward(from: 0.0);
      final isLegendary = _rewardRarity == Rarity.legendary;
      if (isLegendary) {
        setState(() {
          _currentRarity = Rarity.legendary;
        });
        _flashController.forward(from: 0.0);
        AudioManager.instance.playSfx(GameSfx.cornerBoost);
        HapticFeedback.heavyImpact();
      }

      await _shakeController.forward(from: 0.0);
      await _openController.forward();

      setState(() {
        _opened = true;
        _isOpening = false;
      });
      _revealController.forward(from: 0.0);
      AudioManager.instance.playSfx(GameSfx.victory);
      HapticFeedback.heavyImpact();
    }
  }

  void _rollReward() {
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
    final unownedInRarity = available.where((f) => !save.unlockedFish.contains(f.id)).toList();
    final allUnowned = FishItem.allFish.where((f) => !save.unlockedFish.contains(f.id)).toList();

    FishItem fish;
    if (unownedInRarity.isNotEmpty) {
      fish = unownedInRarity[rand.nextInt(unownedInRarity.length)];
    } else if (allUnowned.isNotEmpty && rand.nextDouble() < 0.75) {
      // 75% chance to roll an unowned fish species from another tier to prioritize discovering new fish
      fish = allUnowned[rand.nextInt(allUnowned.length)];
      _rewardRarity = fish.rarity;
    } else {
      fish = available.isNotEmpty ? available[rand.nextInt(available.length)] : FishItem.allFish.first;
    }

    _reward = fish;
    _rewardTitle = fish.name;

    final isNewSpecies = !save.unlockedFish.contains(fish.id);
    save.addFish(fish.id); // ALWAYS adds the fish to the player's aquarium!
    _isDuplicate = false;
    _duplicateGold = 0;

    if (isNewSpecies) {
      _isFoodBonus = false;
      _rewardSubtitle = I18n.tr('new_fish_unlocked');
    } else {
      _isFoodBonus = true;
      save.addFishFood(3);
      _rewardSubtitle = 'Akvaryumuna bir ${fish.name} daha katıldı! (+3 Yem Hediye)';
    }
  }

  void _handleCategoryCrate(SaveManager save, String category, Random rand) {
    final luckLevel = save.upgrades['luck'] ?? 0;
    final weights = Map<Rarity, double>.from(CategoryCrateInfo.rarityWeights);
    // Legendary is rare (~3% base, boosted by luck)
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

    switch (category) {
      case 'balls':
        // Unlockable skins pool (excludes free default starter 'classic')
        final unlockables = BallSkin.allSkins.where((s) => s.id != 'classic').toList();
        var pool = unlockables.where((s) => s.rarity == rolledRarity).toList();
        if (pool.isEmpty) {
          pool = unlockables.where((s) => s.rarity == Rarity.rare).toList();
          if (pool.isEmpty) pool = unlockables;
        }

        final skin = pool[rand.nextInt(pool.length)];
        _reward = skin;
        _rewardTitle = skin.name;
        _rewardRarity = skin.rarity;

        if (save.unlockedBalls.contains(skin.id)) {
          // Genuinely already owned! Convert to duplicate shard
          _isDuplicate = true;
          _isShardReward = true;
          save.addShard(category, 1);
          _rewardSubtitle = 'Bu topa zaten sahipsin! Yerine +1 Parça (Shard) eklendi (${save.getShards(category)}/3).';
        } else {
          // Brand new unlock!
          _isDuplicate = false;
          _isShardReward = false;
          _rewardSubtitle = I18n.tr('new_ball_unlocked');
          save.unlockBall(skin.id);
        }
        break;

      case 'paddles':
        // Unlockable paddles pool (excludes free default starter 'pclassic')
        final unlockables = PaddleSkin.allSkins.where((s) => s.id != 'pclassic').toList();
        var pool = unlockables.where((s) => s.rarity == rolledRarity).toList();
        if (pool.isEmpty) {
          pool = unlockables.where((s) => s.rarity == Rarity.rare).toList();
          if (pool.isEmpty) pool = unlockables;
        }

        final skin = pool[rand.nextInt(pool.length)];
        _reward = skin;
        _rewardTitle = skin.name;
        _rewardRarity = skin.rarity;

        if (save.unlockedPaddles.contains(skin.id)) {
          _isDuplicate = true;
          _isShardReward = true;
          save.addShard(category, 1);
          _rewardSubtitle = 'Bu rakete zaten sahipsin! Yerine +1 Parça (Shard) eklendi (${save.getShards(category)}/3).';
        } else {
          _isDuplicate = false;
          _isShardReward = false;
          _rewardSubtitle = I18n.tr('new_paddle_unlocked');
          save.unlockPaddle(skin.id);
        }
        break;

      case 'trails':
        // Unlockable trails pool (excludes free default starter 't1')
        final unlockables = TrailSkin.allTrails.where((s) => s.id != 't1').toList();
        var pool = unlockables.where((s) => s.rarity == rolledRarity).toList();
        if (pool.isEmpty) {
          pool = unlockables.where((s) => s.rarity == Rarity.rare).toList();
          if (pool.isEmpty) pool = unlockables;
        }

        final skin = pool[rand.nextInt(pool.length)];
        _reward = skin;
        _rewardTitle = skin.name;
        _rewardRarity = skin.rarity;

        if (save.unlockedTrails.contains(skin.id)) {
          _isDuplicate = true;
          _isShardReward = true;
          save.addShard(category, 1);
          _rewardSubtitle = 'Bu ize zaten sahipsin! Yerine +1 Parça (Shard) eklendi (${save.getShards(category)}/3).';
        } else {
          _isDuplicate = false;
          _isShardReward = false;
          _rewardSubtitle = I18n.tr('new_trail_unlocked');
          save.unlockTrail(skin.id);
        }
        break;

      case 'bricks':
        // Unlockable bricks pool (excludes free default starter 'brick_gloss')
        final unlockables = BrickStyle.all.where((s) => s.id != 'brick_gloss').toList();
        var pool = unlockables.where((s) => s.rarity == rolledRarity).toList();
        if (pool.isEmpty) {
          pool = unlockables.where((s) => s.rarity == Rarity.rare).toList();
          if (pool.isEmpty) pool = unlockables;
        }

        final style = pool[rand.nextInt(pool.length)];
        _reward = style;
        _rewardTitle = style.name;
        _rewardRarity = style.rarity;

        if (save.unlockedBrickStyles.contains(style.id)) {
          _isDuplicate = true;
          _isShardReward = true;
          save.addShard(category, 1);
          _rewardSubtitle = 'Bu blok stiline zaten sahipsin! Yerine +1 Parça (Shard) eklendi (${save.getShards(category)}/3).';
        } else {
          _isDuplicate = false;
          _isShardReward = false;
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
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: AnimatedBuilder(
        animation: Listenable.merge([
          _dropController,
          _shakeController,
          _openController,
          _flashController,
          _auraController,
          _shockwaveController,
          _revealController,
        ]),
        builder: (context, _) {
          final activeColor = _opened ? _rewardRarity.primaryColor : _currentPrimaryColor;
          return Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 26),
                decoration: BoxDecoration(
                  color: const Color(0xF00D0F18),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: activeColor,
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: activeColor.withValues(alpha: 0.45),
                      blurRadius: 36,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Title / Rarity Badge
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: activeColor.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: activeColor.withValues(alpha: 0.8), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: activeColor.withValues(alpha: 0.35),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                      child: Text(
                        _opened ? _rewardRarity.label.toUpperCase() : _currentRarityLabel,
                        style: TextStyle(
                          color: activeColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2.0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Unopened Chest View with Drop, Shake, Scale, Aura, Shockwave, and Tap Prompt
                    if (!_opened)
                      Transform.translate(
                        offset: Offset(0, (1.0 - _dropAnimation.value) * -280),
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: _handleChestTap,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 170,
                                height: 140,
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  alignment: Alignment.center,
                                  children: [
                                    // Rotating Sunburst Aura behind chest
                                    Positioned(
                                      top: -15,
                                      child: Transform.rotate(
                                        angle: _auraController.value * 2 * pi,
                                        child: CustomPaint(
                                          size: const Size(190, 170),
                                          painter: _CrateSunburstPainter(
                                            color: activeColor,
                                            intensity: 0.35 + _tapCount * 0.20,
                                            spokeCount: 12,
                                          ),
                                        ),
                                      ),
                                    ),
                                    // Expanding Tap Shockwave
                                    if (_shockwaveController.isAnimating)
                                      Positioned(
                                        top: 0,
                                        child: CustomPaint(
                                          size: const Size(170, 140),
                                          painter: _CrateShockwavePainter(
                                            progress: _shockwaveController.value,
                                            color: activeColor,
                                          ),
                                        ),
                                      ),
                                    // Animated Floating & Shaking Chest
                                    Transform.translate(
                                      offset: Offset(
                                        sin(_shakeController.value * pi * 8) * 3,
                                        sin(_auraController.value * 2 * pi) * 2.5,
                                      ),
                                      child: Transform.rotate(
                                        angle: sin(_shakeController.value * pi * 8) * (0.09 + _tapCount * 0.02) * (1.0 - _shakeController.value),
                                        child: AnimatedScale(
                                          scale: _chestScale,
                                          duration: const Duration(milliseconds: 320),
                                          curve: Curves.elasticOut,
                                          child: ChestWidget(
                                            size: 118,
                                            primaryColor: _currentPrimaryColor,
                                            secondaryColor: _currentSecondaryColor,
                                            openProgress: _openController.value,
                                            showGlow: true,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 18),
                              AnimatedOpacity(
                                opacity: (_dropController.value > 0.80 && !_isShaking && !_isOpening) ? 1.0 : 0.45,
                                duration: const Duration(milliseconds: 150),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: activeColor.withValues(alpha: 0.20),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: activeColor.withValues(alpha: 0.6)),
                                    boxShadow: [
                                      BoxShadow(
                                        color: activeColor.withValues(alpha: 0.3),
                                        blurRadius: 10,
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.touch_app_rounded, color: activeColor, size: 18),
                                      const SizedBox(width: 6),
                                      Text(
                                        _tapPromptText,
                                        style: TextStyle(
                                          color: activeColor,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 13,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                else
                  Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      // Confetti / Starburst Celebration Particles
                      Positioned(
                        top: -10,
                        child: CustomPaint(
                          size: const Size(240, 180),
                          painter: _CrateConfettiPainter(
                            progress: _revealController.value,
                            color: _rewardRarity.primaryColor,
                          ),
                        ),
                      ),
                      ScaleTransition(
                        scale: CurvedAnimation(
                          parent: _revealController,
                          curve: Curves.elasticOut,
                        ),
                        child: FadeTransition(
                          opacity: CurvedAnimation(
                            parent: _revealController,
                            curve: Curves.easeIn,
                          ),
                          child: Column(
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
                      const SizedBox(height: 12),
                      if (_isDuplicate)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF9800).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFFF9800), width: 1),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.inventory, size: 13, color: Color(0xFFFFB74D)),
                              SizedBox(width: 5),
                              Text( 'ZATEN SAHİPSİN (KOPYA)',
                                style: TextStyle(
                                  color: Color(0xFFFFB74D),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00E676).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFF00E676), width: 1),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.stars, size: 13, color: Color(0xFF69F0AE)),
                              SizedBox(width: 5),
                              Text( 'YENİ AÇILDI!',
                                style: TextStyle(
                                  color: Color(0xFF69F0AE),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 8),
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
                      if (_isShardReward) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFF00E5FF).withValues(alpha: 0.2),
                                const Color(0xFF00B0FF).withValues(alpha: 0.1),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.6)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.diamond, color: Color(0xFF00E5FF), size: 18),
                              const SizedBox(width: 8),
                              Text( '+1 Parça Eklendi! (${SaveManager.instance.getShards(widget.category ?? widget.categoryCrate?.category ?? 'balls')}/3)',
                                style: const TextStyle(
                                  color: Color(0xFF00E5FF),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (_isFoodBonus) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4CAF50).withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF66BB6A).withValues(alpha: 0.7)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.set_meal, color: Color(0xFF81C784), size: 18),
                              SizedBox(width: 8),
                              Text(
                                '+3 Balık Yemi Hediye Edildi!',
                                style: TextStyle(
                                  color: Color(0xFF81C784),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
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
          ),
          if (_flashController.isAnimating)
            Positioned.fill(
              child: IgnorePointer(
                child: FadeTransition(
                  opacity: ReverseAnimation(_flashController),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      gradient: const RadialGradient(
                        colors: [
                          Color(0xE6FFF176),
                          Color(0x99FFD54F),
                          Colors.transparent,
                        ],
                        radius: 1.1,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    },
  ),
);
  }

  Widget _buildRewardIcon() {
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
          width: 58,
          height: 26,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(5),
            boxShadow: const [
              BoxShadow(color: Color(0xFFE040FB), blurRadius: 14, spreadRadius: 1),
            ],
          ),
          child: CustomPaint(
            painter: _DialogCosmicBrickPainter(),
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

class _DialogCosmicBrickPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(5.0));
    final halfW = size.width / 2;
    final halfH = size.height / 2;
    final c = Offset(halfW, halfH);

    canvas.save();
    canvas.clipRRect(rrect);

    // Deep cosmic space void
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF070114), Color(0xFF110324), Color(0xFF070114)],
      ).createShader(rect);
    canvas.drawRect(rect, bgPaint);

    // Violet galactic nebula
    final haloRect = Rect.fromCenter(center: Offset(c.dx - halfW * 0.1, c.dy), width: halfW * 2.2, height: halfH * 2.4);
    final haloPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF7C4DFF).withValues(alpha: 0.60),
          const Color(0xFF7C4DFF).withValues(alpha: 0.20),
          Colors.transparent,
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(haloRect);
    canvas.drawOval(haloRect, haloPaint);

    // Magenta nebula filament
    final magRect = Rect.fromCenter(center: Offset(c.dx - halfW * 0.35, c.dy - halfH * 0.25), width: halfW * 1.5, height: halfH * 1.6);
    final magPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFE040FB).withValues(alpha: 0.65),
          const Color(0xFFE040FB).withValues(alpha: 0.22),
          Colors.transparent,
        ],
        stops: const [0.0, 0.48, 1.0],
      ).createShader(magRect);
    canvas.drawOval(magRect, magPaint);

    // Cyan interstellar dust veil
    final cyanRect = Rect.fromCenter(center: Offset(c.dx + halfW * 0.35, c.dy + halfH * 0.22), width: halfW * 1.6, height: halfH * 1.7);
    final cyanPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF00E5FF).withValues(alpha: 0.60),
          const Color(0xFF00E5FF).withValues(alpha: 0.18),
          Colors.transparent,
        ],
        stops: const [0.0, 0.50, 1.0],
      ).createShader(cyanRect);
    canvas.drawOval(cyanRect, cyanPaint);

    // Milky Way stardust stream
    final streamPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment(-0.85, -0.9),
        end: Alignment(0.85, 0.9),
        colors: [
          Colors.transparent,
          Color(0x407C4DFF),
          Color(0x70FFFFFF),
          Color(0x4000E5FF),
          Colors.transparent,
        ],
        stops: [0.0, 0.30, 0.50, 0.70, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, streamPaint);

    // Micro-stars
    final starPaint = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(c.dx - halfW * 0.6, c.dy - halfH * 0.3), 0.9, starPaint);
    canvas.drawCircle(Offset(c.dx + halfW * 0.5, c.dy - halfH * 0.4), 0.8, starPaint);
    canvas.drawCircle(Offset(c.dx + halfW * 0.65, c.dy + halfH * 0.35), 0.9, starPaint);
    canvas.drawCircle(Offset(c.dx - halfW * 0.45, c.dy + halfH * 0.45), 0.8, starPaint);

    // JWST 4-point star
    final starPos = Offset(c.dx - halfW * 0.15, c.dy - halfH * 0.15);
    canvas.drawCircle(starPos, 1.5, starPaint);
    final spikePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = Colors.white.withValues(alpha: 0.85);
    canvas.drawLine(Offset(starPos.dx - 4.5, starPos.dy), Offset(starPos.dx + 4.5, starPos.dy), spikePaint);
    canvas.drawLine(Offset(starPos.dx, starPos.dy - 3.5), Offset(starPos.dx, starPos.dy + 3.5), spikePaint);

    // Crystal prism sheen
    final sheenPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0x55FFFFFF), Color(0x10FFFFFF), Colors.transparent],
        stops: [0.0, 0.45, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, halfH * 0.85));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, halfH * 0.85), sheenPaint);

    canvas.restore();

    // Prismatic crystal rim
    final rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..shader = const LinearGradient(
        colors: [Color(0xFF00E5FF), Color(0xFFE040FB), Color(0xFF7C4DFF), Color(0xFF00E5FF)],
      ).createShader(rect);
    canvas.drawRRect(rrect, rimPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CrateSunburstPainter extends CustomPainter {
  final Color color;
  final double intensity;
  final int spokeCount;

  _CrateSunburstPainter({
    required this.color,
    required this.intensity,
    this.spokeCount = 12,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final spokeAngle = (2 * pi) / spokeCount;

    final rayPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withValues(alpha: (0.42 * intensity).clamp(0.0, 1.0)),
          color.withValues(alpha: (0.12 * intensity).clamp(0.0, 1.0)),
          color.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.65, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    for (int i = 0; i < spokeCount; i++) {
      final angle = i * spokeAngle;
      final path = Path();
      path.moveTo(center.dx, center.dy);
      path.lineTo(
        center.dx + cos(angle - spokeAngle * 0.22) * radius,
        center.dy + sin(angle - spokeAngle * 0.22) * radius,
      );
      path.lineTo(
        center.dx + cos(angle + spokeAngle * 0.22) * radius,
        center.dy + sin(angle + spokeAngle * 0.22) * radius,
      );
      path.close();
      canvas.drawPath(path, rayPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CrateSunburstPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.intensity != intensity;
}

class _CrateShockwavePainter extends CustomPainter {
  final double progress;
  final Color color;

  _CrateShockwavePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.0 || progress >= 1.0) return;
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width * 0.48;
    final currentRadius = maxRadius * progress;
    final alpha = (1.0 - progress).clamp(0.0, 1.0);

    // Primary expanding shockwave ring
    final ringPaint = Paint()
      ..color = color.withValues(alpha: alpha * 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(1.5, 4.0 * (1.0 - progress));
    canvas.drawCircle(center, currentRadius, ringPaint);

    // Secondary inner echo ring
    if (progress > 0.2) {
      final echoProgress = (progress - 0.2) / 0.8;
      final echoRadius = maxRadius * echoProgress * 0.8;
      final echoPaint = Paint()
        ..color = Colors.white.withValues(alpha: (1.0 - echoProgress) * 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawCircle(center, echoRadius, echoPaint);
    }

    // Radiating spark particles
    final sparkPaint = Paint()..style = PaintingStyle.fill;
    for (int i = 0; i < 8; i++) {
      final angle = (i * pi / 4) + (progress * 0.3);
      final dist = currentRadius * 1.08;
      final sparkPos = Offset(center.dx + cos(angle) * dist, center.dy + sin(angle) * dist);
      sparkPaint.color = (i.isEven ? color : Colors.white).withValues(alpha: alpha * 0.9);
      canvas.drawCircle(sparkPos, max(1.0, 3.0 * (1.0 - progress)), sparkPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CrateShockwavePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

class _CrateConfettiPainter extends CustomPainter {
  final double progress;
  final Color color;

  _CrateConfettiPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.05) return;
    final center = Offset(size.width / 2, size.height / 2);
    final rand = Random(42); // deterministic seed for smooth animation

    final pVal = progress.clamp(0.0, 1.0);
    final alpha = pVal < 0.7 ? 1.0 : (1.0 - (pVal - 0.7) / 0.3).clamp(0.0, 1.0);

    for (int i = 0; i < 24; i++) {
      final baseAngle = (i / 24) * 2 * pi + (rand.nextDouble() * 0.2);
      final maxDist = 60.0 + rand.nextDouble() * 60.0;
      final curDist = maxDist * CurvedAnimation(parent: AlwaysStoppedAnimation(pVal), curve: Curves.easeOutCubic).value;
      final px = center.dx + cos(baseAngle) * curDist;
      final py = center.dy + sin(baseAngle) * curDist - (pVal * 15.0); // subtle upward draft

      final pColor = [
        color,
        Colors.white,
        const Color(0xFFFFD54F),
        const Color(0xFF00E5FF),
      ][i % 4];

      final particlePaint = Paint()..color = pColor.withValues(alpha: alpha * 0.85);

      // Diamond star particle
      final pSize = (3.5 - pVal * 1.2).clamp(1.5, 4.0);
      final starPath = Path()
        ..moveTo(px, py - pSize * 1.3)
        ..lineTo(px + pSize, py)
        ..lineTo(px, py + pSize * 1.3)
        ..lineTo(px - pSize, py)
        ..close();
      canvas.drawPath(starPath, particlePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CrateConfettiPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

