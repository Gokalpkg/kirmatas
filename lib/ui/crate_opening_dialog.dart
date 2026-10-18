import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../engine/audio_manager.dart';
import '../engine/i18n.dart';
import '../models/cosmetics.dart';
import '../storage/save_manager.dart';
import 'chest_widget.dart';
import 'kaunos_ui.dart';

class CrateOpeningDialog extends StatefulWidget {
  final CrateDef? crate;
  final CategoryCrateInfo? categoryCrate;
  final bool isGuaranteedRedemption;
  final String? category;
  final PendingCrate? pendingCrate;

  const CrateOpeningDialog({
    super.key,
    this.crate,
    this.categoryCrate,
    this.isGuaranteedRedemption = false,
    this.category,
    this.pendingCrate,
  }) : assert(crate != null || categoryCrate != null || isGuaranteedRedemption || pendingCrate != null);

  @override
  State<CrateOpeningDialog> createState() => _CrateOpeningDialogState();
}

class _CrateOpeningDialogState extends State<CrateOpeningDialog> with TickerProviderStateMixin {
  late final AnimationController _dropController;
  late final Animation<double> _dropAnimation;
  late final AnimationController _shakeController;
  late final AnimationController _openController;
  late final Animation<double> _openAnimation;
  late final AnimationController _squashController;
  late final Animation<double> _squashAnimation;
  late final AnimationController _crystalFlareController;
  late final AnimationController _flashController;
  late final AnimationController _auraController;
  late final AnimationController _shockwaveController;
  late final AnimationController _impactController;
  late final AnimationController _electricController;
  late final AnimationController _pillarController;
  late final AnimationController _cardFlipController;
  late final AnimationController _shineSweepController;
  late final AnimationController _revealController;
  late final AnimationController _suctionController;
  late final AnimationController _floorRunesController;
  late final AnimationController _lightningController;
  late final AnimationController _volumetricRaysController;
  late final AnimationController _chromaticController;
  late final AnimationController _starsPopController;
  late final AnimationController _landingDustController;
  late final AnimationController _popDustController;
  late final AnimationController _bouncingLootController;
  bool _impactTriggered = false;
  bool _openThumpFired = false;
  bool _openJingleFired = false;

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

  CrateDef? get _effectiveCrate {
    if (widget.crate != null) return widget.crate;
    final pending = widget.pendingCrate ?? SaveManager.instance.pendingCrate;
    if (pending?.crateId != null) {
      try {
        return CrateDef.allCrates.firstWhere((c) => c.id == pending!.crateId);
      } catch (_) {}
    }
    return null;
  }

  CategoryCrateInfo? get _effectiveCategoryCrate {
    if (widget.categoryCrate != null) return widget.categoryCrate;
    final pending = widget.pendingCrate ?? SaveManager.instance.pendingCrate;
    if (pending?.category != null) {
      return CategoryCrateInfo.categoryCrates[pending!.category];
    }
    return null;
  }

  Color get _currentPrimaryColor {
    switch (_currentRarity) {
      case Rarity.common:
        return _effectiveCrate?.primaryColor ?? _effectiveCategoryCrate?.primaryColor ?? const Color(0xFF90A4AE);
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
      duration: const Duration(milliseconds: 650),
    );
    _openController.addListener(_onOpenTick);
    _openAnimation = TweenSequence<double>([
      // Step 2 Snap: explosive lid pop with hinge overshoot
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.18).chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 60,
      ),
      // Recoil bounce back
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.18, end: 0.94).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 20,
      ),
      // Settle smoothly to fully open
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.94, end: 1.0).chain(CurveTween(curve: Curves.easeOut)),
        weight: 20,
      ),
    ]).animate(_openController);

    _squashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _squashAnimation = TweenSequence<double>([
      // Step 2 Snap: Deep squash compression down
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.0).chain(CurveTween(curve: Curves.easeInQuad)),
        weight: 35,
      ),
      // Explosive upward snap recoil
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: -0.45).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 35,
      ),
      // Elastic settle
      TweenSequenceItem(
        tween: Tween<double>(begin: -0.45, end: 0.0).chain(CurveTween(curve: Curves.elasticOut)),
        weight: 30,
      ),
    ]).animate(_squashController);

    _crystalFlareController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
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
    _cardFlipController.addListener(_onCardFlipTick);

    _shineSweepController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _revealController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _suctionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _floorRunesController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );

    _lightningController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );

    _volumetricRaysController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _chromaticController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    _starsPopController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _landingDustController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );

    _popDustController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );

    _bouncingLootController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    if (widget.pendingCrate != null) {
      _restoreFromPending(widget.pendingCrate!);
    } else {
      _rollReward();
    }

    _dropController.forward().then((_) {
      if (mounted) {
        _impactController.forward(from: 0.0);
        _landingDustController.forward(from: 0.0);
        AudioManager.instance.playSfx(GameSfx.hitPaddle);
        HapticFeedback.heavyImpact();
      }
    });
  }

  void _onOpenTick() {
    if (!mounted) return;
    // Step 3 Sound: Thump as lid reaches its hinge stop
    if (!_openThumpFired && _openController.value >= 0.25) {
      _openThumpFired = true;
      AudioManager.instance.playSfx(GameSfx.bossHit, playbackRate: 0.82);
      HapticFeedback.heavyImpact();
    }
    // Step 3 Sound: Little jingle as treasure is exposed
    if (!_openJingleFired && _openController.value >= 0.48) {
      _openJingleFired = true;
      AudioManager.instance.playSfx(GameSfx.bubble, playbackRate: 1.6);
      AudioManager.instance.playSfx(GameSfx.powerupBuff, playbackRate: 1.45);
    }
  }

  void _onCardFlipTick() {
    if (!_impactTriggered && _cardFlipController.value >= 0.52 && mounted) {
      _impactTriggered = true;
      _floorRunesController.forward(from: 0.0);
      _lightningController.forward(from: 0.0);
      _chromaticController.forward(from: 0.0);
      _shineSweepController.forward(from: 0.0);
      _volumetricRaysController.forward(from: 0.0);
      _starsPopController.forward(from: 0.0);

      // Arcane climax audio & tactile burst:
      // Bass drop + Boss rumble + Celestial choir chime + Victory
      AudioManager.instance.playSfx(GameSfx.explosion, playbackRate: 0.75);
      AudioManager.instance.playSfx(GameSfx.bossHit, playbackRate: 0.85);
      AudioManager.instance.playSfx(GameSfx.powerupBuff, playbackRate: 1.4);
      AudioManager.instance.playSfx(GameSfx.victory);
      HapticFeedback.heavyImpact();
    }
  }

  @override
  void dispose() {
    _openController.removeListener(_onOpenTick);
    _cardFlipController.removeListener(_onCardFlipTick);
    _dropController.dispose();
    _shakeController.dispose();
    _openController.dispose();
    _squashController.dispose();
    _crystalFlareController.dispose();
    _flashController.dispose();
    _auraController.dispose();
    _shockwaveController.dispose();
    _impactController.dispose();
    _electricController.dispose();
    _pillarController.dispose();
    _cardFlipController.dispose();
    _shineSweepController.dispose();
    _revealController.dispose();
    _suctionController.dispose();
    _floorRunesController.dispose();
    _lightningController.dispose();
    _volumetricRaysController.dispose();
    _chromaticController.dispose();
    _starsPopController.dispose();
    _landingDustController.dispose();
    _popDustController.dispose();
    _bouncingLootController.dispose();
    super.dispose();
  }

  Future<void> _handleChestTap() async {
    if (_opened || _isShaking || _isOpening || _dropController.value < 0.80) return;

    if (_tapCount == 0) {
      // 1. Dokunuş: Sıradan -> Ender kontrolü
      _isShaking = true;
      _tapCount = 1;
      _squashController.forward(from: 0.0);
      _shockwaveController.forward(from: 0.0);
      _electricController.forward(from: 0.0);
      final willUpgrade = _rewardRarity.index >= Rarity.rare.index;
      if (willUpgrade) {
        _crystalFlareController.forward(from: 0.0);
      }
      await _shakeController.forward(from: 0.0);
      if (!mounted) return;
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
      _squashController.forward(from: 0.0);
      _shockwaveController.forward(from: 0.0);
      _electricController.forward(from: 0.0);
      final willUpgrade = _rewardRarity.index >= Rarity.epic.index;
      if (willUpgrade) {
        _crystalFlareController.forward(from: 0.0);
      }
      await _shakeController.forward(from: 0.0);
      if (!mounted) return;
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
      _openThumpFired = false;
      _openJingleFired = false;

      final isLegendary = _rewardRarity == Rarity.legendary;
      if (isLegendary) {
        setState(() {
          _currentRarity = Rarity.legendary;
        });
        AudioManager.instance.playSfx(GameSfx.cornerBoost);
        HapticFeedback.heavyImpact();
      }

      // Step 1: Make chests shake before it opens (anticipation rattle tremor)
      _shakeController.duration = const Duration(milliseconds: 320);
      await _shakeController.forward(from: 0.0);
      if (!mounted) return;

      // Step 2: Snap - squash it down then pop the lid so it bounces!
      _squashController.forward(from: 0.0);
      // Step 3 Sound: Creak as stone/metal hinges strain under mechanical compression
      AudioManager.instance.playSfx(GameSfx.steel, playbackRate: 0.65);
      HapticFeedback.mediumImpact();

      // Step 4 & 5: Fire opening visual effects (pillar of light, flash, pop dust, and bouncing loot)
      _shockwaveController.forward(from: 0.0);
      _pillarController.forward(from: 0.0);
      _flashController.forward(from: 0.0);
      _crystalFlareController.forward(from: 0.0);
      _popDustController.forward(from: 0.0);
      _bouncingLootController.forward(from: 0.0);

      // Pop the lid! Thump & Little Jingle are executed on precise hinge ticks via _onOpenTick
      await _openController.forward(from: 0.0);
      if (!mounted) return;

      setState(() {
        _opened = true;
        _isOpening = false;
        _impactTriggered = false;
      });

      // Claim reward atomically now that chest has opened!
      await SaveManager.instance.claimPendingCrate();

      _suctionController.forward(from: 0.0);
      _cardFlipController.forward(from: 0.0);
      _revealController.forward(from: 0.0);

      // Stage 1: Arcane rising charge sound on card emergence
      AudioManager.instance.playSfx(GameSfx.powerupBuff, playbackRate: 0.95);
    }
  }

  void _restoreFromPending(PendingCrate pending) {
    _rewardRarity = Rarity.values[pending.rarityIndex.clamp(0, Rarity.values.length - 1)];
    _rewardTitle = pending.rewardTitle;
    _rewardSubtitle = pending.rewardSubtitle;
    _isDuplicate = pending.isDuplicate;
    _isShardReward = pending.isShardReward;
    _isFoodBonus = pending.isFoodBonus;

    switch (pending.rewardType) {
      case 'fish':
        try {
          _reward = FishItem.allFish.firstWhere((f) => f.id == pending.rewardId);
        } catch (_) {
          _reward = FishItem.allFish.first;
        }
        break;
      case 'ball':
        try {
          _reward = BallSkin.allSkins.firstWhere((s) => s.id == pending.rewardId);
        } catch (_) {
          _reward = BallSkin.allSkins.first;
        }
        break;
      case 'paddle':
        try {
          _reward = PaddleSkin.allSkins.firstWhere((s) => s.id == pending.rewardId);
        } catch (_) {
          _reward = PaddleSkin.allSkins.first;
        }
        break;
      case 'trail':
        try {
          _reward = TrailSkin.allTrails.firstWhere((s) => s.id == pending.rewardId);
        } catch (_) {
          _reward = TrailSkin.allTrails.first;
        }
        break;
      case 'brick':
        try {
          _reward = BrickStyle.all.firstWhere((s) => s.id == pending.rewardId);
        } catch (_) {
          _reward = BrickStyle.all.first;
        }
        break;
      case 'gold':
        _reward = null;
        break;
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
    final crateDef = _effectiveCrate ?? CrateDef.allCrates.first;
    final luckLevel = save.upgrades['luck'] ?? 0;
    final weights = Map<Rarity, double>.from(crateDef.weights);
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

    // Fish candidate selection
    final available = FishItem.allFish.where((f) => f.rarity == rolledRarity).toList();
    // Prioritize fish that player has 0 copies of
    final unownedInRarity = available.where((f) => save.getFishCount(f.id) == 0).toList();
    final allUnowned = FishItem.allFish.where((f) => save.getFishCount(f.id) == 0).toList();

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

    final currentOwnedCount = save.getFishCount(fish.id);
    int shardYield = 0;

    if (currentOwnedCount >= 2) {
      // 3rd+ copy: Converted to Balık Eklentisi (Fish Shard)!
      // Sıradan balıklar (common) -> +1 shard, ender ve üstü -> +2 shards
      shardYield = fish.rarity == Rarity.common ? 1 : 2;
      _isDuplicate = true;
      _isShardReward = true;
      _isFoodBonus = false;
      final newTotalShards = save.fishShards + shardYield;
      _rewardSubtitle = 'Bu balıktan 2 adede sahipsin! +$shardYield Balık Eklentisi eklendi ($newTotalShards/8).';
    } else if (currentOwnedCount == 1) {
      // 2nd copy: Joins aquarium
      _isDuplicate = true;
      _isShardReward = false;
      _isFoodBonus = true;
      _rewardSubtitle = 'Akvaryumuna 2. ${fish.name} katıldı! (+3 Yem Hediye)';
    } else {
      // 1st copy: Newly unlocked fish
      _isDuplicate = false;
      _isShardReward = false;
      _isFoodBonus = false;
      _rewardSubtitle = I18n.tr('new_fish_unlocked');
    }

    save.savePendingCrate(PendingCrate(
      crateType: 'aquarium',
      crateId: crateDef.id,
      category: 'fish',
      rewardType: 'fish',
      rewardId: fish.id,
      rewardTitle: _rewardTitle,
      rewardSubtitle: _rewardSubtitle,
      rarityIndex: _rewardRarity.index,
      isDuplicate: _isDuplicate,
      isShardReward: _isShardReward,
      shardCount: shardYield > 0 ? shardYield : 1,
      isFoodBonus: _isFoodBonus,
      bonusFoodCount: _isFoodBonus ? 3 : 0,
    ));
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

    String rewardType = 'ball';
    String rewardId = '';

    switch (category) {
      case 'balls':
        rewardType = 'ball';
        final unlockables = BallSkin.allSkins.where((s) => s.id != 'classic').toList();
        var pool = unlockables.where((s) => s.rarity == rolledRarity).toList();
        if (pool.isEmpty) {
          pool = unlockables.where((s) => s.rarity == Rarity.rare).toList();
          if (pool.isEmpty) pool = unlockables;
        }

        final skin = pool[rand.nextInt(pool.length)];
        rewardId = skin.id;
        _reward = skin;
        _rewardTitle = skin.name;
        _rewardRarity = skin.rarity;

        if (save.unlockedBalls.contains(skin.id)) {
          _isDuplicate = true;
          _isShardReward = true;
          _rewardSubtitle = 'Bu topa zaten sahipsin! Yerine +1 Parça (Shard) eklendi (${save.getShards(category) + 1}/3).';
        } else {
          _isDuplicate = false;
          _isShardReward = false;
          _rewardSubtitle = I18n.tr('new_ball_unlocked');
        }
        break;

      case 'paddles':
        rewardType = 'paddle';
        final unlockables = PaddleSkin.allSkins.where((s) => s.id != 'pclassic').toList();
        var pool = unlockables.where((s) => s.rarity == rolledRarity).toList();
        if (pool.isEmpty) {
          pool = unlockables.where((s) => s.rarity == Rarity.rare).toList();
          if (pool.isEmpty) pool = unlockables;
        }

        final skin = pool[rand.nextInt(pool.length)];
        rewardId = skin.id;
        _reward = skin;
        _rewardTitle = skin.name;
        _rewardRarity = skin.rarity;

        if (save.unlockedPaddles.contains(skin.id)) {
          _isDuplicate = true;
          _isShardReward = true;
          _rewardSubtitle = 'Bu rakete zaten sahipsin! Yerine +1 Parça (Shard) eklendi (${save.getShards(category) + 1}/3).';
        } else {
          _isDuplicate = false;
          _isShardReward = false;
          _rewardSubtitle = I18n.tr('new_paddle_unlocked');
        }
        break;

      case 'trails':
        rewardType = 'trail';
        final unlockables = TrailSkin.allTrails.where((s) => s.id != 't1').toList();
        var pool = unlockables.where((s) => s.rarity == rolledRarity).toList();
        if (pool.isEmpty) {
          pool = unlockables.where((s) => s.rarity == Rarity.rare).toList();
          if (pool.isEmpty) pool = unlockables;
        }

        final skin = pool[rand.nextInt(pool.length)];
        rewardId = skin.id;
        _reward = skin;
        _rewardTitle = skin.name;
        _rewardRarity = skin.rarity;

        if (save.unlockedTrails.contains(skin.id)) {
          _isDuplicate = true;
          _isShardReward = true;
          _rewardSubtitle = 'Bu ize zaten sahipsin! Yerine +1 Parça (Shard) eklendi (${save.getShards(category) + 1}/3).';
        } else {
          _isDuplicate = false;
          _isShardReward = false;
          _rewardSubtitle = I18n.tr('new_trail_unlocked');
        }
        break;

      case 'bricks':
        rewardType = 'brick';
        final unlockables = BrickStyle.all.where((s) => s.id != 'brick_gloss').toList();
        var pool = unlockables.where((s) => s.rarity == rolledRarity).toList();
        if (pool.isEmpty) {
          pool = unlockables.where((s) => s.rarity == Rarity.rare).toList();
          if (pool.isEmpty) pool = unlockables;
        }

        final style = pool[rand.nextInt(pool.length)];
        rewardId = style.id;
        _reward = style;
        _rewardTitle = style.name;
        _rewardRarity = style.rarity;

        if (save.unlockedBrickStyles.contains(style.id)) {
          _isDuplicate = true;
          _isShardReward = true;
          _rewardSubtitle = 'Bu blok stiline zaten sahipsin! Yerine +1 Parça (Shard) eklendi (${save.getShards(category) + 1}/3).';
        } else {
          _isDuplicate = false;
          _isShardReward = false;
          _rewardSubtitle = I18n.tr('new_brick_unlocked');
        }
        break;
    }

    save.savePendingCrate(PendingCrate(
      crateType: 'category',
      category: category,
      rewardType: rewardType,
      rewardId: rewardId,
      rewardTitle: _rewardTitle,
      rewardSubtitle: _rewardSubtitle,
      rarityIndex: _rewardRarity.index,
      isDuplicate: _isDuplicate,
      isShardReward: _isShardReward,
      isFoodBonus: false,
    ));
  }

  void _handleGuaranteedRedemption(SaveManager save, String category, Random rand) {
    _isDuplicate = false;
    _isShardReward = false;
    String rewardType = 'ball';
    String rewardId = '';
    int bonusGold = 0;

    switch (category) {
      case 'balls':
        rewardType = 'ball';
        final unowned = BallSkin.allSkins.where((s) => !save.unlockedBalls.contains(s.id)).toList();
        if (unowned.isNotEmpty) {
          final chosen = unowned[rand.nextInt(unowned.length)];
          rewardId = chosen.id;
          _reward = chosen;
          _rewardTitle = chosen.name;
          _rewardRarity = chosen.rarity;
          _rewardSubtitle = I18n.tr('guaranteed_item_unlocked');
        } else {
          rewardType = 'gold';
          bonusGold = 1000;
          _rewardRarity = Rarity.legendary;
          _rewardTitle = I18n.tr('all_items_unlocked');
          _rewardSubtitle = '+1000 Gold';
        }
        break;

      case 'paddles':
        rewardType = 'paddle';
        final unowned = PaddleSkin.allSkins.where((p) => !save.unlockedPaddles.contains(p.id)).toList();
        if (unowned.isNotEmpty) {
          final chosen = unowned[rand.nextInt(unowned.length)];
          rewardId = chosen.id;
          _reward = chosen;
          _rewardTitle = chosen.name;
          _rewardRarity = chosen.rarity;
          _rewardSubtitle = I18n.tr('guaranteed_item_unlocked');
        } else {
          rewardType = 'gold';
          bonusGold = 1000;
          _rewardRarity = Rarity.legendary;
          _rewardTitle = I18n.tr('all_items_unlocked');
          _rewardSubtitle = '+1000 Gold';
        }
        break;

      case 'trails':
        rewardType = 'trail';
        final unowned = TrailSkin.allTrails.where((t) => !save.unlockedTrails.contains(t.id)).toList();
        if (unowned.isNotEmpty) {
          final chosen = unowned[rand.nextInt(unowned.length)];
          rewardId = chosen.id;
          _reward = chosen;
          _rewardTitle = chosen.name;
          _rewardRarity = chosen.rarity;
          _rewardSubtitle = I18n.tr('guaranteed_item_unlocked');
        } else {
          rewardType = 'gold';
          bonusGold = 1000;
          _rewardRarity = Rarity.legendary;
          _rewardTitle = I18n.tr('all_items_unlocked');
          _rewardSubtitle = '+1000 Gold';
        }
        break;

      case 'bricks':
        rewardType = 'brick';
        final unowned = BrickStyle.all.where((b) => !save.unlockedBrickStyles.contains(b.id)).toList();
        if (unowned.isNotEmpty) {
          final chosen = unowned[rand.nextInt(unowned.length)];
          rewardId = chosen.id;
          _reward = chosen;
          _rewardTitle = chosen.name;
          _rewardRarity = chosen.rarity;
          _rewardSubtitle = I18n.tr('guaranteed_item_unlocked');
        } else {
          rewardType = 'gold';
          bonusGold = 1000;
          _rewardRarity = Rarity.legendary;
          _rewardTitle = I18n.tr('all_items_unlocked');
          _rewardSubtitle = '+1000 Gold';
        }
        break;

      case 'fish':
        rewardType = 'fish';
        // Priority: fish where player owns 0 copies
        final unownedFish = FishItem.allFish.where((f) => save.getFishCount(f.id) == 0).toList();
        if (unownedFish.isNotEmpty) {
          final chosen = unownedFish[rand.nextInt(unownedFish.length)];
          rewardId = chosen.id;
          _reward = chosen;
          _rewardTitle = chosen.name;
          _rewardRarity = chosen.rarity;
          _rewardSubtitle = 'Garantili Yeni Balık Açıldı!';
        } else {
          // If player has at least 1 of every fish, check if any have < 2 copies
          final canDuplicateFish = FishItem.allFish.where((f) => save.canAcquireFish(f.id)).toList();
          if (canDuplicateFish.isNotEmpty) {
            final chosen = canDuplicateFish[rand.nextInt(canDuplicateFish.length)];
            rewardId = chosen.id;
            _reward = chosen;
            _rewardTitle = chosen.name;
            _rewardRarity = chosen.rarity;
            _rewardSubtitle = 'Akvaryumuna 2. ${chosen.name} katıldı!';
          } else {
            // All fish at 2/2 max!
            rewardType = 'gold';
            bonusGold = 1500;
            _rewardRarity = Rarity.legendary;
            _rewardTitle = 'Tüm Balıklar Maksimumda!';
            _rewardSubtitle = '+1500 Altın Ödülü';
          }
        }
        break;
    }

    save.savePendingCrate(PendingCrate(
      crateType: 'guaranteed',
      category: category,
      rewardType: rewardType,
      rewardId: rewardId,
      rewardTitle: _rewardTitle,
      rewardSubtitle: _rewardSubtitle,
      rarityIndex: _rewardRarity.index,
      bonusGoldCount: bonusGold,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _opened,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop && _opened) {
          SaveManager.instance.claimPendingCrate();
        }
      },
      child: Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
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
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
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
                child: SingleChildScrollView(
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

                                    // 4b. Crystal Tier Upgrade Particles / Flares on Tap 1 & Tap 2
                                    if (_crystalFlareController.isAnimating)
                                      Positioned.fill(
                                        child: CustomPaint(
                                          painter: _CrateCrystalFlarePainter(
                                            progress: _crystalFlareController.value,
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

                                    // Step 4: Light pouring out from inside the chest (colored by reward rarity)
                                    AnimatedBuilder(
                                      animation: _openAnimation,
                                      builder: (context, _) {
                                        if (_openAnimation.value <= 0.03) return const SizedBox.shrink();
                                        return Positioned(
                                          top: 15,
                                          child: CustomPaint(
                                            size: const Size(190, 150),
                                            painter: _ChestInteriorGlowPainter(
                                              openProgress: _openAnimation.value,
                                              color: _rewardRarity.primaryColor,
                                            ),
                                          ),
                                        );
                                      },
                                    ),

                                    // Step 4: Landing Dust when chest impacts ground
                                    AnimatedBuilder(
                                      animation: _landingDustController,
                                      builder: (context, _) {
                                        if (!_landingDustController.isAnimating) return const SizedBox.shrink();
                                        return Positioned(
                                          bottom: 12,
                                          child: CustomPaint(
                                            size: const Size(220, 45),
                                            painter: _FloorDustPainter(
                                              progress: _landingDustController.value,
                                              color: const Color(0xFFCFD8DC),
                                            ),
                                          ),
                                        );
                                      },
                                    ),

                                    // Step 4: Pop Dust kicked up when lid bursts open
                                    AnimatedBuilder(
                                      animation: _popDustController,
                                      builder: (context, _) {
                                        if (!_popDustController.isAnimating) return const SizedBox.shrink();
                                        return Positioned(
                                          bottom: 12,
                                          child: CustomPaint(
                                            size: const Size(240, 50),
                                            painter: _FloorDustPainter(
                                              progress: _popDustController.value,
                                              color: _rewardRarity.primaryColor,
                                            ),
                                          ),
                                        );
                                      },
                                    ),

                                    // Step 5: Bouncing Loot (Coins, Gems, Shards launching & bouncing)
                                    AnimatedBuilder(
                                      animation: _bouncingLootController,
                                      builder: (context, _) {
                                        if (!_bouncingLootController.isAnimating) return const SizedBox.shrink();
                                        return Positioned(
                                          top: 0,
                                          child: CustomPaint(
                                            size: const Size(240, 160),
                                            painter: _BouncingLootPainter(
                                              progress: _bouncingLootController.value,
                                              color: _rewardRarity.primaryColor,
                                            ),
                                          ),
                                        );
                                      },
                                    ),

                                    // 6. 3D Animated Floating, Tilting, Squash-and-Stretch Shaking Chest
                                    AnimatedBuilder(
                                      animation: Listenable.merge([
                                        _shakeController,
                                        _auraController,
                                        _squashController,
                                        _openController,
                                      ]),
                                      builder: (context, _) {
                                        final squash = _squashAnimation.value;
                                        final scaleX = (1.0 + squash * 0.18) * _chestScale;
                                        final scaleY = (1.0 - squash * 0.18) * _chestScale;
                                        // Step 1: High frequency anticipation tremor shake before opening
                                        final shakeMult = _isOpening ? (5.5 + 3.5 * _shakeController.value) : (3.5 + _tapCount * 1.5);
                                        final shakeFreq = _isOpening ? 22.0 : 10.0;
                                        return Transform.translate(
                                          offset: Offset(
                                            sin(_shakeController.value * pi * shakeFreq) * shakeMult,
                                            sin(_auraController.value * 2 * pi) * 2.8 + squash * 4.0,
                                          ),
                                          child: Transform.rotate(
                                            angle: sin(_shakeController.value * pi * shakeFreq) * (0.08 + _tapCount * 0.03) * (1.0 - _shakeController.value),
                                            child: Transform.scale(
                                              scaleX: scaleX,
                                              scaleY: scaleY,
                                              alignment: Alignment.bottomCenter,
                                              child: ChestWidget(
                                                size: 122,
                                                primaryColor: _currentPrimaryColor,
                                                secondaryColor: _currentSecondaryColor,
                                                openProgress: _openAnimation.value,
                                                showGlow: true,
                                                time: _auraController.value * 2 * pi,
                                                tier: _currentRarity,
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 18),
                              AnimatedOpacity(
                                opacity: (_dropController.value > 0.80 && !_isShaking && !_isOpening) ? 1.0 : 0.45,
                                duration: const Duration(milliseconds: 150),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
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
                          // Step 4b. Volumetric Light Rays Fountain (behind everything)
                          Positioned(
                            top: -45,
                            child: AnimatedBuilder(
                              animation: _volumetricRaysController,
                              builder: (context, _) => CustomPaint(
                                size: const Size(280, 240),
                                painter: _VolumetricRaysFountainPainter(
                                  progress: _volumetricRaysController.value,
                                  color: _rewardRarity.primaryColor,
                                ),
                              ),
                            ),
                          ),

                          // Step 1c. Inward Glowing Energy Orbs Suction
                          Positioned.fill(
                            child: AnimatedBuilder(
                              animation: _suctionController,
                              builder: (context, _) => CustomPaint(
                                painter: _InwardEnergyOrbsPainter(
                                  progress: _suctionController.value,
                                  color: _rewardRarity.primaryColor,
                                ),
                              ),
                            ),
                          ),

                          // Step 3a. Expanding Floor Runes upon Impact
                          Positioned(
                            top: 80,
                            child: AnimatedBuilder(
                              animation: _floorRunesController,
                              builder: (context, _) => CustomPaint(
                                size: const Size(280, 95),
                                painter: _ExpandingFloorRunesPainter(
                                  progress: _floorRunesController.value,
                                  color: _rewardRarity.primaryColor,
                                ),
                              ),
                            ),
                          ),

                          // Confetti / Starburst Celebration Particles
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

                          // Rising Stellar Dust Motes drifting around the opened tablet
                          Positioned.fill(
                            child: AnimatedBuilder(
                              animation: _auraController,
                              builder: (context, _) => CustomPaint(
                                painter: _StellarDustPainter(
                                  time: _auraController.value * 4.0,
                                  color: _rewardRarity.primaryColor,
                                ),
                              ),
                            ),
                          ),

                          // Holographic Reward Presentation Card (3D Obsidian Crystal Tablet)
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
                                  // Step 2 & 5: 3D Flip Card Container with Float, Vibration, Freeze-Frame & Elastic Snap Landing
                                  AnimatedBuilder(
                                    animation: Listenable.merge([
                                      _cardFlipController,
                                      _suctionController,
                                      _chromaticController,
                                      _lightningController,
                                      _shineSweepController,
                                    ]),
                                    builder: (context, child) {
                                      final t = _cardFlipController.value;
                                      double translateY = 0.0;
                                      double vibeX = 0.0;
                                      double vibeY = 0.0;
                                      double angle;
                                      double scale = 1.0;

                                      if (t < 0.46) {
                                        // Step 1: Float card up, violent vibration during inward energy suction
                                        final p = (t / 0.46).clamp(0.0, 1.0);
                                        translateY = -32.0 * sin(p * pi * 0.5);
                                        vibeX = sin(t * 85.0) * (3.5 * p);
                                        vibeY = cos(t * 75.0) * (2.5 * p);
                                        angle = (1.0 - Curves.easeInQuad.transform(p)) * (pi * 0.5);
                                      } else if (t <= 0.52) {
                                        // Step 2: Brief dramatic freeze-frame suspension apex
                                        translateY = -32.0;
                                        vibeX = sin(t * 120.0) * 0.8;
                                        angle = 0.06 * sin((t - 0.46) / 0.06 * pi);
                                      } else {
                                        // Step 2 & 3: Bouncy elastic snap landing from apex to zero
                                        final p = ((t - 0.52) / 0.48).clamp(0.0, 1.0);
                                        final elastic = Curves.elasticOut.transform(p);
                                        translateY = -32.0 * (1.0 - elastic);
                                        angle = (1.0 - elastic) * 0.15;
                                        scale = 0.92 + 0.08 * elastic;
                                      }

                                      final cardWithTransform = Transform.translate(
                                        offset: Offset(vibeX, translateY + vibeY),
                                        child: Transform(
                                          alignment: Alignment.center,
                                          transform: Matrix4.identity()
                                            ..setEntry(3, 2, 0.0018)
                                            ..rotateY(angle)
                                            ..multiply(Matrix4.diagonal3Values(scale, scale, 1.0)),
                                          child: child,
                                        ),
                                      );

                                      // Step 5: Chromatic Aberration RGB channel split pulse on impact
                                      return _buildCardWithChromaticAberration(cardWithTransform);
                                    },
                                    child: Stack(
                                      alignment: Alignment.center,
                                      clipBehavior: Clip.none,
                                      children: [
                                        KaunosCard(
                                          width: 138,
                                          height: 138,
                                          borderRadius: 26,
                                          bottomBevelDepth: 5.0,
                                          bevelColor: KaunosPalette.crystalBevelShadow,
                                          backgroundColor: KaunosPalette.obsidianGlassElevated,
                                          borderColor: _rewardRarity.primaryColor.withValues(alpha: 0.85),
                                          showSpecularRim: true,
                                          showCornerBrackets: true,
                                          padding: EdgeInsets.zero,
                                          child: Stack(
                                            alignment: Alignment.center,
                                            children: [
                                              // Rotating background rune aura inside card
                                              Transform.rotate(
                                                angle: _auraController.value * 2 * pi,
                                                child: CustomPaint(
                                                  size: const Size(116, 116),
                                                  painter: _CardRuneAuraPainter(
                                                    color: _rewardRarity.primaryColor,
                                                  ),
                                                ),
                                              ),
                                              // High-detail Item visual
                                              Center(
                                                child: _buildRewardIcon(),
                                              ),
                                              // Step 4a: Prismatic Rainbow Sheen sweep across art
                                              if (_shineSweepController.value > 0.0 && _shineSweepController.value < 1.0)
                                                Positioned.fill(
                                                  child: ClipRRect(
                                                    borderRadius: BorderRadius.circular(24),
                                                    child: CustomPaint(
                                                      painter: _PrismaticRainbowSheenPainter(
                                                        progress: _shineSweepController.value,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),

                                        // Step 3b: Crackling Golden Lightning from card corners
                                        if (_lightningController.isAnimating)
                                          Positioned.fill(
                                            child: CustomPaint(
                                              painter: _CracklingGoldenLightningPainter(
                                                progress: _lightningController.value,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),

                                  const SizedBox(height: 10),

                                  // Step 6: Sequential Mythic Rarity Stars Pop
                                  AnimatedBuilder(
                                    animation: _starsPopController,
                                    builder: (context, _) => _MythicStarsRow(
                                      rarity: _rewardRarity,
                                      progress: _starsPopController.value,
                                    ),
                                  ),

                                  const SizedBox(height: 8),

                                  // Status Badge (New or Duplicate)
                                  if (_isDuplicate)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFF9800).withValues(alpha: 0.22),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: const Color(0xFFFF9800), width: 1.2),
                                      ),
                                      child: const FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Row(
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
                                      child: const FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Row(
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
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.diamond_rounded, color: Color(0xFF00E5FF), size: 18),
                                            const SizedBox(width: 8),
                                            Text(
                                              ((widget.category ?? widget.categoryCrate?.category) == 'fish' || _effectiveCrate != null)
                                                  ? 'Balık Eklentisi: ${SaveManager.instance.fishShards} / 8'
                                                  : I18n.tr('shard_added').replaceAll('{count}', '${SaveManager.instance.getShards(widget.category ?? widget.categoryCrate?.category ?? 'balls')}'),
                                              style: const TextStyle(
                                                color: Color(0xFF00E5FF),
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                          ],
                                        ),
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
                                      child: const FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Row(
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
                      if (_isShardReward && (((widget.category ?? widget.categoryCrate?.category) == 'fish' || _effectiveCrate != null) ? SaveManager.instance.fishShards >= 8 : SaveManager.instance.getShards(widget.category ?? widget.categoryCrate?.category ?? 'balls') >= 3))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: KaunosTactileButton.gold(
                            height: 44,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            onTap: () async {
                              final isFish = (widget.category ?? widget.categoryCrate?.category) == 'fish' || _effectiveCrate != null;
                              final cat = isFish ? 'fish' : (widget.category ?? widget.categoryCrate?.category ?? 'balls');
                              final ok = isFish ? await SaveManager.instance.consumeFishShards(8) : await SaveManager.instance.consumeShards(cat, 3);
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
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.diamond_rounded, size: 16, color: Color(0xFF1B0E05)),
                                  const SizedBox(width: 8),
                                  Text(
                                    (((widget.category ?? widget.categoryCrate?.category) == 'fish' || _effectiveCrate != null) ? I18n.tr('use_fish_shards_guaranteed') : I18n.tr('use_shards_guaranteed')),
                                    style: const TextStyle(
                                      color: Color(0xFF1B0E05),
                                      fontWeight: FontWeight.w900,
                                      fontSize: 12.5,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      KaunosTactileButton.gold(
                        height: 48,
                        padding: const EdgeInsets.symmetric(horizontal: 36),
                        onTap: () async {
                          await SaveManager.instance.claimPendingCrate();
                          if (context.mounted) {
                            Navigator.of(context).pop();
                          }
                        },
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            I18n.tr('claim_and_close'),
                            style: const TextStyle(
                              color: Color(0xFF1B0E05),
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
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
    ),
    );
  }

  Widget _buildCardWithChromaticAberration(Widget cardWidget) {
    if (_chromaticController.value <= 0.0 || _chromaticController.value >= 1.0) {
      return cardWidget;
    }
    final progress = _chromaticController.value;
    final splitDist = (1.0 - progress) * 6.5;
    final ghostAlpha = ((1.0 - progress) * 0.45).clamp(0.0, 1.0);

    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        // Cyan color channel split (shifted left)
        Transform.translate(
          offset: Offset(-splitDist, 0),
          child: ColorFiltered(
            colorFilter: ColorFilter.mode(
              const Color(0xFF00E5FF).withValues(alpha: ghostAlpha),
              BlendMode.screen,
            ),
            child: cardWidget,
          ),
        ),
        // Red-Orange color channel split (shifted right)
        Transform.translate(
          offset: Offset(splitDist, 0),
          child: ColorFiltered(
            colorFilter: ColorFilter.mode(
              const Color(0xFFFF1744).withValues(alpha: ghostAlpha),
              BlendMode.screen,
            ),
            child: cardWidget,
          ),
        ),
        // Center razor-sharp obsidian crystal card
        cardWidget,
      ],
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

class _CrateCrystalFlarePainter extends CustomPainter {
  final double progress;
  final Color color;

  _CrateCrystalFlarePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.0 || progress >= 1.0) return;
    final center = Offset(size.width * 0.5, size.height * 0.5);
    final alpha = (1.0 - progress).clamp(0.0, 1.0);

    // Expanding crystalline octagonal ring
    final ringPaint = Paint()
      ..color = color.withValues(alpha: alpha * 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(1.2, 3.5 * (1.0 - progress));
    final r = size.width * 0.44 * progress;
    final polyPath = Path();
    for (int i = 0; i < 8; i++) {
      final a = (i * 45) * pi / 180;
      final px = center.dx + cos(a) * r;
      final py = center.dy + sin(a) * r;
      if (i == 0) {
        polyPath.moveTo(px, py);
      } else {
        polyPath.lineTo(px, py);
      }
    }
    polyPath.close();
    canvas.drawPath(polyPath, ringPaint);

    // Radiant diamond crystal shards
    for (int i = 0; i < 12; i++) {
      final angle = (i * (2 * pi / 12)) + (progress * 0.4);
      final dist = (size.width * 0.15) + (size.width * 0.38) * progress;
      final px = center.dx + cos(angle) * dist;
      final py = center.dy + sin(angle) * dist;
      final shardSize = max(1.8, 4.5 * (1.0 - progress));

      final shardPath = Path()
        ..moveTo(px, py - shardSize * 1.4)
        ..lineTo(px + shardSize, py)
        ..lineTo(px, py + shardSize * 1.4)
        ..lineTo(px - shardSize, py)
        ..close();

      final shardPaint = Paint()
        ..color = (i.isEven ? color : Colors.white).withValues(alpha: alpha * 0.95);
      canvas.drawPath(shardPath, shardPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CrateCrystalFlarePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

class _StellarDustPainter extends CustomPainter {
  final double time;
  final Color color;

  _StellarDustPainter({required this.time, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final rand = Random(123);
    final dustPaint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < 20; i++) {
      final seedX = rand.nextDouble();
      final seedY = rand.nextDouble();
      final speed = 0.4 + rand.nextDouble() * 0.6;
      final t = (time * speed + seedY) % 1.0;

      final px = size.width * (0.05 + 0.90 * seedX) + sin((time * 2.0 + i) * pi) * 6.0;
      final py = size.height * (1.0 - t);
      final alpha = (sin(t * pi)).clamp(0.0, 1.0) * 0.75;

      dustPaint.color = (i % 3 == 0 ? Colors.white : color).withValues(alpha: alpha);
      final radius = 1.0 + (i % 3 == 0 ? 1.4 : 0.8);
      canvas.drawCircle(Offset(px, py), radius, dustPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _StellarDustPainter oldDelegate) =>
      oldDelegate.time != time || oldDelegate.color != color;
}

class _InwardEnergyOrbsPainter extends CustomPainter {
  final double progress;
  final Color color;

  _InwardEnergyOrbsPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.0 || progress >= 1.0) return;
    final cx = size.width * 0.5;
    final cy = size.height * 0.5;
    final center = Offset(cx, cy);

    final p = Curves.easeInCubic.transform(progress);
    final alpha = (sin(progress * pi)).clamp(0.0, 1.0);

    final dotPaint = Paint()..style = PaintingStyle.fill;
    final glowPaint = Paint()..style = PaintingStyle.fill;

    const count = 32;
    for (int i = 0; i < count; i++) {
      final seed = (i * 97 + 13) % 1000 / 1000.0;
      final seed2 = (i * 61 + 37) % 1000 / 1000.0;
      final baseRadius = 120.0 + seed * 120.0;
      final baseAngle = i * (2 * pi / count) + seed2 * 0.4;

      final curRadius = baseRadius * (1.0 - p);
      final curAngle = baseAngle + progress * 2.8;

      final curPos = center + Offset(cos(curAngle) * curRadius, sin(curAngle) * curRadius);

      final tailAngle = curAngle - 0.12 * (1.0 - p);
      final tailRadius = curRadius + 14.0 * (1.0 - p);
      final tailPos = center + Offset(cos(tailAngle) * tailRadius, sin(tailAngle) * tailRadius);

      final orbColor = (i % 4 == 0)
          ? Colors.white
          : (i % 4 == 1 ? color : (i % 4 == 2 ? const Color(0xFFFFD54F) : const Color(0xFF38BDF8)));

      final orbAlpha = alpha * (0.5 + 0.5 * (1.0 - p));

      final trailPaint = Paint()
        ..color = orbColor.withValues(alpha: orbAlpha * 0.6)
        ..strokeWidth = 1.8 * (1.0 - p)
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(tailPos, curPos, trailPaint);

      glowPaint.color = orbColor.withValues(alpha: orbAlpha * 0.25);
      canvas.drawCircle(curPos, (3.5 + seed * 2.0) * 1.5, glowPaint);
      glowPaint.color = orbColor.withValues(alpha: orbAlpha * 0.60);
      canvas.drawCircle(curPos, 3.5 + seed * 2.0, glowPaint);

      dotPaint.color = Colors.white.withValues(alpha: orbAlpha * 0.95);
      canvas.drawCircle(curPos, 1.5 + seed * 1.5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _InwardEnergyOrbsPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

class _ExpandingFloorRunesPainter extends CustomPainter {
  final double progress;
  final Color color;

  _ExpandingFloorRunesPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.0 || progress >= 1.0) return;
    final alpha = (1.0 - progress).clamp(0.0, 1.0);
    final cx = size.width * 0.5;
    final cy = size.height * 0.5;

    canvas.save();
    canvas.translate(cx, cy);
    canvas.scale(1.0, 0.36);

    final expandP = Curves.easeOutCubic.transform(progress);
    final maxRadius = 135.0 * expandP;

    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..color = color.withValues(alpha: alpha * 0.85);
    canvas.drawCircle(Offset.zero, maxRadius, ringPaint);

    final glowRingPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 4.5)
      ..color = const Color(0xFFFFD54F).withValues(alpha: alpha * 0.65);
    canvas.drawCircle(Offset.zero, maxRadius, glowRingPaint);

    final innerR = maxRadius * 0.68;
    canvas.drawCircle(Offset.zero, innerR, ringPaint..strokeWidth = 1.4);

    final starPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = Colors.white.withValues(alpha: alpha * 0.9);
    final starPath = Path();
    const points = 8;
    for (int i = 0; i < points * 2; i++) {
      final r = i.isEven ? maxRadius * 0.95 : maxRadius * 0.45;
      final angle = i * (pi / points) + progress * 0.5;
      final pt = Offset(cos(angle) * r, sin(angle) * r);
      if (i == 0) {
        starPath.moveTo(pt.dx, pt.dy);
      } else {
        starPath.lineTo(pt.dx, pt.dy);
      }
    }
    starPath.close();
    canvas.drawPath(starPath, starPaint);

    const tickCount = 24;
    final tickPaint = Paint()
      ..color = const Color(0xFFFFD54F).withValues(alpha: alpha * 0.85)
      ..strokeWidth = 1.5;
    for (int i = 0; i < tickCount; i++) {
      final angle = i * (2 * pi / tickCount) - progress * 0.3;
      final p1 = Offset(cos(angle) * (maxRadius - 6.0), sin(angle) * (maxRadius - 6.0));
      final p2 = Offset(cos(angle) * (maxRadius + 6.0), sin(angle) * (maxRadius + 6.0));
      canvas.drawLine(p1, p2, tickPaint);
    }

    final corePaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.white.withValues(alpha: alpha * 0.7)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6.0);
    canvas.drawCircle(Offset.zero, 18.0 * (1.0 - progress), corePaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ExpandingFloorRunesPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

class _CracklingGoldenLightningPainter extends CustomPainter {
  final double progress;

  _CracklingGoldenLightningPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.0 || progress >= 1.0) return;
    final alpha = (1.0 - progress).clamp(0.0, 1.0);
    final rand = Random(88);

    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFFFA000).withValues(alpha: alpha * 0.8)
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 4.0);

    final corePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFFFD54F).withValues(alpha: alpha * 0.95);

    final whiteHotPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: alpha);

    final origins = [
      Offset(0, 0),
      Offset(size.width, 0),
      Offset(0, size.height),
      Offset(size.width, size.height),
      Offset(size.width * 0.5, 0),
      Offset(size.width * 0.5, size.height),
      Offset(0, size.height * 0.5),
      Offset(size.width, size.height * 0.5),
    ];

    for (int b = 0; b < origins.length; b++) {
      final start = origins[b];
      final dirX = (start.dx - size.width * 0.5).sign;
      final dirY = (start.dy - size.height * 0.5).sign;
      final baseAngle = atan2(dirY == 0 ? (b.isEven ? 1.0 : -1.0) : dirY, dirX == 0 ? 1.0 : dirX);

      final path = Path()..moveTo(start.dx, start.dy);
      Offset cur = start;
      const segments = 4;
      final totalDist = 28.0 + rand.nextDouble() * 26.0;

      for (int s = 1; s <= segments; s++) {
        final t = s / segments;
        final segDist = totalDist * t;
        final perp = (rand.nextDouble() - 0.5) * 16.0 * (1.0 - t * 0.4);
        final next = Offset(
          start.dx + cos(baseAngle) * segDist - sin(baseAngle) * perp,
          start.dy + sin(baseAngle) * segDist + cos(baseAngle) * perp,
        );
        path.lineTo(next.dx, next.dy);
        cur = next;
      }

      canvas.drawPath(path, glowPaint);
      canvas.drawPath(path, corePaint);
      canvas.drawPath(path, whiteHotPaint);

      canvas.drawCircle(cur, 2.2, whiteHotPaint..style = PaintingStyle.fill);
    }
  }

  @override
  bool shouldRepaint(covariant _CracklingGoldenLightningPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _PrismaticRainbowSheenPainter extends CustomPainter {
  final double progress;

  _PrismaticRainbowSheenPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.0 || progress >= 1.0) return;

    final shift = progress * 2.2 - 0.6;
    final w = size.width;
    final h = size.height;

    final start = Offset(w * (shift - 0.35), h * (shift - 0.35));
    final end = Offset(w * (shift + 0.35), h * (shift + 0.35));

    final rainbowGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Colors.transparent,
        const Color(0x339C27B0), // Violet
        const Color(0x553F51B5), // Indigo
        const Color(0x7700E5FF), // Crystal Cyan
        const Color(0x7700E676), // Mint Emerald
        const Color(0x99FFD54F), // Amber Gold
        const Color(0x77FF4081), // Coral Rose
        Colors.white.withValues(alpha: 0.85), // Pure Starlight White Flash
        const Color(0x7700E5FF), // Crystal Cyan
        const Color(0x339C27B0), // Violet
        Colors.transparent,
      ],
      stops: const [0.0, 0.15, 0.28, 0.40, 0.48, 0.55, 0.63, 0.70, 0.82, 0.92, 1.0],
    );

    final rect = Rect.fromLTWH(0, 0, w, h);
    final sheenPaint = Paint()
      ..shader = rainbowGradient.createShader(Rect.fromPoints(start, end))
      ..blendMode = BlendMode.screen;

    canvas.drawRect(rect, sheenPaint);
  }

  @override
  bool shouldRepaint(covariant _PrismaticRainbowSheenPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _VolumetricRaysFountainPainter extends CustomPainter {
  final double progress;
  final Color color;

  _VolumetricRaysFountainPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.0 || progress >= 1.0) return;
    final alpha = (sin(progress * pi)).clamp(0.0, 1.0) * (1.0 - progress * 0.45);
    final cx = size.width * 0.5;
    final originY = size.height * 0.72;

    const rayCount = 12;
    for (int i = 0; i < rayCount; i++) {
      final angleSpread = -1.22 + (i / (rayCount - 1)) * 2.44;
      final rayAngle = -pi * 0.5 + angleSpread;

      final length = 170.0 + (i % 3) * 35.0;
      final rayEnd = Offset(cx + cos(rayAngle) * length, originY + sin(rayAngle) * length);

      final beamWidth = 14.0 + (i % 2) * 10.0;
      final perpAngle = rayAngle + pi * 0.5;
      final p1 = Offset(cx - cos(perpAngle) * 3.0, originY - sin(perpAngle) * 3.0);
      final p2 = Offset(cx + cos(perpAngle) * 3.0, originY + sin(perpAngle) * 3.0);
      final p3 = Offset(rayEnd.dx + cos(perpAngle) * beamWidth, rayEnd.dy + sin(perpAngle) * beamWidth);
      final p4 = Offset(rayEnd.dx - cos(perpAngle) * beamWidth, rayEnd.dy - sin(perpAngle) * beamWidth);

      final rayPath = Path()
        ..moveTo(p1.dx, p1.dy)
        ..lineTo(p2.dx, p2.dy)
        ..lineTo(p3.dx, p3.dy)
        ..lineTo(p4.dx, p4.dy)
        ..close();

      final rayColor = (i.isEven ? Colors.white : color).withValues(alpha: alpha * (0.35 + (i % 2) * 0.25));
      final rayGrad = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [
          rayColor,
          rayColor.withValues(alpha: rayColor.a * 0.6),
          Colors.transparent,
        ],
        stops: const [0.0, 0.45, 1.0],
      );

      final rayBounds = rayPath.getBounds();
      final rayPaint = Paint()
        ..shader = rayGrad.createShader(rayBounds)
        ..blendMode = BlendMode.screen;

      canvas.drawPath(rayPath, rayPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _VolumetricRaysFountainPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

class _MythicStarsRow extends StatelessWidget {
  final Rarity rarity;
  final double progress;

  const _MythicStarsRow({required this.rarity, required this.progress});

  int get _starCount {
    switch (rarity) {
      case Rarity.common:
        return 1;
      case Rarity.rare:
        return 2;
      case Rarity.epic:
        return 3;
      case Rarity.legendary:
        return 5;
    }
  }

  @override
  Widget build(BuildContext context) {
    final count = _starCount;
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (index) {
        final startThreshold = index * 0.12;
        final starP = ((progress - startThreshold) / 0.40).clamp(0.0, 1.0);
        final scale = starP > 0.0 ? Curves.elasticOut.transform(starP) : 0.0;
        final opacity = starP.clamp(0.0, 1.0);

        return Transform.scale(
          scale: scale,
          child: Opacity(
            opacity: opacity,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (starP > 0.2 && starP < 0.95)
                    Transform.rotate(
                      angle: starP * pi,
                      child: Icon(
                        Icons.flare_rounded,
                        size: 26,
                        color: const Color(0xFFFFD54F).withValues(alpha: (1.0 - starP).clamp(0.0, 1.0)),
                      ),
                    ),
                  const Icon(
                    Icons.star_rounded,
                    size: 22,
                    color: Color(0xFFFF8F00),
                  ),
                  const Icon(
                    Icons.star_rounded,
                    size: 19,
                    color: Color(0xFFFFD54F),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _FloorDustPainter extends CustomPainter {
  final double progress;
  final Color color;

  _FloorDustPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.0 || progress >= 1.0) return;
    final alpha = (1.0 - progress).clamp(0.0, 1.0);
    final cx = size.width * 0.5;
    final baseY = size.height * 0.75;

    final dustPaint = Paint()..style = PaintingStyle.fill;
    final rand = Random(55);

    // Billowing dust clouds kicking left and right
    const puffCount = 14;
    for (int i = 0; i < puffCount; i++) {
      final isLeft = i.isEven;
      final seed = rand.nextDouble();
      final speed = 0.6 + seed * 0.8;
      final dist = (22.0 + seed * 68.0) * Curves.easeOutCubic.transform(progress * speed);
      final px = cx + (isLeft ? -dist : dist);
      final py = baseY - sin(progress * pi) * (6.0 + seed * 16.0);
      final radius = (6.0 + seed * 10.0) * (0.6 + progress * 0.8);

      final puffAlpha = (alpha * (0.35 + (1.0 - seed) * 0.35)).clamp(0.0, 1.0);
      final puffColor = (i % 3 == 0 ? color : const Color(0xFFCFD8DC));
      // Outer soft halo
      dustPaint.color = puffColor.withValues(alpha: puffAlpha * 0.28);
      canvas.drawCircle(Offset(px, py), radius * 1.35, dustPaint);
      // Inner dense puff
      dustPaint.color = puffColor.withValues(alpha: puffAlpha * 0.62);
      canvas.drawCircle(Offset(px, py), radius * 0.85, dustPaint);
    }

    // High-speed flying stone debris sparks
    final sparkPaint = Paint()..style = PaintingStyle.fill;
    for (int j = 0; j < 10; j++) {
      final isLeft = j.isEven;
      final seed = rand.nextDouble();
      final dist = (35.0 + seed * 75.0) * Curves.easeOutQuad.transform(progress);
      final px = cx + (isLeft ? -dist : dist);
      final py = baseY - (seed * 22.0 * sin(progress * pi));
      final sparkAlpha = (alpha * 0.85).clamp(0.0, 1.0);
      sparkPaint.color = Colors.white.withValues(alpha: sparkAlpha);
      canvas.drawCircle(Offset(px, py), 1.2 + seed * 1.2, sparkPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _FloorDustPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

class _ChestInteriorGlowPainter extends CustomPainter {
  final double openProgress;
  final Color color;

  _ChestInteriorGlowPainter({required this.openProgress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (openProgress <= 0.03) return;
    final cx = size.width * 0.5;
    final mouthY = size.height * 0.60;
    final effectiveP = (openProgress.clamp(0.0, 1.0));

    // 1. Broad radial glow pouring out of chest chamber
    final glowRect = Rect.fromCenter(
      center: Offset(cx, mouthY),
      width: size.width * 0.85 * effectiveP,
      height: size.height * 0.90 * effectiveP,
    );

    final glowShader = RadialGradient(
      colors: [
        Colors.white.withValues(alpha: (0.85 * effectiveP).clamp(0.0, 1.0)),
        color.withValues(alpha: (0.75 * effectiveP).clamp(0.0, 1.0)),
        color.withValues(alpha: (0.25 * effectiveP).clamp(0.0, 1.0)),
        Colors.transparent,
      ],
      stops: const [0.0, 0.28, 0.65, 1.0],
    ).createShader(glowRect);

    canvas.drawOval(glowRect, Paint()..shader = glowShader);

    // 2. Upward fanning volumetric light beam cone
    final coneW = (size.width * 0.40) * effectiveP;
    final coneTopW = (size.width * 0.70) * effectiveP;
    final conePath = Path()
      ..moveTo(cx - coneW * 0.5, mouthY)
      ..lineTo(cx + coneW * 0.5, mouthY)
      ..lineTo(cx + coneTopW * 0.5, 0)
      ..lineTo(cx - coneTopW * 0.5, 0)
      ..close();

    final coneGrad = LinearGradient(
      begin: Alignment.bottomCenter,
      end: Alignment.topCenter,
      colors: [
        Colors.white.withValues(alpha: 0.75 * effectiveP),
        color.withValues(alpha: 0.45 * effectiveP),
        Colors.transparent,
      ],
      stops: const [0.0, 0.40, 1.0],
    );

    canvas.drawPath(
      conePath,
      Paint()
        ..shader = coneGrad.createShader(Rect.fromLTWH(cx - coneTopW * 0.5, 0, coneTopW, mouthY))
        ..blendMode = BlendMode.screen,
    );

    // 3. Floating starlight motes rising out of the interior
    final rand = Random(33);
    final sparkPaint = Paint()..style = PaintingStyle.fill;
    for (int i = 0; i < 8; i++) {
      final seedX = (rand.nextDouble() - 0.5) * coneW * 0.9;
      final seedY = rand.nextDouble() * mouthY * effectiveP;
      final px = cx + seedX;
      final py = mouthY - seedY;
      sparkPaint.color = (i.isEven ? Colors.white : color).withValues(alpha: 0.85 * effectiveP);
      canvas.drawCircle(Offset(px, py), 1.5 + rand.nextDouble() * 1.5, sparkPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ChestInteriorGlowPainter oldDelegate) =>
      oldDelegate.openProgress != openProgress || oldDelegate.color != color;
}

class _BouncingLootPainter extends CustomPainter {
  final double progress;
  final Color color;

  _BouncingLootPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.0 || progress >= 1.0) return;
    final cx = size.width * 0.5;
    final originY = size.height * 0.55;
    final groundY = size.height * 0.82;

    final alpha = (1.0 - (progress - 0.65).clamp(0.0, 0.35) / 0.35).clamp(0.0, 1.0);
    final rand = Random(99);

    const count = 16;
    for (int i = 0; i < count; i++) {
      final angle = -pi * 0.5 + (rand.nextDouble() - 0.5) * 1.45;
      final speed = 110.0 + rand.nextDouble() * 140.0;
      final vx = cos(angle) * speed;
      final vy0 = sin(angle) * speed;

      final t = progress * 1.4;
      final g = 380.0;

      final tPeak = -vy0 / g;
      final tImpact = 2 * tPeak;

      double px = cx + vx * t;
      double py;
      if (t < tImpact) {
        py = originY + vy0 * t + 0.5 * g * t * t;
      } else {
        final tAfter = t - tImpact;
        final vyBounce = -vy0 * 0.52;
        py = groundY + vyBounce * tAfter + 0.5 * g * tAfter * tAfter;
        if (py > groundY) py = groundY;
      }

      if (py > groundY) py = groundY;

      final isCoin = i < 8;
      final isGem = i >= 8 && i < 12;

      canvas.save();
      canvas.translate(px, py);
      canvas.rotate((t * 6.0 + i) * (i.isEven ? 1.0 : -1.0));

      if (isCoin) {
        final coinRadius = 4.5 + rand.nextDouble() * 2.0;
        final coinGrad = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: alpha),
            const Color(0xFFFFD54F).withValues(alpha: alpha),
            const Color(0xFFFFA000).withValues(alpha: alpha),
          ],
          stops: const [0.0, 0.65, 1.0],
        );
        final coinPaint = Paint()..shader = coinGrad.createShader(Rect.fromCircle(center: Offset.zero, radius: coinRadius));
        canvas.drawCircle(Offset.zero, coinRadius, coinPaint);
        canvas.drawCircle(
          Offset.zero,
          coinRadius,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.9
            ..color = const Color(0xFFFF8F00).withValues(alpha: alpha),
        );
      } else if (isGem) {
        final gemSize = 5.0 + rand.nextDouble() * 2.5;
        final gemPath = Path()
          ..moveTo(0, -gemSize)
          ..lineTo(gemSize * 0.7, 0)
          ..lineTo(0, gemSize)
          ..lineTo(-gemSize * 0.7, 0)
          ..close();
        final gemPaint = Paint()
          ..style = PaintingStyle.fill
          ..color = (i.isEven ? color : const Color(0xFF00E5FF)).withValues(alpha: alpha * 0.95);
        canvas.drawPath(gemPath, gemPaint);
      } else {
        final sparkSize = 2.5 + rand.nextDouble() * 1.5;
        final sparkPaint = Paint()
          ..style = PaintingStyle.fill
          ..color = Colors.white.withValues(alpha: alpha);
        canvas.drawCircle(Offset.zero, sparkSize, sparkPaint);
      }

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _BouncingLootPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
