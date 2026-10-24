import 'analytics_manager.dart';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/black_hole.dart';
import '../models/portal.dart';
import 'package:flutter/material.dart';
import '../models/ball.dart';
import '../models/brick.dart';
import '../models/cosmetics.dart';
import '../models/fish_synergy.dart';
import '../models/easter_egg.dart';
import '../models/game_state.dart';
import '../models/level_design.dart';
import '../models/paddle.dart';
import '../models/powerup.dart';
import '../models/sector_data.dart';
import '../models/sector_blessing.dart';
import '../storage/save_manager.dart';
import 'audio_manager.dart';
import 'ad_manager.dart';
import 'play_games_manager.dart';
import 'i18n.dart';
import 'particle_system.dart';
import '../config/balance_config.dart';
import 'game_event_bus.dart';

enum ChaosPerkType {
  emberCore,
  chainShock,
  microBlast,
  magnetPull,
  sniperSight;

  String get titleTr {
    switch (this) {
      case ChaosPerkType.emberCore:
        return '🔥 Kor Çekirdek';
      case ChaosPerkType.chainShock:
        return '⚡ Zincirleme Şok';
      case ChaosPerkType.microBlast:
        return '💣 Mikro Patlama';
      case ChaosPerkType.magnetPull:
        return '🧲 Manyetik Çekim';
      case ChaosPerkType.sniperSight:
        return '🎯 Keskin Nişancı';
    }
  }

  String get cleanTitleTr {
    switch (this) {
      case ChaosPerkType.emberCore:
        return 'Kor Çekirdek';
      case ChaosPerkType.chainShock:
        return 'Zincirleme Şok';
      case ChaosPerkType.microBlast:
        return 'Mikro Patlama';
      case ChaosPerkType.magnetPull:
        return 'Manyetik Çekim';
      case ChaosPerkType.sniperSight:
        return 'Keskin Nişancı';
    }
  }

  String get nameTr => titleTr;

  String get descriptionTr {
    switch (this) {
      case ChaosPerkType.emberCore:
        return 'Tuğlalara +1 ekstra kor hasarı verir.';
      case ChaosPerkType.chainShock:
        return 'Her 8 vuruşta komşu tuğlalara elektrik arkı sıçratır.';
      case ChaosPerkType.microBlast:
        return 'Kırılan her 6. tuğla çevresine mikro şok dalgası vurur.';
      case ChaosPerkType.magnetPull:
        return '+1 Top kapsüllerini toplara doğru manyetik olarak çeker.';
      case ChaosPerkType.sniperSight:
        return 'Nişan lazerini uzatır ve ilk vuruşlara ekstra güç katar.';
    }
  }

  String get descTr => descriptionTr;

  IconData get icon {
    switch (this) {
      case ChaosPerkType.emberCore:
        return Icons.local_fire_department_rounded;
      case ChaosPerkType.chainShock:
        return Icons.bolt_rounded;
      case ChaosPerkType.microBlast:
        return Icons.flare_rounded;
      case ChaosPerkType.magnetPull:
        return Icons.attractions_rounded;
      case ChaosPerkType.sniperSight:
        return Icons.gps_fixed_rounded;
    }
  }

  Color get color {
    switch (this) {
      case ChaosPerkType.emberCore:
        return const Color(0xFFFF5722);
      case ChaosPerkType.chainShock:
        return const Color(0xFF00E5FF);
      case ChaosPerkType.microBlast:
        return const Color(0xFFFF9100);
      case ChaosPerkType.magnetPull:
        return const Color(0xFFE040FB);
      case ChaosPerkType.sniperSight:
        return const Color(0xFF69F0AE);
    }
  }
}

class TickNotifier extends ChangeNotifier { void ping() => notifyListeners(); }

class GameController extends ChangeNotifier {

  static const Set<int> portalLevels = {
    35, 41, 47, 53, 56,
    62, 68, 74, 80, 86, 92, 98, 104, 107, 113,
    119, 125, 131, 137, 143, 149, 155, 161, 167, 170,
    176, 182, 188, 194, 200, 202, 206, 208, 212, 214,
    218, 220, 222,
  };

  static PortalType getPortalTypeForLevel(int level) {
    switch (level) {
      case 18:
      case 30:
      case 53:
      case 74:
      case 86:
      case 107:
      case 125:
      case 149:
      case 167:
      case 182:
      case 206:
        return PortalType.moving;
      case 35:
      case 68:
      case 98:
      case 131:
      case 161:
      case 194:
      case 220:
        return PortalType.accelerator;
      case 47:
      case 80:
      case 113:
      case 143:
      case 170:
      case 200:
        return PortalType.gravity;
      case 56:
      case 92:
      case 119:
      case 155:
      case 188:
      case 212:
        return PortalType.quantumPhase;
      default:
        return PortalType.standard;
    }
  }
  final TickNotifier frameTick = TickNotifier();
  final List<BlackHole> blackHoles = [];
  final List<Portal> portals = [];
  final SaveManager save = SaveManager.instance;
  final AudioManager audio = AudioManager.instance;
  final ParticleSystem particles = ParticleSystem();
  final Random _rand = Random();

  GameMode currentMode = GameMode.classic;
  final ValueNotifier<int> statusVersion = ValueNotifier<int>(0);
  GameStatus _status = GameStatus.ready;
  GameStatus get status => _status;
  set status(GameStatus value) {
    if (_status != value) {
      _status = value;
      statusVersion.value++;
    }
  }
  final MatchStats stats = MatchStats();

  double screenWidth = 360.0;
  double screenHeight = 640.0;

  /// Micro-freeze timer (hit-stop) applied during solid/heavy brick destruction.
  /// Freezes ball physics momentarily for high-impact crunch while VFX & particles continue.
  double _hitStopTimer = 0.0;
  double get hitStopTimer => _hitStopTimer;

  void triggerHitStop([double duration = BalanceConfig.hitStopDurationSeconds]) {
    if (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST')) return;
    _hitStopTimer = duration;
  }
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
  final List<ChaosPerkType> offeredChaosPerks = [];
  final List<ChaosPerkType> activeChaosPerks = [];
  int chaosTurnCounter = 0;
  int _chaosHitCounter = 0;

  /// Chaos capsule pacing: falling capsules arrive one at a time and each
  /// drop starts a breathing-room cooldown, so a single volley can't rain
  /// a dozen power-ups on the paddle.
  static const double chaosCapsuleCooldownSeconds = 9.0;
  double _chaosCapsuleCooldown = 0;
  double get chaosCapsuleCooldown => _chaosCapsuleCooldown;

  /// Chaos turns are short, so mid-wave perk offers come less often than
  /// the wave-based ones (which stay every 5 waves).
  static const int chaosPerkOfferEveryTurns = 8;

  CosmeticSynergy get activeCosmeticSynergy => CosmeticCatalog.getActiveSynergy(
        save.activePaddle,
        save.activeBall,
        save.activeTrail,
      );

  bool get awaitingChaosPerkSelection => offeredChaosPerks.isNotEmpty;

  void offerChaosPerksForWave() {
    // Already-owned perks stay out: each perk can be earned only once,
    // so a long run tops out at the five distinct perks instead of stacking
    // endless copies.
    final pool = ChaosPerkType.values
        .where((p) => !activeChaosPerks.contains(p))
        .toList()
      ..shuffle(_rand);
    if (pool.isEmpty) return;
    offeredChaosPerks
      ..clear()
      ..addAll(pool.take(3));
    notifyListeners();
  }

  void selectChaosPerk(ChaosPerkType perk) {
    activeChaosPerks.add(perk);
    offeredChaosPerks.clear();
    audio.playSfx(GameSfx.powerupBuff);
    particles.spawnBurst(screenWidth * 0.5, screenHeight * 0.5, perk.color, count: 20);
    particles.spawnFloatingText(
      screenWidth * 0.5,
      screenHeight * 0.42,
      perk.titleTr,
      perk.color,
      isLarge: true,
    );
    notifyListeners();
  }

  SectorBlessing? activeSectorBlessing;
  final List<SectorBlessing> offeredSectorBlessings = [];
  bool emergencyClutchUsedThisStage = false;
  double chronoBulletTimeTimer = 0.0;
  bool get awaitingSectorBlessingSelection => offeredSectorBlessings.isNotEmpty;

  void offerSectorBlessings() {
    final pool = List<SectorBlessing>.from(SectorBlessing.all)..shuffle(_rand);
    offeredSectorBlessings
      ..clear()
      ..addAll(pool.take(3));
    notifyListeners();
  }

  void selectSectorBlessing(SectorBlessing blessing) {
    activeSectorBlessing = blessing;
    offeredSectorBlessings.clear();
    emergencyClutchUsedThisStage = false;
    particles.triggerShake(5.0, 0.25);
    particles.spawnShockwave(screenWidth * 0.5, screenHeight * 0.5, blessing.primaryColor, maxRadius: 100.0);
    particles.spawnFloatingText(
      screenWidth * 0.5,
      screenHeight * 0.45,
      blessing.title,
      blessing.primaryColor,
      isLarge: true,
    );
    audio.playSfx(GameSfx.powerupBuff);
    notifyListeners();
  }

  double get chaosFloorY => screenHeight - 86;

  late Paddle paddle;
  final List<Ball> balls = [];
  List<Brick> bricks = [];
  final List<FallingCapsule> capsules = [];
  final List<Projectile> projectiles = [];
  final List<ActivePowerUp> activePowerUps = [];

  EasterEggBee? activeBee;

  /// Amber scorch mark the bee leaves where it slammed into the paddle.
  double beePaddleMarkTimer = 0.0;
  double beePaddleMarkX = 0.0;
  WindshieldSplat? activeSplat;
  double beeSpawnCooldown = 35.0;

  // Juice timers (coin magnet, combo pulse, new-record banner, revive flash)
  double hudGoldPunchTimer = 0.0;
  int coinArrivalCount = 0;

  /// Gold amount the HUD pill currently displays. It only rises when coin
  /// orbs actually land in the counter, so the player sees every coin arrive.
  int hudGoldShown = 0;

  // Lifetime-stat run tracking (flushed once per run).
  double _runElapsedSeconds = 0.0;
  bool _runStatsFlushed = true;
  double _zenQuestBuffer = 0.0;

  void _flushRunStats() {
    if (_runStatsFlushed) return;
    _runStatsFlushed = true;
    save.addLifetimeRunStats(
      bricks: stats.bricksBroken,
      seconds: _runElapsedSeconds.round(),
    );
  }

  /// Where coin orbs land: the gold pill on the left of the HUD bar.
  static const Offset coinHudTarget = Offset(128.0, 58.0);
  int _coinClinkIndex = 0;
  double comboPulseTimer = 0.0;
  double newRecordBannerTimer = 0.0;
  double reviveFlashTimer = 0.0;
  double _feverEmberTimer = 0.0;
  double _recordEmberTimer = 0.0;

  double descendTimer = 0.0;
  int descendRowsSurvived = 0;
  double get runElapsedSeconds => _runElapsedSeconds;
  double get descendDropProgress =>
      (1.0 - (descendTimer / 11.0)).clamp(0.0, 1.0);
  double droneShootTimer = 0.0;
  double? laserTimer;
  double? rocketTimer;
  double? _blackHoleTimer;
  double comboTimer = 0.0;

  /// Remaining seconds of the neon "near-miss" edge flash (0 = inactive).
  double nearMissFlashTimer = 0.0;
  double _nearMissCooldown = 0.0;
  double _nearMissSlowLeft = 0.0;

  /// Target lock-on state (PowerUpType.lock): homing missile steering and visual reticle
  Brick? lockedTargetBrick;
  Ball? targetLockingBall;
  double targetLockTimer = 0.0;

  int _lastKnownLives = 3;
  double lowLifeAlertTimer = 0.0;
  static const double lowLifeAlertDuration = 2.8;

  /// True while the player is on their very last life.
  bool get isLastLife => status == GameStatus.playing && stats.lives == 1;
  bool get isLowLifeAlertActive => isLastLife && lowLifeAlertTimer > 0;

  void checkLowLifeTransition() {
    if (stats.lives == 1 && _lastKnownLives > 1) {
      lowLifeAlertTimer = lowLifeAlertDuration;
    }
    _lastKnownLives = stats.lives;
  }
  double gameTime = 0.0;
  double bossWarningTimer = 0.0;
  double levelTransitionTimer = 0.0;
  bool _hasLoadedBricks = false;
  List<Brick>? _loadedBricksRef;

  List<int> shapesPermutation = [];
  double checkpointBannerTimer = 0.0;
  int checkpointBannerLevel = 1;

  int get currentShapeIndex {
    if (shapesPermutation.isEmpty) {
      return (stats.level - 1) % LevelDesign.allShapes.length;
    }
    final idx = (stats.level - 1) % shapesPermutation.length;
    return shapesPermutation[idx];
  }

  String get currentShapeName => LevelDesign.getShapeName(currentShapeIndex, lang: save.language);

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

  int revivesUsed = 0;
  static const int maxRevivesPerGame = 2;
  bool get canRevive => revivesUsed < maxRevivesPerGame;
  bool get hasUsedRevive => revivesUsed >= maxRevivesPerGame;
  bool _pendingLevelInterstitial = false;
  bool get pendingLevelInterstitial => _pendingLevelInterstitial;
  set pendingLevelInterstitial(bool value) {
    if (_pendingLevelInterstitial != value) {
      _pendingLevelInterstitial = value;
      statusVersion.value++;
    }
  }
  bool hasClaimedVictoryBonus = false;
  int endGameRolledDice = 0;
  int endGameMultiplier = 0;
  int endGameBonusGoldAdded = 0;
  int _sessionStartingBestScore = 0;
  bool _hasCelebratedNewRecord = false;
  bool _bossEnrageAnnounced = false;
  int _bossHitsCounter = 0;
  bool _chaosAllSolidBroken = false;
  int activeIceVariant = 0;
  double endgameStallTimer = 0.0;
  String? activeTipText;
  double tipTimer = 0.0;

  // R3 & R4: Onboarding, Pacing, and Progressive Feature Tracking
  bool firstCornerHitShown = false;
  double level1GuideTimer = 0.0;
  int levelBricksBroken = 0;
  bool earlyActionDropGranted = false;

  bool get isChaosMode => currentMode == GameMode.chaos;
  bool get isZenMode => currentMode == GameMode.zen;
  int get level => stats.level;
  set level(int v) => stats.level = v;
  double get ultiCharge => stats.ultiCharge;
  set ultiCharge(double v) => stats.ultiCharge = v;
  bool get isUltiReady => !isChaosMode && ((stats.diceChargeMax > 0 && stats.diceCharge >= stats.diceChargeMax) || stats.ultiCharge >= 100.0);
  bool get showLevel1DragGuide => level == 1 && !isChaosMode && !isZenMode && level1GuideTimer < 8.0;

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

  int get sessionStartingBestScore => _sessionStartingBestScore;

  /// Death returns the player to:
  /// - The current boss level if reached (e.g. 12)
  /// - The post-boss level (e.g. 13) if the boss was defeated
  /// - Otherwise the start of the current 8-level series.
  int get classicCheckpointLevel {
    final level = stats.level.clamp(1, 238);
    return SectorData.getSectorForLevel(level).checkpointLevel;
  }

  int get endGameMultiplierBaseGold => max(stats.goldCollected, 100);

  Brick? get activeBossBrick {
    for (final b in bricks) {
      if (b.isAlive && b.isBoss) return b;
    }
    return null;
  }

  bool get isBossLevel => LevelDesign.isBossLevelNumber(stats.level);

  void startNewGame(GameMode mode, {bool isResume = false, int? explicitStartLevel}) {
    audio.isBgmAllowed = false;
    audio.pauseBgm();
    rollSessionCosmetics();
    currentMode = mode;
    status = GameStatus.ready;
    revivesUsed = 0;
    hasClaimedVictoryBonus = false;
    endGameRolledDice = 0;
    endGameMultiplier = 0;
    endGameBonusGoldAdded = 0;
    _sessionStartingBestScore = save.getHighScore(mode);
    hudGoldShown = save.gold;
    descendRowsSurvived = 0;
    _runElapsedSeconds = 0.0;
    _runStatsFlushed = false;
    if (!isResume) {
      save.recordRunStarted();
    }
    _hasCelebratedNewRecord = false;
    _bossEnrageAnnounced = false;
    _bossHitsCounter = 0;
    _glassBreaksTowardDice = 0;
    _blocksUntilDicePoint = _rollDiceBlockGap();
    checkpointBannerTimer = 0.0;
    newRecordBannerTimer = 0.0;
    reviveFlashTimer = 0.0;
    firstCornerHitShown = false;
    level1GuideTimer = 0.0;
    levelBricksBroken = 0;
    earlyActionDropGranted = false;

    if (mode == GameMode.shapes) {
      shapesPermutation = List<int>.generate(LevelDesign.allShapes.length, (i) => i)..shuffle();
    }

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
      offeredChaosPerks.clear();
      activeChaosPerks.clear();
      chaosTurnCounter = 0;
      _chaosHitCounter = 0;
      _chaosCapsuleCooldown = 0;
      chaosSpeedMultiplier = 1.0;
      chaosRecallActive = false;
    }

    if (!isResume) {
      activeSectorBlessing = null;
      offeredSectorBlessings.clear();
      emergencyClutchUsedThisStage = false;
      chronoBulletTimeTimer = 0.0;
    }

    int startLives = mode == GameMode.zen ? 999 : 3;
    int startLevel = explicitStartLevel ?? 1;
    int startScore = 0;

    if (isResume && explicitStartLevel == null) {
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
      _sessionStartingBestScore = max(_sessionStartingBestScore, startScore);
      if (startScore >= _sessionStartingBestScore && startScore > 0) {
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
    _lastKnownLives = startLives;
    lowLifeAlertTimer = 0.0;
    if (mode == GameMode.classic) {
      save.noteClassicProgress(stats.level);
      if (isBossLevel) {
        save.saveClassicSession(level: stats.level, score: stats.score, lives: stats.lives);
      }
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
      // Side modes get the same grand entrance as the main adventure.
      final intro = switch (mode) {
        GameMode.zen => ('ZEN • SAKİN AKIŞ', const Color(0xFFF5B041)),
        GameMode.descend => ('ÇÖKÜŞ • HAYATTA KAL', const Color(0xFF48A9A6)),
        GameMode.shapes => ('ŞEKİLLER • FİGÜR ${stats.level}', const Color(0xFFFFB74D)),
        _ => null,
      };
      if (intro != null) {
        particles.spawnFloatingText(
            screenWidth / 2, screenHeight * 0.35, intro.$1, intro.$2,
            isLarge: true);
      }
    }

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

  DateTime? dailyBlitzDate;

  void startDailyBlitz({DateTime? date}) {
    final targetDate = date ?? DateTime.now();
    dailyBlitzDate = targetDate;
    startNewGame(GameMode.daily);
    bricks = LevelDesign.buildDailyLevel(targetDate, screenWidth, screenHeight);
    _hasLoadedBricks = bricks.isNotEmpty;
    _loadedBricksRef = bricks;
    status = GameStatus.ready;
    notifyListeners();
  }

  // --- R6: PRESTIGE TIER & MULTIPLIERS ---
  int get prestigeTier => stats.level > 238 ? ((stats.level - 239) ~/ 17) + 1 : 0;
  double get prestigeGoldMultiplier => prestigeTier > 0 ? (1.0 + prestigeTier * 0.20) : 1.0;

  // --- R5: COSMIC MASTERY MULTIPLIERS ---
  double get cosmicGoldDamageMultiplier => 1.0 + save.cosmicGoldMasteryLevel * 0.02;
  double get cosmicGoldRewardMultiplier => 1.0 + save.cosmicGoldMasteryLevel * 0.02;
  double get cosmicPearlUltiMultiplier => 1.0 + save.cosmicPearlMasteryLevel * 0.02;
  double get cosmicPearlLuckBonus => save.cosmicPearlMasteryLevel * 0.01;

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
    lockedTargetBrick = null;
    targetLockingBall = null;
    targetLockTimer = 0.0;
  }

  @visibleForTesting
  void haltBackgroundGameplay() => _haltBackgroundGameplay();

  @visibleForTesting
  void testChargeDiceFromGlass(Brick b) => _chargeDiceFromGlass(b);

  void resetPaddleAndBall() {
    // Step 7: Aquarium Synergy - Passive buffs based on unlocked fish in Eco-Tank
    final fishBuffs = FishSynergyBuffs.calculate(save);
    final paddleWidthLvl = save.getUpgradeLevel('paddle_width');
    final upgradeWidthBonus = paddleWidthLvl * 2.0;
    final relicWidthBonus = (save.hasPermanentRelic && save.activeRelicStyle == 'aegis') ? paddle.baseWidth * 0.08 : 0.0;
    paddle.width = paddle.baseWidth + fishBuffs.extraPaddleWidth + upgradeWidthBonus + relicWidthBonus;
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
    AnalyticsManager.instance.logLevelStart(stats.level, currentMode.name);
    activeIceVariant = _rand.nextInt(4);
    portals.clear();
    blackHoles.clear();
    activeBee = null;
    beeSpawnCooldown = 25.0 + _rand.nextDouble() * 25.0;
    _blackHoleTimer = 0.0;
    levelBricksBroken = 0;
    earlyActionDropGranted = false;
    switch (currentMode) {
      case GameMode.classic:
        bricks = LevelDesign.buildClassicLevel(stats.level, screenWidth, screenHeight);
        if (prestigeTier > 0) {
          for (final b in bricks) {
            if (!b.isSteel && !b.isDynamite && !b.isIce && !b.isTuft) {
              if (b.isBoss) {
                b.hp += prestigeTier * 25;
                b.maxHp += prestigeTier * 25;
              } else {
                b.hp += prestigeTier;
                b.maxHp += prestigeTier;
              }
            }
          }
        }
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
          // Enforce strict safety margin:
          // Portals are NEVER placed too close to the paddle (at least 165px clearance above paddle.y)
          // ensuring the ball will never escape immediately before the player can react!
          final double maxSafePortalY = paddle.y - 165.0;
          final double minSafePortalY = (lowestAliveBrickY + 36.0).clamp(140.0, maxSafePortalY - 50.0);
          final double availableSpan = max(30.0, maxSafePortalY - minSafePortalY);

          final p1Y = minSafePortalY + levelRand.nextDouble() * (availableSpan * 0.42);
          final p2Y = minSafePortalY + (availableSpan * 0.52) + levelRand.nextDouble() * (availableSpan * 0.45);

          final portalType = getPortalTypeForLevel(stats.level);
          Color color1;
          Color color2;
          switch (portalType) {
            case PortalType.moving:
              color1 = const Color(0xFF00B0FF); // Cyber Azure
              color2 = const Color(0xFFFF5252); // Neon Coral
              break;
            case PortalType.accelerator:
              color1 = const Color(0xFFFFD700); // Hyper Gold
              color2 = const Color(0xFFE040FB); // Electric Violet
              break;
            case PortalType.gravity:
              color1 = const Color(0xFF00E676); // Emerald Jade
              color2 = const Color(0xFF1DE9B6); // Teal Singularity
              break;
            case PortalType.quantumPhase:
              color1 = const Color(0xFFFF4081); // Prismatic Magenta
              color2 = const Color(0xFF7C4DFF); // Deep Plasma
              break;
            case PortalType.standard:
              color1 = const Color(0xFF00E5FF); // Quantum Cyan
              color2 = const Color(0xFFFF9100); // Solar Amber
              break;
          }

          final p1 = Portal(
            x: screenWidth * (0.22 + levelRand.nextDouble() * 0.12),
            y: p1Y,
            radius: 20.0,
            isBlue: true,
            color: color1,
            type: portalType,
            moveSpeed: 1.4 + levelRand.nextDouble() * 0.6,
            moveAmplitude: 45.0 + levelRand.nextDouble() * 25.0,
            movePhase: 0.0,
          );
          final p2 = Portal(
            x: screenWidth * (0.66 + levelRand.nextDouble() * 0.12),
            y: p2Y,
            radius: 20.0,
            isBlue: false,
            color: color2,
            type: portalType,
            moveSpeed: 1.4 + levelRand.nextDouble() * 0.6,
            moveAmplitude: 45.0 + levelRand.nextDouble() * 25.0,
            movePhase: pi,
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
        bricks = LevelDesign.buildDailyLevel(dailyBlitzDate ?? DateTime.now(), screenWidth, screenHeight);
        break;
      case GameMode.shapes:
        bricks = LevelDesign.buildShapesLevel(
          stats.level,
          screenWidth,
          screenHeight,
          explicitShapeIndex: currentShapeIndex,
        );
        break;
      case GameMode.chaos:
        bricks = LevelDesign.buildChaosLevel(stats.level, screenWidth, screenHeight);
        if (stats.level > 0 && stats.level % 5 == 0 && offeredChaosPerks.isEmpty) {
          offerChaosPerksForWave();
        }
        if (stats.level >= 10 && stats.level % 10 == 0) {
          bossWarningTimer = 2.2;
          particles.triggerShake(5.5, 0.40);
          audio.playSfx(GameSfx.bossHit);
        }
        break;
    }
    _loadedBricksRef = bricks;

    // Checkpoint announce banner for classic mode sectors and boss checkpoints
    if (currentMode == GameMode.classic && stats.level > 1 && stats.level == classicCheckpointLevel) {
      checkpointBannerTimer = 2.5;
      checkpointBannerLevel = stats.level;
    }

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
    if (currentMode != GameMode.chaos || status != GameStatus.ready || awaitingChaosPerkSelection) return;
    chaosAiming = true;
    chaosAimX = x.clamp(10.0, screenWidth - 10.0);
    chaosAimY = min(y, chaosFloorY - 18.0);
    frameTick.ping();
  }

  void toggleChaosTurbo({bool bypassCooldown = false}) {
    if (currentMode != GameMode.chaos || status != GameStatus.playing) return;
    if (!bypassCooldown && chaosTurnTime < 8.0) {
      final remaining = (8.0 - chaosTurnTime).ceil();
      particles.spawnFloatingText(screenWidth * 0.25, chaosFloorY - 55, '$remaining sn kilitli', const Color(0xFFB0BEC5));
      return;
    }
    if (chaosSpeedMultiplier <= 1.05) {
      chaosSpeedMultiplier = 2.2;
      particles.spawnFloatingText(screenWidth * 0.25, chaosFloorY - 55, I18n.tr('chaos_2x_speed'), const Color(0xFFFFD700), isLarge: true);
      audio.playSfx(GameSfx.wallBounce8);
    } else {
      chaosSpeedMultiplier = 1.0;
      particles.spawnFloatingText(screenWidth * 0.25, chaosFloorY - 55, '1X HIZ', const Color(0xFFFFFFFF));
    }
    notifyListeners();
  }

  void toggleChaosTurboOrRecall({bool bypassCooldown = true}) {
    if (currentMode != GameMode.chaos || status != GameStatus.playing) return;
    if (chaosRecallActive) return;
    if (chaosSpeedMultiplier <= 1.05) {
      toggleChaosTurbo(bypassCooldown: bypassCooldown);
    } else {
      recallChaosBalls();
    }
  }

  void recallChaosBalls() {
    if (currentMode != GameMode.chaos || status != GameStatus.playing) return;
    if (chaosRecallActive) return;
    chaosRecallActive = true;
    chaosToLaunch = 0;
    chaosSpeedMultiplier = max(chaosSpeedMultiplier, 2.2);
    particles.spawnFloatingText(screenWidth * 0.75, chaosFloorY - 55, I18n.tr('chaos_recall'), const Color(0xFF00E5FF), isLarge: true);
    audio.playSfx(GameSfx.powerupBuff);
    notifyListeners();
  }

  void fireChaos() {
    if (currentMode != GameMode.chaos || status != GameStatus.ready || chaosStock <= 0 || awaitingChaosPerkSelection) return;
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
      final baseGold = 12 + (stats.level * 2).clamp(0, 24);
      final relicBonus = save.hasPermanentRelic ? max(1, (baseGold * 0.05).round()) : 0;
      final luckLvl = save.getUpgradeLevel('u_luck');
      final luckBonus = (baseGold * (luckLvl * 0.05)).round();
      final levelGold = baseGold + relicBonus + luckBonus;
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

    chaosTurnCounter++;
    chaosStock += chaosPendingExtraBalls;
    chaosPendingExtraBalls = 0;
    const step = LevelDesign.chaosStep;
    for (final brick in bricks) {
      if (!brick.isAlive) continue;
      // Slide down smoothly (Brick.update eases y toward targetY).
      brick.targetY += step;
      if (!brick.isBallPickup && brick.targetY + brick.height >= chaosFloorY - 36) {
        if (brick.isSteel) {
          // If any legacy or hazard steel block reaches floor, vaporize safely instead of unfair game over!
          brick.isAlive = false;
          particles.spawnBurst(brick.x + brick.width / 2, chaosFloorY - 20, Colors.grey, count: 12);
          continue;
        }
        brick.y = brick.targetY;
        _onGameOver();
        return;
      }
    }
    bricks.removeWhere((brick) => !brick.isAlive);
    bricks.removeWhere((brick) => brick.isBallPickup && brick.y + brick.height >= chaosFloorY - 20);

    final effectiveWave = (chaosTurnCounter > 0 && chaosTurnCounter % 10 == 0 && stats.level < 10)
        ? chaosTurnCounter
        : stats.level;
    final newRow = LevelDesign.buildChaosRow(effectiveWave, 0, screenWidth, turn: chaosTurnCounter);
    for (final brick in newRow) {
      brick.y = brick.targetY - step;
    }
    bricks.addAll(newRow);
    particles.triggerShake(2.5, 0.12);
    if ((stats.level > 0 && stats.level % 5 == 0 ||
            (chaosTurnCounter > 0 && chaosTurnCounter % chaosPerkOfferEveryTurns == 0)) &&
        offeredChaosPerks.isEmpty) {
      offerChaosPerksForWave();
    }
    if (effectiveWave >= 10 && effectiveWave % 10 == 0) {
      bossWarningTimer = 2.2;
    }
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
    double levelSpeed = base + min(stats.level * 10.0, 90.0);
    if (save.hasPermanentRelic && save.activeRelicStyle == 'overdrive') {
      levelSpeed *= 1.06;
    }
    if (stats.level <= 5 && !isChaosMode && !isZenMode) {
      return levelSpeed * 1.15;
    }
    return levelSpeed;
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

    // Perk / Blessing choice freezes the whole board until the player picks.
    if (awaitingChaosPerkSelection || awaitingSectorBlessingSelection) {
      particles.update(dt);
      frameTick.ping();
      _syncHud();
      return;
    }

    // Constitutional Rule 5 / Phase 2: 35ms Hit-Stop Crunch on Brick Shatter
    if (_hitStopTimer > 0) {
      _hitStopTimer = max(0.0, _hitStopTimer - dt);
      particles.update(dt);
      frameTick.ping();
      _syncHud();
      return;
    }

    if (chronoBulletTimeTimer > 0) {
      chronoBulletTimeTimer = max(0.0, chronoBulletTimeTimer - dt);
    }

    if (lowLifeAlertTimer > 0) {
      lowLifeAlertTimer = max(0.0, lowLifeAlertTimer - dt);
    }

    if (level == 1 && !isChaosMode && !isZenMode) {
      level1GuideTimer += dt;
    }

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
      if (checkpointBannerTimer > 0) {
        checkpointBannerTimer -= dt;
        if (checkpointBannerTimer < 0) checkpointBannerTimer = 0;
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
      // Chaos bricks keep sliding down to their target row while aiming.
      var chaosSliding = false;
      if (currentMode == GameMode.chaos) {
        for (final b in bricks) {
          if (!b.isAlive) continue;
          if ((b.targetY - b.y).abs() > 0.2) {
            b.y += (b.targetY - b.y) * (1.0 - exp(-12.0 * dt));
            chaosSliding = true;
          } else if (b.y != b.targetY) {
            b.y = b.targetY;
            chaosSliding = true;
          }
        }
      }
      final splash =
          chaosSliding ||
          hadSplat ||
          particles.particles.isNotEmpty ||
          particles.shockwaves.isNotEmpty ||
          particles.floatingTexts.isNotEmpty ||
          particles.shards.isNotEmpty ||
          bossWarningTimer > 0 ||
          levelTransitionTimer > 0 ||
          reviveFlashTimer > 0 ||
          newRecordBannerTimer > 0 ||
          particles.shakeTimeLeft > 0;
      if (!splash) return;
      particles.update(dt);
      _updateJuiceTimers(dt);
      frameTick.ping();
      _syncHud();
      return;
    }

    // Lifetime stats: accumulate real play time for the stats screen.
    _runElapsedSeconds += dt;

    // Daily quest: bank Zen play time in small chunks.
    if (currentMode == GameMode.zen && status == GameStatus.playing) {
      _zenQuestBuffer += dt;
      if (_zenQuestBuffer >= 2.0) {
        final whole = _zenQuestBuffer.floor();
        _zenQuestBuffer -= whole;
        save.addQuestZenSeconds(whole);
      }
    }

    // Bullet time slow motion
    double effectiveDt = dt;
    if (stats.bulletTimeLeft > 0) {
      stats.bulletTimeLeft -= dt;
      effectiveDt = dt * 0.45;
    }
    if (_nearMissSlowLeft > 0) {
      _nearMissSlowLeft = max(0.0, _nearMissSlowLeft - dt);
      effectiveDt = min(effectiveDt, dt * 0.45);
    }
    if (nearMissFlashTimer > 0) nearMissFlashTimer = max(0.0, nearMissFlashTimer - dt);
    if (_nearMissCooldown > 0) _nearMissCooldown = max(0.0, _nearMissCooldown - dt);

    if (lockedTargetBrick != null) {
      if (!lockedTargetBrick!.isAlive || targetLockTimer <= 0) {
        lockedTargetBrick = null;
        targetLockingBall = null;
        targetLockTimer = 0.0;
      } else {
        targetLockTimer -= effectiveDt;
      }
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
    _updateJuiceTimers(effectiveDt);
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

  @override
  void notifyListeners() {
    if (_status != GameStatus.playing && _status != GameStatus.ready) {
      statusVersion.value++;
    }
    super.notifyListeners();
  }

  void _syncHud() {
    final boss = activeBossBrick;
    var sig = Object.hashAll([
      stats.score,
      stats.lives,
      stats.level,
      stats.combo,
      stats.isFever,
      hudGoldShown,
      hudGoldPunchTimer > 0.05,
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
      newRecordBannerTimer > 0,
      checkpointBannerTimer > 0,
      activeTipText,
    ]);
    for (final p in activePowerUps) {
      sig = Object.hash(sig, p.type, (p.timeLeft * 4).floor());
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

  void _burnBee() {
    final bee = activeBee;
    if (bee == null || bee.state != BeeState.flying) return;
    bee.state = BeeState.burning;
    bee.stateTime = 0.0;
    bee.vy = 24.0;
    stats.score += 100;
    particles.spawnBurst(bee.x, bee.y, const Color(0xFFFF6D00), count: 18, speed: 130.0);
    particles.spawnBurst(bee.x, bee.y, const Color(0xFF424242), count: 10, speed: 70.0);
    particles.spawnFloatingText(bee.x, bee.y - 18.0, I18n.tr('bee_turned_to_ash'), const Color(0xFFFF9100), isLarge: true);
    audio.playSfx(GameSfx.explosion);
  }

  void _freezeBee() {
    final bee = activeBee;
    if (bee == null || bee.state != BeeState.flying) return;
    bee.state = BeeState.frozenFalling;
    bee.stateTime = 0.0;
    bee.vy = 0.0;
    particles.spawnBurst(bee.x, bee.y, const Color(0xFF80D8FF), count: 16, speed: 110.0);
    particles.spawnShockwave(bee.x, bee.y, const Color(0xFF00E5FF), maxRadius: 30.0);
    particles.spawnFloatingText(bee.x, bee.y - 18.0, I18n.tr('bee_frozen'), const Color(0xFF80D8FF), isLarge: true);
    audio.playSfx(GameSfx.breakBrick, combo: stats.combo);
  }

  /// Black holes bend the bee's flight: inside reach its trajectory curves
  /// gracefully around the celestial horizon (gravitational slingshot), but the
  /// bee NEVER enters or gets sucked inside the event horizon. It circles the outer rim
  /// and escapes on the other side.
  void _bendBeePastBlackHoles(EasterEggBee bee, double dt) {
    for (final bh in blackHoles) {
      final dx = bh.x - bee.x;
      final dy = bh.y - bee.baseY;
      final dist = sqrt(dx * dx + dy * dy);
      final reach = bh.maxInfluenceDist;
      if (dist <= 0.001 || dist > reach) continue;

      final nx = dx / dist;
      final ny = dy / dist;
      final minSafeDist = bh.radius + 20.0;
      final proximity = 1.0 - (dist / reach);
      final falloff = pow(proximity, 0.65).toDouble();
      final drift = (bh.isVortexTrap ? 115.0 : (bh.isSupercharged ? 95.0 : 75.0)) * falloff;
      final spin = bee.isFacingRight ? 1.0 : -1.0;

      if (dist > minSafeDist) {
        // Outer gravitational curve: gently pull toward the well while curling tangentially
        final inwardRatio = ((dist - minSafeDist) / (reach - minSafeDist)).clamp(0.0, 1.0);
        bee.x += nx * drift * inwardRatio * 0.45 * dt;
        bee.baseY += ny * drift * inwardRatio * 0.45 * dt;

        // Tangential orbital velocity (slingshot arc)
        bee.x += -ny * spin * drift * 0.85 * dt;
        bee.baseY += nx * spin * drift * 0.85 * dt;
      } else {
        // Horizon boundary zone: ZERO inward pull; strong centrifugal deflection + orbital acceleration
        final horizonProximity = ((minSafeDist - dist) / minSafeDist).clamp(0.0, 1.0);
        final repulsion = (bh.radius + 120.0) * horizonProximity;

        // Push outwards away from black hole core
        bee.x -= nx * repulsion * dt;
        bee.baseY -= ny * repulsion * dt;

        // Accelerate around the perimeter (gravity assist slingshot)
        bee.x += -ny * spin * (drift * 1.35 + 40.0) * dt;
        bee.baseY += nx * spin * (drift * 1.35 + 40.0) * dt;
      }

      // Hard cosmic firewall: strict collision barrier ensures the bee never penetrates event horizon
      final currentDx = bee.x - bh.x;
      final currentDy = bee.baseY - bh.y;
      final currentDist = sqrt(currentDx * currentDx + currentDy * currentDy);
      final absoluteMinDist = bh.radius + 15.0;
      if (currentDist < absoluteMinDist && currentDist > 0.001) {
        final cnx = currentDx / currentDist;
        final cny = currentDy / currentDist;
        bee.x = bh.x + cnx * absoluteMinDist;
        bee.baseY = bh.y + cny * absoluteMinDist;
      }
    }
    bee.baseY = bee.baseY.clamp(110.0, paddle.y - 55.0);
  }

  /// Sends the bee through a portal pair: emerges from the linked
  /// portal on the far side, still facing (and flying) the same way.
  /// Returns true when a hop happened.
  bool _tryBeePortalHop(EasterEggBee bee) {
    for (final p in portals) {
      if (p.linkedPortal == null) continue;
      final dx = p.x - bee.x;
      final dy = p.y - bee.y;
      if (dx * dx + dy * dy > p.radius * p.radius) continue;
      final target = p.linkedPortal!;
      particles.spawnBurst(p.x, p.y, p.color, count: 14, speed: 100.0);
      particles.spawnShockwave(p.x, p.y, p.color, maxRadius: 30.0);
      bee.x = target.x + (bee.isFacingRight ? 1.0 : -1.0) * (target.radius + 14.0);
      bee.baseY = target.y.clamp(110.0, paddle.y - 55.0);
      bee.portalCooldown = 0.7;
      particles.spawnBurst(target.x, target.y, target.color, count: 16, speed: 110.0);
      particles.spawnShockwave(target.x, target.y, target.color, maxRadius: 34.0);
      audio.playSfx(GameSfx.ulti);
      return true;
    }
    return false;
  }

  void _updateEasterEgg(double dt) {
    if (currentMode == GameMode.chaos) return;
    if (beePaddleMarkTimer > 0) {
      beePaddleMarkTimer = max(0.0, beePaddleMarkTimer - dt);
    }
    final bee = activeBee;
    if (bee == null) {
      beeSpawnCooldown -= dt;
      if (beeSpawnCooldown <= 0) {
        spawnEasterEggBee();
        beeSpawnCooldown = 35.0 + _rand.nextDouble() * 30.0;
      }
      return;
    }

    switch (bee.state) {
      case BeeState.flying:
        // Portals work on the bee just like on the ball: in one, out
        // the linked one, still flying the same way it came in.
        if (bee.portalCooldown > 0) bee.portalCooldown -= dt;
        if (bee.portalCooldown <= 0) _tryBeePortalHop(bee);

        // Only an active Vortex power-up drags the bee down onto the
        // paddle. Ambient black holes only bend its flight a little.
        if (paddle.hasVortex) {
          final targetX = paddle.x + paddle.width / 2;
          final targetY = paddle.y - 12.0;
          final pull = min(1.0, dt * 4.2);
          bee.baseY += (targetY - bee.baseY) * pull;
          bee.x += (targetX - bee.x) * pull - bee.vx * 0.65 * dt;
          bee.update(dt);
          final dx = bee.x - targetX;
          final dy = bee.y - targetY;
          if (dx * dx + dy * dy < 22.0 * 22.0) {
            bee.state = BeeState.stuckToPaddle;
            bee.stateTime = 0.0;
            bee.stuckOffsetX = (bee.x - paddle.x).clamp(8.0, max(8.0, paddle.width - 8.0));
            beePaddleMarkX = bee.x;
            beePaddleMarkTimer = 5.0;
            particles.spawnBurst(bee.x, bee.y, const Color(0xFFFFD54F), count: 14, speed: 90.0);
            audio.playSfx(GameSfx.powerupBuff);
          }
        } else {
          _bendBeePastBlackHoles(bee, dt);
          bee.update(dt);
          if (bee.isOffScreen(screenWidth)) {
            activeBee = null;
            return;
          }
        }
        break;

      case BeeState.burning:
        bee.stateTime += dt;
        bee.vy += 520.0 * dt;
        bee.y += bee.vy * dt;
        bee.x += bee.vx * 0.25 * dt;
        // Trail of ash and embers as it drops.
        if (_rand.nextDouble() < 0.65) {
          particles.spawnBurnEmber(bee.x, bee.y, color: const Color(0xFF616161));
        }
        if (_rand.nextDouble() < 0.35) {
          particles.spawnBurnEmber(bee.x, bee.y, color: const Color(0xFFFF6D00));
        }
        if (bee.y > screenHeight + 30.0) {
          activeBee = null;
        }
        break;

      case BeeState.frozenFalling:
        bee.stateTime += dt;
        if (bee.stateTime > 0.22) {
          // Hangs frozen for a beat, then drops and shatters on the floor line.
          bee.vy += 640.0 * dt;
          bee.y += bee.vy * dt;
          bee.fallSpin += dt * 2.4;
          if (bee.y >= paddle.y - 8.0) {
            stats.score += 100;
            particles.spawnBurst(bee.x, bee.y, const Color(0xFF80D8FF), count: 22, speed: 170.0);
            particles.spawnShockwave(bee.x, bee.y, const Color(0xFF00E5FF), maxRadius: 34.0);
            particles.spawnFloatingText(bee.x, bee.y - 16.0, '${I18n.tr('ice_shattered')} +100', const Color(0xFF80D8FF), isLarge: true);
            audio.playSfx(GameSfx.breakBrick, combo: stats.combo);
            activeBee = null;
          }
        }
        break;

      case BeeState.stuckToPaddle:
        // Pinned on the paddle: struggles briefly, then the paddle
        // crushes it flat — it dies right there, no escape.
        bee.stateTime += dt;
        bee.x = paddle.x + bee.stuckOffsetX;
        bee.y = paddle.y - 9.0;
        if (bee.stateTime >= 0.45) {
          stats.score += 50;
          particles.spawnBurst(bee.x, bee.y, const Color(0xFFFFD54F), count: 18, speed: 120.0);
          particles.spawnBurst(bee.x, bee.y, const Color(0xFF424242), count: 8, speed: 60.0);
          particles.spawnFloatingText(bee.x, bee.y - 20.0, I18n.tr('bee_squashed'), const Color(0xFFFFD54F), isLarge: true);
          audio.playSfx(GameSfx.breakBrick, combo: stats.combo);
          activeBee = null;
        }
        break;
    }
  }

  void _updatePowerUpTimers(double dt) {
    if (_chaosCapsuleCooldown > 0) {
      _chaosCapsuleCooldown = max(0.0, _chaosCapsuleCooldown - dt);
    }
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
    audio.setDynamicTempo(isFever: stats.isFever, isBoss: activeBossBrick != null);
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

      // Shrapnel lateral wall bounce
      if (p.isShrapnel) {
        if (p.x <= 8.0 && p.vx < 0) {
          p.x = 8.0;
          p.vx = -p.vx;
        } else if (p.x >= screenWidth - 8.0 && p.vx > 0) {
          p.x = screenWidth - 8.0;
          p.vx = -p.vx;
        }
      }

      // Boss bullets hitting paddle (or bottom launcher area in Chaos mode)
      if (p.isBossBullet) {
        if (currentMode == GameMode.chaos) {
          if (p.y >= chaosFloorY - 14.0) {
            projectiles.removeAt(i);
            particles.triggerShake(6.5, 0.30);
            particles.spawnBurst(p.x, chaosFloorY, const Color(0xFFFF1744), count: 16, speed: 120.0);
            particles.spawnShockwave(p.x, chaosFloorY, const Color(0xFFFF1744), maxRadius: 75.0);
            audio.playSfx(GameSfx.explosion);
            // Boss earthquake slams the brick formation downward closer to the danger line!
            for (final brick in bricks) {
              if (!brick.isAlive) continue;
              brick.targetY += 10.0;
              if (!brick.isBallPickup && brick.targetY + brick.height >= chaosFloorY - 36) {
                if (brick.isSteel) {
                  brick.isAlive = false;
                  particles.spawnBurst(brick.x + brick.width / 2, chaosFloorY - 20, Colors.grey, count: 12);
                  continue;
                }
                brick.y = brick.targetY;
                _onGameOver();
                return;
              }
            }
            particles.spawnFloatingText(
              screenWidth * 0.5,
              chaosFloorY - 45.0,
              I18n.tr('boss_attack_bricks_advanced'),
              const Color(0xFFFF1744),
              isLarge: true,
            );
            continue;
          }
        } else if (paddle.rect.contains(Offset(p.x, p.y))) {
          // Bullet Tennis! Intercept and deflect back up at the boss
          p.isBossBullet = false;
          p.isRocket = true;
          p.vy = -p.vy.abs() * 1.55;
          p.vx = ((p.x - (paddle.x + paddle.width / 2)) / (paddle.width / 2)) * 120.0;
          particles.triggerShake(4.0, 0.20);
          particles.spawnBurst(p.x, p.y, const Color(0xFFFFD700), count: 14, speed: 140.0);
          particles.spawnFloatingText(p.x, paddle.y - 20, I18n.tr('bullet_deflected'), const Color(0xFFFFD700), isLarge: true);
          audio.playSfx(GameSfx.laser);
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
            } else if (p.isShrapnel) {
              _hitBrick(b, null);
              particles.spawnBurst(p.x, p.y, const Color(0xFFECEFF1), count: 6, speed: 120.0);
              audio.playSfx(GameSfx.steel);
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
      } else if (save.hasPermanentRelic) {
        // Midas Micro-Attraction: subtle magnetic pull towards paddle center
        final dx = paddleCenter.dx - c.x;
        final dy = paddleCenter.dy - c.y;
        final dist = sqrt(dx * dx + dy * dy);
        if (dist > 2.0 && dist < 250.0) {
          const pull = 38.0;
          c.x += (dx / dist) * pull * dt;
          c.y += (dy / dist) * (pull * 0.4) * dt;
        }
      } else if (magnetLevel > 0) {
        final dx = paddleCenter.dx - c.x;
        final dy = paddleCenter.dy - c.y;
        final dist = sqrt(dx * dx + dy * dy);
        final pullRange = 100.0 + magnetLevel * 25.0;
        if (dist > 2.0 && dist < pullRange) {
          final pull = 120.0 + magnetLevel * 45.0;
          c.x += (dx / dist) * pull * dt;
          c.y += (dy / dist) * (pull * 0.6) * dt;
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

      // Boss shooting (Spread Attack) — slower volleys, slower bullets
      if (b.isAlive && b.isBoss && b.shootTimer <= 0) {
        b.shootTimer = b.isEnraged ? 4.2 + _rand.nextDouble() * 0.9 : 5.5 + _rand.nextDouble() * 1.2;

        // Shoot 3 bullets in a spread pattern with generous reaction time
        final centerX = b.x + b.width / 2;
        final bottomY = b.y + b.height + 6.0;

        projectiles.add(Projectile(x: centerX - 20, y: bottomY, vx: -50.0, vy: 125.0, radius: 6.0, isBossBullet: true));
        projectiles.add(Projectile(x: centerX, y: bottomY, vy: 125.0, radius: 7.0, isBossBullet: true));
        projectiles.add(Projectile(x: centerX + 20, y: bottomY, vx: 50.0, vy: 125.0, radius: 6.0, isBossBullet: true));
        
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
        descendRowsSurvived++;
        save.recordDescendRowQuest();
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
      p.update(dt, screenWidth: screenWidth);
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

      // Collision with Easter Egg Bee (only while it is still flying free)
      if (activeBee != null && activeBee!.isAlive && activeBee!.state == BeeState.flying) {
        final bdx = ball.x - activeBee!.x;
        final bdy = ball.y - activeBee!.y;
        final distSq = bdx * bdx + bdy * bdy;
        final hitDist = ball.radius + activeBee!.hitRadius;
        if (distSq <= hitDist * hitDist) {
          if (ball.isFrost) {
            _freezeBee();
          } else if (ball.isFireball) {
            _burnBee();
          } else {
            final splatX = activeBee!.x;
            final splatY = activeBee!.y;
            activeBee!.isAlive = false;
            activeBee = null;
            activeSplat = WindshieldSplat(x: splatX, y: splatY, duration: 2.0);
            stats.score += 100;
            particles.spawnBurst(splatX, splatY, const Color(0xFFD31018), count: 24, speed: 110.0);
            particles.spawnFloatingText(splatX, splatY - 18.0, 'BZZZ! SPLAT! +100', const Color(0xFFFF1744), isLarge: true);
            audio.playSfx(GameSfx.breakBrick, combo: stats.combo);
          }
        } else if (ball.isFireball && distSq <= (hitDist + 26.0) * (hitDist + 26.0)) {
          // A fireball passing close enough still singes the bee.
          _burnBee();
        } else if (ball.isFrost && distSq <= (hitDist + 9.0) * (hitDist + 9.0)) {
          _freezeBee();
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

      // Gravitational attraction from gravity portals
      for (final p in portals) {
        if (p.type == PortalType.gravity) {
          final dx = p.x - ball.x;
          final dy = p.y - ball.y;
          final distSq = dx * dx + dy * dy;
          if (distSq > p.radius * p.radius && distSq < 75.0 * 75.0) {
            final dist = sqrt(distSq);
            final force = (1.0 - dist / 75.0) * 130.0;
            ball.vx += (dx / dist) * force * dt;
            ball.vy += (dy / dist) * force * dt;
          }
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

            // Safe human-reactable exit angle: If directed downward, avoid pure vertical missile dive
            if (dirY > 0.85) {
              dirX = (dirX.sign == 0 ? (ball.x > screenWidth / 2 ? -0.4 : 0.4) : dirX.sign * 0.45);
              dirY = sqrt(max(0.1, 1.0 - dirX * dirX));
            }

            // Safe ejection distance outside target portal's event horizon
            final ejectDist = target.radius + ball.radius + 6.0;
            ball.x = (target.x + dirX * ejectDist).clamp(ball.radius + 12.0, screenWidth - ball.radius - 12.0);
            // Critical safeguard: Ejection point is NEVER lower than paddle.y - 100.0,
            // preventing the ball from instantly escaping past the paddle!
            ball.y = (target.y + dirY * ejectDist).clamp(42.0, paddle.y - 100.0);

            // Accelerator portal supercharge:
            if (target.type == PortalType.accelerator || p.type == PortalType.accelerator) {
              ball.setSpeed((currentSpd * 1.15).clamp(getBaseBallSpeed(), 850.0));
              ball.cornerBoostTimer = max(ball.cornerBoostTimer, 2.5);
              particles.spawnBurst(target.x, target.y, const Color(0xFFFFD700), count: 32, speed: 160.0);
              particles.spawnShockwave(target.x, target.y, const Color(0xFFFFD700), maxRadius: 50.0);
            } else {
              ball.setSpeed(currentSpd.clamp(getBaseBallSpeed(), 850.0));
            }
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

      // Kaos modu anti-stuck & recall (Ghost balls flying straight to launcher without brick collisions):
      if (currentMode == GameMode.chaos) {
        if (chaosRecallActive) {
          final targetX = chaosHomeX;
          final targetY = chaosFloorY;
          final dx = targetX - ball.x;
          final dy = targetY - ball.y;
          final dist = sqrt(dx * dx + dy * dy);
          if (dist > 6.0) {
            const recallSpeed = 850.0;
            ball.vx = (dx / dist) * recallSpeed;
            ball.vy = (dy / dist) * recallSpeed;
          } else {
            ball.vy = 850.0;
          }
        } else {
          // Anti-bug / Anti-stuck:
          if (ball.sideWallBounceCount >= 3 && ball.vy.abs() < 80.0) {
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

      // Guided Strike / Target Lock: Ball curves and tracks directly towards locked target brick!
      if (lockedTargetBrick != null &&
          lockedTargetBrick!.isAlive &&
          (ball == targetLockingBall || balls.length == 1) &&
          !ball.isStuck) {
        final tx = lockedTargetBrick!.x + lockedTargetBrick!.width / 2;
        final ty = lockedTargetBrick!.y + lockedTargetBrick!.height / 2;
        final dx = tx - ball.x;
        final dy = ty - ball.y;
        final dist = sqrt(dx * dx + dy * dy);
        if (dist > 8.0) {
          final curSpeed = ball.speed.clamp(getBaseBallSpeed(), 650.0);
          final targetVx = (dx / dist) * curSpeed;
          final targetVy = (dy / dist) * curSpeed;
          // Crisp, intelligent homing turn towards target
          final steer = (dt * 9.5).clamp(0.05, 0.40);
          ball.vx = ball.vx * (1.0 - steer) + targetVx * steer;
          ball.vy = ball.vy * (1.0 - steer) + targetVy * steer;
          final normSpeed = sqrt(ball.vx * ball.vx + ball.vy * ball.vy);
          if (normSpeed > 0) {
            ball.vx = (ball.vx / normSpeed) * curSpeed;
            ball.vy = (ball.vy / normSpeed) * curSpeed;
          }
        }
      }

      // Gravity Pin Blessing: pulls upper ball towards nearest dense brick cluster
      if (activeSectorBlessing?.type == SectorBlessingType.gravityPin &&
          ball.y < screenHeight * 0.25 &&
          !ball.isStuck &&
          currentMode != GameMode.chaos) {
        Brick? nearest;
        double minDistSq = 999999.0;
        for (final b in bricks) {
          if (!b.isAlive || b.isSteel) continue;
          final dSq = (b.x + b.width / 2 - ball.x) * (b.x + b.width / 2 - ball.x) +
                      (b.y + b.height / 2 - ball.y) * (b.y + b.height / 2 - ball.y);
          if (dSq < minDistSq) {
            minDistSq = dSq;
            nearest = b;
          }
        }
        if (nearest != null && minDistSq > 220.0) {
          final steerX = (nearest.x + nearest.width / 2) > ball.x ? 38.0 : -38.0;
          ball.vx += steerX * dt;
        }
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
        if (currentMode == GameMode.chaos && ball.y > chaosFloorY) {
          break;
        }
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
          // Anti-horizontal infinite bounce trapping: inject vertical deflection
          if (ball.sideWallBounceCount >= 3 && ball.vy.abs() < 85.0) {
            ball.vy = (ball.vy >= 0 ? 1.0 : -1.0) * max(ball.vy.abs(), 95.0);
            ball.setSpeed(ball.speed);
          }
          if (ball.sideWallBounceCount >= 4) {
            final nudge = (ball.y < screenHeight * 0.45) ? 75.0 : -75.0;
            ball.vy += nudge;
            ball.setSpeed(ball.speed);
          }
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
          if (ball.sideWallBounceCount >= 3 && ball.vy.abs() < 85.0) {
            ball.vy = (ball.vy >= 0 ? 1.0 : -1.0) * max(ball.vy.abs(), 95.0);
            ball.setSpeed(ball.speed);
          }
          if (ball.sideWallBounceCount >= 4) {
            final nudge = (ball.y < screenHeight * 0.45) ? 75.0 : -75.0;
            ball.vy += nudge;
            ball.setSpeed(ball.speed);
          }
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

        // Brick collision (Ghost balls pass through all bricks harmlessly during recall)
        if (!(currentMode == GameMode.chaos && chaosRecallActive)) {
          _checkBallBrickCollision(ball);
        }
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
        if (activeSectorBlessing?.type == SectorBlessingType.emergencyClutch &&
            !emergencyClutchUsedThisStage &&
            balls.length == 1) {
          emergencyClutchUsedThisStage = true;
          ball.y = paddle.y - ball.radius - 2.0;
          ball.vy = -ball.vy.abs();
          particles.triggerShake(7.0, 0.32);
          particles.spawnShockwave(screenWidth / 2, paddle.y + 15.0, const Color(0xFF76FF03), maxRadius: screenWidth);
          particles.spawnFloatingText(screenWidth / 2, paddle.y - 30.0, I18n.tr('blessing_clutch_title'), const Color(0xFF76FF03), isLarge: true);
          audio.playSfx(GameSfx.powerupBuff);
          continue;
        }
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

      // Step 2: Capped speed escalation (keep within human reaction limits)
      final baseSpeed = min(ball.speed + 4.0, 580.0);
      final isCornerHit = hitOffset.abs() >= 0.78;

      if (paddle.isClumsy) {
        // Kaygan Zemin aktifken:
        // Top normalde belli bir açıdan geliyorsa veya paddle hareketi topa ivme/spin veriyorsa bile,
        // kaygan yüzey nedeniyle bu tamamen iptal edilir:
        // Açı tamamen rastgele (-74° ile +74° arası) seçilir, paddle ivmesi sıfırlanır,
        // hız rastgele dalgalanır ve top oyuncunun kontrolü dışında tamamen rastgele bir yere fırlar!
        final randomAngle = (_rand.nextDouble() * 2.0 - 1.0) * (pi / 2.45); // ~ -74 deg .. +74 deg
        final clumsySpeed = (baseSpeed * (0.85 + _rand.nextDouble() * 0.35)).clamp(180.0, 620.0);
        ball.vx = sin(randomAngle) * clumsySpeed;
        ball.vy = -cos(randomAngle) * clumsySpeed;
        particles.spawnBurst(ball.x, paddle.y, const Color(0xFF80D8FF), count: 14, speed: 150.0);
        particles.spawnFloatingText(ball.x, paddle.y - 14, 'KAYGAN!', const Color(0xFF80D8FF));
        audio.playSfx(GameSfx.steel);
      } else {
        final bounceAngle = hitOffset * (pi / 2.7); // -66 deg to +66 deg
        final speedMultiplier = isCornerHit ? 1.35 : 1.0;
        final finalSpeed = (baseSpeed * speedMultiplier).clamp(100.0, 680.0);

        var vx = sin(bounceAngle) * finalSpeed;
        var vy = -cos(bounceAngle) * finalSpeed;

        // Spin transfer: Paddle motion applies natural spin, normalized to prevent erratic speed spikes
        vx += (paddle.velocityX * 0.18).clamp(-120.0, 120.0);
        final spinMag = sqrt(vx * vx + vy * vy);
        if (spinMag > 0) {
          vx = (vx / spinMag) * finalSpeed;
          vy = (vy / spinMag) * finalSpeed;
        }

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
      }

      ball.y = pr.top - ball.radius - 1.0;
      ball.triggerSquash(-pi / 2);
      paddle.triggerHitReaction(isCorner: isCornerHit);
      particles.spawnBrickShards(
        ball.x - 8.0,
        pr.top - 4.0,
        16.0,
        6.0,
        activePaddleSkin.glowColor,
        count: isCornerHit ? 5 : 3,
      );

      if (isCornerHit) {
        ball.cornerHitCount++;
        ball.cornerBoostTimer = 3.2; // Speeds up for 3.2 seconds
        ball.megaTimer = 2.5; // Option C: Mega Ball for 2.5 seconds!

        if (!firstCornerHitShown) {
          firstCornerHitShown = true;
          stats.bulletTimeLeft = 0.75; // Brief slow-motion pulse
          particles.triggerShake(6.0, 0.28);
          particles.spawnShockwave(ball.x, pr.top, const Color(0xFFFFD700), maxRadius: 85.0);
          particles.spawnFloatingText(
            screenWidth / 2,
            screenHeight * 0.38,
            '⚡ SÜPER KÖŞE VURUŞU!',
            const Color(0xFFFFD700),
            isLarge: true,
          );
        }

        // Outer 10% tip save bonus (silent bonus, no extra overlapping text!)
        final isClutchSave = hitOffset.abs() >= 0.90 && balls.length == 1;
        if (isClutchSave) {
          stats.score += 150;
          // Near-miss: 0.35s cinematic slow-mo + neon edge flash (5s cooldown).
          if (_nearMissCooldown <= 0 && _nearMissSlowLeft <= 0) {
            _nearMissCooldown = 5.0;
            nearMissFlashTimer = 0.55;
            _nearMissSlowLeft = 0.35;
            particles.triggerShake(4.0, 0.2);
            audio.playSfx(GameSfx.powerupBuff, playbackRate: 0.7);
          }
        }
        stats.ultiCharge = (stats.ultiCharge + 3.0 * cosmicPearlUltiMultiplier).clamp(0.0, 100.0);

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

        // Springboard blessing: explosive center bounce
        if (activeSectorBlessing?.type == SectorBlessingType.springboard && hitOffset.abs() <= 0.22) {
          ball.vy = -ball.vy.abs() * 1.35;
          ball.vx *= 0.45;
          particles.spawnBurst(ball.x, pr.top, const Color(0xFFFF6D00), count: 18, speed: 160.0);
          particles.spawnFloatingText(ball.x, pr.top - 24, I18n.tr('blessing_spring_title'), const Color(0xFFFF6D00), isLarge: true);
          audio.playSfx(GameSfx.cornerBoost);
        }
      }

      // Chrono-Smash: bullet time on paddle hit
      if (activeSectorBlessing?.type == SectorBlessingType.chronoSmash) {
        chronoBulletTimeTimer = 0.28;
        stats.bulletTimeLeft = 0.28;
        particles.spawnShockwave(ball.x, pr.top, const Color(0xFFFFD54F), maxRadius: 45.0);
      }

      // Prismatic Splitter: chance to duplicate ball when lone ball hits paddle
      if (activeSectorBlessing?.type == SectorBlessingType.prismaticSplitter && balls.length == 1) {
        if (_rand.nextDouble() < 0.22) {
          final clone = Ball(
            x: ball.x,
            y: ball.y - 4,
            vx: -ball.vx * 0.85,
            vy: ball.vy * 0.9,
            radius: 6.0,
          );
          balls.add(clone);
          particles.spawnBurst(ball.x, pr.top, const Color(0xFFE040FB), count: 14, speed: 120.0);
          particles.spawnFloatingText(ball.x, pr.top - 24, I18n.tr('blessing_prismatic_title'), const Color(0xFFE040FB));
          audio.playSfx(GameSfx.powerupBuff);
        }
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
    final r = ball.effectiveRadius;
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
        if (ball.isFrost || activePowerUps.any((p) => p.type == PowerUpType.frost)) {
          if (b.isIce) {
            // Frost striking a true ice brick flash-freezes a huge 2x area!
            _freezeArea(b.x + b.width / 2, b.y + b.height / 2, radius: 210.0, freezeAll: true);
            particles.spawnFloatingText(b.x + b.width / 2, b.y - 12, 'BÜYÜK BUZ PATLAMASI!', const Color(0xFF80D8FF), isLarge: true);
          } else {
            _freezeArea(b.x + b.width / 2, b.y + b.height / 2, radius: 95.0);
          }
          // Buz yeteneği tek vuruşluk: 1 vuruştan sonra biter!
          ball.isFrost = false;
          activePowerUps.removeWhere((p) => p.type == PowerUpType.frost);
          particles.spawnBurst(ball.x, ball.y, const Color(0xFF80D8FF), count: 14, speed: 130.0);
        }
        if (ball.isShrapnel || activePowerUps.any((p) => p.type == PowerUpType.shrapnel)) {
          _spawnShrapnel(b.x + b.width / 2, b.y + b.height / 2);
        }
        if (!b.isTuft) {
          break;
        }
      }
    }
  }

  void _spawnShrapnel(double bx, double by) {
    const spd = 520.0;
    // Focused vertical kinetic shrapnel aimed directly at the brick directly above
    projectiles.add(Projectile(
      x: bx,
      y: by - 4.0,
      vx: 0.0,
      vy: -spd,
      radius: 3.5,
      isShrapnel: true,
    ));
    particles.spawnBurst(bx, by, const Color(0xFFCFD8DC), count: 6, speed: 120.0);
    audio.playSfx(GameSfx.steel);
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
      particles.spawnBurst(b.x + b.width / 2, b.y + b.height / 2, const Color(0xFF80D8FF), count: 24, speed: 200.0);
      particles.spawnShockwave(b.x + b.width / 2, b.y + b.height / 2, const Color(0xFF00E5FF), maxRadius: 36.0);
      particles.spawnFloatingText(b.x + b.width / 2, b.y, I18n.tr('ice_shattered'), const Color(0xFF80D8FF));
      audio.playSfx(GameSfx.breakBrick, combo: stats.combo);
      final frostHit = (ball?.isFrost ?? false) || activePowerUps.any((p) => p.type == PowerUpType.frost);
      if (frostHit) {
        _shatterFrozenChain(b);
      } else {
        b.isFrozen = false;
      }
      return;
    }

    // A frost ball can never detonate dynamite: it freezes it solid so it
    // can later be shattered like a normal brick.
    final frostHitNow = (ball?.isFrost ?? false) || activePowerUps.any((p) => p.type == PowerUpType.frost);
    if (frostHitNow && b.isDynamite) {
      b.isFrozen = true;
      particles.spawnBurst(b.x + b.width / 2, b.y + b.height / 2, const Color(0xFF80D8FF), count: 16, speed: 150.0);
      particles.spawnShockwave(b.x + b.width / 2, b.y + b.height / 2, const Color(0xFF00E5FF), maxRadius: 30.0);
      particles.spawnFloatingText(b.x + b.width / 2, b.y - 6, 'DONDU!', const Color(0xFF80D8FF));
      audio.playSfx(GameSfx.breakBrick, combo: stats.combo);
      ball?.isFrost = false;
      activePowerUps.removeWhere((p) => p.type == PowerUpType.frost);
      return;
    }
    if (b.isTuft) {
      if (!b.tuftFilled) {
        b.tuftFilled = true;
        b.color = b.tuftColor;
        particles.spawnBurst(b.x + b.width / 2, b.y + b.height / 2, b.tuftColor, count: 8);
        audio.playSfx(GameSfx.hitBrick, combo: stats.combo);
        _registerCombo(b.points);

    // Sector Blessing: Sonic Ripple
    if (activeSectorBlessing?.type == SectorBlessingType.sonicRipple) {
      particles.spawnShockwave(b.x + b.width / 2, b.y + b.height / 2, const Color(0xFFFF4081), maxRadius: 55.0);
      stats.score += 25 * (stats.combo + 1);
    }

    // Sector Blessing: Ghost Echo
    if (activeSectorBlessing?.type == SectorBlessingType.ghostEcho) {
      final neighbors = bricks.where((other) =>
          other != b && other.isAlive && !other.isSteel &&
          (other.x - b.x).abs() <= 60 && (other.y - b.y).abs() <= 60).toList();
      if (neighbors.isNotEmpty) {
        final target = neighbors[_rand.nextInt(neighbors.length)];
        _hitBrick(target, null);
        particles.spawnBurst(target.x + target.width / 2, target.y + target.height / 2, const Color(0xFFB388FF), count: 8, speed: 85.0);
      }
    }
      }
      return;
    }

    if (currentMode == GameMode.chaos) {
      int dmg = 1;
      final emberStacks = activeChaosPerks.where((p) => p == ChaosPerkType.emberCore).length;
      if (emberStacks > 0) {
        dmg += emberStacks;
      }
      if (activeCosmeticSynergy == CosmeticSynergy.iceCrystal &&
          (b.isIce || b.maxHp > 1 || b.isHeavySteel)) {
        dmg += activeCosmeticSynergy.extraIceArmoredDamage;
      }
      final fishBuffs = FishSynergyBuffs.calculate(save);
      final critLvl = save.getUpgradeLevel('u_crit');
      final cosmicBonus = save.cosmicGoldMasteryLevel * 0.02;
      final totalCritChance = critLvl * 0.035 + cosmicBonus * 0.5 + fishBuffs.critChanceBonus;
      if (totalCritChance > 0 && _rand.nextDouble() < totalCritChance) {
        dmg += 1;
        if (cosmicBonus > 0 && _rand.nextDouble() < cosmicBonus) dmg += 1;
        particles.spawnFloatingText(b.x + b.width / 2, b.y - 8, 'KRİTİK!', const Color(0xFFFF5252));
      } else if (cosmicBonus > 0 && _rand.nextDouble() < cosmicBonus) {
        dmg += 1;
      }
      b.hp -= dmg;
      b.jelly = 0.35;
      stats.score += (dmg * activeCosmeticSynergy.scoreMultiplier).round();
      _chaosHitCounter++;
      if (activeChaosPerks.contains(ChaosPerkType.chainShock) && _chaosHitCounter % 8 == 0) {
        final neighbors = bricks.where((nb) => nb.isAlive && !nb.isBallPickup && nb != b).take(2).toList();
        for (final nb in neighbors) {
          nb.hp -= 1;
          particles.spawnBurst(nb.x + nb.width / 2, nb.y + nb.height / 2, const Color(0xFF00E5FF), count: 5);
          if (nb.hp <= 0) {
            _destroyBrick(nb);
          }
        }
      }
      if (b.hp <= 0) {
        _destroyBrick(b);
      } else if (b.hp % 6 == 0) {
        audio.playSfx(GameSfx.hitBrick, combo: stats.combo);
      }
      return;
    }

    int dmg = 1;
    if (b == lockedTargetBrick) {
      lockedTargetBrick = null;
      targetLockingBall = null;
      targetLockTimer = 0.0;
      dmg += 3; // Huge guided missile damage!
      particles.spawnShockwave(b.x + b.width / 2, b.y + b.height / 2, const Color(0xFF00E5FF), maxRadius: 52.0);
      particles.spawnBurst(b.x + b.width / 2, b.y + b.height / 2, const Color(0xFFFFD54F), count: 16, speed: 160.0);
      particles.triggerShake(4.5, 0.22);
      audio.playSfx(GameSfx.bossHit);
    }
    if (activeCosmeticSynergy == CosmeticSynergy.iceCrystal &&
        (b.isIce || b.maxHp > 1 || b.isHeavySteel)) {
      dmg += activeCosmeticSynergy.extraIceArmoredDamage;
    }
    final fishBuffs = FishSynergyBuffs.calculate(save);
    final critLvl = save.getUpgradeLevel('crit_damage');
    final cosmicBonus = save.cosmicGoldMasteryLevel * 0.02;
    final totalCritChance = critLvl * 0.035 + cosmicBonus * 0.5 + fishBuffs.critChanceBonus;
    if (totalCritChance > 0 && _rand.nextDouble() < totalCritChance) {
      dmg += 1;
      if (cosmicBonus > 0 && _rand.nextDouble() < cosmicBonus) dmg += 1;
      particles.spawnFloatingText(b.x + b.width / 2, b.y - 8, 'KRİTİK!', const Color(0xFFFF5252));
    } else if (cosmicBonus > 0 && _rand.nextDouble() < cosmicBonus) {
      dmg += 1;
    }
    b.hp -= dmg;
    b.jelly = 0.8;
    endgameStallTimer = 0.0;

    if (activeSectorBlessing?.type == SectorBlessingType.resonanceTether && ball != null) {
      if (ball.x >= paddle.x && ball.x <= paddle.x + paddle.width) {
        stats.score += (b.points * 0.5).round();
        particles.spawnBurst(ball.x, ball.y, const Color(0xFF00E5FF), count: 6, speed: 80.0);
      }
    }

    if (b.hp <= 0) {
      _destroyBrick(b);
    } else {
      // Step 1: Hit white flash
      b.triggerWhiteFlash(b.isBoss ? 0.035 : 0.025);
      particles.spawnBurst(b.x + b.width / 2, b.y + b.height / 2, b.color, count: 6);
      if (b.isBoss) {
        b.triggerElasticSettle(impulse: 6.5);
        particles.spawnPixelWave(b.x, b.y, b.width, b.height, const Color(0xFFFF1744));
        particles.spawnBrickShards(b.x, b.y, b.width, b.height, const Color(0xFFFF5252), count: 4);
        audio.playSfx(GameSfx.bossHit);
        particles.triggerShake(4.0, 0.16);
        _bossHitsCounter++;
        // Boss milestone & hit capsule drops
        if (_bossHitsCounter % 5 == 0 || b.hp == (b.maxHp * 0.75).round() || b.hp == (b.maxHp * 0.50).round() || b.hp == (b.maxHp * 0.25).round()) {
          _rollCapsuleDrop(b.x + b.width / 2, b.y + b.height + 8.0, force: true);
        }
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
        audio.playSfx(GameSfx.hitBrick, combo: stats.combo);
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
    final batteryLvl = save.getUpgradeLevel('battery');
    final ultiGain = (1.0 + (batteryLvl * 0.15)) * cosmicPearlUltiMultiplier * 1.08;
    stats.ultiCharge = (stats.ultiCharge + ultiGain).clamp(0.0, 100.0);
  }

  @visibleForTesting
  void destroyBrickForTest(Brick b) => _destroyBrick(b);

  @visibleForTesting
  void hitBrickForTest(Brick b, [Ball? ball]) => _hitBrick(b, ball);

  void _destroyBrick(Brick b) {
    b.isAlive = false;
    if (b == lockedTargetBrick) {
      lockedTargetBrick = null;
      targetLockingBall = null;
      targetLockTimer = 0.0;
    }
    stats.bricksBroken++;
    levelBricksBroken++;
    save.recordBrickBrokenQuest();
    _chargeDiceFromGlass(b);
    if (currentMode == GameMode.classic && stats.level <= 3 && !save.seenFirstShot) {
      save.markFirstShotSeen();
      showOnceTip('first_break', I18n.tr('tip_first_break'));
    }

    // Step 1: Patlayan blok saf beyaz renge bürünür, 35ms hit-stop
    b.triggerWhiteFlash(0.035);
    triggerHitStop(BalanceConfig.hitStopDurationSeconds);

    // Step 2: Soldan sağa doğru kare piksellerden oluşan dalga yayılır
    particles.spawnPixelWave(b.x, b.y, b.width, b.height, b.color);

    // Step 3: Bloklar etrafa küçük, sert keskin piksel parçacıkları (pixel chunks) halinde zıplayarak dağılır
    particles.spawnBrickShards(b.x, b.y, b.width, b.height, b.color, count: b.isBoss ? 16 : 6);

    // Step 5: Kalan komşu ve aynı satırdaki bloklar yerine zıplayarak (elastic overshoot) oturur
    for (final other in bricks) {
      if (!other.isAlive || other == b) continue;
      final dy = (other.y - b.y).abs();
      final dx = (other.x - b.x).abs();
      if (dy < 26.0 || (dx < 75.0 && dy < 75.0)) {
        final dist = sqrt(dx * dx + dy * dy);
        final impulse = max(1.5, 5.2 - (dist / 24.0));
        other.triggerElasticSettle(impulse: impulse);
      }
    }

    // Decoupled Game Event Bus dispatch
    GameEventBus().fire(
      BrickDestroyedEvent(
        position: Offset(b.x + b.width / 2, b.y + b.height / 2),
        brickTypeIndex: b.type.index,
        comboCount: stats.combo,
        wasSolid: !b.isBallPickup,
        goldAwarded: b.isBoss ? BalanceConfig.bossBrickGold : BalanceConfig.regularBrickGold,
      ),
    );

    if (stats.combo == BalanceConfig.feverComboThreshold || stats.combo == BalanceConfig.cosmicComboThreshold) {
      GameEventBus().fire(
        ComboMilestoneEvent(
          comboCount: stats.combo,
          isFever: stats.combo >= BalanceConfig.feverComboThreshold,
          triggerPosition: Offset(b.x + b.width / 2, b.y + b.height / 2),
        ),
      );
      particles.triggerShake(stats.combo >= BalanceConfig.cosmicComboThreshold ? 5.0 : 3.0, 0.25);
    }

    if (currentMode == GameMode.chaos) {
      particles.spawnBurst(b.x + b.width / 2, b.y + b.height / 2, b.color, count: 4);
      audio.playSfx(GameSfx.breakBrick, combo: stats.combo);
      stats.score += (15 * activeCosmeticSynergy.scoreMultiplier).round();
      _checkLiveNewRecordCelebration();

      if (b.isBoss) {
        final bossGold = 75 + (stats.level ~/ 10) * 25;
        stats.goldCollected += bossGold;
        save.addGold(bossGold);
        save.addPearls(2);
        particles.spawnShockwave(b.x + b.width / 2, b.y + b.height / 2, const Color(0xFFFFD700), maxRadius: 100.0);
        particles.spawnFloatingText(b.x + b.width / 2, b.y - 16, '+$bossGold ALTIN! +2 İNCİ!', const Color(0xFFFFD700), isLarge: true);
        audio.playSfx(GameSfx.explosion);
      }

      if (activeChaosPerks.contains(ChaosPerkType.microBlast) && stats.bricksBroken % 6 == 0) {
        final cx = b.x + b.width / 2;
        final cy = b.y + b.height / 2;
        particles.spawnShockwave(cx, cy, const Color(0xFFFF9100), maxRadius: 65.0);
        for (final nb in bricks) {
          if (!nb.isAlive || nb.isBallPickup || nb == b) continue;
          final nbx = nb.x + nb.width / 2;
          final nby = nb.y + nb.height / 2;
          if (sqrt((nbx - cx) * (nbx - cx) + (nby - cy) * (nby - cy)) <= 65.0) {
            nb.hp -= 2;
            if (nb.hp <= 0) {
              nb.isAlive = false;
              stats.bricksBroken++;
            }
          }
        }
      }

      // Coin drops in Chaos Mode scaled by u_luck and u_gold
      final luckLvl = save.getUpgradeLevel('u_luck');
      final dropRate = 0.20 + (luckLvl * 0.04) + cosmicPearlLuckBonus;
      if (_rand.nextDouble() < dropRate) {
        final goldLvl = save.getUpgradeLevel('u_gold');
        int coins = 1 + _rand.nextInt(3);
        coins = (coins * (1.0 + goldLvl * 0.10)).round();
        if (save.cosmicGoldMasteryLevel > 0) {
          coins = (coins * cosmicGoldRewardMultiplier).round();
        }
        if (activeCosmeticSynergy == CosmeticSynergy.cosmicLegendary) {
          coins = (coins * activeCosmeticSynergy.goldMultiplier).round();
        }
        if (coins > 0) {
          stats.goldCollected += coins;
          save.addGold(coins);
          particles.spawnFloatingText(b.x + b.width / 2, b.y, '+$coins ', const Color(0xFFFFD54F));
          particles.spawnCoinOrbs(b.x + b.width / 2, b.y + b.height / 2, count: coins >= 8 ? 5 : 3, totalValue: coins);
        }
      }

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
      // Boss kills pay out like a headline moment: gold shower + a pearl.
      final bossGold = 50 + stats.level;
      stats.goldCollected += bossGold;
      save.addGold(bossGold);
      save.addPearls(1);
      particles.spawnCoinOrbs(b.x + b.width / 2, b.y + b.height / 2, count: 6, totalValue: bossGold);
      particles.spawnFloatingText(b.x + b.width / 2, b.y - 38, '+$bossGold ALTIN! +1 İNCİ!', const Color(0xFFFFD700), isLarge: true);
      audio.playSfx(GameSfx.explosion);
    } else {
      particles.spawnBurst(b.x + b.width / 2, b.y + b.height / 2, b.color, count: 16);
      particles.spawnShockwave(b.x + b.width / 2, b.y + b.height / 2, b.color, maxRadius: 40.0);
      audio.playSfx(GameSfx.breakBrick, combo: stats.combo);
    }

    _registerCombo(b.points);

    // Sector Blessing: Sonic Ripple
    if (activeSectorBlessing?.type == SectorBlessingType.sonicRipple) {
      particles.spawnShockwave(b.x + b.width / 2, b.y + b.height / 2, const Color(0xFFFF4081), maxRadius: 55.0);
      stats.score += 25 * (stats.combo + 1);
    }

    // Sector Blessing: Ghost Echo
    if (activeSectorBlessing?.type == SectorBlessingType.ghostEcho) {
      final neighbors = bricks.where((other) =>
          other != b && other.isAlive && !other.isSteel &&
          (other.x - b.x).abs() <= 60 && (other.y - b.y).abs() <= 60).toList();
      if (neighbors.isNotEmpty) {
        final target = neighbors[_rand.nextInt(neighbors.length)];
        _hitBrick(target, null);
        particles.spawnBurst(target.x + target.width / 2, target.y + target.height / 2, const Color(0xFFB388FF), count: 8, speed: 85.0);
      }
    }

    if (b.isDynamite && !b.isFrozen) {
      final frostInPlay = balls.any((ball) => ball.isFrost) || activePowerUps.any((p) => p.type == PowerUpType.frost);
      if (!frostInPlay) {
        // Under a fireball, dynamite blows twice as wide with a growing ring.
        final fireballInPlay = balls.any((ball) => ball.isFireball) || activePowerUps.any((p) => p.type == PowerUpType.fireball);
        if (fireballInPlay) {
          particles.spawnShockwave(b.x + b.width / 2, b.y + b.height / 2, const Color(0xFFFF9100), maxRadius: 165.0);
          particles.spawnShockwave(b.x + b.width / 2, b.y + b.height / 2, const Color(0xFFFFD54F), maxRadius: 110.0);
          particles.spawnFloatingText(b.x + b.width / 2, b.y - 14, '2X MEGA PATLAMA!', const Color(0xFFFF9100), isLarge: true);
          particles.triggerShake(6.5, 0.32);
        }
        _explodeArea(b.x + b.width / 2, b.y + b.height / 2, radius: fireballInPlay ? 160.0 : 80.0);
      }
    } else if (b.isIce) {
      _freezeArea(b.x + b.width / 2, b.y + b.height / 2, radius: 90.0);
    }

    // R4: Guaranteed Action Capsule Drop in Levels 1–5
    bool actionDropped = false;
    if (stats.level <= 5 && !isChaosMode && !isZenMode && !earlyActionDropGranted) {
      if (levelBricksBroken <= 3) {
        final shouldDrop = levelBricksBroken == 1 || (levelBricksBroken == 3 && !earlyActionDropGranted);
        if (shouldDrop) {
          earlyActionDropGranted = true;
          actionDropped = true;
          // Fire and frost are mutually exclusive: never hand out fireball
          // while frost is in play (the normal roll below enforces the rest).
          final frostInPlay = balls.any((ball) => ball.isFrost) ||
              activePowerUps.any((p) => p.type == PowerUpType.frost);
          final actionType = frostInPlay
              ? PowerUpType.multiBall
              : (_rand.nextBool() ? PowerUpType.multiBall : PowerUpType.fireball);
          capsules.add(FallingCapsule(x: b.x + b.width / 2, y: b.y + b.height / 2, type: actionType));
        }
      }
    }

    // Roll powerup drop
    if (!actionDropped) {
      _rollCapsuleDrop(b.x + b.width / 2, b.y + b.height / 2);
    }

    // Balanced coin gain: 30% drop rate, 2-5 coins + combo bonus
    final luckLvl = save.getUpgradeLevel('u_luck');
    final relicAlchemistBonus = (save.hasPermanentRelic && save.activeRelicStyle == 'alchemist') ? 0.15 : 0.0;
    final coinDropRate = 0.30 + (luckLvl * 0.04) + cosmicPearlLuckBonus + relicAlchemistBonus;
    if (_rand.nextDouble() < coinDropRate) {
      final goldLvl = save.getUpgradeLevel('u_gold');
      int coins = 2 + _rand.nextInt(4);
      if (stats.combo >= 5) coins += 2;
      coins = (coins * (1.0 + goldLvl * 0.10)).round();
      if (save.cosmicGoldMasteryLevel > 0) {
        coins = (coins * cosmicGoldRewardMultiplier).round();
      }
      if (activeCosmeticSynergy == CosmeticSynergy.cosmicLegendary) {
        coins = (coins * activeCosmeticSynergy.goldMultiplier).round();
      }
      stats.goldCollected += coins;
      save.addGold(coins);
      particles.spawnFloatingText(b.x + b.width / 2, b.y, '+$coins ', const Color(0xFFFFD54F));
      particles.spawnCoinOrbs(b.x + b.width / 2, b.y + b.height / 2, count: coins >= 8 ? 5 : 3, totalValue: coins);
    }
  }

  /// Destroys every frozen brick connected (touching) to [start], chaining
  /// outward through neighbours. Frozen dynamite shatters silently.
  void _shatterFrozenChain(Brick start) {
    final chain = <Brick>[];
    final seen = <Brick>{start};
    final queue = <Brick>[start];
    while (queue.isNotEmpty) {
      final cur = queue.removeAt(0);
      if (!cur.isAlive || !cur.isFrozen) continue;
      chain.add(cur);
      for (final other in bricks) {
        if (!other.isAlive || !other.isFrozen || seen.contains(other)) continue;
        final dx = (other.x + other.width / 2) - (cur.x + cur.width / 2);
        final dy = (other.y + other.height / 2) - (cur.y + cur.height / 2);
        final touchX = (cur.width + other.width) / 2 + 10.0;
        final touchY = (cur.height + other.height) / 2 + 10.0;
        if (dx.abs() <= touchX && dy.abs() <= touchY) {
          seen.add(other);
          queue.add(other);
        }
      }
    }
    if (chain.isEmpty) return;
    for (final brick in chain) {
      if (brick.isDynamite) {
        brick.isDynamite = false; // Disarm dynamite completely so it shatters as pure ice!
      }
      brick.isFrozen = false;
      particles.spawnBurst(brick.x + brick.width / 2, brick.y + brick.height / 2, const Color(0xFFB3E5FC), count: 8, speed: 160.0);
      _destroyBrick(brick);
    }
    if (chain.length > 1) {
      particles.triggerShake(min(2.0 + chain.length * 0.5, 6.0), 0.22);
      particles.spawnFloatingText(start.x + start.width / 2, start.y - 10, 'ZİNCİR KIRILDI! x${chain.length}', const Color(0xFF80D8FF), isLarge: true);
      audio.playSfx(GameSfx.explosion, playbackRate: 1.3);
    }
  }

  void _freezeArea(double cx, double cy, {double radius = 90.0, bool freezeAll = false}) {
    particles.spawnBurst(cx, cy, const Color(0xFF80D8FF), count: 28, speed: 200.0);
    particles.spawnShockwave(cx, cy, const Color(0xFF00E5FF), maxRadius: radius);
    audio.playSfx(GameSfx.breakBrick);

    // 1. Any TNT / Dynamite blocks in range are guaranteed to freeze!
    for (final b in bricks) {
      if (!b.isAlive || b.isSteel || b.isFrozen) continue;
      if (b.isDynamite) {
        final bx = b.x + b.width / 2;
        final by = b.y + b.height / 2;
        final dist = sqrt((bx - cx) * (bx - cx) + (by - cy) * (by - cy));
        if (dist <= radius * 1.15) {
          b.isFrozen = true;
          particles.spawnBurst(bx, by, const Color(0xFF80D8FF), count: 14, speed: 180.0);
          particles.spawnShockwave(bx, by, const Color(0xFF00E5FF), maxRadius: 26.0);
        }
      }
    }

    // 2. Also freeze 2 to 4 random neighboring normal bricks
    final candidates = bricks.where((b) {
      if (!b.isAlive || b.isSteel || b.isTuft || b.isFrozen || b.isDynamite) return false;
      final bx = b.x + b.width / 2;
      final by = b.y + b.height / 2;
      final dist = sqrt((bx - cx) * (bx - cx) + (by - cy) * (by - cy));
      return dist <= radius;
    }).toList();

    candidates.shuffle(_rand);
    final count = freezeAll ? candidates.length : min(candidates.length, 2 + _rand.nextInt(3)); // 2 to 4 blocks
    for (int i = 0; i < count; i++) {
      final b = candidates[i];
      b.isFrozen = true;
      particles.spawnBurst(b.x + b.width / 2, b.y + b.height / 2, const Color(0xFFE0F7FA), count: 8);
    }
  }

  void explodeArea(double cx, double cy, {double radius = 60.0}) =>
      _explodeArea(cx, cy, radius: radius);

  void _explodeArea(double cx, double cy, {double radius = 60.0}) {
    final effectiveRadius = radius * (1.0 + activeCosmeticSynergy.explosionRadiusBonus);
    particles.spawnBurst(cx, cy, const Color(0xFFFF5722), count: 28, speed: 240.0);
    particles.spawnShockwave(cx, cy, const Color(0xFFFF9800), maxRadius: effectiveRadius);
    particles.spawnPixelCrossBlast(cx, cy, effectiveRadius, const Color(0xFFFF5722));
    particles.triggerShake(5.0, 0.22);
    audio.playSfx(GameSfx.explosion);

    for (final b in bricks) {
      if (!b.isAlive || b.isSteel) continue;
      final bx = b.x + b.width / 2;
      final by = b.y + b.height / 2;
      final dist = sqrt((bx - cx) * (bx - cx) + (by - cy) * (by - cy));
      if (dist <= effectiveRadius) {
        if (b.isFrozen) {
          // TNT explosions shatter only the ice of frozen bricks! The brick itself survives!
          b.isFrozen = false;
          b.triggerWhiteFlash(0.035);
          b.triggerElasticSettle(impulse: 5.5);
          particles.spawnBurst(bx, by, const Color(0xFF80D8FF), count: 18, speed: 190.0);
          particles.spawnShockwave(bx, by, const Color(0xFF00E5FF), maxRadius: 30.0);
          audio.playSfx(GameSfx.breakBrick, combo: stats.combo);
        } else {
          _destroyBrick(b);
        }
      } else if (dist <= effectiveRadius + 48.0) {
        final impulse = max(1.8, 5.8 - ((dist - effectiveRadius) / 12.0));
        b.triggerElasticSettle(impulse: impulse);
      }
    }
  }

  void _checkLiveNewRecordCelebration() {
    if (!_hasCelebratedNewRecord && _sessionStartingBestScore > 0 && stats.score > _sessionStartingBestScore) {
      _hasCelebratedNewRecord = true;
      newRecordBannerTimer = 2.4;
      hudGoldPunchTimer = 1.0;
      particles.spawnShockwave(screenWidth / 2, screenHeight * 0.32, const Color(0xFFFFD700), maxRadius: 110.0);
      particles.spawnBurst(screenWidth / 2, screenHeight * 0.32, const Color(0xFFFFD54F), count: 35, speed: 210.0);
      particles.spawnBrickShards(screenWidth / 2 - 30, screenHeight * 0.30, 60, 14, const Color(0xFFFFD700), count: 8);
      particles.spawnCoinOrbs(screenWidth / 2, screenHeight * 0.32, count: 5);
      particles.spawnFloatingText(screenWidth / 2, screenHeight * 0.32, I18n.tr('new_record_broken'), const Color(0xFFFFD700), isLarge: true);
      audio.playSfx(GameSfx.victory);
    }
  }

  void _updateJuiceTimers(double dt) {
    if (hudGoldPunchTimer > 0) hudGoldPunchTimer = max(0.0, hudGoldPunchTimer - dt * 3.2);
    if (comboPulseTimer > 0) comboPulseTimer = max(0.0, comboPulseTimer - dt * 3.5);
    if (newRecordBannerTimer > 0) newRecordBannerTimer = max(0.0, newRecordBannerTimer - dt);
    if (reviveFlashTimer > 0) reviveFlashTimer = max(0.0, reviveFlashTimer - dt * 1.4);

    // Coin orbs fly to the gold pill on the left of the HUD; every landing
    // visibly adds its gold to the counter, punches it and plays a
    // rising-pitch clink sequence, finishing with a sparkle burst.
    if (particles.coinOrbs.isNotEmpty) {
      var arrivedNow = 0;
      var arrivedValue = 0;
      particles.updateCoinOrbs(dt, coinHudTarget, (value) {
        arrivedNow++;
        arrivedValue += value;
      });
      if (arrivedNow > 0) {
        coinArrivalCount += arrivedNow;
        hudGoldShown += arrivedValue;
        hudGoldPunchTimer = 1.0;
        _coinClinkIndex = min(_coinClinkIndex + arrivedNow, 12);
        audio.playSfx(GameSfx.bubble, playbackRate: 0.9 + _coinClinkIndex * 0.07);
        particles.spawnBurst(coinHudTarget.dx, coinHudTarget.dy, const Color(0xFFFFF9C4), count: 2, speed: 55.0);
        if (particles.coinOrbs.isEmpty) {
          particles.spawnBurst(coinHudTarget.dx, coinHudTarget.dy, const Color(0xFFFFD54F), count: 10, speed: 90.0);
          _coinClinkIndex = 0;
        }
      }
    }

    // Keep the shown gold honest: gold earned without orbs (bonuses) catches
    // up smoothly, and any overshoot snaps back to the real balance.
    if (hudGoldShown > save.gold) {
      hudGoldShown = save.gold;
    } else if (particles.coinOrbs.isEmpty && hudGoldShown < save.gold) {
      final diff = save.gold - hudGoldShown;
      final step = max(1, (diff * dt * 5.0).round());
      hudGoldShown += min(diff, step);
    }

    // Fever leaks rising embers; a fresh record keeps a golden ember fountain.
    if (stats.isFever && status == GameStatus.playing) {
      _feverEmberTimer -= dt;
      if (_feverEmberTimer <= 0) {
        _feverEmberTimer = 0.12;
        particles.spawnBurnEmber(_rand.nextDouble() * screenWidth, screenHeight * (0.35 + _rand.nextDouble() * 0.5));
      }
    }
    if (_hasCelebratedNewRecord && status == GameStatus.playing) {
      _recordEmberTimer -= dt;
      if (_recordEmberTimer <= 0) {
        _recordEmberTimer = 0.22;
        particles.spawnBurnEmber(screenWidth - 90.0 + _rand.nextDouble() * 50.0, 44.0);
      }
    }
  }

  void _registerCombo(int basePoints) {
    stats.combo++;
    comboPulseTimer = 1.0;
    if (stats.combo > stats.maxCombo) {
      stats.maxCombo = stats.combo;
    }
    comboTimer = 2.4 * (1.0 + activeCosmeticSynergy.comboMomentumBonus);

    double multiplier = activeCosmeticSynergy.scoreMultiplier;
    if (stats.combo >= 8) {
      multiplier *= 3.0;
      if (!stats.isFever) {
        stats.isFever = true;
        stats.feverTimeLeft = 6.0;
        particles.spawnFloatingText(screenWidth / 2, screenHeight * 0.35, I18n.tr('fever_mode'), const Color(0xFFFF9100), isLarge: true);
        particles.spawnShockwave(screenWidth / 2, screenHeight * 0.4, const Color(0xFFFFD700), maxRadius: screenWidth * 0.6);
        particles.triggerShake(4.0, 0.25);
        audio.playSfx(GameSfx.explosion);
        audio.playSfx(GameSfx.ulti, playbackRate: 0.8);
        audio.triggerHaptic(() async => audio.playSfx(GameSfx.hitBrick));
      }
    } else if (stats.combo >= 4) {
      multiplier *= 2.0;
    }

    if (activePowerUps.any((p) => p.type == PowerUpType.doublescore)) {
      multiplier *= 2.0;
    }

    if (stats.combo >= 2 && save.hasPermanentRelic && save.activeRelicStyle == 'overdrive') {
      multiplier *= 1.20; // Overdrive: +20% combo score
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

  void _rollCapsuleDrop(double x, double y, {bool force = false}) {
    // At most 2 active power-ups while several balls are in play
    // (mirrors the cap enforced in applyPowerUp), otherwise 3.
    final activeCap = balls.length > 1 ? 2 : 3;
    if (activePowerUps.length >= activeCap && !force) return;
    if (isChaosMode && !force) {
      // Chaos breaks bricks in bulk, so capsules are serialized: one in the
      // air at a time, then a cooldown before the next can even roll.
      if (_chaosCapsuleCooldown > 0) return;
      if (capsules.isNotEmpty) return;
    }
    final luckLevel = save.upgrades['luck'] ?? 0;
    var dropChance = 0.14 + luckLevel * 0.04 + cosmicPearlLuckBonus;
    if (isChaosMode) dropChance *= 0.5; // Bulk breaks: half rate per brick.
    if (!force && _rand.nextDouble() > dropChance) return;

    final allTypes = PowerUpType.values;
    // Luck tilts towards buffs (exclude mirror and pierce; multi allowed with healthy ~4% rate)
    PowerUpType chosen;
    if (_rand.nextDouble() < 0.78 + luckLevel * 0.05) {
      var buffs = allTypes.where((t) => t.kind == PowerUpKind.buff && t != PowerUpType.mirror && t != PowerUpType.pierce && t != PowerUpType.drone).toList();
      if (currentMode == GameMode.classic && stats.level < 4) {
        buffs = buffs.where((t) => t != PowerUpType.vortex).toList();
      }
      // Alev ve buz aynı anda olmaz: biri aktifken diğeri asla düşmez.
      final fireInPlay = balls.any((b) => b.isFireball) ||
          activePowerUps.any((p) => p.type == PowerUpType.fireball);
      final frostInPlay = balls.any((b) => b.isFrost) ||
          activePowerUps.any((p) => p.type == PowerUpType.frost);
      if (fireInPlay) {
        buffs = buffs.where((t) => t != PowerUpType.frost).toList();
      }
      if (frostInPlay) {
        buffs = buffs.where((t) => t != PowerUpType.fireball).toList();
      }
      if (buffs.isEmpty) return;
      chosen = buffs[_rand.nextInt(buffs.length)];

      // Nadir dörtlü (Çoklu Top, Ateş, Roket, Buz): seçilirlerse %75
      // ihtimalle zar yeniden atılır, böylece dördü de seyrek gelir.
      if (chosen == PowerUpType.multi && balls.length > 1) {
        // Ekranda birden fazla top varken Çoklu Top'un gelme şansı %0,5:
        // zar tutmazsa Çoklu Top havuzdan çıkarılıp yeniden seçilir.
        if (_rand.nextDouble() >= 0.005) {
          final noMulti = buffs.where((t) => t != PowerUpType.multi).toList();
          if (noMulti.isNotEmpty) {
            chosen = noMulti[_rand.nextInt(noMulti.length)];
          }
        }
      } else if ((chosen == PowerUpType.multi ||
              chosen == PowerUpType.fireball ||
              chosen == PowerUpType.rocket ||
              chosen == PowerUpType.frost ||
              chosen == PowerUpType.bomb ||
              chosen == PowerUpType.shrapnel) &&
          _rand.nextDouble() < 0.75) {
        chosen = buffs[_rand.nextInt(buffs.length)];
      }

      // Eşzamanlı bomba & mükerrer kapsül koruması (Aynı anda 2 bomba veya mükerrer kapsül düşmesini engeller)
      if (chosen == PowerUpType.bomb && capsules.any((c) => c.type == PowerUpType.bomb)) {
        final noBomb = buffs.where((t) => t != PowerUpType.bomb).toList();
        if (noBomb.isNotEmpty) chosen = noBomb[_rand.nextInt(noBomb.length)];
      } else if (capsules.any((c) => c.type == chosen)) {
        final unspawned = buffs.where((t) => !capsules.any((c) => c.type == t)).toList();
        if (unspawned.isNotEmpty) chosen = unspawned[_rand.nextInt(unspawned.length)];
      }
    } else {
      final debuffs = allTypes.where((t) => t.kind == PowerUpKind.debuff).toList();
      chosen = debuffs[_rand.nextInt(debuffs.length)];
    }

    capsules.add(FallingCapsule(x: x, y: y, type: chosen));
    if (isChaosMode) _chaosCapsuleCooldown = chaosCapsuleCooldownSeconds;
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
    // Alev ve buz aynı anda alınamaz: biri aktifken diğeri yakalanırsa
    // kapsül boşa gitmez, çoklu topa dönüşür.
    final fireInPlayNow = balls.any((b) => b.isFireball) ||
        activePowerUps.any((p) => p.type == PowerUpType.fireball);
    final frostInPlayNow = balls.any((b) => b.isFrost) ||
        activePowerUps.any((p) => p.type == PowerUpType.frost);
    if ((type == PowerUpType.frost && fireInPlayNow) || (type == PowerUpType.fireball && frostInPlayNow)) {
      type = PowerUpType.multi;
    }

    audio.playSfx(type.kind == PowerUpKind.buff ? GameSfx.powerupBuff : GameSfx.powerupDebuff);
    particles.spawnFloatingText(paddle.x + paddle.width / 2, paddle.y - 30.0, type.label, type.color);

    if (type.isInstant) {
      switch (type) {
        case PowerUpType.multi:
          _splitBalls();
          break;
        case PowerUpType.life:
          stats.lives++;
          _lastKnownLives = stats.lives;
          break;
        case PowerUpType.mirror:
          if (balls.isNotEmpty) {
            final first = balls.first;
            final hasFireball = activePowerUps.any((p) => p.type == PowerUpType.fireball) || first.isFireball;
            final hasBomb = activePowerUps.any((p) => p.type == PowerUpType.bomb) || first.isBomb;
            final hasPierce = activePowerUps.any((p) => p.type == PowerUpType.pierce) || first.isPierce;
            final hasFrost = activePowerUps.any((p) => p.type == PowerUpType.frost) || first.isFrost;
            final hasShrapnel = activePowerUps.any((p) => p.type == PowerUpType.shrapnel) || first.isShrapnel;
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
              isFrost: hasFrost,
              isShrapnel: hasShrapnel,
            ));
          }
          break;
        case PowerUpType.lock:
          final aliveBricks = bricks.where((b) => b.isAlive && !b.isSteel).toList();
          if (aliveBricks.isNotEmpty) {
            final bosses = aliveBricks.where((b) => b.isBoss).toList();
            final target = bosses.isNotEmpty ? bosses.first : aliveBricks[_rand.nextInt(aliveBricks.length)];
            lockedTargetBrick = target;
            targetLockTimer = 6.0;
            targetLockingBall = balls.firstWhere((b) => !b.isStuck, orElse: () => balls.first);

            final tx = target.x + target.width / 2;
            final ty = target.y + target.height / 2;
            particles.spawnShockwave(tx, ty, const Color(0xFF00E5FF), maxRadius: 46.0);
            particles.spawnBurst(tx, ty, const Color(0xFF00E5FF), count: 14, speed: 120.0);
            particles.spawnFloatingText(tx, target.y - 14, '[+] ${I18n.tr('target_locked')}', const Color(0xFF00E5FF), isLarge: true);
            audio.playSfx(GameSfx.laser);
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
    final powerUp = ActivePowerUp(type);
    if (type.kind == PowerUpKind.debuff && save.hasPermanentRelic && save.activeRelicStyle == 'aegis') {
      powerUp.timeLeft *= 0.65; // Aegis: 35% shorter harmful debuff duration
    }
    activePowerUps.add(powerUp);

    switch (type) {
      case PowerUpType.wide:
        paddle.width = paddle.baseWidth * 1.45;
        break;
      case PowerUpType.shrink:
        paddle.width = paddle.baseWidth * 0.65;
        break;
      case PowerUpType.slow:
        final slowFactor = activeCosmeticSynergy == CosmeticSynergy.iceCrystal ? 0.82 : 0.65;
        for (final b in balls) {
          b.setSpeed(getBaseBallSpeed() * slowFactor);
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
        final fishBuffs = FishSynergyBuffs.calculate(save);
        paddle.laserAmmo = _rollLaserShots() + fishBuffs.startingLaserAmmoBonus;
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
      case PowerUpType.frost:
        for (final b in balls) {
          b.isFrost = true;
        }
        particles.spawnBurst(paddle.x + paddle.width / 2, paddle.y, const Color(0xFF80D8FF), count: 20, speed: 180.0);
        particles.spawnFloatingText(paddle.x + paddle.width / 2, paddle.y - 18, 'BUZ TOPU!', const Color(0xFF80D8FF), isLarge: true);
        audio.playSfx(GameSfx.powerupBuff);
        break;
      case PowerUpType.shrapnel:
        for (final b in balls) {
          b.isShrapnel = true;
        }
        particles.spawnBurst(paddle.x + paddle.width / 2, paddle.y, const Color(0xFFCFD8DC), count: 20, speed: 180.0);
        particles.spawnFloatingText(paddle.x + paddle.width / 2, paddle.y - 18, 'ŞARAPNEL!', const Color(0xFFCFD8DC), isLarge: true);
        audio.playSfx(GameSfx.powerupBuff);
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
        final fishBuffs = FishSynergyBuffs.calculate(save);
        final paddleWidthLvl = save.getUpgradeLevel('paddle_width');
        final upgradeWidthBonus = paddleWidthLvl * 2.0;
        final relicWidthBonus = (save.hasPermanentRelic && save.activeRelicStyle == 'aegis') ? paddle.baseWidth * 0.08 : 0.0;
        paddle.width = paddle.baseWidth + fishBuffs.extraPaddleWidth + upgradeWidthBonus + relicWidthBonus;
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
      case PowerUpType.frost:
        if (!activePowerUps.any((p) => p.type == PowerUpType.frost)) {
          for (final b in balls) {
            b.isFrost = false;
          }
        }
        break;
      case PowerUpType.shrapnel:
        if (!activePowerUps.any((p) => p.type == PowerUpType.shrapnel)) {
          for (final b in balls) {
            b.isShrapnel = false;
          }
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
    final hasFrost = activePowerUps.any((p) => p.type == PowerUpType.frost) || first.isFrost;
    final hasShrapnel = activePowerUps.any((p) => p.type == PowerUpType.shrapnel) || first.isShrapnel;

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
        isFrost: hasFrost,
        isShrapnel: hasShrapnel,
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
        isFrost: hasFrost,
        isShrapnel: hasShrapnel,
      ),
    );
  }

  void triggerUlti() {
    if (currentMode == GameMode.chaos) return;
    if (!isUltiReady || isDiceRolling || diceSalvoRemaining > 0) return;
    stats.ultiCharge = 0.0;

    isDiceRolling = true;
    diceRollTimer = 0.88;
    _diceShuffleTimer = 0.0;
    diceDisplayTimer = 0.0;
    diceSalvoRemaining = 0;

    // 25% base chance of jackpot double dice + pearl mastery luck bonus
    final jackpotChance = 0.25 + cosmicPearlLuckBonus;
    isDoubleDice = _rand.nextDouble() < jackpotChance;
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
    checkLowLifeTransition();
    if (stats.lives <= 0 && currentMode == GameMode.classic && !save.usedFreeContinue) {
      save.markFreeContinueUsed();
      stats.lives = 1;
      checkLowLifeTransition();
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
    AnalyticsManager.instance.logLevelFail(stats.level, currentMode.name, bricksLeft: bricks.where((b) => b.isAlive).length);
    if (currentMode == GameMode.classic) {
      save.recordClassicLevelFailed(stats.level);
    }
    if (currentMode == GameMode.chaos) {
      save.noteBestChaosWave(stats.level);
    }
    _flushRunStats();
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
    // Real global ranking: push the fresh best to Play Games (no-op
    // while signed out or leaderboards are not created yet).
    PlayGamesManager.instance.submitBestScores(save);
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
      if (currentMode == GameMode.daily ||
          (currentMode == GameMode.classic && stats.level == 238) ||
          (currentMode == GameMode.shapes && stats.level >= 38)) {
        if (AdManager.instance.registerLevelClear()) pendingLevelInterstitial = true;
        if (currentMode == GameMode.daily) {
          save.claimDailyBlitzReward();
        }
        if (currentMode == GameMode.classic) {
          save.recordClassicLevelCleared(stats.level);
          if (save.isLeagueUnlocked) {
            save.addTournamentScore(100);
            particles.spawnFloatingText(screenWidth / 2, screenHeight * 0.30, '+100 LİG PUANI', const Color(0xFF00E676));
          }
        }
        if (currentMode == GameMode.shapes) {
          save.recordShapesClearQuest();
        }
        _flushRunStats();
        _onVictory();
      } else {
        // Immediate next level load with celebratory transition freeze!
        levelTransitionTimer = 0.65;
        final baseGold = 25 + (stats.level * 5).clamp(0, 50);
        final relicBonus = save.hasPermanentRelic ? max(1, (baseGold * 0.05).round()) : 0;
        final luckLvl = save.getUpgradeLevel('luck');
        final luckBonus = (baseGold * (luckLvl * 0.05)).round();
        final fishBuffs = FishSynergyBuffs.calculate(save);
        int levelGold = baseGold + relicBonus + luckBonus;
        if (fishBuffs.goldMultiplier > 1.0) {
          levelGold = (levelGold * fishBuffs.goldMultiplier).round();
        }
        if (prestigeTier > 0) {
          levelGold = (levelGold * prestigeGoldMultiplier).round();
        }
        if (save.cosmicGoldMasteryLevel > 0) {
          levelGold = (levelGold * cosmicGoldRewardMultiplier).round();
        }
        stats.goldCollected += levelGold;
        save.addGold(levelGold);
        if (currentMode == GameMode.classic) {
          save.recordClassicLevelCleared(stats.level);
          if (save.isLeagueUnlocked) {
            save.addTournamentScore(100);
            particles.spawnFloatingText(screenWidth / 2, screenHeight * 0.30, '+100 LİG PUANI', const Color(0xFF00E676));
          }
        }
        if (currentMode == GameMode.shapes) {
          save.recordShapesClearQuest();
        }
        final clearedLevel = stats.level;
        final wasBossLevel = LevelDesign.isBossLevelNumber(clearedLevel);
        stats.level++;
        if (currentMode == GameMode.chaos) {
          save.noteBestChaosWave(stats.level);
          if (save.isLeagueUnlocked) {
            save.addTournamentScore(25);
            particles.spawnFloatingText(screenWidth / 2, screenHeight * 0.30, '+25 LİG PUANI', const Color(0xFF00E676));
          }
        }
        stats.score += 250 * stats.level;
        if (AdManager.instance.registerLevelClear()) pendingLevelInterstitial = true;
        if (currentMode == GameMode.classic) {
          save.noteClassicProgress(stats.level);
          save.saveClassicSession(level: stats.level, score: stats.score, lives: stats.lives);
        }
        loadLevelBricks();
        _hasLoadedBricks = bricks.isNotEmpty;
        status = GameStatus.ready;
        emergencyClutchUsedThisStage = false;
        if (wasBossLevel && currentMode == GameMode.classic) {
          offerSectorBlessings();
        }
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
    int victoryGold = 100;
    if (save.cosmicGoldMasteryLevel > 0) {
      victoryGold = (victoryGold * cosmicGoldRewardMultiplier).round();
    }
    save.addGold(victoryGold);
    stats.goldCollected += victoryGold;
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

  /// Chaos revive rescue: wipes the lowest [rows] brick rows so the wall
  /// that just crushed the player can't instantly crush them again after
  /// watching the revive ad. Returns how many bricks were cleared.
  int clearChaosBottomRows(int rows) {
    if (currentMode != GameMode.chaos) return 0;
    final alive = bricks.where((b) => b.isAlive && !b.isBallPickup).toList();
    if (alive.isEmpty) return 0;
    final rowKeys = alive.map((b) => (b.targetY / LevelDesign.chaosStep).round()).toSet().toList()..sort();
    final doomed = rowKeys.reversed.take(rows).toSet();
    var cleared = 0;
    for (final b in alive) {
      if (doomed.contains((b.targetY / LevelDesign.chaosStep).round())) {
        b.isAlive = false;
        cleared++;
        particles.spawnBurst(b.x + b.width / 2, b.y + b.height / 2, b.color, count: 8);
      }
    }
    if (cleared > 0) {
      particles.spawnFloatingText(
        screenWidth / 2,
        chaosFloorY - 130,
        'ALT $rows SIRA TEMİZLENDİ!',
        const Color(0xFF69F0AE),
        isLarge: true,
      );
    }
    return cleared;
  }

  void reviveWithOneLife() {
    if (!canRevive) return;
    revivesUsed++;
    if (currentMode == GameMode.chaos) {
      clearChaosBottomRows(3);
    }
    stats.lives = 1;
    lowLifeAlertTimer = lowLifeAlertDuration;
    _lastKnownLives = 1;
    resetPaddleAndBall();
    status = GameStatus.ready;
    if (currentMode == GameMode.classic) {
      save.saveClassicSession(level: stats.level, score: stats.score, lives: stats.lives);
    }
    audio.playSfx(GameSfx.powerupBuff);
    reviveFlashTimer = 1.0;
    particles.spawnShockwave(screenWidth / 2, paddle.y, const Color(0xFFFF1744), maxRadius: 100.0);
    particles.spawnShockwave(paddle.x + paddle.width / 2, paddle.y, const Color(0xFFFFD54F), maxRadius: screenWidth * 0.55);
    final text = '${I18n.tr('second_chance_life')} ($revivesUsed/$maxRevivesPerGame)';
    particles.spawnFloatingText(screenWidth / 2, screenHeight * 0.45, text, const Color(0xFFFF1744), isLarge: true);
    notifyListeners();
  }

  int rollEndGameGoldDice({int? forcedDice}) {
    if (hasClaimedVictoryBonus || isChaosMode) return 0;
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













