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
  late final AnimationController _impactController;
  late final AnimationController _electricController;
  late final AnimationController _pillarController;
  late final AnimationController _cardFlipController;
  late final AnimationController _shineSweepController;
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
  bool _isShardReward = false;
  bool _isFoodBonus = false;

  double get _chestScale {
    switch (_currentRarity) {
      case Rarity.common:
        return 1.0;
      case Rarity.rare:
        return 1.15;
      case Rarity.epic:
        return 1.30;
      case Rarity.legendary:
        return 1.48;
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
        return 'EFSANEVİ';
    }
  }

  String get _tapPromptText {
    if (_tapCount == 0) return 'Sandığa Dokun (1/3)';
    if (_tapCount == 1) return 'Tekrar Dokun (2/3)';
    if (_tapCount == 2) return 'Açmak İçin Dokun! (3/3)';
    return '';
  }

  @override
  void initState() {
    super.initState();

    _dropController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _dropAnimation = CurvedAnimation(
      parent: _dropController,
      curve: Curves.bounceOut,
    );

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 340),
    );

    _openController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );

    _flashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );

    _auraController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    _shockwaveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );

    _impactController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );

    _electricController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _pillarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );

    _cardFlipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );

    _shineSweepController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _revealController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _rollReward();

    _dropController.forward().then((_) {
      if (mounted) {
        _impactController.forward(from: 0.0);
        AudioManager.instance.playSfx(GameSfx.hitPaddle);
        HapticFeedback.heavyImpact();
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
    _impactController.dispose();
    _electricController.dispose();
    _pillarController.dispose();
    _cardFlipController.dispose();
    _shineSweepController.dispose();
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
      _electricController.forward(from: 0.0);
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
      _electricController.forward(from: 0.0);
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
      _pillarController.forward(from: 0.0);
      _flashController.forward(from: 0.0);

      final isLegendary = _rewardRarity == Rarity.legendary;
      if (isLegendary) {
        setState(() {
          _currentRarity = Rarity.legendary;
        });
        AudioManager.instance.playSfx(GameSfx.cornerBoost);
        HapticFeedback.heavyImpact();
      }

      await _shakeController.forward(from: 0.0);
      await _openController.forward();

      setState(() {
        _opened = true;
        _isOpening = false;
      });

      _cardFlipController.forward(from: 0.0);
      _revealController.forward(from: 0.0);
      _shineSweepController.forward(from: 0.0);

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
          _isDuplicate = true;
          _isShardReward = true;
          save.addShard(category, 1);
          _rewardSubtitle = 'Bu topa zaten sahipsin! Yerine +1 Parça (Shard) eklendi (${save.getShards(category)}/3).';
        } else {
          _isDuplicate = false;
          _isShardReward = false;
          _rewardSubtitle = I18n.tr('new_ball_unlocked');
          save.unlockBall(skin.id);
        }
        break;

      case 'paddles':
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
          _impactController,
          _electricController,
          _pillarController,
          _cardFlipController,
          _shineSweepController,
          _revealController,
        ]),
        builder: (context, _) {
          final activeColor = _opened ? _rewardRarity.primaryColor : _currentPrimaryColor;
          return Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              // Dialog Main Shell
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 26),
                decoration: BoxDecoration(
                  gradient: const RadialGradient(
                    center: Alignment(0, -0.2),
                    radius: 1.2,
                    colors: [
                      Color(0xF5141926),
                      Color(0xFA090B12),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: activeColor.withValues(alpha: 0.85),
                    width: 2.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: activeColor.withValues(alpha: 0.40),
                      blurRadius: 42,
                      spreadRadius: 3,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Title / Rarity Badge
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 320),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 7),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            activeColor.withValues(alpha: 0.28),
                            activeColor.withValues(alpha: 0.10),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: activeColor, width: 1.6),
                        boxShadow: [
                          BoxShadow(
                            color: activeColor.withValues(alpha: 0.38),
                            blurRadius: 14,
                          ),
                        ],
                      ),
                      child: Text(
                        _opened ? _rewardRarity.label.toUpperCase() : _currentRarityLabel,
                        style: TextStyle(
                          color: activeColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // UNOPENED CHEST SCENE
                    if (!_opened)
                      Transform.translate(
                        offset: Offset(0, (1.0 - _dropAnimation.value) * -290),
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: _handleChestTap,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 200,
                                height: 160,
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  alignment: Alignment.center,
                                  children: [
                                    // 1. Ambient Sunburst Aura behind chest
                                    Positioned(
                                      top: -10,
                                      child: Transform.rotate(
                                        angle: _auraController.value * 2 * pi,
                                        child: CustomPaint(
                                          size: const Size(210, 180),
                                          painter: _CrateSunburstPainter(
                                            color: activeColor,
                                            intensity: 0.40 + _tapCount * 0.22,
                                            spokeCount: 14,
                                          ),
                                        ),
                                      ),
                                    ),

                                    // 2. Ground Impact Shockwave upon Landing
                                    if (_impactController.isAnimating)
                                      Positioned(
                                        bottom: 10,
                                        child: CustomPaint(
                                          size: const Size(190, 70),
                                          painter: _GroundImpactPainter(
                                            progress: _impactController.value,
                                            color: activeColor,
                                          ),
                                        ),
                                      ),

                                    // 3. Expanding Tap Shockwave
                                    if (_shockwaveController.isAnimating)
                                      Positioned(
                                        top: 10,
                                        child: CustomPaint(
                                          size: const Size(180, 140),
                                          painter: _CrateShockwavePainter(
                                            progress: _shockwaveController.value,
                                            color: activeColor,
                                          ),
                                        ),
                                      ),

                                    // 4. Electric Arcs / Plasma Sparks between chest corners
                                    if (_electricController.isAnimating)
                                      Positioned.fill(
                                        child: CustomPaint(
                                          painter: _CrateElectricArcsPainter(
                                            progress: _electricController.value,
                                            color: activeColor,
                                          ),
                                        ),
                                      ),

                                    // 5. Grand Vertical Beam of Light / Pillar on Opening
                                    if (_pillarController.isAnimating)
                                      Positioned(
                                        bottom: 20,
                                        child: CustomPaint(
                                          size: const Size(180, 260),
                                          painter: _CratePillarLightPainter(
                                            progress: _pillarController.value,
                                            color: activeColor,
                                          ),
                                        ),
                                      ),

                                    // 6. 3D Animated Floating, Tilting & Shaking Chest
                                    Transform.translate(
                                      offset: Offset(
                                        sin(_shakeController.value * pi * 10) * (3.5 + _tapCount * 1.5),
                                        sin(_auraController.value * 2 * pi) * 2.8,
                                      ),
                                      child: Transform.rotate(
                                        angle: sin(_shakeController.value * pi * 10) * (0.08 + _tapCount * 0.03) * (1.0 - _shakeController.value),
                                        child: AnimatedScale(
                                          scale: _chestScale,
                                          duration: const Duration(milliseconds: 320),
                                          curve: Curves.elasticOut,
                                          child: ChestWidget(
                                            size: 122,
                                            primaryColor: _currentPrimaryColor,
                                            secondaryColor: _currentSecondaryColor,
                                            openProgress: _openController.value,
                                            showGlow: true,
                                            time: _auraController.value * 2 * pi,
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
                                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        activeColor.withValues(alpha: 0.25),
                                        activeColor.withValues(alpha: 0.12),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(22),
                                    border: Border.all(color: activeColor.withValues(alpha: 0.75)),
                                    boxShadow: [
                                      BoxShadow(
                                        color: activeColor.withValues(alpha: 0.35),
                                        blurRadius: 12,
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.touch_app_rounded, color: activeColor, size: 19),
                                      const SizedBox(width: 7),
                                      Text(
                                        _tapPromptText,
                                        style: TextStyle(
                                          color: activeColor,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 13.5,
                                          letterSpacing: 0.6,
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

                    // OPENED REWARD SCENE (Holographic Card & Celebration)
                    else
                      Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.center,
                        children: [
                          // 1. Confetti / Starburst Celebration Particles
                          Positioned(
                            top: -15,
                            child: CustomPaint(
                              size: const Size(260, 210),
                              painter: _CrateConfettiPainter(
                                progress: _revealController.value,
                                color: _rewardRarity.primaryColor,
                              ),
                            ),
                          ),

                          // 2. Holographic Reward Presentation Card
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
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // 3D Flip Card Container
                                  AnimatedBuilder(
                                    animation: _cardFlipController,
                                    builder: (context, child) {
                                      final angle = (1.0 - _cardFlipController.value) * pi * 0.5;
                                      return Transform(
                                        alignment: Alignment.center,
                                        transform: Matrix4.identity()
                                          ..setEntry(3, 2, 0.0018)
                                          ..rotateY(angle),
                                        child: child,
                                      );
                                    },
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        // Card Chassis
                                        Container(
                                          width: 130,
                                          height: 130,
                                          decoration: BoxDecoration(
                                            gradient: RadialGradient(
                                              center: Alignment.center,
                                              radius: 0.9,
                                              colors: [
                                                _rewardRarity.darkColor.withValues(alpha: 0.85),
                                                const Color(0xFF070911),
                                              ],
                                            ),
                                            borderRadius: BorderRadius.circular(26),
                                            border: Border.all(
                                              color: _rewardRarity.primaryColor,
                                              width: 2.2,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: _rewardRarity.primaryColor.withValues(alpha: 0.55),
                                                blurRadius: 28,
                                                spreadRadius: 2,
                                              ),
                                            ],
                                          ),
                                          child: Stack(
                                            alignment: Alignment.center,
                                            children: [
                                              // Rotating background rune aura inside card
                                              Transform.rotate(
                                                angle: _auraController.value * 2 * pi,
                                                child: CustomPaint(
                                                  size: const Size(110, 110),
                                                  painter: _CardRuneAuraPainter(
                                                    color: _rewardRarity.primaryColor,
                                                  ),
                                                ),
                                              ),
                                              // High-detail Item visual
                                              Center(
                                                child: _buildRewardIcon(),
                                              ),
                                              // Specular shine sweep across card
                                              if (_shineSweepController.value > 0.0 && _shineSweepController.value < 1.0)
                                                Positioned.fill(
                                                  child: ClipRRect(
                                                    borderRadius: BorderRadius.circular(24),
                                                    child: CustomPaint(
                                                      painter: _CardShineSweepPainter(
                                                        progress: _shineSweepController.value,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  const SizedBox(height: 14),

                                  // Status Badge (New or Duplicate)
                                  if (_isDuplicate)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFF9800).withValues(alpha: 0.22),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: const Color(0xFFFF9800), width: 1.2),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.inventory_2_rounded, size: 14, color: Color(0xFFFFB74D)),
                                          SizedBox(width: 5),
                                          Text(
                                            'ZATEN SAHİPSİN (KOPYA)',
                                            style: TextStyle(
                                              color: Color(0xFFFFB74D),
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: 0.8,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  else
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF00E676).withValues(alpha: 0.22),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: const Color(0xFF00E676), width: 1.2),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.stars_rounded, size: 14, color: Color(0xFF69F0AE)),
                                          SizedBox(width: 5),
                                          Text(
                                            'YENİ AÇILDI!',
                                            style: TextStyle(
                                              color: Color(0xFF69F0AE),
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: 0.8,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                  const SizedBox(height: 9),

                                  Text(
                                    _rewardTitle,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 21,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.5,
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
                                            const Color(0xFF00E5FF).withValues(alpha: 0.22),
                                            const Color(0xFF00B0FF).withValues(alpha: 0.12),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.7)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.diamond_rounded, color: Color(0xFF00E5FF), size: 18),
                                          const SizedBox(width: 8),
                                          Text(
                                            '+1 Parça Eklendi! (${SaveManager.instance.getShards(widget.category ?? widget.categoryCrate?.category ?? 'balls')}/3)',
                                            style: const TextStyle(
                                              color: Color(0xFF00E5FF),
                                              fontSize: 12.5,
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
                                        color: const Color(0xFF4CAF50).withValues(alpha: 0.20),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(color: const Color(0xFF66BB6A).withValues(alpha: 0.75)),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.set_meal_rounded, color: Color(0xFF81C784), size: 18),
                                          SizedBox(width: 8),
                                          Text(
                                            '+3 Balık Yemi Hediye Edildi!',
                                            style: TextStyle(
                                              color: Color(0xFF81C784),
                                              fontSize: 12.5,
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

                    const SizedBox(height: 16),

                    // Dialog Actions
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
                            icon: const Icon(Icons.diamond_rounded, size: 16),
                            label: Text(
                              I18n.tr('use_shards_guaranteed'),
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00E5FF),
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                            ),
                          ),
                        ),
                      ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _rewardRarity.primaryColor,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 13),
                          elevation: 6,
                        ),
                        child: Text(
                          I18n.tr('claim_and_close'),
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Fullscreen Screen Flash Bloom on Legendary or Opening
              if (_flashController.isAnimating)
                Positioned.fill(
                  child: IgnorePointer(
                    child: FadeTransition(
                      opacity: ReverseAnimation(_flashController),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(30),
                          gradient: RadialGradient(
                            colors: [
                              Colors.white.withValues(alpha: 0.95),
                              activeColor.withValues(alpha: 0.75),
                              Colors.transparent,
                            ],
                            radius: 1.2,
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
      return Image.asset((_reward as FishItem).assetPath, width: 72, height: 72, fit: BoxFit.contain);
    }
    if (_reward is BallSkin) {
      final b = _reward as BallSkin;
      return Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          color: b.mainColor,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: b.glowColor, blurRadius: 16, spreadRadius: 2),
          ],
        ),
        child: Center(
          child: Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
        ),
      );
    }
    if (_reward is PaddleSkin) {
      final p = _reward as PaddleSkin;
      return Container(
        width: 72,
        height: 24,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [p.color1, p.color2]),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(color: p.glowColor, blurRadius: 14, spreadRadius: 1),
          ],
        ),
      );
    }
    if (_reward is BrickStyle) {
      final br = _reward as BrickStyle;
      if (br.id == 'brick_cosmic') {
        return Container(
          width: 68,
          height: 30,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            boxShadow: const [
              BoxShadow(color: Color(0xFFE040FB), blurRadius: 18, spreadRadius: 2),
            ],
          ),
          child: CustomPaint(
            painter: _DialogCosmicBrickPainter(),
          ),
        );
      }
      return Container(
        width: 64,
        height: 28,
        decoration: BoxDecoration(
          color: br.accent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: [
            BoxShadow(color: br.accent.withValues(alpha: 0.7), blurRadius: 14, spreadRadius: 1),
          ],
        ),
      );
    }
    if (_reward is TrailSkin) {
      final t = _reward as TrailSkin;
      Color trailColor = const Color(0xFFFFD54F);
      IconData icon = Icons.auto_awesome;
      if (t.style == TrailStyle.fire) {
        trailColor = const Color(0xFFFF3D00);
        icon = Icons.local_fire_department_rounded;
      } else if (t.style == TrailStyle.plasma) {
        trailColor = const Color(0xFF00E5FF);
        icon = Icons.electric_bolt_rounded;
      } else if (t.style == TrailStyle.rainbow) {
        trailColor = const Color(0xFFE040FB);
        icon = Icons.looks_rounded;
      } else if (t.style == TrailStyle.ghost) {
        trailColor = const Color(0xFFBA68C8);
        icon = Icons.lens_blur_rounded;
      }
      return Icon(icon, size: 54, color: trailColor);
    }
    return const Icon(Icons.check_circle_rounded, size: 54, color: Colors.white);
  }
}

// ==========================================
// CUSTOM PAINTERS: PARTICLES, SHOCKS & WAVES
// ==========================================

class _DialogCosmicBrickPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(6.0));
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

    // Micro-stars
    final starPaint = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(c.dx - halfW * 0.6, c.dy - halfH * 0.3), 0.9, starPaint);
    canvas.drawCircle(Offset(c.dx + halfW * 0.5, c.dy - halfH * 0.4), 0.8, starPaint);
    canvas.drawCircle(Offset(c.dx + halfW * 0.65, c.dy + halfH * 0.35), 0.9, starPaint);

    canvas.restore();

    // Prismatic crystal rim
    final rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..shader = const LinearGradient(
        colors: [Color(0xFF00E5FF), Color(0xFFE040FB), Color(0xFF7C4DFF), Color(0xFF00E5FF)],
      ).createShader(rect);
    canvas.drawRRect(rrect, rimPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _GroundImpactPainter extends CustomPainter {
  final double progress;
  final Color color;

  _GroundImpactPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.0 || progress >= 1.0) return;
    final center = Offset(size.width * 0.5, size.height * 0.85);
    final radiusX = size.width * 0.48 * progress;
    final radiusY = size.height * 0.25 * progress;
    final alpha = (1.0 - progress).clamp(0.0, 1.0);

    // Oval shockwave expanding across the floor
    final shockPaint = Paint()
      ..color = color.withValues(alpha: alpha * 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(1.5, 4.0 * (1.0 - progress));
    canvas.drawOval(Rect.fromCenter(center: center, width: radiusX * 2, height: radiusY * 2), shockPaint);

    // Vertical dust/spark jets bursting up
    final rand = Random(88);
    final jetPaint = Paint()..style = PaintingStyle.fill;
    for (int i = 0; i < 10; i++) {
      final angle = (rand.nextDouble() - 0.5) * pi * 0.7 - pi / 2;
      final dist = (30.0 + rand.nextDouble() * 40.0) * progress;
      final px = center.dx + cos(angle) * dist;
      final py = center.dy + sin(angle) * dist;
      jetPaint.color = (i.isEven ? color : Colors.white).withValues(alpha: alpha * 0.9);
      canvas.drawCircle(Offset(px, py), max(1.0, 2.5 * (1.0 - progress)), jetPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _GroundImpactPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

class _CrateElectricArcsPainter extends CustomPainter {
  final double progress;
  final Color color;

  _CrateElectricArcsPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.0 || progress >= 1.0) return;
    final alpha = (sin(progress * pi)).clamp(0.0, 1.0);
    final arcPaint = Paint()
      ..color = Colors.white.withValues(alpha: alpha * 0.95)
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final glowPaint = Paint()
      ..color = color.withValues(alpha: alpha * 0.60)
      ..strokeWidth = 4.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final rand = Random((progress * 100).toInt());
    // Draw 3 jagged electrical bolts leaping around chest
    for (int bolt = 0; bolt < 3; bolt++) {
      final path = Path();
      final start = Offset(
        size.width * (0.2 + rand.nextDouble() * 0.6),
        size.height * (0.3 + rand.nextDouble() * 0.5),
      );
      path.moveTo(start.dx, start.dy);
      var cur = start;
      for (int seg = 0; seg < 4; seg++) {
        final next = Offset(
          cur.dx + (rand.nextDouble() - 0.5) * 35,
          cur.dy + (rand.nextDouble() - 0.5) * 35,
        );
        path.lineTo(next.dx, next.dy);
        cur = next;
      }
      canvas.drawPath(path, glowPaint);
      canvas.drawPath(path, arcPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CrateElectricArcsPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

class _CratePillarLightPainter extends CustomPainter {
  final double progress;
  final Color color;

  _CratePillarLightPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.0 || progress >= 1.0) return;
    final alpha = (1.0 - progress).clamp(0.0, 1.0);
    final cx = size.width * 0.5;
    final bottomY = size.height * 0.85;
    final pillarW = (size.width * 0.45) * (0.6 + progress * 0.4);

    final pillarGrad = LinearGradient(
      begin: Alignment.bottomCenter,
      end: Alignment.topCenter,
      colors: [
        Colors.white.withValues(alpha: alpha * 0.9),
        color.withValues(alpha: alpha * 0.7),
        color.withValues(alpha: alpha * 0.15),
        Colors.transparent,
      ],
      stops: const [0.0, 0.25, 0.70, 1.0],
    );

    final pillarRect = Rect.fromLTWH(cx - pillarW * 0.5, 0, pillarW, bottomY);
    canvas.drawRect(pillarRect, Paint()..shader = pillarGrad.createShader(pillarRect));

    // Rising energy sparks
    final sparkPaint = Paint()..style = PaintingStyle.fill;
    final rand = Random(44);
    for (int i = 0; i < 14; i++) {
      final sx = cx + (rand.nextDouble() - 0.5) * pillarW * 0.8;
      final sy = bottomY - (rand.nextDouble() * bottomY * (0.5 + progress * 0.5));
      sparkPaint.color = (i.isEven ? Colors.white : color).withValues(alpha: alpha * 0.9);
      canvas.drawCircle(Offset(sx, sy), 1.5 + rand.nextDouble() * 2.0, sparkPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CratePillarLightPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

class _CardRuneAuraPainter extends CustomPainter {
  final Color color;

  _CardRuneAuraPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.5, size.height * 0.5);
    final r = size.width * 0.42;

    final ringPaint = Paint()
      ..color = color.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawCircle(center, r, ringPaint);

    final runePaint = Paint()
      ..color = color.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Outer cyber-rune tick marks
    for (int i = 0; i < 8; i++) {
      final angle = i * (pi / 4);
      final p1 = Offset(center.dx + cos(angle) * (r - 4), center.dy + sin(angle) * (r - 4));
      final p2 = Offset(center.dx + cos(angle) * (r + 4), center.dy + sin(angle) * (r + 4));
      canvas.drawLine(p1, p2, runePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CardRuneAuraPainter oldDelegate) => oldDelegate.color != color;
}

class _CardShineSweepPainter extends CustomPainter {
  final double progress;

  _CardShineSweepPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.0 || progress >= 1.0) return;
    final rect = Offset.zero & size;
    final sweepX = size.width * 2.0 * progress - size.width * 0.5;

    final shinePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.transparent,
          Colors.white.withValues(alpha: 0.45),
          Colors.transparent,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(sweepX, 0, size.width * 0.5, size.height));

    canvas.drawRect(rect, shinePaint);
  }

  @override
  bool shouldRepaint(covariant _CardShineSweepPainter oldDelegate) => oldDelegate.progress != progress;
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
    final maxRadius = size.width * 0.50;
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
    final rand = Random(42);

    final pVal = progress.clamp(0.0, 1.0);
    final alpha = pVal < 0.7 ? 1.0 : (1.0 - (pVal - 0.7) / 0.3).clamp(0.0, 1.0);

    for (int i = 0; i < 28; i++) {
      final baseAngle = (i / 28) * 2 * pi + (rand.nextDouble() * 0.2);
      final maxDist = 70.0 + rand.nextDouble() * 70.0;
      final curDist = maxDist * CurvedAnimation(parent: AlwaysStoppedAnimation(pVal), curve: Curves.easeOutCubic).value;
      final px = center.dx + cos(baseAngle) * curDist;
      final py = center.dy + sin(baseAngle) * curDist - (pVal * 18.0);

      final pColor = [
        color,
        Colors.white,
        const Color(0xFFFFD54F),
        const Color(0xFF00E5FF),
      ][i % 4];

      final particlePaint = Paint()..color = pColor.withValues(alpha: alpha * 0.85);

      final pSize = (3.8 - pVal * 1.2).clamp(1.5, 4.2);
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
