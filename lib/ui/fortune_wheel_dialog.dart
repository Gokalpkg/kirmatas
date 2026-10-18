import 'dart:math';
import 'package:flutter/material.dart';
import '../engine/ad_manager.dart';
import '../engine/audio_manager.dart';
import '../engine/i18n.dart';
import '../models/cosmetics.dart';
import '../storage/save_manager.dart';

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

  @override
  State<FortuneWheelDialog> createState() => _FortuneWheelDialogState();
}

class _FortuneWheelDialogState extends State<FortuneWheelDialog> with SingleTickerProviderStateMixin {
  late final AnimationController _spinController;
  late Animation<double> _spinAnimation;

  double _currentRotation = 0.0;
  bool _isSpinning = false;

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
      label: 'SANDIK',
      subtitle: 'Gizemli Ödül',
      icon: Icons.inventory_2,
      primaryColor: const Color(0xFFE040FB),
      secondaryColor: const Color(0xFF7C4DFF),
      onClaim: (context, save) async {
        final crateDef = CrateDef.allCrates.first;
        final rand = Random();
        final luckLevel = save.upgrades['luck'] ?? 0;
        final weights = Map<Rarity, double>.from(crateDef.weights);
        weights[Rarity.legendary] = (weights[Rarity.legendary] ?? 1.0) * (1.0 + luckLevel * 0.35);
        weights[Rarity.epic] = (weights[Rarity.epic] ?? 5.0) * (1.0 + luckLevel * 0.25);
        double totalWeight = weights.values.fold(0.0, (a, b) => a + b);
        double roll = rand.nextDouble() * totalWeight;
        Rarity rolledRarity = Rarity.common;
        for (final entry in weights.entries) {
          if (roll <= entry.value) {
            rolledRarity = entry.key;
            break;
          }
          roll -= entry.value;
        }
        final available = FishItem.allFish.where((f) => f.rarity == rolledRarity).toList();
        final unownedInRarity = available.where((f) => save.getFishCount(f.id) == 0).toList();
        final allUnowned = FishItem.allFish.where((f) => save.getFishCount(f.id) == 0).toList();
        FishItem fish;
        if (unownedInRarity.isNotEmpty) {
          fish = unownedInRarity[rand.nextInt(unownedInRarity.length)];
        } else if (allUnowned.isNotEmpty && rand.nextDouble() < 0.75) {
          fish = allUnowned[rand.nextInt(allUnowned.length)];
          rolledRarity = fish.rarity;
        } else {
          fish = available.isNotEmpty ? available[rand.nextInt(available.length)] : FishItem.allFish.first;
        }
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
    _spinController.dispose();
    super.dispose();
  }

  void _triggerWheelSpin({bool clockwise = true}) {
    if (_isSpinning) return;
    setState(() {
      _isSpinning = true;
    });

    final rand = Random();
    // Weighted selection: visually all 8 sectors are identically sized (45 degrees),
    // but lower/mid rewards have a noticeably higher probability (75, 100, 150 gold total ~68%)
    // while high-tier prizes remain rare and exciting.
    // Indexes:
    // 0: 500g   (Jackpot) -> 2.5%
    // 1: Crate  (Gizemli) -> 4.5%
    // 2: Shard  (Parça)   -> 6.0%
    // 3: 250g   (Büyük)   -> 9.0%
    // 4: 150g   (Altın)   -> 20.0%
    // 5: +1 Can (Can)     -> 10.0%
    // 6: 100g   (Altın)   -> 23.0%
    // 7: 75g    (Altın)   -> 25.0%
    final weights = [2.5, 4.5, 6.0, 9.0, 20.0, 10.0, 23.0, 25.0];
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
    _spinAnimation.addListener(() {
      setState(() {
        _currentRotation = _spinAnimation.value;
      });

      // Sound effect ticks when crossing sector dividers
      final currentSector = ((_currentRotation / sectorAngle).floor()) % _rewards.length;
      if (currentSector != lastTickSector) {
        lastTickSector = currentSector;
        AudioManager.instance.playSfx(GameSfx.hitBrick);
      }
    });

    _spinController.forward(from: 0.0).then((_) {
      final selectedReward = _rewards[targetIndex];
      setState(() {
        _isSpinning = false;
      });

      AudioManager.instance.playSfx(GameSfx.ulti);

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

  void _onManualFlingSpin({bool clockwise = true}) {
    final save = SaveManager.instance;
    if (!save.canSpinFortuneWheel) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Bugünkü 3 çark hakkını kullandın! Yarın yeni haklar gelecek.'),
          backgroundColor: const Color(0xFF1E2438),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      );
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
          content: const Text('Bugünkü 3 çark hakkını kullandın! Yarın yeni haklar gelecek.'),
          backgroundColor: const Color(0xFF1E2438),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      );
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
    final isChest = reward.label == 'SANDIK';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xF0101320),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: reward.primaryColor, width: 2),
        ),
        title: Column(
          children: [
            Icon(displayIcon, color: reward.primaryColor, size: 54),
            const SizedBox(height: 12),
            const Text(
              'TEBRİKLER!',
              style: TextStyle(color: Color(0xFFFFD54F), fontWeight: FontWeight.w900, fontSize: 20),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              displayLabel,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: reward.primaryColor,
                fontWeight: FontWeight.w900,
                fontSize: displayLabel.length > 10 ? 21 : 25,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              displaySubtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.3),
            ),
            const SizedBox(height: 14),
            Text(
              isChest ? 'Sandığın arkaya bırakıldı! Çıkışta hemen açabilirsin.' : 'Ödül hesabınıza aktarıldı!',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
        actions: [
          Center(
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                if (isChest) {
                  Navigator.of(context).pop();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: reward.primaryColor,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
              ),
              child: Text(isChest ? 'SANDIĞI AÇ!' : 'HARİKA!', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
            ),
          ),
        ],
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
                    IconButton(
                      onPressed: _isSpinning ? null : () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, color: Colors.white70),
                    ),
                  ],
                ),
                const SizedBox(height: 4),

                // Daily Spins Badge Chip
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: canSpin ? const Color(0x2E00E5FF) : const Color(0x33FF5252),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: canSpin ? const Color(0xFF00E5FF) : const Color(0xFFFF5252),
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        canSpin ? Icons.local_activity_rounded : Icons.lock_clock,
                        color: canSpin ? const Color(0xFF00E5FF) : const Color(0xFFFF5252),
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          canSpin
                              ? 'Bugün Kalan Hak: $spinsLeft / 3'
                              : 'Günlük Hak Bitti (0/3)',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: canSpin ? const Color(0xFF00E5FF) : const Color(0xFFFF8A80),
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
                    const sectorAngle = (2 * pi) / 8;
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
                            painter: _WheelPainter(rewards: _rewards),
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

                        // Top Indicator Arrow
                        Positioned(
                          top: 0,
                          child: CustomPaint(
                            size: const Size(26, 26),
                            painter: _PointerArrowPainter(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // Action Button: Watch Skippable Ad & Spin
                Container(
                  decoration: BoxDecoration(
                    gradient: (!canSpin)
                        ? null
                        : (isLoading
                            ? null
                            : const LinearGradient(
                                colors: [Color(0xFFFFF176), Color(0xFFFFB300), Color(0xFFFF8F00)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )),
                    color: (!canSpin)
                        ? const Color(0xFF1E2436)
                        : (isLoading ? const Color(0x33FFB300) : null),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: (!canSpin)
                          ? Colors.white24
                          : (isLoading ? Colors.white12 : const Color(0xFFFFFDE7)),
                      width: 1.8,
                    ),
                    boxShadow: (!canSpin || isLoading)
                        ? null
                        : [
                            BoxShadow(
                              color: const Color(0xFFFF8F00).withValues(alpha: 0.5),
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
                                children: [
                                  Text( 'GÜNLÜK HAK BİTTİ (0 / 3)',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 13,
                                      letterSpacing: 0.4,
                                    ),
                                  ),
                                  Text( 'Yarın yeni 3 çevirme hakkı eklenecek!',
                                    style: TextStyle(
                                      color: Colors.white38,
                                      fontWeight: FontWeight.w600,
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
                                child: const Icon(Icons.fast_forward_rounded, color: Color(0xFFFFD54F), size: 18),
                              ),
                              const SizedBox(width: 10),
                              Flexible(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text( ' ŞANSINI DENE & ÇEVİR! ($spinsLeft / 3)',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Color(0xFF2E1C00),
                                      fontWeight: FontWeight.w900,
                                      fontSize: 13,
                                      letterSpacing: 0.4,
                                    ),
                                  ),
                                  const Text( ' Geçilebilir Kısa Reklam İzle & Çevir',
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

class _WheelPainter extends CustomPainter {
  final List<WheelReward> rewards;
  static final Map<String, TextPainter> _textPainters = {};
  static final Map<int, Shader> _sectorShaders = {};

  _WheelPainter({required this.rewards});

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
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 12,
            shadows: [Shadow(color: Colors.black87, blurRadius: 4, offset: Offset(0, 1))],
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
