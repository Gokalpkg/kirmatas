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

  bool isDiceRolling = false;
  double diceRollTimer = 0.0;
  bool isDoubleDice = false;
  int dice1Value = 1;
  int dice2Value = 1;
  int diceDisplay1 = 1;
  int diceDisplay2 = 1;
  int diceSalvoRemaining = 0;
  double diceSalvoCooldown = 0.0;
  double diceDisplayTimer = 0.0;
  double _diceShuffleTimer = 0.0;

  bool get isDiceActive => isDiceRolling || diceDisplayTimer > 0;
  int get diceTotal => isDoubleDice ? (diceDisplay1 + diceDisplay2) : diceDisplay1;

  BallSkin get activeBallSkin => BallSkin.getById(save.activeBall);
  PaddleSkin get activePaddleSkin => PaddleSkin.getById(save.activePaddle);
  TrailSkin get activeTrailSkin => TrailSkin.getById(save.activeTrail);

  GameController() {
    paddle = Paddle(x: 140, y: 560);
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

  void startNewGame(GameMode mode) {
    currentMode = mode;
    status = GameStatus.ready;
    hasUsedRevive = false;

    int startLives = mode == GameMode.zen ? 999 : 3;
    if (save.boostStocks['life'] != null && save.boostStocks['life']! > 0) {
      save.consumeBoost('life');
      startLives += 1;
    }

    stats.reset(initialLives: startLives, startLevel: 1);
    particles.clear();
    capsules.clear();
    projectiles.clear();
    activePowerUps.clear();
    activeBee = null;
    activeSplat = null;
    beeSpawnCooldown = 25.0 + _rand.nextDouble() * 25.0;

    resetPaddleAndBall();
    loadLevelBricks();

    if (save.boostStocks['wide'] != null && save.boostStocks['wide']! > 0) {
      save.consumeBoost('wide');
      applyPowerUp(PowerUpType.wide);
    }
    if (save.boostStocks['multi'] != null && save.boostStocks['multi']! > 0) {
      save.consumeBoost('multi');
      applyPowerUp(PowerUpType.multi);
    }

    notifyListeners();
  }

  void resetPaddleAndBall() {
    paddle.width = paddle.baseWidth;
    paddle.x = (screenWidth - paddle.width) / 2;
    paddle.y = screenHeight - 110.0;
    paddle.isSticky = false;
    paddle.hasLaser = false;
    paddle.hasRockets = false;
    paddle.hasDrone = false;
    paddle.hasNet = false;
    paddle.isGhost = false;
    paddle.isReversed = false;
    paddle.isClumsy = false;
    paddle.rocketAmmo = 0;

    activePowerUps.clear();
    capsules.clear();
    projectiles.clear();

    balls.clear();
    balls.add(
      Ball(
        x: paddle.x + paddle.width / 2,
        y: paddle.y - 12.0,
        isStuck: true,
        stuckOffsetX: paddle.width / 2,
      ),
    );
  }

  void loadLevelBricks() {
    portals.clear();
    blackHoles.clear();
    activeBee = null;
    beeSpawnCooldown = 25.0 + _rand.nextDouble() * 25.0;
    _blackHoleTimer = 0.0;
    switch (currentMode) {
      case GameMode.classic:
        bricks = LevelDesign.buildClassicLevel(stats.level, screenWidth, screenHeight);
        if (portalLevels.contains(stats.level)) {
          final levelRand = Random(stats.level * 1337);
          final p1 = Portal(
            x: screenWidth * (0.18 + levelRand.nextDouble() * 0.16),
            y: screenHeight * (0.45 + levelRand.nextDouble() * 0.12),
            radius: 22.0,
            isBlue: true,
            color: const Color(0xFF00B0FF),
          );
          final p2 = Portal(
            x: screenWidth * (0.66 + levelRand.nextDouble() * 0.16),
            y: screenHeight * (0.45 + levelRand.nextDouble() * 0.12),
            radius: 22.0,
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
    }
  }

  bool get hasStuckBall => balls.any((b) => b.isStuck);

  void launchBall() {
    if (status == GameStatus.ready) {
      status = GameStatus.playing;
    }

    bool anyLaunched = false;
    for (final ball in balls) {
      if (ball.isStuck) {
        ball.isStuck = false;
        ball.stuckTimer = 0.0;
                final speed = getBaseBallSpeed();
        ball.vx = 0.0;
        ball.vy = -speed;
        anyLaunched = true;
      }
    }
    if (anyLaunched) {
      audio.playSfx(GameSfx.hitPaddle);
      notifyListeners();
    }
  }

  double getBaseBallSpeed() {
    final base = 350.0 * save.speed.multiplier;
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
      // Slippery lerp
      paddle.x += (newX - paddle.x) * 0.15;
    } else {
      paddle.x = newX;
    }

    paddle.x = paddle.x.clamp(8.0, screenWidth - paddle.width - 8.0);

    for (final ball in balls) {
      if (ball.isStuck) {
        ball.x = paddle.x + ball.stuckOffsetX;
        ball.y = paddle.y - ball.radius - 2.0;
      }
    }
  }

  void movePaddleBy(double deltaX) {
    if (status != GameStatus.playing && status != GameStatus.ready) return;

    double delta = deltaX;
    if (paddle.isReversed) {
      delta = -deltaX;
    }

    if (paddle.isClumsy) {
      paddle.x += delta * 1.35;
    } else {
      paddle.x += delta;
    }

    paddle.x = paddle.x.clamp(8.0, screenWidth - paddle.width - 8.0);

    for (final ball in balls) {
      if (ball.isStuck) {
        ball.x = paddle.x + ball.stuckOffsetX;
        ball.y = paddle.y - ball.radius - 2.0;
      }
    }
  }

  void update(double dt) {
    gameTime += dt;

    // Windshield Splat update: persists on screen glass for 2 seconds even when game state changes
    if (activeSplat != null) {
      activeSplat!.update(dt);
      if (activeSplat!.isDead) {
        activeSplat = null;
      }
    }

    if (status != GameStatus.playing) {
      particles.update(dt);
      notifyListeners();
      return;
    }

    // Bullet time slow motion
    double effectiveDt = dt;
    if (stats.bulletTimeLeft > 0) {
      stats.bulletTimeLeft -= dt;
      effectiveDt = dt * 0.45;
    }

    particles.update(effectiveDt);
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
    _checkGameProgress();
    frameTick.ping();
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

    // GÜÇLENDİRİCİ KOMBİNASYONU: Lazer + Alev Topu (Fire Laser) veya sadece Lazer
    if (paddle.hasLaser) {
      laserTimer = (laserTimer ?? 0.0) + dt;
      if (laserTimer! >= 0.65) {
        laserTimer = 0.0;
        final hasFireball = balls.any((b) => b.isFireball);
        if (hasFireball) {
          // Kombinasyon: Alev Lazerleri! Üçlü geniş atış
          projectiles.add(Projectile(x: paddle.x + 10, y: paddle.y - 12, vx: -80, vy: -500.0, radius: 6.0, isLaser: true));
          projectiles.add(Projectile(x: paddle.x + paddle.width - 10, y: paddle.y - 12, vx: 80, vy: -500.0, radius: 6.0, isLaser: true));
          audio.playSfx(GameSfx.explosion);
        } else {
          // Normal Lazer
          projectiles.add(Projectile(x: paddle.x + 10, y: paddle.y - 12, vy: -450.0, radius: 4.0, isLaser: true));
          projectiles.add(Projectile(x: paddle.x + paddle.width - 10, y: paddle.y - 12, vy: -450.0, radius: 4.0, isLaser: true));
          audio.playSfx(GameSfx.laser);
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
          particles.spawnFloatingText(screenWidth / 2, screenHeight * 0.38, '👑 EFSANEVİ 12! ÇİFT ALTI! 👑', const Color(0xFFFFD700), isLarge: true);
          audio.playSfx(GameSfx.ulti);
        } else if (totalShots == 11) {
          particles.triggerShake(7.0, 0.4);
          particles.spawnShockwave(paddle.x + paddle.width / 2, paddle.y - 50, const Color(0xFFFF6D00), maxRadius: screenWidth * 0.7);
          particles.spawnFloatingText(screenWidth / 2, screenHeight * 0.38, '🔥 EPİK ŞANS! (11) 🔥', const Color(0xFFFF6D00), isLarge: true);
          audio.playSfx(GameSfx.ulti);
        } else if (totalShots == 10) {
          particles.triggerShake(6.0, 0.35);
          particles.spawnShockwave(paddle.x + paddle.width / 2, paddle.y - 50, const Color(0xFF00E5FF), maxRadius: screenWidth * 0.6);
          particles.spawnFloatingText(screenWidth / 2, screenHeight * 0.38, '💎 BÜYÜK KAZANÇ! (10) 💎', const Color(0xFF00E5FF), isLarge: true);
          audio.playSfx(GameSfx.ulti);
        } else if (isDoubleDice) {
          particles.spawnFloatingText(screenWidth / 2, screenHeight * 0.38, '🎰  X ÇİFT ZAR! 🎰', const Color(0xFFFFD700), isLarge: true);
          audio.playSfx(GameSfx.ulti);
        } else {
          particles.spawnFloatingText(screenWidth / 2, screenHeight * 0.38, '🎲  X ZAR ATIŞI! 🎲', const Color(0xFF00E5FF), isLarge: true);
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
        diceSalvoCooldown = 0.16;
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
          particles.triggerShake(4.0, 0.2);
          particles.spawnBurst(p.x, p.y, Colors.redAccent, count: 12);
          audio.playSfx(GameSfx.explosion);
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

      // Magnet attraction
      if (magnetLevel > 0) {
        final dx = paddleCenter.dx - c.x;
        final dy = paddleCenter.dy - c.y;
        final dist = sqrt(dx * dx + dy * dy);
        if (dist < 220.0) {
          final pull = 180.0 * magnetLevel;
          c.x += (dx / dist) * pull * dt;
          c.y += (dy / dist) * pull * dt;
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
    if (status == GameStatus.playing && blackHoles.isEmpty && currentMode != GameMode.zen) {
      _blackHoleTimer = (_blackHoleTimer ?? 0.0) + dt;
      if (_blackHoleTimer! >= 22.0 && _rand.nextDouble() < 0.03) {
        // Find bottom-most active brick to ensure black hole NEVER spawns inside or above brick grid
        double lowestAliveBrickY = 0.0;
        for (final b in bricks) {
          if (b.isAlive && (b.y + b.height) > lowestAliveBrickY) {
            lowestAliveBrickY = b.y + b.height;
          }
        }

        final minY = lowestAliveBrickY + 45.0;
        final maxY = paddle.y - 75.0;

        // Only spawn if there is sufficient open space between bricks and paddle
        if (maxY > minY + 40.0) {
          _blackHoleTimer = 0.0;
          final r = 20.0 + _rand.nextDouble() * 14.0;
          final isVortexTrap = _rand.nextDouble() < 0.01; // Exactly 1% chance (1 in 100)
          final spawnY = minY + _rand.nextDouble() * (maxY - minY);
          final spawnX = (screenWidth * 0.20 + _rand.nextDouble() * (screenWidth * 0.60)).clamp(r + 20.0, screenWidth - r - 20.0);

          blackHoles.add(
            BlackHole(
              x: spawnX,
              y: spawnY,
              radius: r,
              mass: r * 3200.0,
              timeLeft: isVortexTrap ? 6.5 : (4.5 + _rand.nextDouble() * 2.0),
              isVortexTrap: isVortexTrap,
            ),
          );
          audio.playSfx(GameSfx.laser);
          if (isVortexTrap) {
            particles.spawnFloatingText(screenWidth * 0.5, spawnY, '🌌 GİRDAP KARADELİK (%1)! 🌌', const Color(0xFFFF1744), isLarge: true);
            particles.spawnShockwave(spawnX, spawnY, const Color(0xFFFF1744), maxRadius: 80.0);
          } else {
            particles.spawnShockwave(spawnX, spawnY, const Color(0xFF7C4DFF), maxRadius: 60.0);
          }
        }
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
        // Corner Shot (Köşe Vuruşu): Supersonic afterburner exhaust sparks and lingering heat burn trail
        particles.spawnBurnEmber(ball.x, ball.y);
        if (_rand.nextDouble() < 0.30) {
          final sparkColor = _rand.nextBool() ? const Color(0xFFFFD54F) : const Color(0xFFFFF9C4);
          particles.spawnBurst(ball.x, ball.y, sparkColor, count: 1, speed: 65.0);
        }
      } else if (ball.speed > getBaseBallSpeed() * 1.15 && !activePowerUps.any((p) => p.type == PowerUpType.fastball)) {
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

      // Anti-softlock: prevent ball from getting stuck horizontally forever
      if (!ball.isStuck && ball.vy.abs() < 28.0) {
        ball.vy = ball.vy >= 0 ? 35.0 : -35.0;
      }

      // Black Hole gravity pull & trajectory deflection:
      // Redirection capped at up to 360 degrees (2*pi radians) for largest black hole so balls slingshot away
      // instead of endlessly orbiting inside.
      // Only the 1% rare vortex trap allows multiple trapped revolutions.
      for (final bh in blackHoles) {
        final dx = bh.x - ball.x;
        final dy = bh.y - ball.y;
        final dist = sqrt(dx * dx + dy * dy);
        final maxInfluenceDist = bh.radius * (bh.isVortexTrap ? 9.0 : 6.5);

        if (dist > 3.0 && dist < maxInfluenceDist) {
          final ballKey = ball.hashCode;
          final currentAngle = atan2(ball.y - bh.y, ball.x - bh.x);

          // Measure angular rotation around black hole center
          if (bh.ballAngles.containsKey(ballKey)) {
            final prevAngle = bh.ballAngles[ballKey]!;
            var delta = currentAngle - prevAngle;
            while (delta > pi) {
              delta -= 2 * pi;
            }
            while (delta < -pi) {
              delta += 2 * pi;
            }
            bh.ballAccumulatedAngles[ballKey] = (bh.ballAccumulatedAngles[ballKey] ?? 0.0) + delta.abs();
          }
          bh.ballAngles[ballKey] = currentAngle;

          final accumulatedAngle = bh.ballAccumulatedAngles[ballKey] ?? 0.0;

          // Max allowed deflection angle:
          // Largest black hole (radius ~34) deflects up to 360 degrees (2*pi).
          // Smaller black holes (radius ~20) deflect up to ~210 degrees.
          // Rare 1% vortex trap allows up to 4 revolutions (8*pi).
          final maxAllowedDeflection = bh.isVortexTrap
              ? (8.0 * pi)
              : ((bh.radius / 34.0).clamp(0.58, 1.0) * (2.0 * pi));

          if (accumulatedAngle < maxAllowedDeflection) {
            final normalizedDist = (dist / maxInfluenceDist).clamp(0.0, 1.0);
            final proximity = 1.0 - normalizedDist;

            final basePull = bh.isVortexTrap
                ? (600.0 + bh.radius * 65.0)
                : (320.0 + bh.radius * 28.0);
            final pull = basePull * proximity * (1.1 + proximity * 2.2);

            final nx = dx / dist;
            final ny = dy / dist;

            ball.vx += nx * pull * dt;
            ball.vy += ny * pull * dt;

            // Anti-singularity cushion for normal black holes: prevent endless stuck bouncing at center
            if (!bh.isVortexTrap && dist < bh.radius * 0.75) {
              ball.vx += (-nx * 160.0) * dt;
              ball.vy += (-ny * 160.0) * dt;
            }

            if (ball.speed > 850.0) {
              ball.setSpeed(850.0);
            }
          } else {
            // Capped: ball reached max 360-degree trajectory change. Slingshot out cleanly!
            if (dist < bh.radius * 1.8) {
              final outwardX = (ball.x - bh.x) / dist;
              final outwardY = (ball.y - bh.y) / dist;
              ball.vx += outwardX * 240.0 * dt;
              ball.vy += outwardY * 240.0 * dt;
            }
          }
        } else {
          // Ball is outside gravitational influence: clear accumulated angle for next encounter
          final ballKey = ball.hashCode;
          bh.ballAngles.remove(ballKey);
          bh.ballAccumulatedAngles.remove(ballKey);
        }
      }

      // Portal teleportation
      if (ball.anomalyCooldown <= 0) {
        for (final p in portals) {
          final dx = p.x - ball.x;
          final dy = p.y - ball.y;
          if (dx * dx + dy * dy <= p.radius * p.radius && p.linkedPortal != null) {
            final target = p.linkedPortal!;
            final spd = ball.speed > 0 ? ball.speed : getBaseBallSpeed();
            final dirX = ball.vx / spd;
            final dirY = ball.vy / spd;
            ball.x = target.x + dirX * (target.radius + ball.radius + 3.0);
            ball.y = target.y + dirY * (target.radius + ball.radius + 3.0);
            ball.anomalyCooldown = 1.0;
            particles.spawnBurst(p.x, p.y, p.color, count: 18, speed: 100.0);
            particles.spawnBurst(target.x, target.y, target.color, count: 22, speed: 130.0);
            audio.playSfx(GameSfx.ulti);
            break;
          }
        }
      }

      // High-speed sub-stepping prevents tunneling through bricks or walls
      final subSteps = (ball.speed > 380.0) ? 2 : 1;
      final subDt = dt / subSteps;
      for (int step = 0; step < subSteps; step++) {
        ball.update(subDt, trailLength: activeTrailSkin.length);

        // Wall collisions
        if (ball.x - ball.radius <= 0) {
          ball.x = ball.radius;
          ball.vx = ball.vx.abs();
          ball.triggerSquash(0);
          audio.playSfx(GameSfx.hitWall);
        } else if (ball.x + ball.radius >= screenWidth) {
          ball.x = screenWidth - ball.radius;
          ball.vx = -ball.vx.abs();
          ball.triggerSquash(pi);
          audio.playSfx(GameSfx.hitWall);
        }

        if (ball.y - ball.radius <= 36.0) {
          ball.y = 36.0 + ball.radius;
          ball.vy = ball.vy.abs();
          ball.triggerSquash(pi / 2);
          audio.playSfx(GameSfx.hitWall);
        }

        // Safety Net collision
        if (paddle.hasNet && ball.y + ball.radius >= screenHeight - 20.0) {
          ball.vy = -ball.vy.abs();
          paddle.netHitsRemaining--;
          if (paddle.netHitsRemaining <= 0) {
            paddle.hasNet = false;
          }
          particles.spawnShockwave(ball.x, ball.y, const Color(0xFF8BC34A), maxRadius: 35.0);
          audio.playSfx(GameSfx.hitWall);
        }

        // Paddle collision
        if (_checkBallPaddleCollision(ball)) {
          break;
        }

        // Brick collision
        _checkBallBrickCollision(ball);
      }

      // Bottom fall
      if (ball.y - ball.radius > screenHeight) {
        balls.removeAt(i);
        continue;
      }
    }

    // Check if all balls lost
    if (balls.isEmpty) {
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

      if (paddle.isSticky) {
        ball.isStuck = true;
        ball.stuckTimer = 0.0;
        ball.stuckOffsetX = ball.x - paddle.x;
        ball.vy = 0;
        ball.vx = 0;
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
      final baseSpeed = min(ball.speed + 6.0, 680.0);

      // Corner hit detection (outer 22% of paddle)
      final isCornerHit = hitOffset.abs() >= 0.78;
      final speedMultiplier = isCornerHit ? 1.45 : 1.0;
      final finalSpeed = (baseSpeed * speedMultiplier).clamp(100.0, 850.0);

      ball.vx = sin(bounceAngle) * finalSpeed;
      ball.vy = -cos(bounceAngle) * finalSpeed;

      // Spin transfer
      ball.vx += paddle.velocityX * 0.25;

      ball.y = pr.top - ball.radius - 1.0;
      ball.triggerSquash(-pi / 2);

      if (isCornerHit) {
        ball.cornerHitCount++;
        ball.cornerBoostTimer = 3.2; // Speeds up for 3.2 seconds
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
          audio.playSfx(GameSfx.ulti);
        }
      } else {
        ball.cornerHitCount = 0; // Reset consecutive hits
        particles.spawnShockwave(ball.x, pr.top, activePaddleSkin.glowColor, maxRadius: 32.0);
        audio.playSfx(GameSfx.hitPaddle);
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
        // Hit brick!
        _hitBrick(b, ball);

        if (!ball.isFireball && !ball.isPierce && !b.isTuft) {
          // Robust velocity-direction face collision resolution:
          // A ball cannot bounce off a face it was moving away from!
          // Calculate penetration depths into the faces the ball entered from.
          final depthLeft = (ball.vx > 0) ? ((bx + r) - b.x) : double.infinity;
          final depthRight = (ball.vx < 0) ? ((b.x + b.width) - (bx - r)) : double.infinity;
          final depthTop = (ball.vy > 0) ? ((by + r) - b.y) : double.infinity;
          final depthBottom = (ball.vy < 0) ? ((b.y + b.height) - (by - r)) : double.infinity;

          final minHorizontalDepth = min(depthLeft, depthRight);
          final minVerticalDepth = min(depthTop, depthBottom);

          // Time-of-impact normalized comparison: time = depth / speed
          final tX = (minHorizontalDepth.isFinite && ball.vx.abs() > 0.001)
              ? (minHorizontalDepth / ball.vx.abs())
              : double.infinity;
          final tY = (minVerticalDepth.isFinite && ball.vy.abs() > 0.001)
              ? (minVerticalDepth / ball.vy.abs())
              : double.infinity;

          if (tX < tY) {
            // Horizontal rebound (hit left or right face)
            if (depthLeft < depthRight) {
              ball.vx = -ball.vx.abs();
              ball.x = b.x - r - 0.5;
              ball.triggerSquash(pi);
            } else {
              ball.vx = ball.vx.abs();
              ball.x = b.x + b.width + r + 0.5;
              ball.triggerSquash(0);
            }
          } else {
            // Vertical rebound (hit top or bottom face)
            if (depthTop < depthBottom) {
              ball.vy = -ball.vy.abs();
              ball.y = b.y - r - 0.5;
              ball.triggerSquash(-pi / 2);
            } else {
              ball.vy = ball.vy.abs();
              ball.y = b.y + b.height + r + 0.5;
              ball.triggerSquash(pi / 2);
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

    if (b.isSteel) {
      if (ball != null && ball.isFireball) {
        // Fireball melts steel!
        _destroyBrick(b);
      } else {
        b.jelly = 1.0;
        particles.spawnBurst(b.x + b.width / 2, b.y + b.height / 2, Colors.grey, count: 6);
        audio.playSfx(GameSfx.steel);
      }
      return;
    }

    b.hp--;
    b.jelly = 0.8;

    if (b.hp <= 0) {
      _destroyBrick(b);
    } else {
      particles.spawnBurst(b.x + b.width / 2, b.y + b.height / 2, b.color, count: 6);
      audio.playSfx(GameSfx.hitBrick);
      _registerCombo(b.points ~/ 2);
    }
  }

  void _destroyBrick(Brick b) {
    b.isAlive = false;
    stats.bricksBroken++;

    particles.spawnBurst(b.x + b.width / 2, b.y + b.height / 2, b.color, count: 16);
    particles.spawnShockwave(b.x + b.width / 2, b.y + b.height / 2, b.color, maxRadius: 40.0);
    audio.playSfx(GameSfx.breakBrick);

        _registerCombo(b.points);

    if (b.isDynamite) {
      _explodeArea(b.x + b.width / 2, b.y + b.height / 2, radius: 80.0);
    } else if (b.isIce) {
      _freezeArea(b.x + b.width / 2, b.y + b.height / 2, radius: 90.0);
    }

    // Charge Ulti (with battery upgrade bonus)
    final batteryLevel = save.upgrades['battery'] ?? 0;
    final ultiGain = 3.5 * (1.0 + batteryLevel * 0.25);
    stats.ultiCharge = (stats.ultiCharge + ultiGain).clamp(0.0, 100.0);

    // Roll powerup drop
    _rollCapsuleDrop(b.x + b.width / 2, b.y + b.height / 2);

    // Coin gain
    if (_rand.nextDouble() < 0.20) {
      final coins = 1 + _rand.nextInt(3);
      stats.goldCollected += coins;
      save.addGold(coins);
      particles.spawnFloatingText(b.x + b.width / 2, b.y, '+$coins 🪙', const Color(0xFFFFD54F));
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

    if (stats.combo > 1 && stats.combo % 3 == 0) {
      particles.spawnFloatingText(
        paddle.x + paddle.width / 2,
        paddle.y - 28.0,
        '${I18n.tr('combo')} x${stats.combo}!',
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
    // Luck tilts towards buffs
    PowerUpType chosen;
    if (_rand.nextDouble() < 0.78 + luckLevel * 0.05) {
      final buffs = allTypes.where((t) => t.kind == PowerUpKind.buff).toList();
      chosen = buffs[_rand.nextInt(buffs.length)];
      
      // KURAL: Ateş topu ve Roket çok daha nadir çıkmalı (2/3 oranında tekrar kura çekilir)
      if ((chosen == PowerUpType.fireball || chosen == PowerUpType.rocket) && _rand.nextDouble() < 0.66) {
        chosen = buffs[_rand.nextInt(buffs.length)];
      }
    } else {
      final debuffs = allTypes.where((t) => t.kind == PowerUpKind.debuff).toList();
      chosen = debuffs[_rand.nextInt(debuffs.length)];
    }

    capsules.add(FallingCapsule(x: x, y: y, type: chosen));
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
        case PowerUpType.shield:
          paddle.hasNet = true;
          paddle.netHitsRemaining = 1;
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
            _destroyBrick(target);
            particles.spawnFloatingText(target.x + target.width / 2, target.y, I18n.tr('target_locked'), const Color(0xFFFFAB00));
          }
          break;
        case PowerUpType.rocket:
          paddle.hasRockets = true;
          paddle.rocketAmmo = _rand.nextInt(11) + 1; // 1 to 11 random shots
          particles.spawnFloatingText(paddle.x + paddle.width / 2, paddle.y - 15, '${paddle.rocketAmmo}x ROKET!', const Color(0xFFFF5722), isLarge: true);
          break;
        default:
          break;
      }
      

      return;
    }

        // Remove existing if already present
    activePowerUps.removeWhere((p) => p.type == type);

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
        break;
      case PowerUpType.rocket:
        paddle.hasRockets = true;
        break;
      case PowerUpType.fireball:
        for (final b in balls) {
          b.isFireball = true;
        }
        break;
      case PowerUpType.bomb:
        for (final b in balls) {
          b.isBomb = true;
        }
        break;
      case PowerUpType.pierce:
        for (final b in balls) {
          b.isPierce = true;
        }
        break;
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
        break;
      case PowerUpType.rocket:
        paddle.hasRockets = false;
        break;
      case PowerUpType.fireball:
        for (final b in balls) {
          b.isFireball = false;
        }
        break;
      case PowerUpType.bomb:
        for (final b in balls) {
          b.isBomb = false;
        }
        break;
      case PowerUpType.pierce:
        for (final b in balls) {
          b.isPierce = false;
        }
        break;
      case PowerUpType.net:
        paddle.hasNet = false;
        break;
      case PowerUpType.drone:
        paddle.hasDrone = false;
        break;
      case PowerUpType.reverse:
        paddle.isReversed = false;
        break;
      case PowerUpType.clumsy:
        paddle.isClumsy = false;
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

    if (isDoubleDice) {
      particles.triggerShake(7.0, 0.35);
      particles.spawnShockwave(paddle.x + paddle.width / 2, paddle.y - 45, const Color(0xFFFFD700), maxRadius: screenWidth * 0.7);
      particles.spawnFloatingText(screenWidth / 2, screenHeight * 0.42, '🎰 JACKPOT! 2X ZAR! 🎰', const Color(0xFFFFD700), isLarge: true);
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
      particles.spawnFloatingText(screenWidth / 2, screenHeight * 0.42, '🎲 ŞANSLI ZAR! 🎲', const Color(0xFF00E5FF), isLarge: true);
      audio.playSfx(GameSfx.laser);
    }

    notifyListeners();
  }

  void _loseLife() {
    stats.lives--;
    audio.playSfx(GameSfx.gameOver);

    if (stats.lives <= 0 && currentMode != GameMode.zen) {
      _onGameOver();
    } else {
      resetPaddleAndBall();
      status = GameStatus.ready;
    }
  }

  void _onGameOver() {
    status = GameStatus.gameOver;
    save.updateHighScore(currentMode, stats.score);
    audio.playSfx(GameSfx.gameOver);
  }

  void _checkGameProgress() {
    if (currentMode == GameMode.zen) return;



    final remainingBreakable = bricks.where((b) {
      if (!b.isAlive) return false;
      if (b.isSteel) return false;
      if (b.isTuft && b.tuftFilled) return false;
      return true;
    }).length;
    if (remainingBreakable == 0) {
      if (currentMode == GameMode.daily) {
        _onVictory();
      } else {
        // Classic next level
        stats.level++;
        stats.score += 250 * stats.level;
        particles.spawnFloatingText(screenWidth / 2, screenHeight * 0.4, '${I18n.tr('level').toUpperCase()} ${stats.level}!', const Color(0xFFFFD54F), isLarge: true);
        audio.playSfx(GameSfx.victory);
        resetPaddleAndBall();
        loadLevelBricks();
        status = GameStatus.ready;
      }
    }
  }

  void _onVictory() {
    status = GameStatus.victory;
    save.updateHighScore(currentMode, stats.score);
    save.addGold(50);
    audio.playSfx(GameSfx.victory);
  }

  GameStatus _statusBeforePause = GameStatus.playing;

  void pause() {
    if (status == GameStatus.playing || status == GameStatus.ready) {
      _statusBeforePause = status;
      status = GameStatus.paused;
      notifyListeners();
    }
  }

  void resume() {
    if (status == GameStatus.paused) {
      status = _statusBeforePause;
      notifyListeners();
    }
  }

  void reviveWithOneLife() {
    if (hasUsedRevive) return;
    hasUsedRevive = true;
    stats.lives = 1;
    resetPaddleAndBall();
    status = GameStatus.ready;
    audio.playSfx(GameSfx.powerupBuff);
    particles.spawnShockwave(screenWidth / 2, paddle.y, const Color(0xFFFF1744), maxRadius: 100.0);
    particles.spawnFloatingText(screenWidth / 2, screenHeight * 0.45, '❤️ İKİNCİ ŞANS! +1 CAN', const Color(0xFFFF1744), isLarge: true);
    notifyListeners();
  }
}













