import 'dart:math';
import '../models/black_hole.dart';
import '../models/portal.dart';
import 'package:flutter/material.dart';
import '../models/ball.dart';
import '../models/brick.dart';
import '../models/cosmetics.dart';
import '../models/easter_egg.dart';
import '../models/game_state.dart';
import '../models/level_design.dart';
import '../models/paddle.dart';
import '../models/powerup.dart';
import '../storage/save_manager.dart';
import 'audio_manager.dart';
import 'ad_manager.dart';
import 'i18n.dart';
import 'particle_system.dart';

class TickNotifier extends ChangeNotifier { void ping() => notifyListeners(); }

class GameController extends ChangeNotifier {
  static final Set<int> portalLevels = () {
    final rand = Random(2026);
    final all = List.generate(238, (i) => i + 1);
    all.shuffle(rand);
    return all.take(83).toSet();
  }();
  final TickNotifier frameTick = TickNotifier();
  final List<BlackHole> blackHoles = [];
  final List<Portal> portals = [];
  final SaveManager save = SaveManager.instance;
  final AudioManager audio = AudioManager.instance;
  final ParticleSystem particles = ParticleSystem();
  final Random _rand = Random();

  GameMode currentMode = GameMode.classic;
  GameStatus status = GameStatus.ready;
  final MatchStats stats = MatchStats();

  double screenWidth = 360.0;
  double screenHeight = 640.0;
  int chaosStock = 3;
  int chaosPendingExtraBalls = 0;
  int chaosToLaunch = 0;
  int chaosReturned = 0;
  double chaosShotTimer = 0;
  double chaosTurnTime = 0;
  double chaosShotVx = 0;
  double chaosShotVy = 0;
  double chaosHomeX = 180;
  double chaosLaunchX = 180;
  bool chaosHomeLocked = false;
  bool chaosAiming = false;
  double chaosAimX = 180;
  double chaosAimY = 240;
  double chaosSpeedMultiplier = 1.0;
  bool chaosRecallActive = false;

  double get chaosFloorY => screenHeight - 86;

  late Paddle paddle;
  final List<Ball> balls = [];
  List<Brick> bricks = [];
  final List<FallingCapsule> capsules = [];
  final List<Projectile> projectiles = [];
  final List<ActivePowerUp> activePowerUps = [];

  EasterEggBee? activeBee;
  WindshieldSplat? activeSplat;
  double beeSpawnCooldown = 35.0;

  double descendTimer = 0.0;
  double droneShootTimer = 0.0;
  double? laserTimer;
  double? rocketTimer;
  double? _blackHoleTimer;
  double comboTimer = 0.0;
  double gameTime = 0.0;
  double bossWarningTimer = 0.0;
  double levelTransitionTimer = 0.0;
  bool _hasLoadedBricks = false;
  List<Brick>? _loadedBricksRef;

  bool isDiceRolling = false;
  double diceRollTimer = 0.0;
  bool isDoubleDice = false;
  int dice1Value = 1;
  int dice2Value = 1;
  int diceDisplay1 = 1;
  int diceDisplay2 = 1;
  int _glassBreaksTowardDice = 0;
  int _blocksUntilDicePoint = 3;
  int diceSalvoRemaining = 0;
  double diceSalvoCooldown = 0.0;
  double diceDisplayTimer = 0.0;
  double _diceShuffleTimer = 0.0;

  bool get isDiceActive => isDiceRolling || diceDisplayTimer > 0;
  int get diceTotal => isDoubleDice ? (diceDisplay1 + diceDisplay2) : diceDisplay1;

  String? _sessionBall;
  String? _sessionPaddle;
  String? _sessionTrail;
  String? _sessionBrickStyle;
  String? _sessionBackground;

  String _pickRandomBall() {
    final list = save.unlockedBalls.where((id) => id != 'random').toList();
    if (list.isEmpty) return 'classic';
    return list[_rand.nextInt(list.length)];
  }

  String _pickRandomPaddle() {
    final list = save.unlockedPaddles.where((id) => id != 'random').toList();
    if (list.isEmpty) return 'pclassic';
    return list[_rand.nextInt(list.length)];
  }

  String _pickRandomTrail() {
    final list = save.unlockedTrails.where((id) => id != 'random').toList();
    if (list.isEmpty) return 't1';
    return list[_rand.nextInt(list.length)];
  }

  String _pickRandomBrickStyle() {
    final list = save.unlockedBrickStyles.where((id) => id != 'random').toList();
    if (list.isEmpty) return 'brick_gloss';
    return list[_rand.nextInt(list.length)];
  }

  String _pickRandomBackground() {
    final list = save.unlockedBackgrounds.where((id) => id != 'random').toList();
    if (list.isEmpty) return 'bg_default';
    return list[_rand.nextInt(list.length)];
  }

  /// Rolls random cosmetics from owned collections for the current game session.
  /// Remains locked until the game ends or restarts.
  void rollSessionCosmetics() {
    _sessionBall = (save.activeBall == 'random') ? _pickRandomBall() : save.activeBall;
    _sessionPaddle = (save.activePaddle == 'random') ? _pickRandomPaddle() : save.activePaddle;
    _sessionTrail = (save.activeTrail == 'random') ? _pickRandomTrail() : save.activeTrail;
    _sessionBrickStyle = (save.activeBrickStyle == 'random') ? _pickRandomBrickStyle() : save.activeBrickStyle;
    _sessionBackground = (save.activeBackground == 'random') ? _pickRandomBackground() : save.activeBackground;
  }

  String get activeBallId => _sessionBall ?? (save.activeBall == 'random' ? _pickRandomBall() : save.activeBall);
  String get activePaddleId => _sessionPaddle ?? (save.activePaddle == 'random' ? _pickRandomPaddle() : save.activePaddle);
  String get activeTrailId => _sessionTrail ?? (save.activeTrail == 'random' ? _pickRandomTrail() : save.activeTrail);
  String get activeBrickStyle => _sessionBrickStyle ?? (save.activeBrickStyle == 'random' ? _pickRandomBrickStyle() : save.activeBrickStyle);
  String get activeBackground => _sessionBackground ?? (save.activeBackground == 'random' ? _pickRandomBackground() : save.activeBackground);

  BallSkin get activeBallSkin => BallSkin.getById(activeBallId);
  PaddleSkin get activePaddleSkin => PaddleSkin.getById(activePaddleId);
  TrailSkin get activeTrailSkin => TrailSkin.getById(activeTrailId);

  GameController() {
    paddle = Paddle(x: 140, y: 560);
    rollSessionCosmetics();
  }

  void setDimensions(double width, double height) {
    if ((screenWidth - width).abs() < 1 && (screenHeight - height).abs() < 1) return;
    screenWidth = width;
    screenHeight = height;
    paddle.y = screenHeight - 110.0;
    if (status == GameStatus.ready) {
      resetPaddleAndBall();
      loadLevelBricks();
    }
  }

  bool hasUsedRevive = false;
  bool pendingLevelInterstitial = false;
  bool hasClaimedVictoryBonus = false;
  int endGameRolledDice = 0;
  int endGameMultiplier = 0;
  int endGameBonusGoldAdded = 0;
  int _sessionStartingBestScore = 0;
  bool _hasCelebratedNewRecord = false;
  bool _bossEnrageAnnounced = false;
  bool _chaosAllSolidBroken = false;
  int activeIceVariant = 0;
  double endgameStallTimer = 0.0;
  String? activeTipText;
  double tipTimer = 0.0;

  void showMicroTip(String tipId, String text) {
    if (stats.level <= 10 && !save.hasSeenTip(tipId)) {
      save.markTipSeen(tipId);
      activeTipText = text;
      tipTimer = 3.5;
      notifyListeners();
    }
  }

  void showOnceTip(String tipId, String text) {
    if (save.hasSeenTip(tipId)) return;
    save.markTipSeen(tipId);
    activeTipText = text;
    tipTimer = 3.8;
    notifyListeners();
  }

  bool get _blackHolesAllowed => currentMode != GameMode.classic || stats.level >= 4;

  /// Death returns the player to the first board of the current ten-level band.
  int get classicCheckpointLevel {
    final level = stats.level.clamp(1, 238);
    return ((level - 1) ~/ 10) * 10 + 1;
  }

  int get endGameMultiplierBaseGold => max(stats.goldCollected, 100);

  Brick? get activeBossBrick {
    for (final b in bricks) {
      if (b.isAlive && b.isBoss) return b;
    }
    return null;
  }

  void startNewGame(GameMode mode, {bool isResume = false}) {
    audio.isBgmAllowed = false;
    audio.pauseBgm();
    rollSessionCosmetics();
    currentMode = mode;
    status = GameStatus.ready;
    hasUsedRevive = false;
    hasClaimedVictoryBonus = false;
    endGameRolledDice = 0;
    endGameMultiplier = 0;
    endGameBonusGoldAdded = 0;
    _sessionStartingBestScore = save.getHighScore(mode);
    _hasCelebratedNewRecord = false;
    _bossEnrageAnnounced = false;
    _glassBreaksTowardDice = 0;
    _blocksUntilDicePoint = _rollDiceBlockGap();

    if (mode == GameMode.chaos) {
      if (!isResume) {
        chaosStock = 3;
      }
      chaosPendingExtraBalls = 0;
      chaosHomeX = screenWidth / 2;
      chaosAimX = chaosHomeX;
      chaosAimY = screenHeight * 0.45;
      chaosAiming = false;
      chaosToLaunch = 0;
      chaosReturned = 0;
      chaosHomeLocked = false;
    }

    int startLives = mode == GameMode.zen ? 999 : 3;
    int startLevel = 1;
    int startScore = 0;

    if (isResume) {
      if (mode == GameMode.classic) {
        startLevel = save.classicSavedLevel ?? 1;
        startScore = save.classicSavedScore ?? 0;
        startLives = save.classicSavedLives ?? 3;
      } else if (mode == GameMode.chaos) {
        startLevel = save.chaosSavedLevel ?? 1;
        startScore = save.chaosSavedScore ?? 0;
        chaosStock = save.chaosSavedStock ?? 3;
        startLives = 1;
      }
      if (startScore > _sessionStartingBestScore) {
        _hasCelebratedNewRecord = true;
      }
    } else {
      if (mode == GameMode.classic) {
        save.clearClassicSession();
      } else if (mode == GameMode.chaos) {
        save.clearChaosSession();
      }
      if (save.boostStocks['life'] != null && save.boostStocks['life']! > 0) {
        save.consumeBoost('life');
        startLives += 1;
      }
    }

    stats.reset(initialLives: startLives, startLevel: startLevel);
    stats.score = startScore;
    if (mode == GameMode.classic) {
      save.noteClassicProgress(stats.level);
    }
    particles.clear();
    capsules.clear();
    projectiles.clear();
    activePowerUps.clear();
    activeBee = null;
    activeSplat = null;
    beeSpawnCooldown = 25.0 + _rand.nextDouble() * 25.0;

    resetPaddleAndBall();
    loadLevelBricks();

    if (!isResume) {
      if (save.boostStocks['wide'] != null && save.boostStocks['wide']! > 0) {
        save.consumeBoost('wide');
        applyPowerUp(PowerUpType.wide);
      }
      if (save.boostStocks['multi'] != null && save.boostStocks['multi']! > 0) {
        save.consumeBoost('multi');
        applyPowerUp(PowerUpType.multi);
      }
    }

    notifyListeners();
  }

  void _haltBackgroundGameplay() {
    balls.clear();
    projectiles.clear();
    capsules.clear();
    isDiceRolling = false;
    diceSalvoRemaining = 0;
    diceRollTimer = 0.0;
    diceDisplayTimer = 0.0;
    laserTimer = 0.0;
    rocketTimer = 0.0;
    droneShootTimer = 0.0;
    paddle.hasLaser = false;
    paddle.laserAmmo = 0;
    paddle.hasRockets = false;
    paddle.hasDrone = false;
    paddle.hasVortex = false;
    paddle.slideVelocity = 0.0;
  }

  @visibleForTesting
  void haltBackgroundGameplay() => _haltBackgroundGameplay();

  void resetPaddleAndBall() {
    // Step 7: Aquarium Synergy - Passive buffs based on unlocked fish in Eco-Tank
    double fishWidthBonus = 0.0;
    if (save.unlockedFish.contains('guppy')) fishWidthBonus += 4.0;
    if (save.unlockedFish.contains('tetra')) fishWidthBonus += 3.0;

    paddle.width = paddle.baseWidth + fishWidthBonus;
    paddle.x = (screenWidth - paddle.width) / 2;
    paddle.y = screenHeight - 110.0;
    paddle.isSticky = false;
    paddle.hasLaser = false;
    paddle.laserAmmo = 0;
    paddle.hasRockets = false;
    paddle.hasDrone = false;
    paddle.hasNet = false;
    paddle.isGhost = false;
    paddle.isReversed = false;
    paddle.isClumsy = false;
    paddle.hasVortex = false;
    paddle.slideVelocity = 0.0;
    paddle.rocketAmmo = 0;

    activePowerUps.clear();
    capsules.clear();
    projectiles.clear();

    balls.clear();
    if (currentMode == GameMode.chaos) {
      _layoutChaosPile();
    } else {
      balls.add(
        Ball(
          x: paddle.x + paddle.width / 2,
          y: paddle.y - 12.0,
          isStuck: true,
          stuckOffsetX: paddle.width / 2,
        ),
      );
    }
  }

  void loadLevelBricks() {
    _hasLoadedBricks = true;
    activeIceVariant = _rand.nextInt(4);
    portals.clear();
    blackHoles.clear();
    activeBee = null;
    beeSpawnCooldown = 25.0 + _rand.nextDouble() * 25.0;
    _blackHoleTimer = 0.0;
    switch (currentMode) {
      case GameMode.classic:
        bricks = LevelDesign.buildClassicLevel(stats.level, screenWidth, screenHeight);
        if (LevelDesign.isBossLevelNumber(stats.level)) {
          bossWarningTimer = 2.2;
          particles.triggerShake(5.0, 0.35);
          audio.playSfx(GameSfx.bossHit);
        }
        if (portalLevels.contains(stats.level)) {
          final levelRand = Random(stats.level * 1337);
          double lowestAliveBrickY = 120.0;
          for (final b in bricks) {
            if ((b.y + b.height) > lowestAliveBrickY) {
              lowestAliveBrickY = b.y + b.height;
            }
          }
          final minY = (lowestAliveBrickY + 45.0).clamp(160.0, paddle.y - 140.0);
          final maxY = (paddle.y - 80.0).clamp(minY + 20.0, paddle.y - 40.0);
          final rangeY = max(20.0, maxY - minY);

          final p1Y = minY + levelRand.nextDouble() * rangeY * 0.45;
          final p2Y = minY + rangeY * 0.55 + levelRand.nextDouble() * rangeY * 0.45;

          final p1 = Portal(
            x: screenWidth * (0.20 + levelRand.nextDouble() * 0.14),
            y: p1Y,
            radius: 20.0,
            isBlue: true,
            color: const Color(0xFF00E5FF),
          );
          final p2 = Portal(
            x: screenWidth * (0.66 + levelRand.nextDouble() * 0.14),
            y: p2Y,
            radius: 20.0,
            isBlue: false,
            color: const Color(0xFFFF9100),
          );
          p1.linkedPortal = p2;
          p2.linkedPortal = p1;
          portals.add(p1);
          portals.add(p2);
        }
        break;
      case GameMode.zen:
        bricks = LevelDesign.buildZenLevel(screenWidth, screenHeight);
        break;
      case GameMode.descend:
        bricks = LevelDesign.buildDescendInitial(screenWidth, screenHeight);
        descendTimer = 13.0;
        break;
      case GameMode.daily:
        bricks = LevelDesign.buildDailyLevel(DateTime.now(), screenWidth, screenHeight);
        break;
      case GameMode.shapes:
        bricks = LevelDesign.buildShapesLevel(stats.level, screenWidth, screenHeight);
        break;
      case GameMode.chaos:
        bricks = LevelDesign.buildChaosLevel(stats.level, screenWidth, screenHeight);
        break;
    }
    _loadedBricksRef = bricks;

    // Micro-onboarding: Check if this level introduces a new mechanic (levels 1-10)
    if (currentMode == GameMode.classic && stats.level <= 10) {
      if (LevelDesign.isBossLevelNumber(stats.level)) {
        showMicroTip('boss', I18n.tr('tip_boss'));
      } else if (portals.isNotEmpty) {
        showMicroTip('portal', I18n.tr('tip_portal'));
      } else if (bricks.any((b) => b.isIce)) {
        showMicroTip('ice', I18n.tr('tip_ice'));
      } else if (bricks.any((b) => b.isDynamite)) {
        showMicroTip('bomb', I18n.tr('tip_bomb'));
      } else if (bricks.any((b) => b.isTuft)) {
        showMicroTip('tuft', I18n.tr('tip_tuft'));
      }
    }
    if (currentMode == GameMode.classic && bricks.any((b) => b.isSteel)) {
      showOnceTip('steel', I18n.tr('tip_steel'));
    }
    if (currentMode == GameMode.classic && stats.level < 4) {
      blackHoles.clear();
    }
    if (currentMode == GameMode.classic && stats.level >= 11 && stats.level % 10 == 1) {
      final rule = LevelDesign.decadeRuleKey(stats.level);
      if (rule != null) {
        showOnceTip(
          'decade_${LevelDesign.decadeIndex(stats.level)}',
          '${LevelDesign.getWorldName(stats.level)} · ${I18n.tr(rule)}',
        );
      }
    }
  }

  bool get hasStuckBall => balls.any((b) => b.isStuck);

  void launchBall() {
    if (levelTransitionTimer > 0) {
      levelTransitionTimer = 0.0;
      if (balls.isEmpty) {
        resetPaddleAndBall();
      }
    }
    if (status == GameStatus.ready) {
      status = GameStatus.playing;
    }

    bool anyLaunched = false;
    final stuck = balls.where((b) => b.isStuck).toList();
    for (int i = 0; i < stuck.length; i++) {
      final ball = stuck[i];
      ball.isStuck = false;
      ball.stuckTimer = 0.0;
      final speed = getBaseBallSpeed();
      if (currentMode == GameMode.chaos && stuck.length > 1) {
        final spread = (i - (stuck.length - 1) / 2) * 0.22;
        ball.vx = speed * sin(spread);
        ball.vy = -speed * cos(spread);
      } else {
        // Extremely subtle tilt angle (~0.8-1.5 degrees) barely perceptible to human eye yet prevents idle vertical exploit
        final tilt = (_rand.nextBool() ? 1.0 : -1.0) * (0.014 + _rand.nextDouble() * 0.012);
        ball.vx = speed * sin(tilt);
        ball.vy = -speed * cos(tilt);
      }
      anyLaunched = true;
    }
    if (anyLaunched) {
      audio.playSfx(GameSfx.hitPaddle);
      _blessFirstBallOfDay(stuck);
      notifyListeners();
    }
  }

  void _blessFirstBallOfDay(List<Ball> launched) {
    if (launched.isEmpty || currentMode == GameMode.chaos) return;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    if (save.dayBlessingDate == today) return;
    String? key;
    final fedDay = save.lastFishFedDay;
    if (fedDay != null && fedDay.compareTo(today) < 0) key = 'day_fish_ball';
    if (key == null && currentMode == GameMode.daily) key = 'day_board_ball';
    if (key == null) return;
    save.markDayBlessed(today);
    launched.first.isDayBlessed = true;
    particles.spawnFloatingText(
      screenWidth * 0.5,
      screenHeight * 0.56,
      I18n.tr(key),
      const Color(0xFFFFD54F),
      isLarge: true,
    );
  }

  void aimChaos(double x, double y) {
    if (currentMode != GameMode.chaos || status != GameStatus.ready) return;
    chaosAiming = true;
    chaosAimX = x.clamp(10.0, screenWidth - 10.0);
    chaosAimY = min(y, chaosFloorY - 18.0);
    frameTick.ping();
  }

  void toggleChaosTurboOrRecall() {
    if (currentMode != GameMode.chaos || status != GameStatus.playing) return;
    if (chaosRecallActive) return;
    if (chaosSpeedMultiplier <= 1.05) {
      chaosSpeedMultiplier = 2.2;
      particles.spawnFloatingText(screenWidth / 2, chaosFloorY - 55, I18n.tr('chaos_2x_speed'), const Color(0xFFFFD700), isLarge: true);
      audio.playSfx(GameSfx.wallBounce8);
    } else {
      recallChaosBalls();
    }
    notifyListeners();
  }

  void recallChaosBalls() {
    if (currentMode != GameMode.chaos || status != GameStatus.playing) return;
    chaosRecallActive = true;
    chaosToLaunch = 0;
    particles.spawnFloatingText(screenWidth / 2, chaosFloorY - 55, I18n.tr('chaos_recall'), const Color(0xFF00E5FF), isLarge: true);
    audio.playSfx(GameSfx.powerupBuff);
    notifyListeners();
  }

  void fireChaos() {
    if (currentMode != GameMode.chaos || status != GameStatus.ready || chaosStock <= 0) return;
    var dx = chaosAimX - chaosHomeX;
    var dy = chaosAimY - chaosFloorY;
    if (!chaosAiming || dy >= -10) {
      dx = 0;
      dy = -1;
    }
    final angle = atan2(dy, dx);
    final clampedAngle = angle.clamp(-pi + 0.16, -0.16);
    final finalDx = cos(clampedAngle);
    final finalDy = sin(clampedAngle);

    final speed = getBaseBallSpeed();
    chaosLaunchX = chaosHomeX;
    chaosShotVx = finalDx * speed;
    chaosShotVy = finalDy * speed;
    chaosToLaunch = chaosStock;
    chaosReturned = 0;
    chaosHomeLocked = false;
    chaosShotTimer = 0;
    chaosTurnTime = 0;
    chaosAiming = false;
    chaosSpeedMultiplier = 1.0;
    chaosRecallActive = false;
    balls.clear();
    status = GameStatus.playing;
    audio.playSfx(GameSfx.hitPaddle);
    notifyListeners();
  }

  void _layoutChaosPile() {
    balls.clear();
    // Kaos modunda hedeflerken/başlangıçta üst üste yığılmış toplar yerine tek bir net top gösterilir
    if (chaosStock > 0) {
      balls.add(
        Ball(
          x: chaosHomeX,
          y: chaosFloorY - 8,
          radius: 5.2,
          isStuck: true,
        ),
      );
    }
  }

  void _launchChaosVolley(double dt) {
    if (chaosToLaunch <= 0) return;
    chaosShotTimer -= dt;
    final interval = (0.050 - (chaosStock * 0.0005)).clamp(0.026, 0.050);
    while (chaosShotTimer <= 0 && chaosToLaunch > 0) {
      balls.add(
        Ball(
          x: chaosLaunchX,
          y: chaosFloorY - 10,
          vx: chaosShotVx,
          vy: chaosShotVy,
          radius: 5.2,
          isStuck: false,
        ),
      );
      chaosToLaunch--;
      chaosShotTimer += interval;
    }
  }

  void _chaosAdvanceTurn() {
    chaosSpeedMultiplier = 1.0;
    chaosRecallActive = false;
    final remainingSolid = bricks.where((b) => b.isAlive && !b.isBallPickup).toList();
    if (remainingSolid.isEmpty) {
      final baseGold = 25 + (stats.level * 5).clamp(0, 50);
      final relicBonus = save.hasPermanentRelic ? max(1, (baseGold * 0.05).round()) : 0;
      final levelGold = baseGold + relicBonus;
      stats.goldCollected += levelGold;
      save.addGold(levelGold);

      stats.level++;
      stats.score += 300 * stats.level;
      if (AdManager.instance.registerLevelClear()) pendingLevelInterstitial = true;
      chaosStock = 3;
      chaosPendingExtraBalls = 0;
      chaosReturned = 0;
      chaosToLaunch = 0;
      chaosHomeLocked = false;
      save.saveChaosSession(level: stats.level, score: stats.score, stock: chaosStock);
      loadLevelBricks();
      status = GameStatus.ready;
      _layoutChaosPile();
      particles.spawnShockwave(screenWidth * 0.5, screenHeight * 0.4, const Color(0xFFFFD700), maxRadius: 75.0);
      particles.spawnBurst(screenWidth * 0.5, screenHeight * 0.4, const Color(0xFF00E5FF), count: 25, speed: 180.0);
      particles.spawnFloatingText(screenWidth * 0.5, screenHeight * 0.4, I18n.tr('level_cleared'), const Color(0xFFFFD700), isLarge: true);
      particles.spawnFloatingText(screenWidth * 0.5, screenHeight * 0.47, '+$levelGold  ${I18n.tr('level_bonus')}', const Color(0xFFFFD54F), isLarge: false);
      audio.playSfx(GameSfx.victory);
      notifyListeners();
      return;
    }

    chaosStock += chaosPendingExtraBalls;
    chaosPendingExtraBalls = 0;
    const step = LevelDesign.chaosStep;
    for (final brick in bricks) {
      if (!brick.isAlive) continue;
      brick.y += step;
      brick.targetY = brick.y;
      if (!brick.isBallPickup && brick.y + brick.height >= chaosFloorY - 36) {
        _onGameOver();
        return;
      }
    }
    bricks.removeWhere((brick) => !brick.isAlive);
    bricks.removeWhere((brick) => brick.isBallPickup && brick.y + brick.height >= chaosFloorY - 20);

    bricks.addAll(LevelDesign.buildChaosRow(stats.level, 0, screenWidth));
    save.saveChaosSession(level: stats.level, score: stats.score, stock: chaosStock);
    chaosReturned = 0;
    chaosToLaunch = 0;
    chaosHomeLocked = false;
    status = GameStatus.ready;
    _layoutChaosPile();
    audio.playSfx(GameSfx.hitPaddle);
    notifyListeners();
  }

  double getBaseBallSpeed() {
    const pace = 1.48;
    if (currentMode == GameMode.chaos) {
      return 420.0 * pace;
    }
    final base = 350.0 * pace;
    return base + min(stats.level * 10.0, 90.0);
  }

  void movePaddleTo(double targetX) {
    if (status != GameStatus.playing && status != GameStatus.ready) return;

    double actualTarget = targetX;
    if (paddle.isReversed) {
      actualTarget = screenWidth - targetX;
    }

    final halfW = paddle.width / 2;
    double newX = actualTarget - halfW;

    if (paddle.isClumsy) {
      final diff = newX - paddle.x;
      paddle.x += diff * 0.16;
      paddle.slideVelocity = (diff * 12.0).clamp(-760.0, 760.0);
    } else {
      paddle.x = newX;
      paddle.slideVelocity = 0.0;
    }

    paddle.x = paddle.x.clamp(8.0, screenWidth - paddle.width - 8.0);

    for (final ball in balls) {
      if (ball.isStuck) {
        ball.x = paddle.x + ball.stuckOffsetX;
        ball.y = paddle.y - ball.radius - 2.0;
      }
    }
    frameTick.ping();
  }

  void movePaddleBy(double deltaX) {
    if (status != GameStatus.playing && status != GameStatus.ready) return;

    double delta = deltaX;
    if (paddle.isReversed) {
      delta = -deltaX;
    }

    if (paddle.isClumsy) {
      paddle.x += delta * 1.15;
      paddle.slideVelocity = (paddle.slideVelocity * 0.45 + delta * 42.0).clamp(-760.0, 760.0);
    } else {
      paddle.x += delta;
      paddle.slideVelocity = 0.0;
    }

    paddle.x = paddle.x.clamp(8.0, screenWidth - paddle.width - 8.0);

    for (final ball in balls) {
      if (ball.isStuck) {
        ball.x = paddle.x + ball.stuckOffsetX;
        ball.y = paddle.y - ball.radius - 2.0;
      }
    }
    frameTick.ping();
  }

  void _updatePaddleIceSlide(double dt) {
    if (!paddle.isClumsy || paddle.slideVelocity.abs() <= 2.0) {
      if (!paddle.isClumsy) paddle.slideVelocity = 0.0;
      return;
    }
    paddle.x += paddle.slideVelocity * dt;
    // Smooth ice friction: glides for ~0.5-0.8s after releasing finger
    paddle.slideVelocity *= exp(-2.8 * dt);
    if (paddle.slideVelocity.abs() < 4.0) {
      paddle.slideVelocity = 0.0;
    }

    final minX = 8.0;
    final maxX = screenWidth - paddle.width - 8.0;
    if (paddle.x <= minX) {
      paddle.x = minX;
      paddle.slideVelocity = paddle.slideVelocity.abs() * 0.65;
    } else if (paddle.x >= maxX) {
      paddle.x = maxX;
      paddle.slideVelocity = -paddle.slideVelocity.abs() * 0.65;
    }

    for (final ball in balls) {
      if (ball.isStuck) {
        ball.x = paddle.x + ball.stuckOffsetX;
        ball.y = paddle.y - ball.radius - 2.0;
      }
    }
  }

  void update(double dt) {
    gameTime += dt;

    // Update micro-onboarding tip timer
    if (tipTimer > 0) {
      tipTimer -= dt;
      if (tipTimer <= 0) {
        tipTimer = 0.0;
        activeTipText = null;
        notifyListeners();
      }
    }

    // Windshield Splat update: persists on screen glass for 2 seconds even when game state changes
    final hadSplat = activeSplat != null;
    if (activeSplat != null) {
      activeSplat!.update(dt);
      if (activeSplat!.isDead) {
        activeSplat = null;
      }
    }

    if (status == GameStatus.playing || status == GameStatus.ready) {
      if (bossWarningTimer > 0) {
        bossWarningTimer -= dt;
        if (bossWarningTimer < 0) bossWarningTimer = 0;
      }
      if (levelTransitionTimer > 0) {
        levelTransitionTimer = ((levelTransitionTimer - dt) * 1000000).round() / 1000000.0;
        if (levelTransitionTimer <= 0) {
          levelTransitionTimer = 0.0;
          if (balls.isEmpty) {
            resetPaddleAndBall();
          }
          status = GameStatus.ready;
          particles.update(dt);
          frameTick.ping();
          _syncHud();
          return;
        }
        particles.update(dt);
        frameTick.ping();
        _syncHud();
        return;
      }
      if (status == GameStatus.ready) {
        final hasActiveMovingBall = balls.any((b) => !b.isStuck);
        final allBallsLost = balls.isEmpty && currentMode != GameMode.chaos;
        final allBreakableCleared = currentMode != GameMode.zen &&
            bricks.isNotEmpty &&
            bricks.every((b) => !b.isAlive || b.isSteel || (b.isTuft && b.tuftFilled));
        if (hasActiveMovingBall || allBallsLost || allBreakableCleared) {
          status = GameStatus.playing;
        }
      }
    }

    if (status != GameStatus.playing) {
      final splash =
          hadSplat ||
          particles.particles.isNotEmpty ||
          particles.shockwaves.isNotEmpty ||
          particles.floatingTexts.isNotEmpty ||
          particles.shards.isNotEmpty ||
          bossWarningTimer > 0 ||
          levelTransitionTimer > 0 ||
          particles.shakeTimeLeft > 0;
      if (!splash) return;
      particles.update(dt);
      frameTick.ping();
      _syncHud();
      return;
    }

    // Bullet time slow motion
    double effectiveDt = dt;
    if (stats.bulletTimeLeft > 0) {
      stats.bulletTimeLeft -= dt;
      effectiveDt = dt * 0.45;
    }

    if (currentMode == GameMode.chaos) {
      effectiveDt *= chaosSpeedMultiplier;
      chaosTurnTime += effectiveDt;
      _launchChaosVolley(effectiveDt);
    }

    if (currentMode != GameMode.zen &&
        currentMode != GameMode.chaos &&
        bricks.isNotEmpty &&
        !(!identical(bricks, _loadedBricksRef) && balls.any((b) => b.isFireball || b.isPierce)) &&
        bricks.every((b) => !b.isAlive || b.isSteel || (b.isTuft && b.tuftFilled))) {
      _checkGameProgress();
      if (levelTransitionTimer > 0 || status != GameStatus.playing) {
        particles.update(effectiveDt);
        frameTick.ping();
        _syncHud();
        return;
      }
    }

    particles.update(effectiveDt);
    _updatePaddleIceSlide(effectiveDt);
    paddle.update(effectiveDt);

    _updateEasterEgg(effectiveDt);
    _updatePowerUpTimers(effectiveDt);
    _updateCombo(effectiveDt);
    _updateProjectiles(effectiveDt);
    _updateCapsules(effectiveDt);
    _updateBricks(effectiveDt);
    _updateAnomalies(effectiveDt);
    _updateBalls(effectiveDt);
    _updateDice(effectiveDt);
    endgameStallTimer += effectiveDt;
    _checkGameProgress();
    frameTick.ping();
    _syncHud();
  }

  int _hudSig = 0;

  void _syncHud() {
    final boss = activeBossBrick;
    var sig = Object.hash(
      stats.score,
      stats.lives,
      stats.level,
      status,
      stats.ultiCharge.floor(),
      isDiceRolling,
      diceDisplayTimer > 0,
      diceTotal,
      boss?.hp ?? 0,
      activePowerUps.length,
      balls.length,
      chaosStock,
      chaosToLaunch,
    );
    for (final p in activePowerUps) {
      sig = Object.hash(sig, p.type, (p.timeLeft * 10).floor());
    }
    if (sig == _hudSig) return;
    _hudSig = sig;
    notifyListeners();
  }

  void spawnEasterEggBee({double? customY, bool? facingRight}) {
    final right = facingRight ?? _rand.nextBool();
    final startX = right ? -35.0 : screenWidth + 35.0;
    final speed = 48.0 + _rand.nextDouble() * 16.0;
    final vx = right ? speed : -speed;
    double laneY = customY ?? (screenHeight * 0.48 + (_rand.nextDouble() * 120.0 - 60.0));
    laneY = laneY.clamp(180.0, paddle.y - 70.0);

    activeBee = EasterEggBee(
      x: startX,
      baseY: laneY,
      vx: vx,
      isFacingRight: right,
    );
  }

  void _updateEasterEgg(double dt) {
    if (currentMode == GameMode.chaos) return;
    if (activeBee == null) {
      beeSpawnCooldown -= dt;
      if (beeSpawnCooldown <= 0) {
        spawnEasterEggBee();
        beeSpawnCooldown = 35.0 + _rand.nextDouble() * 30.0;
      }
    } else {
      activeBee!.update(dt);
      if (activeBee!.isOffScreen(screenWidth)) {
        activeBee = null;
      }
    }
  }

  void _updatePowerUpTimers(double dt) {
    for (int i = activePowerUps.length - 1; i >= 0; i--) {
      final p = activePowerUps[i];
      p.timeLeft -= dt;
      if (p.timeLeft <= 0) {
        _removePowerUp(p.type);
        activePowerUps.removeAt(i);
      }
    }

    // Drone auto firing
    if (paddle.hasDrone) {
      droneShootTimer += dt;
      if (droneShootTimer >= 0.85) {
        droneShootTimer = 0;
        final droneOffset = Offset(
          paddle.x + paddle.width / 2 + cos(paddle.droneAngle) * 40.0,
          paddle.y - 20.0 + sin(paddle.droneAngle) * 15.0,
        );
        projectiles.add(Projectile(x: droneOffset.dx, y: droneOffset.dy, vy: -480.0, radius: 3.5, isLaser: true));
        audio.playSfx(GameSfx.laser);
      }
    }

    // Lazer: yakalanınca 1–6 atış. 1, 2, 3 sık; 4, 5, 6 seyrek.
    if (paddle.hasLaser && paddle.laserAmmo > 0) {
      laserTimer = (laserTimer ?? 0.0) + dt;
      if (laserTimer! >= 0.65) {
        laserTimer = 0.0;
        final hasFireball = balls.any((b) => b.isFireball);
        if (hasFireball) {
          projectiles.add(Projectile(x: paddle.x + 10, y: paddle.y - 12, vx: -80, vy: -500.0, radius: 6.0, isLaser: true));
          projectiles.add(Projectile(x: paddle.x + paddle.width - 10, y: paddle.y - 12, vx: 80, vy: -500.0, radius: 6.0, isLaser: true));
          audio.playSfx(GameSfx.explosion);
        } else {
          projectiles.add(Projectile(x: paddle.x + 10, y: paddle.y - 12, vy: -450.0, radius: 4.0, isLaser: true));
          projectiles.add(Projectile(x: paddle.x + paddle.width - 10, y: paddle.y - 12, vy: -450.0, radius: 4.0, isLaser: true));
          audio.playSfx(GameSfx.laser);
        }
        paddle.laserAmmo--;
        if (paddle.laserAmmo <= 0) {
          paddle.hasLaser = false;
          activePowerUps.removeWhere((p) => p.type == PowerUpType.laser);
        }
      }
    }

    // Rocket auto firing
    if (paddle.hasRockets) {
      rocketTimer = (rocketTimer ?? 0.0) + dt;
      if (rocketTimer! >= 1.2) {
        rocketTimer = 0.0;
        projectiles.add(Projectile(x: paddle.x + paddle.width / 2, y: paddle.y - 10, vy: -350.0, radius: 6.0, isRocket: true));
        audio.playSfx(GameSfx.ulti);
        
        paddle.rocketAmmo--;
        if (paddle.rocketAmmo <= 0) {
          paddle.hasRockets = false;
        }
      }
    }

    
  }

  void _updateDice(double dt) {
    if (isDiceRolling) {
      diceRollTimer -= dt;
      _diceShuffleTimer += dt;
      if (_diceShuffleTimer >= 0.05) {
        _diceShuffleTimer = 0.0;
        diceDisplay1 = 1 + _rand.nextInt(6);
        diceDisplay2 = 1 + _rand.nextInt(6);
        particles.spawnBurst(
          paddle.x + paddle.width / 2 + (_rand.nextDouble() * 40 - 20),
          paddle.y - 65.0 + (_rand.nextDouble() * 24 - 12),
          isDoubleDice ? const Color(0xFFFFD700) : const Color(0xFF00E5FF),
          count: 2,
          speed: 60.0,
        );
      }

      if (diceRollTimer <= 0) {
        isDiceRolling = false;
        diceDisplay1 = dice1Value;
        diceDisplay2 = dice2Value;
        final totalShots = diceTotal;
        diceSalvoRemaining = totalShots;
        diceSalvoCooldown = 0.05;
        diceDisplayTimer = 2.5;

        if (totalShots == 12) {
          particles.triggerShake(9.5, 0.5);
          particles.spawnShockwave(paddle.x + paddle.width / 2, paddle.y - 50, const Color(0xFFFF1744), maxRadius: screenWidth * 0.9);
          particles.spawnShockwave(paddle.x + paddle.width / 2, paddle.y - 50, const Color(0xFFFFD700), maxRadius: screenWidth * 0.7);
          particles.spawnFloatingText(screenWidth / 2, screenHeight * 0.38, I18n.tr('dice_legendary_12'), const Color(0xFFFFD700), isLarge: true);
          audio.playSfx(GameSfx.ulti);
        } else if (totalShots == 11) {
          particles.triggerShake(7.0, 0.4);
          particles.spawnShockwave(paddle.x + paddle.width / 2, paddle.y - 50, const Color(0xFFFF6D00), maxRadius: screenWidth * 0.7);
          particles.spawnFloatingText(screenWidth / 2, screenHeight * 0.38, I18n.tr('dice_epic_11'), const Color(0xFFFF6D00), isLarge: true);
          audio.playSfx(GameSfx.ulti);
        } else if (totalShots == 10) {
          particles.triggerShake(6.0, 0.35);
          particles.spawnShockwave(paddle.x + paddle.width / 2, paddle.y - 50, const Color(0xFF00E5FF), maxRadius: screenWidth * 0.6);
          particles.spawnFloatingText(screenWidth / 2, screenHeight * 0.38, I18n.tr('dice_big_10'), const Color(0xFF00E5FF), isLarge: true);
          audio.playSfx(GameSfx.ulti);
        } else if (isDoubleDice) {
          particles.spawnFloatingText(screenWidth / 2, screenHeight * 0.38, ' $totalShots ${I18n.tr('dice_double_suffix')}', const Color(0xFFFFD700), isLarge: true);
          audio.playSfx(GameSfx.ulti);
        } else {
          particles.spawnFloatingText(screenWidth / 2, screenHeight * 0.38, ' $totalShots ${I18n.tr('dice_shot_suffix')}', const Color(0xFF00E5FF), isLarge: true);
          audio.playSfx(GameSfx.laser);
        }
      }
    }

    if (diceDisplayTimer > 0) {
      diceDisplayTimer -= dt;
    }

    // Salvo firing: exactly 1 shot from left, 1 shot from right
    if (diceSalvoRemaining > 0) {
      diceSalvoCooldown -= dt;
      if (diceSalvoCooldown <= 0) {
        diceSalvoCooldown = 0.30;
        diceSalvoRemaining--;

        final leftX = paddle.x + 8.0;
        final rightX = paddle.x + paddle.width - 8.0;
        final spawnY = paddle.y - 6.0;

        projectiles.add(
          Projectile(
            x: leftX,
            y: spawnY,
            vy: -550.0,
            radius: 5.5,
            isRocket: true,
          ),
        );

        projectiles.add(
          Projectile(
            x: rightX,
            y: spawnY,
            vy: -550.0,
            radius: 5.5,
            isRocket: true,
          ),
        );

        particles.spawnBurst(leftX, spawnY, const Color(0xFFFFD54F), count: 6, speed: 90.0);
        particles.spawnBurst(rightX, spawnY, const Color(0xFFFFD54F), count: 6, speed: 90.0);
        audio.playSfx(GameSfx.laser);
      }
    }
  }

  void _updateCombo(double dt) {
    if (comboTimer > 0) {
      comboTimer -= dt;
      if (comboTimer <= 0) {
        stats.combo = 0;
        stats.isFever = false;
      }
    }
    if (stats.feverTimeLeft > 0) {
      stats.feverTimeLeft -= dt;
      if (stats.feverTimeLeft <= 0) {
        stats.isFever = false;
      }
    }
  }

  void _updateProjectiles(double dt) {
    for (int i = projectiles.length - 1; i >= 0; i--) {
      final p = projectiles[i];
      p.update(dt);

      // Offscreen check
      if (p.y < 0 || p.y > screenHeight) {
        projectiles.removeAt(i);
        continue;
      }

      // Boss bullets hitting paddle
      if (p.isBossBullet) {
        if (paddle.rect.contains(Offset(p.x, p.y))) {
          projectiles.removeAt(i);
          particles.triggerShake(5.5, 0.25);
          particles.spawnBurst(p.x, p.y, Colors.redAccent, count: 16);
          particles.spawnFloatingText(p.x, paddle.y - 24, I18n.tr('boss_hit_shrink'), const Color(0xFFFF1744));
          // Apply short 3.5s shrink debuff to make dodging boss bullets exciting!
          activePowerUps.removeWhere((ap) => ap.type == PowerUpType.wide || ap.type == PowerUpType.shrink);
          final shrinkDebuff = ActivePowerUp(PowerUpType.shrink);
          shrinkDebuff.timeLeft = 3.5;
          activePowerUps.add(shrinkDebuff);
          paddle.width = paddle.baseWidth * 0.65;
          audio.playSfx(GameSfx.powerupDebuff);
          continue;
        }
      } else {
        // Lasers & Rockets hitting bricks
        bool hit = false;
        for (final b in bricks) {
          if (!b.isAlive) continue;
          if (b.rect.contains(Offset(p.x, p.y))) {
            hit = true;
            if (p.isRocket) {
              _explodeArea(p.x, p.y, radius: 65.0);
            } else {
              _hitBrick(b, null);
            }
            break;
          }
        }
        if (hit) {
          projectiles.removeAt(i);
        }
      }
    }
  }

  void _updateCapsules(double dt) {
    final magnetLevel = save.upgrades['magnet'] ?? 0;
    final paddleCenter = Offset(paddle.x + paddle.width / 2, paddle.y);

    for (int i = capsules.length - 1; i >= 0; i--) {
      final c = capsules[i];
      c.update(dt);

      // Vortex vacuum: pulls all falling good (buff) capsules across the screen into the paddle!
      if (paddle.hasVortex && c.type.kind == PowerUpKind.buff) {
        final dx = paddleCenter.dx - c.x;
        final dy = paddleCenter.dy - c.y;
        final dist = sqrt(dx * dx + dy * dy);
        if (dist > 2.0 && dist < 420.0) {
          const pull = 360.0;
          c.x += (dx / dist) * pull * dt;
          c.y += (dy / dist) * (pull * 0.75) * dt;
        }
      } else if (magnetLevel > 0) {
        final dx = paddleCenter.dx - c.x;
        final dy = paddleCenter.dy - c.y;
        final dist = sqrt(dx * dx + dy * dy);
        if (dist < 220.0) {
          final pull = 180.0 * magnetLevel;
          c.x += (dx / dist) * pull * dt;
          c.y += (dy / dist) * pull * dt;
        }
      } else if (save.hasPermanentRelic) {
        final dx = paddleCenter.dx - c.x;
        final dy = paddleCenter.dy - c.y;
        if (dx.abs() > 4.0 && dy < 220.0 && dy > -20.0) {
          c.x += dx.sign * (72.0 * dt);
        }
      }

      // Check collision with paddle
      final capRect = Rect.fromCenter(center: Offset(c.x, c.y), width: c.width, height: c.height);
      if (paddle.rect.overlaps(capRect)) {
        final type = c.type;
        capsules.removeAt(i);
        applyPowerUp(type);
        continue;
      }

      // Fallen below screen
      if (c.y > screenHeight) {
        capsules.removeAt(i);
      }
    }
  }

  void _updateBricks(double dt) {
    for (final b in bricks) {
      b.update(dt);

      // Boss shooting (Spread Attack)
      if (b.isAlive && b.isBoss && b.shootTimer <= 0) {
        b.shootTimer = 2.0 + _rand.nextDouble() * 1.0;
        
        // Shoot 3 bullets in a spread pattern
        final centerX = b.x + b.width / 2;
        final bottomY = b.y + b.height + 6.0;
        
        projectiles.add(Projectile(x: centerX - 20, y: bottomY, vx: -120.0, vy: 250.0, radius: 6.0, isBossBullet: true));
        projectiles.add(Projectile(x: centerX, y: bottomY, vy: 250.0, radius: 7.0, isBossBullet: true));
        projectiles.add(Projectile(x: centerX + 20, y: bottomY, vx: 120.0, vy: 250.0, radius: 6.0, isBossBullet: true));
        
        audio.playSfx(GameSfx.explosion);
        particles.spawnBurst(centerX, bottomY, const Color(0xFFFF1744), count: 12);
      }
    }

    // Global dead brick pruning to eliminate memory accumulation and CPU lag
    bricks.removeWhere((b) => !b.isAlive);

    // Descend mode marching with smooth sliding animation
    if (currentMode == GameMode.descend) {
      descendTimer -= dt;
      if (descendTimer <= 0) {
        descendTimer = 11.0;
        const rowStep = 28.0; // bh (22) + gap (6)
        for (final b in bricks) {
          b.targetY += rowStep;
          if (b.isAlive && b.targetY + b.height >= paddle.y) {
            // Bricks reached paddle!
            _onGameOver();
            return;
          }
        }
        // Add new top row cleanly, starting above and sliding down
        final newRow = LevelDesign.buildDescendRow(0, screenWidth, screenHeight);
        for (final b in newRow) {
          b.y = LevelDesign.baseTopMargin - rowStep;
          b.targetY = LevelDesign.baseTopMargin;
        }
        bricks.addAll(newRow);
        particles.triggerShake(3.0, 0.16);
        audio.playSfx(GameSfx.hitWall);
      }
    }

    // Zen mode replenishment when all bricks are cleared
    if (currentMode == GameMode.zen && bricks.every((b) => !b.isAlive)) {
      bricks = LevelDesign.buildZenLevel(screenWidth, screenHeight);
    }
  }

  void _updateAnomalies(double dt) {
    for (final p in portals) {
      p.update(dt);
    }

    for (int i = blackHoles.length - 1; i >= 0; i--) {
      final bh = blackHoles[i];
      bh.update(dt);
      if (bh.timeLeft <= 0) {
        particles.spawnBurst(bh.x, bh.y, const Color(0xFFB388FF), count: 20, speed: 120.0);
        blackHoles.removeAt(i);
      }
    }

    // Black Hole random dynamic appearance strictly in open playable zone between bricks and paddle
    // Genelde (%90+) 1 adet karadelik bulunur. 2. karadelik çok nadiren (%5-10) belirir.
    if (status == GameStatus.playing &&
        currentMode != GameMode.zen &&
        currentMode != GameMode.chaos &&
        blackHoles.length < 2 &&
        _blackHolesAllowed) {
      _blackHoleTimer = (_blackHoleTimer ?? 0.0) + dt;
      final canSpawn = blackHoles.isEmpty
          ? (_blackHoleTimer! >= 8.0 && _rand.nextDouble() < 0.12)
          : (blackHoles.length == 1 && _blackHoleTimer! >= 14.0 && _rand.nextDouble() < 0.02);
      if (canSpawn) {
        // Find bottom-most active breakable brick so steel barriers don't block black hole spawns
        double lowestAliveBrickY = 0.0;
        for (final b in bricks) {
          if (b.isAlive && !b.isSteel && (b.y + b.height) > lowestAliveBrickY) {
            lowestAliveBrickY = b.y + b.height;
          }
        }

        final minY = lowestAliveBrickY + 45.0;
        final maxY = paddle.y - 170.0;

        _blackHoleTimer = 0.0;
        final roll = _rand.nextDouble();
        final isVortexTrap = roll < 0.02; // 2% rare ultra vortex
        final isSupercharged = !isVortexTrap && (roll < 0.30); // ~28% exotic supercharged black hole
        final r = isVortexTrap ? 32.0 : (isSupercharged ? 28.0 : (20.0 + _rand.nextDouble() * 10.0));
        final double spawnY = (maxY > minY + 20.0)
            ? (minY + _rand.nextDouble() * (maxY - minY))
            : (paddle.y - 200.0).clamp(160.0, paddle.y - 170.0);
        var spawnX = (screenWidth * 0.22 + _rand.nextDouble() * (screenWidth * 0.56)).clamp(r + 20.0, screenWidth - r - 20.0);

        // 2. karadelik çıktığında 1.siyle üst üste binmesin diye yatay mesafe garantisi:
        if (blackHoles.isNotEmpty) {
          final first = blackHoles.first;
          if ((spawnX - first.x).abs() < 120.0) {
            spawnX = (first.x > screenWidth * 0.5)
                ? (first.x - 130.0).clamp(r + 20.0, screenWidth - r - 20.0)
                : (first.x + 130.0).clamp(r + 20.0, screenWidth - r - 20.0);
          }
        }

        blackHoles.add(
          BlackHole(
            x: spawnX,
            y: spawnY,
            radius: r,
            mass: r * 8000.0,
            timeLeft: isVortexTrap ? 7.5 : (isSupercharged ? 6.5 : (5.5 + _rand.nextDouble() * 2.0)),
            isVortexTrap: isVortexTrap,
            isSupercharged: isSupercharged,
          ),
        );
        audio.playSfx(GameSfx.laser);
        if (isVortexTrap) {
          particles.spawnFloatingText(screenWidth * 0.5, spawnY, I18n.tr('vortex_black_hole'), const Color(0xFFFF1744), isLarge: true);
          particles.spawnShockwave(spawnX, spawnY, const Color(0xFFFF1744), maxRadius: 80.0);
        } else if (isSupercharged) {
          particles.spawnShockwave(spawnX, spawnY, const Color(0xFFFF9100), maxRadius: 70.0);
        } else {
          particles.spawnShockwave(spawnX, spawnY, const Color(0xFF7C4DFF), maxRadius: 60.0);
        }
        showMicroTip('black_hole', I18n.tr('tip_black_hole'));
      }
    }
  }

  void _updateBalls(double dt) {
    for (int i = balls.length - 1; i >= 0; i--) {
      final ball = balls[i];
      if (ball.isStuck) {
        if (status == GameStatus.playing) {
          ball.stuckTimer += dt;
          if (ball.stuckTimer >= 1.6 || !paddle.isSticky) {
            launchBall();
          }
        }
        continue;
      }

      // Fireball & Corner boost trail sparks & decay
      if (ball.isFireball) {
        if (_rand.nextDouble() < 0.25) {
          particles.spawnBurst(ball.x, ball.y, const Color(0xFFFF1744), count: 1, speed: 70.0);
        }
      }
      if (ball.cornerBoostTimer > 0) {
        final Color cbBaseColor = activeBallSkin.mainColor;
        final Color cbGlowColor = activeBallSkin.glowColor;
        if (_rand.nextDouble() < 0.45) {
          particles.spawnBurnEmber(ball.x, ball.y, color: cbBaseColor);
        }
        if (_rand.nextDouble() < 0.30) {
          final sparkColor = _rand.nextBool() ? cbBaseColor : cbGlowColor;
          particles.spawnBurst(ball.x, ball.y, sparkColor, count: 1, speed: 65.0);
        }
      } else if (ball.speed > getBaseBallSpeed() * 1.15 && !activePowerUps.any((p) => p.type == PowerUpType.fastball) && !ball.isWallSpeedBoosted) {
        ball.setSpeed((ball.speed - dt * 140.0).clamp(getBaseBallSpeed(), 850.0));
      }

      // Collision with Easter Egg Bee
      if (activeBee != null && activeBee!.isAlive) {
        final bdx = ball.x - activeBee!.x;
        final bdy = ball.y - activeBee!.y;
        final distSq = bdx * bdx + bdy * bdy;
        final hitDist = ball.radius + activeBee!.hitRadius;
        if (distSq <= hitDist * hitDist) {
          final splatX = activeBee!.x;
          final splatY = activeBee!.y;
          activeBee!.isAlive = false;
          activeBee = null;
          activeSplat = WindshieldSplat(x: splatX, y: splatY, duration: 2.0);
          stats.score += 100;
          particles.spawnBurst(splatX, splatY, const Color(0xFFD31018), count: 24, speed: 110.0);
          particles.spawnFloatingText(splatX, splatY - 18.0, 'BZZZ! SPLAT! +100', const Color(0xFFFF1744), isLarge: true);
          audio.playSfx(GameSfx.breakBrick);
        }
      }

      // Anti-softlock: prevent ball from getting stuck horizontally or vertically forever
      if (!ball.isStuck && ball.vy.abs() < 28.0) {
        ball.vy = ball.vy >= 0 ? 35.0 : -35.0;
      }
      if (!ball.isStuck && ball.vx != 0.0 && ball.vx.abs() < 8.0) {
        ball.vx = ball.vx >= 0 ? 8.0 : -8.0;
      }

      // Black Hole gravity: the whole painted field bends the ball, not only the core.
      for (final bh in blackHoles) {
        final dx = bh.x - ball.x;
        final dy = bh.y - ball.y;
        final dist = sqrt(dx * dx + dy * dy);
        final maxInfluenceDist = bh.maxInfluenceDist;

        if (dist > 1.0 && dist < maxInfluenceDist) {
          final ballKey = ball.hashCode;
          final currentAngle = atan2(ball.y - bh.y, ball.x - bh.x);

          if (bh.ballAngles.containsKey(ballKey)) {
            final prevAngle = bh.ballAngles[ballKey]!;
            var delta = currentAngle - prevAngle;
            while (delta > pi) {
              delta -= 2 * pi;
            }
            while (delta < -pi) {
              delta += 2 * pi;
            }
            final oldAccum = bh.ballAccumulatedAngles[ballKey] ?? 0.0;
            final newAccum = oldAccum + delta.abs();
            bh.ballAccumulatedAngles[ballKey] = newAccum;

            final currentLaps = (newAccum / (2 * pi)).floor();
            final recordedLaps = bh.ballOrbitLaps[ballKey] ?? 0;
            if (currentLaps > recordedLaps) {
              bh.ballOrbitLaps[ballKey] = currentLaps;
              final currentSpd = ball.speed;
              if (bh.isSupercharged || bh.isVortexTrap) {
                final boostedSpeed = (currentSpd * 1.30).clamp(getBaseBallSpeed(), 760.0);
                ball.setSpeed(boostedSpeed);
                particles.spawnBurst(ball.x, ball.y, const Color(0xFFFF9100), count: 8, speed: 130.0);
                audio.playSfx(GameSfx.laser);
              } else {
                final boostedSpeed = (currentSpd * 1.15).clamp(getBaseBallSpeed(), 660.0);
                ball.setSpeed(boostedSpeed);
                particles.spawnBurst(ball.x, ball.y, const Color(0xFFE040FB), count: 5, speed: 80.0);
              }
            }
          }
          bh.ballAngles[ballKey] = currentAngle;

          final normalizedDist = (dist / maxInfluenceDist).clamp(0.0, 1.0);
          final proximity = 1.0 - normalizedDist;
          final falloff = pow(proximity, 0.65).toDouble();

          final sizeMult = (bh.radius / 20.0).clamp(1.0, 2.0);
          final basePull = (bh.isVortexTrap ? 5400.0 : (bh.isSupercharged ? 4400.0 : 3400.0)) * sizeMult;
          final pull = basePull * falloff;

          final nx = dx / dist;
          final ny = dy / dist;

          ball.vx += nx * pull * dt;
          ball.vy += ny * pull * dt;

          final tangentX = -ny;
          final tangentY = nx;
          final dotTangent = ball.vx * tangentX + ball.vy * tangentY;
          final dragDirection = dotTangent >= 0 ? 1.0 : -1.0;
          final spinDrag = (bh.isVortexTrap ? 1400.0 : (bh.isSupercharged ? 1100.0 : 850.0)) * falloff;
          ball.vx += tangentX * spinDrag * dragDirection * dt;
          ball.vy += tangentY * spinDrag * dragDirection * dt;

          if (proximity > 0.45 || dist < bh.radius * 3.5) {
            ball.vx += tangentX * 280.0 * dragDirection * dt;
            ball.vy += tangentY * 280.0 * dragDirection * dt;
            if (_rand.nextDouble() < 0.25) {
              particles.spawnBurnEmber(ball.x, ball.y, color: bh.isSupercharged ? const Color(0xFF00E5FF) : const Color(0xFFE040FB));
            }
          }

          if (dist <= bh.radius * 0.48 + ball.radius) {
            final exitSpeed = max(ball.speed * 1.15, getBaseBallSpeed() * 1.25).clamp(getBaseBallSpeed(), 820.0);
            ball.vx = tangentX * exitSpeed * dragDirection;
            ball.vy = tangentY * exitSpeed * dragDirection;
            particles.spawnBurst(ball.x, ball.y, const Color(0xFFFFD54F), count: 12, speed: 160.0);
            particles.spawnShockwave(bh.x, bh.y, const Color(0xFFE040FB), maxRadius: 45.0);
            audio.playSfx(GameSfx.cornerBoost);
          }

          final minSpeed = getBaseBallSpeed();
          if (ball.speed < minSpeed) {
            ball.setSpeed(minSpeed);
          }
          final maxAllowedSpeed = (bh.isSupercharged || bh.isVortexTrap || ball.isWallSpeedBoosted) ? 800.0 : 700.0;
          if (ball.speed > maxAllowedSpeed) {
            ball.setSpeed(maxAllowedSpeed);
          }
        } else {
          final ballKey = ball.hashCode;
          if ((bh.isSupercharged || bh.isVortexTrap) && (bh.ballAccumulatedAngles[ballKey] ?? 0.0) >= pi * 0.65) {
            final currentSpd = ball.speed;
            final slingshotSpeed = (currentSpd * 1.18).clamp(getBaseBallSpeed(), 760.0);
            ball.setSpeed(slingshotSpeed);
            particles.spawnBurst(ball.x, ball.y, const Color(0xFFFFD54F), count: 8, speed: 140.0);
            audio.playSfx(GameSfx.hitPaddle);
          }
          bh.ballAngles.remove(ballKey);
          bh.ballAccumulatedAngles.remove(ballKey);
          bh.ballOrbitLaps.remove(ballKey);
        }
      }

      // Portal teleportation
      if (ball.anomalyCooldown <= 0) {
        for (final p in portals) {
          final dx = p.x - ball.x;
          final dy = p.y - ball.y;
          if (dx * dx + dy * dy <= p.radius * p.radius && p.linkedPortal != null) {
            final target = p.linkedPortal!;
            final currentSpd = ball.speed > 0 ? ball.speed : getBaseBallSpeed();
            // Preserve ball direction vector, but ensure it never stalls
            var dirX = ball.vx / currentSpd;
            var dirY = ball.vy / currentSpd;
            if (dirX.abs() < 0.1 && dirY.abs() < 0.1) {
              dirY = -1.0;
              dirX = 0.0;
            }

            // Safe ejection distance outside target portal's event horizon
            final ejectDist = target.radius + ball.radius + 6.0;
            ball.x = (target.x + dirX * ejectDist).clamp(ball.radius + 8.0, screenWidth - ball.radius - 8.0);
            ball.y = (target.y + dirY * ejectDist).clamp(42.0, screenHeight - 60.0);
            ball.setSpeed(currentSpd.clamp(getBaseBallSpeed(), 850.0));
            ball.anomalyCooldown = 0.55;

            // Spawn portal warp effects
            particles.spawnBurst(p.x, p.y, p.color, count: 22, speed: 120.0);
            particles.spawnShockwave(p.x, p.y, p.color, maxRadius: 38.0);
            particles.spawnBurst(target.x, target.y, target.color, count: 26, speed: 140.0);
            particles.spawnShockwave(target.x, target.y, target.color, maxRadius: 44.0);
            audio.playSfx(GameSfx.ulti);
            break;
          }
        }
      }

      // Kaos modu anti-stuck & recall:
      if (currentMode == GameMode.chaos) {
        if (chaosRecallActive) {
          ball.vx *= 0.88;
          ball.vy = max(ball.vy, 760.0);
        } else {
          // Anti-bug / Anti-stuck:
          if (ball.vy.abs() < 80.0) {
            ball.vy = ball.vy >= 0 ? 100.0 : -100.0;
          }
          if (chaosTurnTime >= 26.0) {
            ball.vy = ball.vy.abs() + 260.0;
          }
        }
      }

      // Vortex Rescue Magnet: curves falling balls toward the center of the paddle!
      if (paddle.hasVortex &&
          currentMode != GameMode.chaos &&
          ball.vy > 0 &&
          ball.y > paddle.y - 210.0 &&
          ball.y <= paddle.y + 12.0) {
        final targetX = paddle.x + paddle.width / 2;
        final dx = targetX - ball.x;
        final dy = (paddle.y - ball.y).clamp(16.0, 210.0);
        final desiredVx = (dx / dy) * ball.vy.abs();
        ball.vx += (desiredVx - ball.vx) * (6.5 * dt).clamp(0.0, 1.0);
        ball.x += dx.clamp(-140.0, 140.0) * 2.8 * dt;
        final spd = ball.speed.clamp(getBaseBallSpeed(), 750.0);
        ball.setSpeed(spd);
      }

      // High-speed adaptive sub-stepping prevents tunneling through bricks or walls
      final maxStepDist = (currentMode == GameMode.chaos) ? 3.5 : 5.0;
      final stepDist = ball.speed * dt;
      final subSteps = max(currentMode == GameMode.chaos ? 3 : 1, (stepDist / maxStepDist).ceil()).clamp(1, 8);
      final subDt = dt / subSteps;
      // Trail length calibration requested by user:
      // Normal trail: 45% of full baseline length
      // Corner shot trail: 83% of peak maximum trail
      final fullBaseTrail = currentMode == GameMode.chaos ? 28 : (activeTrailSkin.length * 1.25).round();
      final normalTrail = (fullBaseTrail * 0.58).round().clamp(14, 40);
      final cornerTrail = (fullBaseTrail * 1.8 * 0.83).round().clamp(28, 80);
      final effectiveTrail = ball.cornerBoostTimer > 0 ? cornerTrail : normalTrail;
      for (int step = 0; step < subSteps; step++) {
        ball.update(
          subDt,
          trailLength: effectiveTrail,
          recordTrail: step == subSteps - 1,
        );

        // Wall collisions
        if (ball.x - ball.radius <= 0) {
          ball.x = ball.radius;
          ball.vx = ball.vx.abs();
          ball.triggerSquash(0);
          audio.playSfx(GameSfx.hitWall);
          ball.sideWallBounceCount++;
          if (ball.sideWallBounceCount >= 8) {
            ball.isWallSpeedBoosted = true;
            final boostedSpeed = max(ball.speed, getBaseBallSpeed() * 1.55);
            ball.setSpeed(boostedSpeed.clamp(100.0, 1050.0));
            particles.spawnBurst(ball.x, ball.y, const Color(0xFFFFD700), count: 6, speed: 120.0);
            audio.playSfx(GameSfx.wallBounce8);
          }
        } else if (ball.x + ball.radius >= screenWidth) {
          ball.x = screenWidth - ball.radius;
          ball.vx = -ball.vx.abs();
          ball.triggerSquash(pi);
          audio.playSfx(GameSfx.hitWall);
          ball.sideWallBounceCount++;
          if (ball.sideWallBounceCount >= 8) {
            ball.isWallSpeedBoosted = true;
            final boostedSpeed = max(ball.speed, getBaseBallSpeed() * 1.55);
            ball.setSpeed(boostedSpeed.clamp(100.0, 1050.0));
            particles.spawnBurst(ball.x, ball.y, const Color(0xFFFFD700), count: 6, speed: 120.0);
            audio.playSfx(GameSfx.wallBounce8);
          }
        }

        if (ball.y - ball.radius <= 36.0) {
          ball.y = 36.0 + ball.radius;
          ball.vy = ball.vy.abs();
          ball.triggerSquash(pi / 2);
          audio.playSfx(GameSfx.hitWall);
        }

        // Safety Net / Shield collision
        if (paddle.hasNet && ball.y + ball.radius >= screenHeight - 20.0) {
          ball.vy = -ball.vy.abs();
          paddle.netHitsRemaining--;
          if (paddle.netHitsRemaining <= 0) {
            paddle.hasNet = false;
            activePowerUps.removeWhere((p) => p.type == PowerUpType.shield || p.type == PowerUpType.net);
          }
          particles.spawnShockwave(ball.x, ball.y, const Color(0xFF8BC34A), maxRadius: 35.0);
          audio.playSfx(GameSfx.hitWall);
        }

        if (currentMode != GameMode.chaos && _checkBallPaddleCollision(ball)) {
          ball.sideWallBounceCount = 0;
          ball.isWallSpeedBoosted = false;
          break;
        }

        // Brick collision
        _checkBallBrickCollision(ball);
      }

      if (currentMode == GameMode.chaos) {
        if (ball.y > chaosFloorY) {
          if (!chaosHomeLocked) {
            chaosHomeX = ball.x.clamp(20.0, screenWidth - 20.0);
            chaosHomeLocked = true;
          }
          balls.removeAt(i);
          chaosReturned++;
          particles.spawnBurst(ball.x, chaosFloorY, const Color(0xFF00E5FF), count: 2, speed: 40.0);
          continue;
        }
      } else if (ball.y - ball.radius > screenHeight) {
        balls.removeAt(i);
        continue;
      }
    }

    if (currentMode == GameMode.chaos) {
      // Topların hepsinin aşağı inmesi beklensin:
      // Fırlatılacak top kalmadığında (chaosToLaunch == 0) ve havadaki tüm toplar zemine indiğinde (balls.isEmpty)
      // veya aşırı uzun süreli (28 saniye) güvenlik zaman aşımında tur tamamlansın.
      final volleyDone = status == GameStatus.playing && chaosToLaunch == 0 && chaosReturned > 0;
      if (volleyDone && (balls.isEmpty || chaosTurnTime > 28.0)) {
        balls.clear();
        _chaosAdvanceTurn();
      }
      return;
    }

    if (balls.isEmpty && levelTransitionTimer <= 0 && status == GameStatus.playing) {
      _loseLife();
    }
  }

  bool _checkBallPaddleCollision(Ball ball) {
    final pr = paddle.rect;
    if (ball.vy > 0 &&
        ball.y + ball.radius >= pr.top &&
        ball.y - ball.radius <= pr.bottom &&
        ball.x + ball.radius >= pr.left &&
        ball.x - ball.radius <= pr.right) {

      // Ghost paddle mechanic: Center 50% is hollow/permeable, wings (25% each) are solid
      if (paddle.isGhost) {
        final leftBoundary = paddle.x + paddle.width * 0.25;
        final rightBoundary = paddle.x + paddle.width * 0.75;
        if (ball.x >= leftBoundary && ball.x <= rightBoundary) {
          return false; // Ball passes through the hollow center
        }
      }

      if (ball.isDayBlessed) ball.isDayBlessed = false;
      if (paddle.isSticky) {
        ball.isStuck = true;
        ball.stuckTimer = 0.0;
        ball.stuckOffsetX = ball.x - paddle.x;
        ball.vy = 0;
        ball.vx = 0;
        ball.trail.clear(); // Yapışkan raket tuttuğunda iz tamamen yok olur, havada asılı kalmaz!
        audio.playSfx(GameSfx.hitPaddle);
        return true;
      }

      // Hit point on paddle (-1.0 left to 1.0 right)
      double hitOffset;
      if (paddle.isGhost) {
        final wingWidth = paddle.width * 0.25;
        if (ball.x < paddle.x + wingWidth) {
          // Left wing: ball.x from paddle.x to paddle.x + wingWidth
          // Map to [-1.0, -0.2] (outer tip -> steep left, inner edge -> slight left)
          final t = ((ball.x - paddle.x) / wingWidth).clamp(0.0, 1.0);
          hitOffset = -1.0 + t * 0.8;
        } else {
          // Right wing: ball.x from paddle.x + 0.75 * paddle.width to paddle.x + paddle.width
          // Map to [0.2, 1.0] (inner edge -> slight right, outer tip -> steep right)
          final t = ((ball.x - (paddle.x + paddle.width * 0.75)) / wingWidth).clamp(0.0, 1.0);
          hitOffset = 0.2 + t * 0.8;
        }
      } else {
        hitOffset = ((ball.x - (paddle.x + paddle.width / 2)) / (paddle.width / 2)).clamp(-1.0, 1.0);
      }

      final bounceAngle = hitOffset * (pi / 2.7); // -66 deg to +66 deg
      // Step 2: Capped speed escalation (keep within human reaction limits)
      final baseSpeed = min(ball.speed + 4.0, 580.0);

      // Corner hit detection (outer 22% of paddle)
      final isCornerHit = hitOffset.abs() >= 0.78;
      final speedMultiplier = isCornerHit ? 1.35 : 1.0;
      final finalSpeed = (baseSpeed * speedMultiplier).clamp(100.0, 680.0);

      var vx = sin(bounceAngle) * finalSpeed;
      var vy = -cos(bounceAngle) * finalSpeed;

      // Spin transfer
      vx += paddle.velocityX * 0.25;

      // Step 1: Endgame Pacing - Micro-nudge targeting towards remaining 1-2 bricks if stalled > 10s
      final remainingAliveBricks = bricks.where((b) => b.isAlive && !b.isSteel).toList();
      if (remainingAliveBricks.isNotEmpty && remainingAliveBricks.length <= 2 && endgameStallTimer >= 10.0) {
        final targetBrick = remainingAliveBricks.first;
        final targetCenterX = targetBrick.x + targetBrick.width / 2;
        final targetCenterY = targetBrick.y + targetBrick.height / 2;
        final dx = targetCenterX - ball.x;
        final dy = targetCenterY - pr.top;
        final desiredAngle = atan2(dx, -dy); // upward heading angle
        final clampedDesiredAngle = desiredAngle.clamp(-pi / 2.8, pi / 2.8);
        // Blend current bounce angle with target angle gently (12% steer)
        final blendedAngle = bounceAngle * 0.88 + clampedDesiredAngle * 0.12;
        vx = sin(blendedAngle) * finalSpeed;
        vy = -cos(blendedAngle) * finalSpeed;
      }

      ball.vx = vx;
      ball.vy = vy;

      ball.y = pr.top - ball.radius - 1.0;
      ball.triggerSquash(-pi / 2);

      if (isCornerHit) {
        ball.cornerHitCount++;
        ball.cornerBoostTimer = 3.2; // Speeds up for 3.2 seconds

        // Outer 10% tip save bonus (silent bonus, no extra overlapping text!)
        final isClutchSave = hitOffset.abs() >= 0.90 && balls.length == 1;
        if (isClutchSave) {
          stats.score += 150;
        }
        stats.ultiCharge = (stats.ultiCharge + 3.0).clamp(0.0, 100.0);

        if (ball.cornerHitCount >= 8) {
          ball.isPurple = true;
          ball.cornerHitCount = 0; // reset after triggering
          particles.spawnBurst(ball.x, pr.top, const Color(0xFFD500F9), count: 50, speed: 150.0);
          particles.spawnFloatingText(ball.x, pr.top - 24, I18n.tr('purple_fever'), const Color(0xFFD500F9), isLarge: true);
          audio.playSfx(GameSfx.ulti);
        } else {
          // Visual boost only - no fireball powerup! 
          particles.spawnBurst(ball.x, pr.top, const Color(0xFFFF6D00), count: 30, speed: 120.0);
          particles.spawnShockwave(ball.x, pr.top, const Color(0xFFFFD600), maxRadius: 48.0);
          particles.spawnFloatingText(ball.x, pr.top - 18, I18n.tr('corner_shot'), const Color(0xFFFF6D00), isLarge: true);
          audio.playSfx(GameSfx.cornerBoost);
        }
      } else {
        ball.cornerHitCount = 0; // Reset consecutive hits
        particles.spawnShockwave(ball.x, pr.top, activePaddleSkin.glowColor, maxRadius: 32.0);
        audio.playSfx(GameSfx.hitPaddle);
      }

      // Alev topunun raket sekme dayanıklılığı: 3 raket dönüşünden sonra söner
      if (ball.isFireball || ball.isPierce) {
        ball.fireballPaddleBounces++;
        if (ball.fireballPaddleBounces >= 3) {
          ball.isFireball = false;
          ball.isPierce = false;
          activePowerUps.removeWhere((p) => p.type == PowerUpType.fireball || p.type == PowerUpType.pierce);
          particles.spawnBurst(ball.x, pr.top, const Color(0xFFFF9100), count: 16, speed: 100.0);
        }
      }
      return true;
    }
    return false;
  }

  void _checkBallBrickCollision(Ball ball) {
    final r = ball.radius;
    final rSq = r * r;
    final bx = ball.x;
    final by = ball.y;

    // 1. Dikey İstif Dikiş Bariyeri (Vertical Seam Barrier):
    // Kaos modunda (ve tüm modlarda) alt alta dizili iki bloğun arasındaki mesafe topun çapından küçükse (örn: 8px < 15px),
    // bu iki blok sol ve sağ yüzeylerinde birleşik, kesintisiz dikey bir duvar oluşturur.
    // Top bu boşluğa yatay olarak giremez/içinden geçemez; dış sınırdan pürüzsüzce geri yansır.
    for (int i = 0; i < bricks.length; i++) {
      final b1 = bricks[i];
      if (!b1.isAlive || b1.isBallPickup || b1.isTuft) continue;

      for (int j = i + 1; j < bricks.length; j++) {
        final b2 = bricks[j];
        if (!b2.isAlive || b2.isBallPickup || b2.isTuft) continue;

        final topBrick = b1.y < b2.y ? b1 : b2;
        final botBrick = b1.y < b2.y ? b2 : b1;

        final vGap = botBrick.y - (topBrick.y + topBrick.height);
        if (vGap < -2.0 || vGap >= 2.0 * r) continue;

        final overlapLeft = max(topBrick.x, botBrick.x);
        final overlapRight = min(topBrick.x + topBrick.width, botBrick.x + botBrick.width);
        if (overlapRight - overlapLeft < 4.0) continue;

        final seamTop = topBrick.y + topBrick.height;
        final seamBottom = botBrick.y;

        // Top bu dikey aralık dikişine temas ediyor mu?
        if (by + r >= seamTop && by - r <= seamBottom) {
          final targetBrick = (by - (topBrick.y + topBrick.height / 2)).abs() <
                  (by - (botBrick.y + botBrick.height / 2)).abs()
              ? topBrick
              : botBrick;

          // Soldan dikişe giriş engelleme:
          if (bx + r >= overlapLeft && bx - r <= overlapLeft + 8.0 && ball.vx > 0) {
            _hitBrick(targetBrick, ball);
            if (!ball.isFireball && !ball.isPierce) {
              ball.vx = -ball.vx.abs();
              ball.x = overlapLeft - r - 0.1;
              ball.triggerSquash(pi);
            }
            return;
          }
          // Sağdan dikişe giriş engelleme:
          if (bx - r <= overlapRight && bx + r >= overlapRight - 8.0 && ball.vx < 0) {
            _hitBrick(targetBrick, ball);
            if (!ball.isFireball && !ball.isPierce) {
              ball.vx = ball.vx.abs();
              ball.x = overlapRight + r + 0.1;
              ball.triggerSquash(0);
            }
            return;
          }
          // Aşırı hız vb. nedeniyle dikişin içine sızmış topu güvenli dış tarafa tahliye etme:
          if (bx >= overlapLeft && bx <= overlapRight) {
            _hitBrick(targetBrick, ball);
            if (!ball.isFireball && !ball.isPierce) {
              if (ball.vx >= 0) {
                ball.vx = -ball.vx.abs();
                ball.x = overlapLeft - r - 0.1;
              } else {
                ball.vx = ball.vx.abs();
                ball.x = overlapRight + r + 0.1;
              }
              ball.triggerSquash(ball.vx < 0 ? pi : 0);
            }
            return;
          }
        }
      }
    }

    // 2. Standart blok çarpışma döngüsü
    for (final b in bricks) {
      if (!b.isAlive) continue;

      // Fast AABB broadphase rejection
      if (by + r < b.y || by - r > b.y + b.height || bx + r < b.x || bx - r > b.x + b.width) {
        continue;
      }

      final nearestX = bx.clamp(b.x, b.x + b.width);
      final nearestY = by.clamp(b.y, b.y + b.height);
      final distX = bx - nearestX;
      final distY = by - nearestY;
      final distSq = distX * distX + distY * distY;

      if (distSq <= rSq) {
        if (b.isBallPickup) {
          b.isAlive = false;
          chaosPendingExtraBalls++;
          particles.spawnBurst(b.x + b.width / 2, b.y + b.height / 2, const Color(0xFF00E5FF), count: 18, speed: 110.0);
          particles.spawnShockwave(b.x + b.width / 2, b.y + b.height / 2, const Color(0xFF00E5FF), maxRadius: 36.0);
          particles.spawnFloatingText(b.x + b.width / 2, b.y - 12.0, I18n.tr('plus_one_ball'), const Color(0xFF00E5FF), isLarge: true);
          audio.playSfx(GameSfx.powerupBuff);
          continue;
        }

        // Hit brick!
        _hitBrick(b, ball);

        // Alev topu dayanıklılık/delme kotası tüketimi
        if (ball.isFireball || ball.isPierce) {
          ball.fireballPierceCount--;
          if (ball.fireballPierceCount <= 0) {
            ball.isFireball = false;
            ball.isPierce = false;
            activePowerUps.removeWhere((p) => p.type == PowerUpType.fireball || p.type == PowerUpType.pierce);
            particles.spawnBurst(ball.x, ball.y, const Color(0xFFFF9100), count: 12, speed: 90.0);
          }
        }

        if (!ball.isFireball && !ball.isPierce && !b.isTuft) {
          final dist = sqrt(distSq);
          double nx, ny;
          if (dist > 0.0001) {
            nx = distX / dist;
            ny = distY / dist;
          } else {
            // Ball center is inside or on the brick edge, determine closest exit face
            final dLeft = (bx - b.x).abs();
            final dRight = ((b.x + b.width) - bx).abs();
            final dTop = (by - b.y).abs();
            final dBottom = ((b.y + b.height) - by).abs();
            final minD = min(min(dLeft, dRight), min(dTop, dBottom));
            if (minD == dLeft) { nx = -1.0; ny = 0.0; }
            else if (minD == dRight) { nx = 1.0; ny = 0.0; }
            else if (minD == dTop) { nx = 0.0; ny = -1.0; }
            else { nx = 0.0; ny = 1.0; }
          }

          // İç Kenar / Hayalet Köşe Düzeltmesi (Neighbor-Aware Normal Clamping):
          // Eğer bloğun altında veya üstünde ball çapından (< 2*r) daha yakın komşu blok varsa,
          // o dikişe doğru sekme normali oluşturulamaz, top duvardan yatay olarak yansıtılır.
          if (ny > 0.001) {
            final hasNeighborBelow = bricks.any((other) =>
                other != b &&
                other.isAlive &&
                !other.isBallPickup &&
                !other.isTuft &&
                other.y >= b.y + b.height - 2.0 &&
                other.y <= b.y + b.height + 2.0 * r &&
                (min(b.x + b.width, other.x + other.width) - max(b.x, other.x) > 4.0));
            if (hasNeighborBelow) {
              ny = 0.0;
              nx = (bx < b.x + b.width / 2) ? -1.0 : 1.0;
            }
          } else if (ny < -0.001) {
            final hasNeighborAbove = bricks.any((other) =>
                other != b &&
                other.isAlive &&
                !other.isBallPickup &&
                !other.isTuft &&
                other.y + other.height >= b.y - 2.0 * r &&
                other.y + other.height <= b.y + 2.0 &&
                (min(b.x + b.width, other.x + other.width) - max(b.x, other.x) > 4.0));
            if (hasNeighborAbove) {
              ny = 0.0;
              nx = (bx < b.x + b.width / 2) ? -1.0 : 1.0;
            }
          }

          final nLen = sqrt(nx * nx + ny * ny);
          if (nLen > 0.0001) {
            nx /= nLen;
            ny /= nLen;
          }

          final dot = ball.vx * nx + ball.vy * ny;
          if (dot < 0) {
            // Real-world continuous velocity reflection: v' = v - 2 * (v . n) * n
            ball.vx -= 2.0 * dot * nx;
            ball.vy -= 2.0 * dot * ny;
            // Position adjustment along contact normal to prevent sticking/tunneling
            ball.x = nearestX + nx * (r + 0.1);
            ball.y = nearestY + ny * (r + 0.1);
            ball.triggerSquash(atan2(ny, nx));

            // Anti-pinch: If trapped bouncing > 4 times in under 0.15s between adjacent bricks, nudge outward
            ball.rapidBounceCount++;
            ball.rapidBounceTimer = 0.15;
            if (ball.rapidBounceCount >= 5) {
              ball.x += nx * 2.5;
              ball.y += (ny != 0 ? ny : 1.0) * 2.5;
              ball.rapidBounceCount = 0;
            }
          }
        }

        if (ball.isBomb) {
          _explodeArea(b.x + b.width / 2, b.y + b.height / 2, radius: 55.0);
        }
        if (!b.isTuft) {
          break;
        }
      }
    }
  }

  void _hitBrick(Brick b, Ball? ball) {
    if (b.isSteel) {
      if (ball != null && ball.isFireball) {
        // Fireball melts steel!
        ball.sideWallBounceCount = 0;
        if (ball.isWallSpeedBoosted) {
          ball.isWallSpeedBoosted = false;
          ball.setSpeed(getBaseBallSpeed());
        }
        _destroyBrick(b);
      } else {
        b.jelly = 1.0;
        particles.spawnBurst(b.x + b.width / 2, b.y + b.height / 2, Colors.grey, count: 6);
        audio.playSfx(GameSfx.steel);
      }
      return;
    }

    if (ball != null) {
      final wasBoosted = ball.isWallSpeedBoosted;
      ball.sideWallBounceCount = 0;
      ball.isWallSpeedBoosted = false;
      if (wasBoosted) {
        ball.setSpeed(getBaseBallSpeed());
      }
    }

    if (b.isFrozen) {
      b.isFrozen = false;
      particles.spawnBurst(b.x + b.width / 2, b.y + b.height / 2, const Color(0xFF80D8FF), count: 20);
      particles.spawnShockwave(b.x + b.width / 2, b.y + b.height / 2, const Color(0xFF00E5FF), maxRadius: 30.0);
      audio.playSfx(GameSfx.breakBrick);
      return;
    }
    if (b.isTuft) {
      if (!b.tuftFilled) {
        b.tuftFilled = true;
        b.color = b.tuftColor;
        particles.spawnBurst(b.x + b.width / 2, b.y + b.height / 2, b.tuftColor, count: 8);
        audio.playSfx(GameSfx.hitBrick);
        _registerCombo(b.points);
      }
      return;
    }

    if (currentMode == GameMode.chaos) {
      b.hp--;
      b.jelly = 0.35;
      stats.score += 1;
      if (b.hp <= 0) {
        _destroyBrick(b);
      } else if (b.hp % 6 == 0) {
        audio.playSfx(GameSfx.hitBrick);
      }
      return;
    }

    b.hp--;
    b.jelly = 0.8;
    endgameStallTimer = 0.0;

    if (b.hp <= 0) {
      _destroyBrick(b);
    } else {
      particles.spawnBurst(b.x + b.width / 2, b.y + b.height / 2, b.color, count: 6);
      if (b.isBoss) {
        audio.playSfx(GameSfx.bossHit);
        particles.triggerShake(4.0, 0.16);
        if (b.hp <= b.maxHp * 0.5) {
          particles.spawnBurst(b.x + b.width / 2, b.y + b.height / 2, const Color(0xFFFF1744), count: 8, speed: 100.0);
          if (!_bossEnrageAnnounced) {
            _bossEnrageAnnounced = true;
            particles.triggerShake(7.5, 0.35);
            particles.spawnShockwave(b.x + b.width / 2, b.y + b.height / 2, const Color(0xFFFF1744), maxRadius: 95.0);
            particles.spawnFloatingText(screenWidth / 2, screenHeight * 0.35, I18n.tr('boss_enraged'), const Color(0xFFFF1744), isLarge: true);
          }
        }
      } else {
        audio.playSfx(GameSfx.hitBrick);
      }
      _registerCombo(b.points ~/ 2);
    }
  }

  int _rollDiceBlockGap() => 3 + ((DateTime.now().microsecond % 2) * 2);

  void _chargeDiceFromGlass(Brick b) {
    if (b.isBoss || b.isSteel || b.isTuft) return;
    _glassBreaksTowardDice++;
    if (_glassBreaksTowardDice < _blocksUntilDicePoint) return;
    _glassBreaksTowardDice = 0;
    _blocksUntilDicePoint = _rollDiceBlockGap();
    stats.ultiCharge = (stats.ultiCharge + 1.0).clamp(0.0, 100.0);
  }

  void _destroyBrick(Brick b) {
    b.isAlive = false;
    stats.bricksBroken++;
    save.recordBrickBrokenQuest();
    _chargeDiceFromGlass(b);
    if (currentMode == GameMode.classic && stats.level <= 3 && !save.seenFirstShot) {
      save.markFirstShotSeen();
      showOnceTip('first_break', I18n.tr('tip_first_break'));
    }

    // Geometric physical shard explosion!
    particles.spawnBrickShards(b.x, b.y, b.width, b.height, b.color, count: b.isBoss ? 16 : 6);

    if (currentMode == GameMode.chaos) {
      particles.spawnBurst(b.x + b.width / 2, b.y + b.height / 2, b.color, count: 4);
      audio.playSfx(GameSfx.breakBrick);
      stats.score += 15;
      _checkLiveNewRecordCelebration();
      if (!bricks.any((br) => br.isAlive && !br.isBallPickup)) {
        _chaosAllSolidBroken = true;
      }
      return;
    }

    if (b.isBoss) {
      particles.triggerShake(9.0, 0.4);
      particles.spawnBurst(b.x + b.width / 2, b.y + b.height / 2, const Color(0xFFFFD700), count: 32, speed: 190.0);
      particles.spawnShockwave(b.x + b.width / 2, b.y + b.height / 2, const Color(0xFFFF1744), maxRadius: 100.0);
      particles.spawnFloatingText(b.x + b.width / 2, b.y - 20, I18n.tr('boss_defeated'), const Color(0xFFFFD700), isLarge: true);
      stats.score += 500;
      audio.playSfx(GameSfx.explosion);
    } else {
      particles.spawnBurst(b.x + b.width / 2, b.y + b.height / 2, b.color, count: 16);
      particles.spawnShockwave(b.x + b.width / 2, b.y + b.height / 2, b.color, maxRadius: 40.0);
      audio.playSfx(GameSfx.breakBrick);
    }

    _registerCombo(b.points);

    if (b.isDynamite) {
      _explodeArea(b.x + b.width / 2, b.y + b.height / 2, radius: 80.0);
    } else if (b.isIce) {
      _freezeArea(b.x + b.width / 2, b.y + b.height / 2, radius: 90.0);
    }

    // Roll powerup drop
    _rollCapsuleDrop(b.x + b.width / 2, b.y + b.height / 2);

    // Balanced coin gain: 30% drop rate, 2-5 coins + combo bonus
    if (_rand.nextDouble() < 0.30) {
      int coins = 2 + _rand.nextInt(4);
      if (stats.combo >= 5) coins += 2;
      stats.goldCollected += coins;
      save.addGold(coins);
      particles.spawnFloatingText(b.x + b.width / 2, b.y, '+$coins ', const Color(0xFFFFD54F));
    }
  }

  void _freezeArea(double cx, double cy, {double radius = 80.0}) {
    particles.spawnBurst(cx, cy, const Color(0xFF80D8FF), count: 28, speed: 200.0);
    particles.spawnShockwave(cx, cy, const Color(0xFF00E5FF), maxRadius: radius);
    audio.playSfx(GameSfx.breakBrick);

    final candidates = bricks.where((b) {
      if (!b.isAlive || b.isSteel || b.isTuft || b.isFrozen) return false;
      final bx = b.x + b.width / 2;
      final by = b.y + b.height / 2;
      final dist = sqrt((bx - cx) * (bx - cx) + (by - cy) * (by - cy));
      return dist <= radius;
    }).toList();

    candidates.shuffle(_rand);
    final count = min(candidates.length, 2 + _rand.nextInt(3)); // 2 to 4 blocks
    for (int i = 0; i < count; i++) {
      final b = candidates[i];
      b.isFrozen = true;
      particles.spawnBurst(b.x + b.width / 2, b.y + b.height / 2, const Color(0xFFE0F7FA), count: 8);
    }
  }

  void _explodeArea(double cx, double cy, {double radius = 60.0}) {
    particles.spawnBurst(cx, cy, const Color(0xFFFF5722), count: 28, speed: 240.0);
    particles.spawnShockwave(cx, cy, const Color(0xFFFF9800), maxRadius: radius);
    particles.triggerShake(5.0, 0.22);
    audio.playSfx(GameSfx.explosion);

    for (final b in bricks) {
      if (!b.isAlive || b.isSteel) continue;
      final bx = b.x + b.width / 2;
      final by = b.y + b.height / 2;
      final dist = sqrt((bx - cx) * (bx - cx) + (by - cy) * (by - cy));
      if (dist <= radius) {
        _destroyBrick(b);
      }
    }
  }

  void _checkLiveNewRecordCelebration() {
    if (!_hasCelebratedNewRecord && _sessionStartingBestScore > 0 && stats.score > _sessionStartingBestScore) {
      _hasCelebratedNewRecord = true;
      particles.spawnShockwave(screenWidth / 2, screenHeight * 0.32, const Color(0xFFFFD700), maxRadius: 110.0);
      particles.spawnBurst(screenWidth / 2, screenHeight * 0.32, const Color(0xFFFFD54F), count: 35, speed: 210.0);
      particles.spawnFloatingText(screenWidth / 2, screenHeight * 0.32, I18n.tr('new_record_broken'), const Color(0xFFFFD700), isLarge: true);
      audio.playSfx(GameSfx.victory);
    }
  }

  void _registerCombo(int basePoints) {
    stats.combo++;
    if (stats.combo > stats.maxCombo) {
      stats.maxCombo = stats.combo;
    }
    comboTimer = 2.4;

    double multiplier = 1.0;
    if (stats.combo >= 8) {
      multiplier = 3.0;
      if (!stats.isFever) {
        stats.isFever = true;
        stats.feverTimeLeft = 6.0;
        particles.spawnFloatingText(screenWidth / 2, screenHeight * 0.35, I18n.tr('fever_mode'), const Color(0xFFFF9100), isLarge: true);
      }
    } else if (stats.combo >= 4) {
      multiplier = 2.0;
    }

    if (activePowerUps.any((p) => p.type == PowerUpType.doublescore)) {
      multiplier *= 2.0;
    }

    final points = (basePoints * multiplier).round();
    stats.score += points;
    _checkLiveNewRecordCelebration();

    // Step 5: Arcade Combo Juice (Milestone floating text and micro-shakes)
    if (stats.combo == 3) {
      particles.spawnFloatingText(
        paddle.x + paddle.width / 2,
        paddle.y - 28.0, ' TRIPLE HIT x3!',
        const Color(0xFF00E5FF),
        isLarge: true,
      );
      particles.triggerShake(2.0, 0.12);
    } else if (stats.combo == 5) {
      particles.spawnFloatingText(
        paddle.x + paddle.width / 2,
        paddle.y - 32.0, ' MEGA COMBO x5!',
        const Color(0xFFFF9100),
        isLarge: true,
      );
      particles.triggerShake(3.5, 0.18);
    } else if (stats.combo >= 8 && stats.combo % 4 == 0) {
      particles.spawnFloatingText(
        paddle.x + paddle.width / 2,
        paddle.y - 36.0, ' ULTRA COMBO x${stats.combo}!',
        const Color(0xFFD500F9),
        isLarge: true,
      );
      particles.triggerShake(5.0, 0.22);
    } else if (stats.combo > 1 && stats.combo % 3 == 0) {
      particles.spawnFloatingText(
        paddle.x + paddle.width / 2,
        paddle.y - 28.0, '${I18n.tr('combo')} x${stats.combo}!',
        const Color(0xFFFFD54F),
      );
    }
  }

  void _rollCapsuleDrop(double x, double y) {
    if (activePowerUps.length >= 3) return; // Limit to 3 active power-ups
    final luckLevel = save.upgrades['luck'] ?? 0;
    final dropChance = 0.14 + luckLevel * 0.04;
    if (_rand.nextDouble() > dropChance) return;

    final allTypes = PowerUpType.values;
    // Luck tilts towards buffs (exclude mirror, multi, and pierce from random drops)
    PowerUpType chosen;
    if (_rand.nextDouble() < 0.78 + luckLevel * 0.05) {
      var buffs = allTypes.where((t) => t.kind == PowerUpKind.buff && t != PowerUpType.mirror && t != PowerUpType.multi && t != PowerUpType.pierce && t != PowerUpType.drone).toList();
      if (currentMode == GameMode.classic && stats.level < 4) {
        buffs = buffs.where((t) => t != PowerUpType.vortex).toList();
      }
      if (buffs.isEmpty) return;
      chosen = buffs[_rand.nextInt(buffs.length)];
      
      // KURAL: Ateş topu ve Roket çok daha nadir çıkmalı (0.88 oranında tekrar kura çekilir, çok nadir düşer)
      if ((chosen == PowerUpType.fireball || chosen == PowerUpType.rocket) && _rand.nextDouble() < 0.88) {
        chosen = buffs[_rand.nextInt(buffs.length)];
      }
    } else {
      final debuffs = allTypes.where((t) => t.kind == PowerUpKind.debuff).toList();
      chosen = debuffs[_rand.nextInt(debuffs.length)];
    }

    capsules.add(FallingCapsule(x: x, y: y, type: chosen));
    showOnceTip('capsule', I18n.tr('tip_capsule'));
  }

  /// 1–3 çoğu zaman. 4, 5 ve 6 seyrek. Üst sınır 6.
  int _rollLaserShots() {
    const weights = [36, 30, 20, 8, 4, 2];
    final roll = _rand.nextInt(100);
    var cursor = 0;
    for (var i = 0; i < weights.length; i++) {
      cursor += weights[i];
      if (roll < cursor) return i + 1;
    }
    return 1;
  }

  void applyPowerUp(PowerUpType type) {
    audio.playSfx(type.kind == PowerUpKind.buff ? GameSfx.powerupBuff : GameSfx.powerupDebuff);
    particles.spawnFloatingText(paddle.x + paddle.width / 2, paddle.y - 30.0, type.label, type.color);

    if (type.isInstant) {
      switch (type) {
        case PowerUpType.multi:
          _splitBalls();
          break;
        case PowerUpType.life:
          stats.lives++;
          break;
        case PowerUpType.mirror:
          if (balls.isNotEmpty) {
            final first = balls.first;
            final hasFireball = activePowerUps.any((p) => p.type == PowerUpType.fireball) || first.isFireball;
            final hasBomb = activePowerUps.any((p) => p.type == PowerUpType.bomb) || first.isBomb;
            final hasPierce = activePowerUps.any((p) => p.type == PowerUpType.pierce) || first.isPierce;
            balls.add(Ball(
              x: (screenWidth - first.x).clamp(20.0, screenWidth - 20.0),
              y: first.y,
              vx: -first.vx,
              vy: first.vy,
              radius: first.radius,
              isStuck: false,
              isMirror: true,
              isFireball: hasFireball,
              isBomb: hasBomb,
              isPierce: hasPierce,
            ));
          }
          break;
        case PowerUpType.lock:
          final aliveBricks = bricks.where((b) => b.isAlive && !b.isSteel).toList();
          if (aliveBricks.isNotEmpty) {
            final target = aliveBricks[_rand.nextInt(aliveBricks.length)];
            final tx = target.x + target.width / 2;
            final ty = target.y + target.height / 2;
            // High-tech cyber targeting reticle & orbital laser beam effect:
            particles.spawnShockwave(tx, ty, const Color(0xFF00E5FF), maxRadius: 42.0);
            particles.spawnShockwave(tx, ty, const Color(0xFFFF1744), maxRadius: 26.0);
            particles.spawnBurst(tx, ty, const Color(0xFF00E5FF), count: 12, speed: 140.0);
            particles.spawnBurst(tx, ty, const Color(0xFFFFD54F), count: 12, speed: 110.0);
            audio.playSfx(GameSfx.laser);
            _destroyBrick(target);
            particles.spawnFloatingText(tx, target.y - 12, '[+] ${I18n.tr('target_locked')}', const Color(0xFF00E5FF), isLarge: true);
          }
          break;
        case PowerUpType.rocket:
          paddle.hasRockets = true;
          paddle.rocketAmmo = _rand.nextInt(11) + 1; // 1 to 11 random shots
          particles.spawnFloatingText(paddle.x + paddle.width / 2, paddle.y - 15, '${paddle.rocketAmmo}${I18n.tr('rocket_ammo_suffix')}', const Color(0xFFFF5722), isLarge: true);
          break;
        default:
          break;
      }
      return;
    }

    // Remove existing if already present, and cancel mutually exclusive opposing powerups!
    activePowerUps.removeWhere((p) {
      if (p.type == type) return true;
      if ((type == PowerUpType.wide && p.type == PowerUpType.shrink) ||
          (type == PowerUpType.shrink && p.type == PowerUpType.wide)) {
        return true;
      }
      if ((type == PowerUpType.slow && p.type == PowerUpType.fastball) ||
          (type == PowerUpType.fastball && p.type == PowerUpType.slow)) {
        return true;
      }
      return false;
    });

    // Active power-up balance: max 2 if multiple balls, else max 3
    final maxActive = (balls.length > 1) ? 2 : 3;
    while (activePowerUps.length >= maxActive) {
      final oldest = activePowerUps.removeAt(0);
      _removePowerUp(oldest.type);
    }
    activePowerUps.add(ActivePowerUp(type));

    switch (type) {
      case PowerUpType.wide:
        paddle.width = paddle.baseWidth * 1.45;
        break;
      case PowerUpType.shrink:
        paddle.width = paddle.baseWidth * 0.65;
        break;
      case PowerUpType.slow:
        for (final b in balls) {
          b.setSpeed(getBaseBallSpeed() * 0.65);
        }
        break;
      case PowerUpType.fastball:
        for (final b in balls) {
          b.setSpeed(getBaseBallSpeed() * 1.8);
        }
        break;
      case PowerUpType.sticky:
        paddle.isSticky = true;
        break;
      case PowerUpType.laser:
        paddle.hasLaser = true;
        paddle.laserAmmo = _rollLaserShots();
        laserTimer = 0.65;
        particles.spawnFloatingText(
          paddle.x + paddle.width / 2,
          paddle.y - 15,
          '${paddle.laserAmmo}${I18n.tr('laser_ammo_suffix')}',
          const Color(0xFFFFD740),
          isLarge: true,
        );
        break;
      case PowerUpType.rocket:
        paddle.hasRockets = true;
        break;
      case PowerUpType.fireball:
      case PowerUpType.pierce:
        for (final b in balls) {
          b.isFireball = true;
          b.isPierce = true;
          b.fireballPierceCount = 12; // 12 tuğla delme hakkı
          b.fireballPaddleBounces = 0; // 3 raket sekme dayanıklılığı
        }
        break;
      case PowerUpType.bomb:
        for (final b in balls) {
          b.isBomb = true;
        }
        break;
      case PowerUpType.shield:
      case PowerUpType.net:
        paddle.hasNet = true;
        paddle.netHitsRemaining = 1;
        break;
      case PowerUpType.drone:
        paddle.hasDrone = true;
        break;
      case PowerUpType.chrono:
        stats.bulletTimeLeft = 4.5;
        break;
      case PowerUpType.vortex:
        if (!_blackHolesAllowed) break;
        paddle.hasVortex = true;
        double lowestAliveBrickY = 0.0;
        for (final b in bricks) {
          if (b.isAlive && (b.y + b.height) > lowestAliveBrickY) {
            lowestAliveBrickY = b.y + b.height;
          }
        }
        final minY = lowestAliveBrickY + 45.0;
        final maxY = paddle.y - 170.0;
        final spawnY = maxY > minY ? (minY + (maxY - minY) * 0.5) : maxY;
        final spawnX = (paddle.x + paddle.width / 2).clamp(48.0, screenWidth - 48.0);
        for (final bh in blackHoles) {
          bh.timeLeft = 9.0;
        }
        blackHoles.add(
          BlackHole(
            x: spawnX,
            y: spawnY,
            radius: 30.0,
            mass: 30.0 * 5000.0,
            timeLeft: 9.0,
            isSupercharged: true,
          ),
        );
        break;
      case PowerUpType.reverse:
        paddle.isReversed = true;
        break;
      case PowerUpType.clumsy:
        paddle.isClumsy = true;
        break;
      case PowerUpType.invis:
        paddle.isGhost = true;
        break;
      default:
        break;
    }
  }

  void _removePowerUp(PowerUpType type) {
    switch (type) {
      case PowerUpType.wide:
      case PowerUpType.shrink:
        paddle.resetWidth();
        break;
      case PowerUpType.slow:
      case PowerUpType.fastball:
        for (final b in balls) {
          b.setSpeed(getBaseBallSpeed());
        }
        break;
      case PowerUpType.sticky:
        paddle.isSticky = false;
        launchBall();
        break;
      case PowerUpType.laser:
        paddle.hasLaser = false;
        paddle.laserAmmo = 0;
        break;
      case PowerUpType.rocket:
        paddle.hasRockets = false;
        break;
      case PowerUpType.fireball:
      case PowerUpType.pierce:
        if (!activePowerUps.any((p) => p.type == PowerUpType.fireball || p.type == PowerUpType.pierce)) {
          for (final b in balls) {
            b.isFireball = false;
            b.isPierce = false;
          }
        }
        break;
      case PowerUpType.bomb:
        for (final b in balls) {
          b.isBomb = false;
        }
        break;
      case PowerUpType.shield:
      case PowerUpType.net:
        paddle.hasNet = false;
        break;
      case PowerUpType.drone:
        paddle.hasDrone = false;
        break;
      case PowerUpType.vortex:
        paddle.hasVortex = false;
        break;
      case PowerUpType.reverse:
        paddle.isReversed = false;
        break;
      case PowerUpType.clumsy:
        paddle.isClumsy = false;
        paddle.slideVelocity = 0.0;
        break;
      case PowerUpType.invis:
        paddle.isGhost = false;
        break;
      default:
        break;
    }
  }

  void _splitBalls() {
    if (balls.isEmpty) return;
    final first = balls.first;
    final spd = first.speed > 0 ? first.speed : getBaseBallSpeed();

    final hasFireball = activePowerUps.any((p) => p.type == PowerUpType.fireball) || first.isFireball;
    final hasBomb = activePowerUps.any((p) => p.type == PowerUpType.bomb) || first.isBomb;
    final hasPierce = activePowerUps.any((p) => p.type == PowerUpType.pierce) || first.isPierce;

    balls.add(
      Ball(
        x: first.x,
        y: first.y,
        vx: -spd * 0.7,
        vy: -spd * 0.7,
        radius: first.radius,
        isStuck: false,
        isFireball: hasFireball,
        isBomb: hasBomb,
        isPierce: hasPierce,
      ),
    );
    balls.add(
      Ball(
        x: first.x,
        y: first.y,
        vx: spd * 0.7,
        vy: -spd * 0.7,
        radius: first.radius,
        isStuck: false,
        isFireball: hasFireball,
        isBomb: hasBomb,
        isPierce: hasPierce,
      ),
    );
  }

  void triggerUlti() {
    if (currentMode == GameMode.chaos) return;
    if (stats.ultiCharge < 100.0 || isDiceRolling || diceSalvoRemaining > 0) return;
    stats.ultiCharge = 0.0;

    isDiceRolling = true;
    diceRollTimer = 0.88;
    _diceShuffleTimer = 0.0;
    diceDisplayTimer = 0.0;
    diceSalvoRemaining = 0;

    // 25% chance of jackpot double dice
    isDoubleDice = _rand.nextDouble() < 0.25;
    dice1Value = 1 + _rand.nextInt(6);
    dice2Value = 1 + _rand.nextInt(6);
    diceDisplay1 = 1 + _rand.nextInt(6);
    diceDisplay2 = 1 + _rand.nextInt(6);
    showOnceTip('dice', I18n.tr('tip_dice'));

    if (isDoubleDice) {
      particles.triggerShake(7.0, 0.35);
      particles.spawnShockwave(paddle.x + paddle.width / 2, paddle.y - 45, const Color(0xFFFFD700), maxRadius: screenWidth * 0.7);
      particles.spawnFloatingText(screenWidth / 2, screenHeight * 0.42, I18n.tr('jackpot_dice'), const Color(0xFFFFD700), isLarge: true);
      audio.playSfx(GameSfx.ulti);

      // Gold coin shower
      for (int i = 0; i < 20; i++) {
        particles.spawnBurst(
          screenWidth * 0.5 + (_rand.nextDouble() * 140 - 70),
          screenHeight * 0.45 + (_rand.nextDouble() * 70 - 35),
          const Color(0xFFFFD54F),
          count: 4,
          speed: 160.0,
        );
      }
    } else {
      particles.triggerShake(4.0, 0.2);
      particles.spawnShockwave(paddle.x + paddle.width / 2, paddle.y - 45, const Color(0xFF00E5FF), maxRadius: screenWidth * 0.5);
      particles.spawnFloatingText(screenWidth / 2, screenHeight * 0.42, I18n.tr('lucky_dice'), const Color(0xFF00E5FF), isLarge: true);
      audio.playSfx(GameSfx.laser);
    }

    notifyListeners();
  }

  void _loseLife() {
    if (levelTransitionTimer > 0 || status != GameStatus.playing) return;
    stats.lives--;
    if (stats.lives <= 0 && currentMode == GameMode.classic && !save.usedFreeContinue) {
      save.markFreeContinueUsed();
      stats.lives = 1;
      particles.spawnFloatingText(
        screenWidth * 0.5,
        screenHeight * 0.46,
        I18n.tr('free_continue'),
        const Color(0xFF69F0AE),
        isLarge: true,
      );
      audio.playSfx(GameSfx.powerupBuff);
      resetPaddleAndBall();
      status = GameStatus.ready;
      notifyListeners();
      return;
    }
    audio.playSfx(GameSfx.gameOver);

    if (stats.lives <= 0 && currentMode != GameMode.zen) {
      _onGameOver();
    } else {
      resetPaddleAndBall();
      status = GameStatus.ready;
    }
  }

  void _onGameOver() {
    _haltBackgroundGameplay();
    status = GameStatus.gameOver;
    if (currentMode == GameMode.classic) {
      save.saveClassicSession(
        level: classicCheckpointLevel,
        score: stats.score,
        lives: 3,
      );
    } else if (currentMode == GameMode.chaos) {
      save.clearChaosSession();
    }
    save.updateHighScore(currentMode, stats.score);
    audio.playSfx(GameSfx.gameOver);
  }

  void _checkGameProgress() {
    if (currentMode == GameMode.zen) return;
    if (currentMode == GameMode.chaos) {
      if (_chaosAllSolidBroken) {
        _chaosAllSolidBroken = false;
        chaosToLaunch = 0;
        _chaosAdvanceTurn();
      }
      return;
    }

    if (!identical(bricks, _loadedBricksRef) && balls.any((b) => b.isFireball || b.isPierce)) {
      return;
    }

    if (bricks.isNotEmpty) {
      _hasLoadedBricks = true;
    }
    if (!_hasLoadedBricks) return;

    final remainingBreakable = bricks.where((b) {
      if (!b.isAlive) return false;
      if (b.isSteel) return false;
      if (b.isTuft && b.tuftFilled) return false;
      return true;
    }).length;
    if (remainingBreakable == 0 && levelTransitionTimer <= 0) {
      _hasLoadedBricks = false;
      _haltBackgroundGameplay();
      if (currentMode == GameMode.daily || (currentMode == GameMode.classic && stats.level >= 238)) {
        if (AdManager.instance.registerLevelClear()) pendingLevelInterstitial = true;
        _onVictory();
      } else {
        // Immediate next level load with celebratory transition freeze!
        levelTransitionTimer = 0.65;
        final baseGold = 25 + (stats.level * 5).clamp(0, 50);
        final relicBonus = save.hasPermanentRelic ? max(1, (baseGold * 0.05).round()) : 0;
        final levelGold = baseGold + relicBonus;
        stats.goldCollected += levelGold;
        save.addGold(levelGold);
        stats.level++;
        stats.score += 250 * stats.level;
        if (AdManager.instance.registerLevelClear()) pendingLevelInterstitial = true;
        if (currentMode == GameMode.classic) {
          save.noteClassicProgress(stats.level);
          save.saveClassicSession(level: stats.level, score: stats.score, lives: stats.lives);
        }
        loadLevelBricks();
        _hasLoadedBricks = bricks.isNotEmpty;
        status = GameStatus.ready;
        particles.triggerShake(5.0, 0.35);
        particles.spawnBurst(screenWidth / 2, screenHeight * 0.38, const Color(0xFFFFD700), count: 24, speed: 200.0);
        particles.spawnShockwave(screenWidth / 2, screenHeight * 0.38, const Color(0xFFFFD700), maxRadius: 85.0);
        particles.spawnFloatingText(screenWidth / 2, screenHeight * 0.40, '${I18n.tr('level').toUpperCase()} ${stats.level}!', const Color(0xFFFFD54F), isLarge: true);
        particles.spawnFloatingText(screenWidth / 2, screenHeight * 0.48, '+$levelGold  ${I18n.tr('level_bonus')}', const Color(0xFFFFD54F), isLarge: false);
        audio.playSfx(GameSfx.victory);
        notifyListeners();
      }
    }
  }

  void _onVictory() {
    _haltBackgroundGameplay();
    status = GameStatus.victory;
    if (currentMode == GameMode.classic) {
      save.clearClassicSession();
    } else if (currentMode == GameMode.chaos) {
      save.clearChaosSession();
    }
    save.updateHighScore(currentMode, stats.score);
    save.addGold(100);
    stats.goldCollected += 100;
    save.recordAdOrWinQuest();
    audio.playSfx(GameSfx.victory);
  }

  GameStatus _statusBeforePause = GameStatus.playing;

  void pause() {
    if (status == GameStatus.playing || status == GameStatus.ready) {
      _statusBeforePause = status;
      status = GameStatus.paused;
      audio.isBgmAllowed = true;
      audio.playDuck = 1.0;
      audio.updateBgmVolume();
      notifyListeners();
    }
  }

  void resume() {
    if (status == GameStatus.paused) {
      status = _statusBeforePause;
      audio.isBgmAllowed = false;
      audio.pauseBgm();
      notifyListeners();
    }
  }

  void reviveWithOneLife() {
    if (hasUsedRevive) return;
    hasUsedRevive = true;
    stats.lives = 1;
    resetPaddleAndBall();
    status = GameStatus.ready;
    if (currentMode == GameMode.classic) {
      save.saveClassicSession(level: stats.level, score: stats.score, lives: stats.lives);
    }
    audio.playSfx(GameSfx.powerupBuff);
    particles.spawnShockwave(screenWidth / 2, paddle.y, const Color(0xFFFF1744), maxRadius: 100.0);
    particles.spawnFloatingText(screenWidth / 2, screenHeight * 0.45, I18n.tr('second_chance_life'), const Color(0xFFFF1744), isLarge: true);
    notifyListeners();
  }

  int rollEndGameGoldDice({int? forcedDice}) {
    if (hasClaimedVictoryBonus) return endGameBonusGoldAdded;
    hasClaimedVictoryBonus = true;
    final baseGold = endGameMultiplierBaseGold;
    final rolled = (forcedDice ?? (1 + _rand.nextInt(6))).clamp(1, 6);
    endGameRolledDice = rolled;
    endGameMultiplier = rolled >= 4 ? 3 : 2;
    final bonusGold = baseGold * (endGameMultiplier - 1);
    endGameBonusGoldAdded = bonusGold;

    save.addGold(bonusGold);
    stats.goldCollected += bonusGold;
    audio.playSfx(endGameMultiplier == 3 ? GameSfx.ulti : GameSfx.powerupBuff);
    particles.spawnShockwave(screenWidth / 2, screenHeight / 2, const Color(0xFFFFD54F), maxRadius: 120.0);
    particles.spawnFloatingText(
      screenWidth / 2,
      screenHeight * 0.45, ' ZAR $rolled  ${endGameMultiplier}X ALTIN (+$bonusGold )!',
      const Color(0xFFFFD54F),
      isLarge: true,
    );
    notifyListeners();
    return bonusGold;
  }

  void claimVictoryBonus({int? forcedDice}) {
    rollEndGameGoldDice(forcedDice: forcedDice ?? 6);
  }
}













