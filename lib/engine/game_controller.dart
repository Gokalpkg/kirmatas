import 'dart:math';
import 'package:flutter/material.dart';
import '../models/ball.dart';
import '../models/brick.dart';
import '../models/cosmetics.dart';
import '../models/game_state.dart';
import '../models/level_design.dart';
import '../models/paddle.dart';
import '../models/powerup.dart';
import '../storage/save_manager.dart';
import 'audio_manager.dart';
import 'i18n.dart';
import 'particle_system.dart';

class GameController extends ChangeNotifier {
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

  double descendTimer = 0.0;
  double droneShootTimer = 0.0;
  double comboTimer = 0.0;
  double gameTime = 0.0;

  BallSkin activeBallSkin = BallSkin.allSkins.first;
  PaddleSkin activePaddleSkin = PaddleSkin.allSkins.first;
  TrailSkin activeTrailSkin = TrailSkin.allTrails.first;

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

  void startNewGame(GameMode mode) {
    currentMode = mode;
    status = GameStatus.ready;

    activeBallSkin = BallSkin.getById(save.activeBall);
    activePaddleSkin = PaddleSkin.getById(save.activePaddle);
    activeTrailSkin = TrailSkin.getById(save.activeTrail);

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
    switch (currentMode) {
      case GameMode.classic:
        bricks = LevelDesign.buildClassicLevel(stats.level, screenWidth, screenHeight);
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
      case GameMode.tuft:
        bricks = LevelDesign.buildTuftLevel(screenWidth, screenHeight);
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
        final angle = -pi / 2 + (_rand.nextDouble() * 0.4 - 0.2);
        ball.vx = cos(angle) * speed;
        ball.vy = sin(angle) * speed;
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

    _updatePowerUpTimers(effectiveDt);
    _updateCombo(effectiveDt);
    _updateProjectiles(effectiveDt);
    _updateCapsules(effectiveDt);
    _updateBricks(effectiveDt);
    _updateBalls(effectiveDt);
    _checkGameProgress();

    notifyListeners();
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
        projectiles.add(
          Projectile(
            x: droneOffset.dx,
            y: droneOffset.dy,
            vy: -480.0,
            radius: 3.5,
            isLaser: true,
          ),
        );
        audio.playSfx(GameSfx.laser);
      }
    }

    // Ulti active timer
    if (stats.ultiActiveLeft > 0) {
      stats.ultiActiveLeft -= dt;
      if (_rand.nextDouble() < 0.25) {
        projectiles.add(
          Projectile(
            x: paddle.x + _rand.nextDouble() * paddle.width,
            y: paddle.y - 8.0,
            vy: -600.0,
            radius: 5.0,
            isLaser: true,
          ),
        );
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
        applyPowerUp(c.type);
        capsules.removeAt(i);
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

      // Boss shooting
      if (b.isAlive && b.isBoss && b.shootTimer <= 0) {
        b.shootTimer = 2.2 + _rand.nextDouble() * 1.2;
        projectiles.add(
          Projectile(
            x: b.x + b.width * 0.25,
            y: b.y + b.height + 6.0,
            vy: 200.0,
            radius: 5.5,
            isBossBullet: true,
          ),
        );
        projectiles.add(
          Projectile(
            x: b.x + b.width * 0.75,
            y: b.y + b.height + 6.0,
            vy: 200.0,
            radius: 5.5,
            isBossBullet: true,
          ),
        );
        audio.playSfx(GameSfx.laser);
      }
    }

    // Global dead brick pruning to eliminate memory accumulation and CPU lag
    if (currentMode != GameMode.tuft) {
      bricks.removeWhere((b) => !b.isAlive && b.jelly <= 0);
    }

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

    // Zen mode replenishment
    if (currentMode == GameMode.zen) {
      final aliveCount = bricks.where((b) => b.isAlive).length;
      if (aliveCount < 8) {
        final newBricks = LevelDesign.buildZenLevel(screenWidth, screenHeight);
        bricks.addAll(newBricks);
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

      ball.update(dt);

      // Corner boost trail sparks & decay
      if (ball.cornerBoostTimer > 0) {
        if (_rand.nextDouble() < 0.35) {
          particles.spawnBurst(ball.x, ball.y, const Color(0xFFFFD54F), count: 2, speed: 60.0);
        }
      } else if (ball.speed > getBaseBallSpeed() * 1.15 && !activePowerUps.any((p) => p.type == PowerUpType.fastball)) {
        ball.setSpeed((ball.speed - dt * 140.0).clamp(getBaseBallSpeed(), 850.0));
      }

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

      // Bottom fall
      if (ball.y - ball.radius > screenHeight) {
        balls.removeAt(i);
        continue;
      }

      // Paddle collision
      if (!paddle.isGhost && _checkBallPaddleCollision(ball)) {
        continue;
      }

      // Brick collision
      _checkBallBrickCollision(ball);
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
      final hitOffset = ((ball.x - (paddle.x + paddle.width / 2)) / (paddle.width / 2)).clamp(-1.0, 1.0);
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
        ball.cornerBoostTimer = 3.2; // Speeds up for 3.2 seconds
        particles.spawnBurst(ball.x, pr.top, const Color(0xFFFFD54F), count: 20);
        particles.spawnFloatingText(ball.x, pr.top - 18, I18n.tr('corner_shot'), const Color(0xFFFFD54F), isLarge: true);
        audio.playSfx(GameSfx.ulti);
      } else {
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
          // Rebound physics
          final overlapX = r - distX.abs();
          final overlapY = r - distY.abs();

          if (overlapX < overlapY) {
            ball.vx = distX > 0 ? ball.vx.abs() : -ball.vx.abs();
            ball.x = distX > 0 ? b.x + b.width + r : b.x - r;
            ball.triggerSquash(distX > 0 ? 0 : pi);
          } else {
            ball.vy = distY > 0 ? ball.vy.abs() : -ball.vy.abs();
            ball.y = distY > 0 ? b.y + b.height + r : b.y - r;
            ball.triggerSquash(distY > 0 ? pi / 2 : -pi / 2);
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
    final luckLevel = save.upgrades['luck'] ?? 0;
    final dropChance = 0.14 + luckLevel * 0.04;
    if (_rand.nextDouble() > dropChance) return;

    final allTypes = PowerUpType.values;
    // Luck tilts towards buffs
    PowerUpType chosen;
    if (_rand.nextDouble() < 0.78 + luckLevel * 0.05) {
      final buffs = allTypes.where((t) => t.kind == PowerUpKind.buff).toList();
      chosen = buffs[_rand.nextInt(buffs.length)];
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
          paddle.netHitsRemaining = 2;
          break;
        case PowerUpType.mirror:
          if (balls.isNotEmpty) {
            final first = balls.first;
            balls.add(Ball(
              x: (screenWidth - first.x).clamp(20.0, screenWidth - 20.0),
              y: first.y,
              vx: -first.vx,
              vy: first.vy,
              radius: first.radius,
              isStuck: false,
              isMirror: true,
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
        default:
          break;
      }
      return;
    }

    // Remove existing if already present
    activePowerUps.removeWhere((p) => p.type == type);
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
          b.setSpeed(getBaseBallSpeed() * 1.5);
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
        paddle.netHitsRemaining = 4;
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

    balls.add(
      Ball(
        x: first.x,
        y: first.y,
        vx: -spd * 0.7,
        vy: -spd * 0.7,
        isStuck: false,
      ),
    );
    balls.add(
      Ball(
        x: first.x,
        y: first.y,
        vx: spd * 0.7,
        vy: -spd * 0.7,
        isStuck: false,
      ),
    );
  }

  void triggerUlti() {
    if (stats.ultiCharge < 100.0 || stats.ultiActiveLeft > 0) return;
    stats.ultiCharge = 0.0;
    stats.ultiActiveLeft = 2.0;

    particles.triggerShake(7.0, 0.35);
    particles.spawnShockwave(paddle.x + paddle.width / 2, paddle.y, const Color(0xFF00E5FF), maxRadius: screenWidth);
    particles.spawnFloatingText(screenWidth / 2, screenHeight * 0.42, I18n.tr('power_mode'), const Color(0xFF00E5FF), isLarge: true);
    audio.playSfx(GameSfx.ulti);

    // Twin giant hyper-lasers
    for (int i = 0; i < 8; i++) {
      projectiles.add(
        Projectile(
          x: paddle.x + (paddle.width * i / 7),
          y: paddle.y - 12.0,
          vy: -650.0,
          radius: 6.0,
          isLaser: true,
        ),
      );
    }
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

    // Check tufting pattern completed
    if (currentMode == GameMode.tuft) {
      final allFilled = bricks.every((b) => b.tuftFilled);
      if (allFilled) {
        _onVictory();
      }
      return;
    }

    // Check normal bricks completed
    final remainingBreakable = bricks.where((b) => b.isAlive && !b.isSteel).length;
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
}
