import 'dart:math';
import 'package:flutter/material.dart';
import '../engine/ad_manager.dart';
import '../engine/audio_manager.dart';
import '../engine/i18n.dart';
import '../models/cosmetics.dart';
import '../storage/save_manager.dart';
import 'chest_widget.dart';
import 'kaunos_ui.dart';

class WheelReward {
  final String label;
  final String subtitle;
  final IconData icon;
  final Color primaryColor;
  final Color secondaryColor;
  final void Function(BuildContext context, SaveManager save) onClaim;

  const WheelReward({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.primaryColor,
    required this.secondaryColor,
    required this.onClaim,
  });
}

class FortuneWheelDialog extends StatefulWidget {
  const FortuneWheelDialog({super.key});

  static List<WheelReward> get rewards => _FortuneWheelDialogState.rewards;

  static List<double> get spinWeights => _FortuneWheelDialogState.spinWeights;

  /// What the Octopus Vault hands out (see the state class for the
  /// single-source picker).
  static FishItem vaultRewardFish(SaveManager save) =>
      _FortuneWheelDialogState.vaultRewardFish(save);

  @override
  State<FortuneWheelDialog> createState() => _FortuneWheelDialogState();
}

class _FortuneWheelDialogState extends State<FortuneWheelDialog> with SingleTickerProviderStateMixin {
  late final AnimationController _spinController;
  late Animation<double> _spinAnimation;

  double _currentRotation = 0.0;
  bool _isSpinning = false;
  int? _winningIndex;
  double _pointerBend = 0.0;
  double _lastSpinValue = 0.0;

  // Spin listener bookkeeping: every spin MUST detach the previous spin's
  // listeners, otherwise stale tweens keep writing _currentRotation on each
  // tick and the wheel visibly stutters/fights itself on later spins.
  int _spinSession = 0;
  Animation<double>? _windAnim;
  VoidCallback? _windListener;
  Animation<double>? _mainAnim;
  VoidCallback? _mainListener;
  int _lastTickSoundAtMs = 0;

  void _detachSpinListeners() {
    if (_windAnim != null && _windListener != null) {
      _windAnim!.removeListener(_windListener!);
    }
    if (_mainAnim != null && _mainListener != null) {
      _mainAnim!.removeListener(_mainListener!);
    }
    _windAnim = null;
    _windListener = null;
    _mainAnim = null;
    _mainListener = null;
  }

  // Manual Drag-to-Spin tracking
  Offset _lastTouchPos = Offset.zero;
  double _dragVelocity = 0.0;
  DateTime _lastTouchTime = DateTime.now();
  int _lastDragTickSector = -1;
  static String? _lastAwardedShardCategory;

  String _getCategoryDisplayName(String cat) {
    switch (cat) {
      case 'balls':
        return 'Top';
      case 'paddles':
        return 'Raket';
      case 'trails':
        return 'İz';
      case 'bricks':
        return 'Blok';
      default:
        return 'Eşya';
    }
  }

  IconData _getCategoryIcon(String cat) {
    switch (cat) {
      case 'balls':
        return Icons.sports_volleyball;
      case 'paddles':
        return Icons.view_stream;
      case 'trails':
        return Icons.grain;
      case 'bricks':
        return Icons.view_module;
      default:
        return Icons.hexagon;
    }
  }

  List<WheelReward> get _rewards => rewards;

  /// What the Octopus Vault hands out. This is the single place that
  /// decides vault contents: for now the octopus itself, guaranteed.
  /// Future vault loot joins here without touching the wheel, the
  /// pending-crate flow, or the pearl lock.
  static FishItem vaultRewardFish(SaveManager save) {
    return FishItem.getById('octopus');
  }

  /// Spin probability per sector (sums to 100), aligned with [rewards].
  /// Gold sectors keep their classic odds; the pearl & food sectors take
  /// their small share from the crate/shard/life sectors.
  static const List<double> spinWeights = [2.5, 4.0, 5.0, 9.0, 20.0, 7.5, 23.0, 25.0, 2.0, 2.0];

  static final List<WheelReward> rewards = [
    WheelReward(
      label: '500 ',
      subtitle: 'JACKPOT!',
      icon: Icons.diamond,
      primaryColor: const Color(0xFFFFD700),
      secondaryColor: const Color(0xFFFF8F00),
      onClaim: (context, save) => save.addGold(500),
    ),
    WheelReward(
      label: 'KASA',
      subtitle: 'Ahtapot Kasası',
      icon: Icons.lock_rounded,
      primaryColor: const Color(0xFFAB47BC),
      secondaryColor: const Color(0xFF6A1B9A),
      onClaim: (context, save) async {
        final crateDef = CrateDef.octopusVault;
        // Vault contents come from a single picker (see vaultRewardFish):
        // for now the octopus itself, guaranteed.
        final fish = vaultRewardFish(save);
        final rolledRarity = fish.rarity;
        final currentOwnedCount = save.getFishCount(fish.id);
        int shardYield = 0;
        bool isDuplicate = false;
        bool isShardReward = false;
        bool isFoodBonus = false;
        String subtitle;

        if (currentOwnedCount >= 2) {
          shardYield = fish.rarity == Rarity.common ? 1 : 2;
          isDuplicate = true;
          isShardReward = true;
          final newTotal = save.fishShards + shardYield;
          subtitle = 'Bu balıktan 2 adede sahipsin! +$shardYield Balık Eklentisi eklendi ($newTotal/8).';
        } else if (currentOwnedCount == 1) {
          isDuplicate = true;
          isFoodBonus = true;
          subtitle = 'Akvaryumuna 2. ${fish.name} katıldı! (+3 Yem Hediye)';
        } else {
          subtitle = I18n.tr('new_fish_unlocked');
        }

        await save.savePendingCrate(PendingCrate(
          crateType: 'aquarium',
          crateId: crateDef.id,
          category: 'fish',
          rewardType: 'fish',
          rewardId: fish.id,
          rewardTitle: fish.name,
          rewardSubtitle: subtitle,
          rarityIndex: rolledRarity.index,
          isDuplicate: isDuplicate,
          isShardReward: isShardReward,
          shardCount: shardYield > 0 ? shardYield : 1,
          isFoodBonus: isFoodBonus,
          bonusFoodCount: isFoodBonus ? 3 : 0,
        ));
      },
    ),
    WheelReward(
      label: 'PARÇA',
      subtitle: '+1 Shard',
      icon: Icons.hexagon,
      primaryColor: const Color(0xFF00E5FF),
      secondaryColor: const Color(0xFF00B0FF),
      onClaim: (context, save) {
        final categories = ['balls', 'paddles', 'trails', 'bricks'];
        final cat = categories[Random().nextInt(categories.length)];
        _lastAwardedShardCategory = cat;
        save.addShard(cat, 1);
      },
    ),
    WheelReward(
      label: '250 ',
      subtitle: 'Büyük Ödül',
      icon: Icons.monetization_on,
      primaryColor: const Color(0xFFFF9100),
      secondaryColor: const Color(0xFFFF6D00),
      onClaim: (context, save) => save.addGold(250),
    ),
    WheelReward(
      label: '150 ',
      subtitle: 'Altın',
      icon: Icons.stars,
      primaryColor: const Color(0xFFFFD54F),
      secondaryColor: const Color(0xFFFFB300),
      onClaim: (context, save) => save.addGold(150),
    ),
    WheelReward(
      label: '+1 CAN',
      subtitle: 'Can Boostu',
      icon: Icons.favorite,
      primaryColor: const Color(0xFFFF1744),
      secondaryColor: const Color(0xFFD50000),
      onClaim: (context, save) => save.addBoostStock('life', 1),
    ),
    WheelReward(
      label: '100 ',
      subtitle: 'Altın',
      icon: Icons.toll,
      primaryColor: const Color(0xFF26A69A),
      secondaryColor: const Color(0xFF00897B),
      onClaim: (context, save) => save.addGold(100),
    ),
    WheelReward(
      label: '75 ',
      subtitle: 'Altın',
      icon: Icons.monetization_on,
      primaryColor: const Color(0xFFAB47BC),
      secondaryColor: const Color(0xFF8E24AA),
      onClaim: (context, save) => save.addGold(75),
    ),
    WheelReward(
      label: '+1 İNCİ',
      subtitle: 'İnci',
      icon: Icons.circle,
      primaryColor: const Color(0xFFF48FB1),
      secondaryColor: const Color(0xFFEC407A),
      onClaim: (context, save) => save.addPearls(1),
    ),
    WheelReward(
      label: '+4 YEM',
      subtitle: 'Balık Yemi',
      icon: Icons.set_meal_rounded,
      primaryColor: const Color(0xFFAED581),
      secondaryColor: const Color(0xFF7CB342),
      onClaim: (context, save) => save.addFishFood(4),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4600),
    );
  }

  @override
  void dispose() {
    _detachSpinListeners();
    _spinController.dispose();
    super.dispose();
  }

  Future<void> _triggerWheelSpin({bool clockwise = true}) async {
    if (_isSpinning) return;
    _detachSpinListeners();
    final session = ++_spinSession;
    setState(() {
      _isSpinning = true;
      _winningIndex = null;
    });

    // Wind-back: coil the wheel against the spin direction with ratchet
    // clicks before launching it forward.
    AudioManager.instance.playSfx(GameSfx.hitBrick, playbackRate: 0.7);
    _spinController.duration = const Duration(milliseconds: 200);
    final windTween = Tween<double>(
      begin: _currentRotation,
      end: _currentRotation + (clockwise ? -0.22 : 0.22),
    ).animate(CurvedAnimation(parent: _spinController, curve: Curves.easeOut));
    _windAnim = windTween;
    _windListener = () {
      if (!mounted || session != _spinSession) return;
      setState(() {
        _currentRotation = windTween.value;
      });
    };
    windTween.addListener(_windListener!);
    await _spinController.forward(from: 0.0);
    if (_windAnim == windTween && _windListener != null) {
      windTween.removeListener(_windListener!);
      _windAnim = null;
      _windListener = null;
    }
    if (!mounted) return;
    AudioManager.instance.playSfx(GameSfx.hitBrick, playbackRate: 1.1);
    _spinController.duration = const Duration(milliseconds: 4600);

    final rand = Random();
    // Weighted selection: all 10 sectors are identically sized (36 degrees).
    // Gold odds are the classic ones; two small variety sectors (pearl,
    // fish food) joined by trimming crate/shard/life a little.
    // Indexes:
    // 0: 500g   (Jackpot) -> 2.5%
    // 1: Crate  (Gizemli) -> 4.0%
    // 2: Shard  (Parça)   -> 5.0%
    // 3: 250g   (Büyük)   -> 9.0%
    // 4: 150g   (Altın)   -> 20.0%
    // 5: +1 Can (Can)     -> 7.5%
    // 6: 100g   (Altın)   -> 23.0%
    // 7: 75g    (Altın)   -> 25.0%
    // 8: +1 İnci          -> 2.0%
    // 9: +4 Yem           -> 2.0%
    final weights = spinWeights;
    final totalWeight = weights.reduce((a, b) => a + b);
    double roll = rand.nextDouble() * totalWeight;
    int targetIndex = 0;
    for (int i = 0; i < weights.length; i++) {
      if (roll <= weights[i]) {
        targetIndex = i;
        break;
      }
      roll -= weights[i];
    }

    final sectorAngle = (2 * pi) / _rewards.length;
    // Pointer is at the TOP (-pi/2 or 3*pi/2).
    // Sector i center is at angle i * sectorAngle + sectorAngle / 2.
    // To align sector i under top pointer:
    final targetAngleOffset = (3 * pi / 2) - (targetIndex * sectorAngle + sectorAngle / 2);
    final fullRotations = (5 + rand.nextInt(3)) * 2 * pi;
    final double finalRotation;
    if (clockwise) {
      final diff = (targetAngleOffset - (_currentRotation % (2 * pi))) % (2 * pi);
      finalRotation = _currentRotation + fullRotations + (diff >= 0 ? diff : diff + 2 * pi);
    } else {
      final diff = ((_currentRotation % (2 * pi)) - targetAngleOffset) % (2 * pi);
      finalRotation = _currentRotation - fullRotations - (diff >= 0 ? diff : diff + 2 * pi);
    }

    _spinAnimation = Tween<double>(
      begin: _currentRotation,
      end: finalRotation,
    ).animate(
      CurvedAnimation(parent: _spinController, curve: Curves.easeOutCubic),
    );

    int lastTickSector = -1;
    _lastSpinValue = _currentRotation;
    _mainAnim = _spinAnimation;
    _mainListener = () {
      if (!mounted || session != _spinSession) return;
      final delta = _spinAnimation.value - _lastSpinValue;
      _lastSpinValue = _spinAnimation.value;
      setState(() {
        _currentRotation = _spinAnimation.value;
        // The pointer pin drags against the pegs: it bends with wheel
        // speed and springs back as the wheel crawls to a stop.
        final target = (delta * 3.2).clamp(-0.55, 0.55);
        _pointerBend = _pointerBend * 0.55 + target * 0.45;
      });

      // Tick when crossing sector dividers, throttled so a fast wheel does
      // not flood the audio channel (which used to hitch the animation).
      final currentSector = ((_currentRotation / sectorAngle).floor()) % _rewards.length;
      if (currentSector != lastTickSector) {
        lastTickSector = currentSector;
        final nowMs = DateTime.now().millisecondsSinceEpoch;
        if (nowMs - _lastTickSoundAtMs >= 45) {
          _lastTickSoundAtMs = nowMs;
          AudioManager.instance.playSfx(GameSfx.hitBrick);
        }
      }
    };
    _spinAnimation.addListener(_mainListener!);

    _spinController.forward(from: 0.0).then((_) async {
      if (session == _spinSession) {
        _detachSpinListeners();
      }
      final selectedReward = _rewards[targetIndex];
      if (!mounted) return;
      // Freeze-frame: flash the winning wedge before the prize burst.
      setState(() {
        _winningIndex = targetIndex;
      });
      AudioManager.instance.playSfx(GameSfx.victory);
      AudioManager.instance.playSfx(GameSfx.ulti);
      await Future.delayed(const Duration(milliseconds: 380));
      if (!mounted) return;
      setState(() {
        _isSpinning = false;
        _winningIndex = null;
      });

      // Claim reward into save
      selectedReward.onClaim(context, SaveManager.instance);

      String? customTitle;
      String? customSubtitle;
      IconData? customIcon;

      // If shard reward, display exact category name and icon
      if (targetIndex == 2) {
        final cat = _lastAwardedShardCategory ?? 'paddles';
        final catName = _getCategoryDisplayName(cat);
        final currentShards = SaveManager.instance.getShards(cat);
        customTitle = '$catName Parçası';
        customSubtitle = '+1 $catName Parçası Eklendi! (Toplam: $currentShards/3)';
        customIcon = _getCategoryIcon(cat);
      }

      _showPrizeDialog(
        selectedReward,
        customLabel: customTitle,
        customSubtitle: customSubtitle,
        customIcon: customIcon,
      );
    });
  }

  Future<void> _executeFreeSpin({bool clockwise = true}) async {
    if (_isSpinning) return;
    final ok = await SaveManager.instance.recordWheelSpin();
    if (ok && mounted) {
      _triggerWheelSpin(clockwise: clockwise);
    }
  }

  void _onManualFlingSpin({bool clockwise = true}) {
    final save = SaveManager.instance;
    if (!save.canSpinFortuneWheel) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Bugünkü çark haklarını kullandın! Yarın yeni haklar gelecek.'),
          backgroundColor: const Color(0xFF1E2438),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      );
      return;
    }

    if (save.isNextWheelSpinFree) {
      _executeFreeSpin(clockwise: clockwise);
      return;
    }

    AdManager.instance.watchSkippableAd(
      context,
      onSuccess: () async {
        if (!mounted) return;
        final ok = await SaveManager.instance.recordWheelSpin();
        if (ok && mounted) {
          _triggerWheelSpin(clockwise: clockwise);
        }
      },
      onDismissedEarly: () {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.info_outline, color: Color(0xFFFFD54F), size: 22),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Şans çarkını çevirmek için reklamı tamamlamalısınız.',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF1E2438),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        );
      },
    );
  }

  void _onWatchAdAndSpin() {
    final save = SaveManager.instance;
    if (!save.canSpinFortuneWheel) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Bugünkü çark haklarını kullandın! Yarın yeni haklar gelecek.'),
          backgroundColor: const Color(0xFF1E2438),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      );
      return;
    }

    if (save.isNextWheelSpinFree) {
      _executeFreeSpin();
      return;
    }

    AdManager.instance.watchSkippableAd(
      context,
      onSuccess: () async {
        if (!mounted) return;
        final ok = await SaveManager.instance.recordWheelSpin();
        if (ok && mounted) {
          _triggerWheelSpin();
        }
      },
      onDismissedEarly: () {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.info_outline, color: Color(0xFFFFD54F), size: 22),
                SizedBox(width: 10),
                Expanded(
                  child: Text( 'Şans çarkını çevirmek için reklamı tamamlamalısınız.',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF1E2438),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        );
      },
    );
  }

  void _showPrizeDialog(
    WheelReward reward, {
    String? customLabel,
    String? customSubtitle,
    IconData? customIcon,
  }) {
    final displayLabel = customLabel ?? reward.label;
    final displaySubtitle = customSubtitle ?? reward.subtitle;
    final displayIcon = customIcon ?? reward.icon;
    final isChest = reward.label == 'KASA';

    // The big catches get a full spectacle; small ones stay casual.
    final spectacle = isChest ||
        reward.label == '500 ' ||
        reward.label == '250 ' ||
        reward.label == '+1 İNCİ';

    // Same chest visual the opening screen uses (rolled rarity tier).
    Rarity? chestTier;
    Color? chestPrimary;
    Color? chestSecondary;
    if (isChest) {
      final pending = SaveManager.instance.pendingCrate;
      final idx = (pending?.rarityIndex ?? 0).clamp(0, Rarity.values.length - 1);
      chestTier = Rarity.values[idx];
      switch (chestTier) {
        case Rarity.common:
          chestPrimary = const Color(0xFF8D6E63);
          chestSecondary = const Color(0xFF5D4037);
        case Rarity.rare:
          chestPrimary = const Color(0xFF00E5FF);
          chestSecondary = const Color(0xFF006064);
        case Rarity.epic:
          chestPrimary = const Color(0xFFE040FB);
          chestSecondary = const Color(0xFF4A148C);
        case Rarity.legendary:
          chestPrimary = const Color(0xFFFFD54F);
          chestSecondary = const Color(0xFFE65100);
      }
    }

    showDialog(
      context: context,
      builder: (ctx) => _PrizeRevealDialog(
        reward: reward,
        displayLabel: displayLabel,
        displaySubtitle: displaySubtitle,
        displayIcon: displayIcon,
        isChest: isChest,
        spectacle: spectacle,
        chestTier: chestTier,
        chestPrimary: chestPrimary,
        chestSecondary: chestSecondary,
        onDone: () {
          Navigator.of(ctx).pop();
          if (isChest) {
            Navigator.of(context).pop();
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final adManager = AdManager.instance;
    final save = SaveManager.instance;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ListenableBuilder(
        listenable: Listenable.merge([adManager, save]),
        builder: (context, _) {
          final spinsLeft = save.remainingWheelSpins;
          final canSpin = save.canSpinFortuneWheel;
          final isLoading = adManager.isShowing || _isSpinning;

          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFA0F1322),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: const Color(0xFFFFD54F), width: 2),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFB300).withValues(alpha: 0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SizedBox(width: 32),
                    Flexible(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.stars, color: Color(0xFFFFD54F), size: 22),
                          SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'ŞANS ÇARKI',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Color(0xFFFFD54F),
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    KaunosPressGlow(
                      isCircle: true,
                      waveColor: const Color(0xFF00E5FF),
                      child: IconButton(
                        onPressed: _isSpinning ? null : () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close, color: Colors.white70),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),

                // Daily Spins Badge Chip
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: canSpin
                        ? (save.isNextWheelSpinFree ? const Color(0x2E00E676) : const Color(0x2E00E5FF))
                        : const Color(0x33FF5252),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: canSpin
                          ? (save.isNextWheelSpinFree ? const Color(0xFF00E676) : const Color(0xFF00E5FF))
                          : const Color(0xFFFF5252),
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        canSpin
                            ? (save.isNextWheelSpinFree ? Icons.card_giftcard_rounded : Icons.local_activity_rounded)
                            : Icons.lock_clock,
                        color: canSpin
                            ? (save.isNextWheelSpinFree ? const Color(0xFF69F0AE) : const Color(0xFF00E5FF))
                            : const Color(0xFFFF5252),
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          canSpin
                              ? (save.isNextWheelSpinFree
                                  ? 'Günün 1. Çevirmesi ÜCRETSİZ! (Kalan: $spinsLeft/${SaveManager.maxDailyWheelSpins})'
                                  : 'Bugün Kalan Hak: $spinsLeft / ${SaveManager.maxDailyWheelSpins}')
                              : 'Günlük Hak Bitti (0/${SaveManager.maxDailyWheelSpins})',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: canSpin
                                ? (save.isNextWheelSpinFree ? const Color(0xFF69F0AE) : const Color(0xFF00E5FF))
                                : const Color(0xFFFF8A80),
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Interactive Animated Wheel with top pointer & Drag-to-spin gesture
                GestureDetector(
                  onPanStart: (details) {
                    if (_isSpinning) return;
                    _lastTouchPos = details.localPosition;
                    _dragVelocity = 0.0;
                    _lastTouchTime = DateTime.now();
                  },
                  onPanUpdate: (details) {
                    if (_isSpinning) return;
                    final currentPos = details.localPosition;
                    const center = Offset(135, 135);

                    // Calculate angular delta around wheel center
                    final prevOffset = _lastTouchPos - center;
                    final curOffset = currentPos - center;
                    final prevAngle = atan2(prevOffset.dy, prevOffset.dx);
                    final curAngle = atan2(curOffset.dy, curOffset.dx);
                    var delta = curAngle - prevAngle;
                    while (delta > pi) {
                      delta -= 2 * pi;
                    }
                    while (delta < -pi) {
                      delta += 2 * pi;
                    }

                    // If dragging vertically near edges (e.g. downward swipe), map vertical delta smoothly
                    final dy = currentPos.dy - _lastTouchPos.dy;
                    if (delta.abs() < 0.02 && dy.abs() > 2.0) {
                      // Left side dragged down rotates counter-clockwise; right side dragged down rotates clockwise
                      final sign = (currentPos.dx >= center.dx) ? 1.0 : -1.0;
                      delta = (dy / 135.0) * sign;
                    }

                    final now = DateTime.now();
                    final dtMs = now.difference(_lastTouchTime).inMilliseconds;
                    if (dtMs > 0) {
                      _dragVelocity = delta / (dtMs / 1000.0);
                    }
                    _lastTouchTime = now;
                    _lastTouchPos = currentPos;

                    setState(() {
                      _currentRotation += delta;
                    });

                    // Audio feedback on manual drag
                    final sectorAngle = (2 * pi) / _rewards.length;
                    final currentSector = ((_currentRotation / sectorAngle).floor()) % _rewards.length;
                    if (currentSector != _lastDragTickSector) {
                      _lastDragTickSector = currentSector;
                      AudioManager.instance.playSfx(GameSfx.hitBrick);
                    }
                  },
                  onPanEnd: (details) {
                    if (_isSpinning) return;
                    final speed = _dragVelocity.abs();
                    final pixelsVelocity = details.velocity.pixelsPerSecond.distance;
                    // Trigger spin if user swiped with reasonable velocity or moved wheel noticeably
                    if (speed > 1.2 || pixelsVelocity > 250) {
                      final cw = _dragVelocity >= 0;
                      _onManualFlingSpin(clockwise: cw);
                    }
                  },
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(end: _winningIndex != null ? 1.05 : 1.0),
                    duration: const Duration(milliseconds: 240),
                    curve: Curves.easeOutBack,
                    builder: (context, scale, child) {
                      return Transform.scale(scale: scale, child: child);
                    },
                    child: SizedBox(
                    width: 270,
                    height: 270,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Outer Glow & Wheel Painter
                        Transform.rotate(
                          angle: _currentRotation,
                          child: CustomPaint(
                            size: const Size(270, 270),
                            painter: _WheelPainter(rewards: _rewards, highlightIndex: _winningIndex),
                          ),
                        ),

                        // Center Pin Hub
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const RadialGradient(
                              colors: [Color(0xFFFFF9C4), Color(0xFFFFD54F), Color(0xFFFF8F00)],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.6),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(Icons.touch_app_rounded, color: Color(0xFF3E2723), size: 24),
                          ),
                        ),

                        // Top Indicator Arrow (bends against the pegs)
                        Positioned(
                          top: 0,
                          child: Transform.rotate(
                            angle: _pointerBend,
                            alignment: Alignment.topCenter,
                            child: CustomPaint(
                              size: const Size(26, 26),
                              painter: _PointerArrowPainter(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // Action Button: Spin or Watch Ad & Spin
                Container(
                  decoration: BoxDecoration(
                    gradient: (!canSpin)
                        ? null
                        : (isLoading
                            ? null
                            : (save.isNextWheelSpinFree
                                ? const LinearGradient(
                                    colors: [Color(0xFF69F0AE), Color(0xFF00E676), Color(0xFF00B0FF)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  )
                                : const LinearGradient(
                                    colors: [Color(0xFFFFF176), Color(0xFFFFB300), Color(0xFFFF8F00)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ))),
                    color: (!canSpin)
                        ? const Color(0xFF1E2436)
                        : (isLoading ? const Color(0x33FFB300) : null),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: (!canSpin)
                          ? Colors.white24
                          : (isLoading
                              ? Colors.white12
                              : (save.isNextWheelSpinFree ? const Color(0xFFB9F6CA) : const Color(0xFFFFFDE7))),
                      width: 1.8,
                    ),
                    boxShadow: (!canSpin || isLoading)
                        ? null
                        : [
                            BoxShadow(
                              color: save.isNextWheelSpinFree
                                  ? const Color(0xFF00E676).withValues(alpha: 0.5)
                                  : const Color(0xFFFF8F00).withValues(alpha: 0.5),
                              blurRadius: 18,
                              offset: const Offset(0, 4),
                            ),
                          ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(22),
                      onTap: isLoading ? null : _onWatchAdAndSpin,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (isLoading) ...[
                              const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                _isSpinning ? 'Çark Dönüyor...' : 'Reklam Hazırlanıyor...',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                ),
                              ),
                            ] else if (!canSpin) ...[
                              const Icon(Icons.timer_outlined, color: Colors.white54, size: 20),
                              const SizedBox(width: 10),
                              Flexible(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: const [
                                    Text(
                                      'GÜNLÜK HAK BİTTİ (0 / ${SaveManager.maxDailyWheelSpins})',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 13,
                                        letterSpacing: 0.4,
                                      ),
                                    ),
                                    Text(
                                      'Yarın yeni ${SaveManager.maxDailyWheelSpins} çevirme hakkı eklenecek!',
                                      style: TextStyle(
                                        color: Colors.white38,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ] else if (save.isNextWheelSpinFree) ...[
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF003816),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF00E676).withValues(alpha: 0.6),
                                      blurRadius: 6,
                                    ),
                                  ],
                                ),
                                child: const Icon(Icons.card_giftcard_rounded, color: Color(0xFF69F0AE), size: 18),
                              ),
                              const SizedBox(width: 10),
                              Flexible(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: const [
                                    Text(
                                      ' ÜCRETSİZ ÇEVİR! (1 / ${SaveManager.maxDailyWheelSpins})',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Color(0xFF003816),
                                        fontWeight: FontWeight.w900,
                                        fontSize: 13,
                                        letterSpacing: 0.4,
                                      ),
                                    ),
                                    Text(
                                      ' Günün İlk Çevirmesi Bedava! (Reklamsız)',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Color(0xFF004D20),
                                        fontWeight: FontWeight.w700,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ] else ...[
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2E1C00),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFFFD54F).withValues(alpha: 0.6),
                                      blurRadius: 6,
                                    ),
                                  ],
                                ),
                                child: const Icon(Icons.ondemand_video_rounded, color: Color(0xFFFFD54F), size: 18),
                              ),
                              const SizedBox(width: 10),
                              Flexible(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      ' REKLAM İZLE & ÇEVİR! (${save.fortuneWheelSpinsToday + 1} / ${SaveManager.maxDailyWheelSpins})',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Color(0xFF2E1C00),
                                        fontWeight: FontWeight.w900,
                                        fontSize: 13,
                                        letterSpacing: 0.4,
                                      ),
                                    ),
                                    const Text(
                                      ' Geçilebilir Kısa Reklam İzle & Çevir',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Color(0xFF4E342E),
                                        fontWeight: FontWeight.w700,
                                        fontSize: 10,
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
}

/// Animated prize reveal: rotating light rays + pulsing prize. Big wins
/// (jackpot, 250g, pearl, Octopus Vault) get the full spectacle; the
/// chest is drawn with the very same ChestWidget the opening screen
/// uses, so what you win is exactly what you later open.
class _PrizeRevealDialog extends StatefulWidget {
  final WheelReward reward;
  final String displayLabel;
  final String displaySubtitle;
  final IconData displayIcon;
  final bool isChest;
  final bool spectacle;
  final Rarity? chestTier;
  final Color? chestPrimary;
  final Color? chestSecondary;
  final VoidCallback onDone;

  const _PrizeRevealDialog({
    required this.reward,
    required this.displayLabel,
    required this.displaySubtitle,
    required this.displayIcon,
    required this.isChest,
    required this.spectacle,
    required this.chestTier,
    required this.chestPrimary,
    required this.chestSecondary,
    required this.onDone,
  });

  @override
  State<_PrizeRevealDialog> createState() => _PrizeRevealDialogState();
}

class _PrizeRevealDialogState extends State<_PrizeRevealDialog> with SingleTickerProviderStateMixin {
  late final AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(seconds: 16))..repeat();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.reward.primaryColor;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
        decoration: BoxDecoration(
          color: const Color(0xF5101320),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: color, width: 2.2),
          boxShadow: [
            BoxShadow(color: color.withValues(alpha: 0.45), blurRadius: 26, offset: const Offset(0, 8)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 170,
              height: 150,
              child: AnimatedBuilder(
                animation: _anim,
                builder: (context, _) {
                  final pulse = 1.0 + (widget.spectacle ? 0.05 * sin(_anim.value * 2 * pi * 3) : 0.0);
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      if (widget.spectacle)
                        Transform.rotate(
                          angle: _anim.value * 2 * pi,
                          child: CustomPaint(
                            size: const Size(170, 150),
                            painter: _RaysPainter(color: color),
                          ),
                        ),
                      Transform.scale(
                        scale: pulse,
                        child: widget.isChest
                            ? ChestWidget(
                                size: 118,
                                tier: widget.chestTier,
                                primaryColor: widget.chestPrimary ?? color,
                                secondaryColor: widget.chestSecondary ?? const Color(0xFF4A148C),
                                time: _anim.value * 2 * pi,
                              )
                            : Container(
                                width: 92,
                                height: 92,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(
                                    colors: [color.withValues(alpha: 0.95), color.withValues(alpha: 0.45)],
                                  ),
                                  border: Border.all(color: Colors.white70, width: 1.6),
                                  boxShadow: [
                                    BoxShadow(color: color.withValues(alpha: 0.65), blurRadius: 18),
                                  ],
                                ),
                                child: Icon(widget.displayIcon, color: Colors.white, size: 46),
                              ),
                      ),
                    ],
                  );
                },
              ),
            ),
            Text(
              widget.spectacle ? '💥 BÜYÜK ÖDÜL!' : 'TEBRİKLER!',
              style: TextStyle(
                color: widget.spectacle ? const Color(0xFFFFD54F) : Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: widget.spectacle ? 23 : 19,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.displayLabel,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w900,
                fontSize: widget.displayLabel.length > 10 ? 21 : 26,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              widget.displaySubtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.3),
            ),
            const SizedBox(height: 12),
            Text(
              widget.isChest
                  ? 'Ahtapot Kasası arkaya bırakıldı! Açmak için ${CrateDef.octopusVaultPearlCost} inci gerekir.'
                  : 'Ödül hesabınıza aktarıldı!',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 14),
            ElevatedButton(
              onPressed: widget.onDone,
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
              ),
              child: Text(
                widget.isChest ? 'KASAYI AÇ!' : 'HARİKA!',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RaysPainter extends CustomPainter {
  final Color color;
  const _RaysPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.52;
    final paint = Paint()..style = PaintingStyle.fill;
    const wedges = 12;
    for (var i = 0; i < wedges; i += 2) {
      final start = (i / wedges) * 2 * pi;
      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..arcTo(Rect.fromCircle(center: center, radius: radius), start, (2 * pi / wedges) * 0.9, false)
        ..close();
      paint.color = color.withValues(alpha: 0.13);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RaysPainter oldDelegate) => oldDelegate.color != color;
}

class _WheelPainter extends CustomPainter {
  final List<WheelReward> rewards;
  final int? highlightIndex;
  static final Map<String, TextPainter> _textPainters = {};
  static final Map<int, Shader> _sectorShaders = {};

  _WheelPainter({required this.rewards, this.highlightIndex});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;
    final sectorAngle = (2 * pi) / rewards.length;

    // Outer Rim
    final rimPaint = Paint()
      ..color = const Color(0xFFFFD54F)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7;
    canvas.drawCircle(center, radius + 4, rimPaint);

    final sectorPaint = Paint()..style = PaintingStyle.fill;
    final dividerPaint = Paint()
      ..color = const Color(0x80FFFFFF)
      ..strokeWidth = 2;

    final circleRect = Rect.fromCircle(center: center, radius: radius);

    for (int i = 0; i < rewards.length; i++) {
      final reward = rewards[i];
      final startAngle = i * sectorAngle;

      // Draw Sector with cached shader
      final shaderKey = Object.hash(reward.primaryColor.toARGB32(), reward.secondaryColor.toARGB32(), radius.round());
      sectorPaint.shader = _sectorShaders.putIfAbsent(shaderKey, () {
        return LinearGradient(
          colors: [reward.primaryColor, reward.secondaryColor],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(circleRect);
      });

      canvas.drawArc(
        circleRect,
        startAngle,
        sectorAngle,
        true,
        sectorPaint,
      );

      if (highlightIndex == i) {
        final flashPaint = Paint()
          ..style = PaintingStyle.fill
          ..color = const Color(0xAAFFFFFF);
        canvas.drawArc(circleRect, startAngle, sectorAngle, true, flashPaint);
        final flashStroke = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.5
          ..color = const Color(0xFFFFD600);
        canvas.drawArc(circleRect, startAngle, sectorAngle, true, flashStroke);
      }

      // Draw Divider
      final divX = center.dx + cos(startAngle) * radius;
      final divY = center.dy + sin(startAngle) * radius;
      canvas.drawLine(center, Offset(divX, divY), dividerPaint);

      // Draw Sector Label & Icon with cached TextPainter
      final midAngle = startAngle + sectorAngle / 2;
      final textRadius = radius * 0.68;
      final tx = center.dx + cos(midAngle) * textRadius;
      final ty = center.dy + sin(midAngle) * textRadius;

      canvas.save();
      canvas.translate(tx, ty);
      canvas.rotate(midAngle + pi / 2);

      final tp = _textPainters.putIfAbsent(reward.label, () {
        final textSpan = TextSpan(
          text: reward.label,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: rewards.length > 8 ? 10.5 : 12,
            shadows: const [Shadow(color: Colors.black87, blurRadius: 4, offset: Offset(0, 1))],
          ),
        );
        return TextPainter(
          text: textSpan,
          textDirection: TextDirection.ltr,
        )..layout();
      });

      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _PointerArrowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFFF1744)
      ..style = PaintingStyle.fill;

    final shadowPaint = Paint()
      ..color = const Color(0xFFB71C1C)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();

    canvas.drawPath(path, paint);
    canvas.drawPath(path, shadowPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
