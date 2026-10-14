# In-Depth Survey & Analysis: Requirement R1 (Stop Background Gameplay After Clearing a Level or Winning)

## 1. Executive Summary
Requirement R1 aims to fix background gameplay leakage and state desynchronization during level clear transitions, victories, and game overs in the `Kırmataş` Flutter Brick Breaker engine. 
Currently:
1. When all breakable bricks are destroyed (`_checkGameProgress()`), active balls, projectiles, capsules, auto-fire timers, and dice salvos continue simulating for 0.95s behind the "BÖLÜM GEÇİLDİ!" celebration banner.
2. During `levelTransitionTimer > 0`, the simulation loop in `GameController.update()` executes all update subroutines (`_updateBalls`, `_updateProjectiles`, `_updateCapsules`, `_updatePowerUpTimers`, `_updateDice`, `_updateBricks`, etc.) because `status` remains `GameStatus.playing`.
3. If balls drop below screen bottom during the celebration banner, `_loseLife()` is called, causing spurious life loss or unexpected game over.
4. `levelTransitionTimer` decrements even when the game is paused (`GameStatus.paused`), in game over (`GameStatus.gameOver`), or in victory (`GameStatus.victory`), overwriting paused/finished states with `GameStatus.ready`.
5. Classic mode clearing level 238 increments `stats.level` to 239 instead of triggering `_onVictory()`.
6. Pointer/touch tracking in `GameCanvas` does not reset across level transitions; releasing a finger held from the previous level triggers `controller.launchBall()` immediately in the new level.

---

## 2. Investigation Area 1: Breakable Bricks Cleared & Victory / Game Over Handling

### 2.1 Code Locations
- `lib/engine/game_controller.dart`:
  - `_checkGameProgress()`: lines 2174–2207
  - `_onVictory()`: lines 2209–2221
  - `_onGameOver()`: lines 2163–2172
  - `_loseLife()`: lines 2151–2161
  - `_updateBalls()`: lines 1137–1457
  - `_updateProjectiles()`: lines 923–970
  - `_updateCapsules()`: lines 972–1012
  - `_updatePowerUpTimers()`: lines 751–811
  - `_updateDice()`: lines 813–921

### 2.2 Current Behavior Analysis
In `_checkGameProgress()` (lines 2174–2207):
```dart
2177:     final remainingBreakable = bricks.where((b) {
2178:       if (!b.isAlive) return false;
2179:       if (b.isSteel) return false;
2180:       if (b.isTuft && b.tuftFilled) return false;
2181:       return true;
2182:     }).length;
2183:     if (remainingBreakable == 0 && levelTransitionTimer <= 0) {
2184:       if (currentMode == GameMode.daily) {
2185:         _onVictory();
2186:       } else {
2187:         // Classic next level: celebratory transition with gold reward!
2188:         levelTransitionTimer = 0.95;
              ...
```
When `remainingBreakable == 0`:
- **Balls (`balls`)**: NOT cleared. Balls remain at high velocity in `balls` list.
- **Projectiles (`projectiles`)**: NOT cleared. Active lasers, rockets, boss bullets remain in `projectiles`.
- **Capsules (`capsules`)**: NOT cleared. Power-up capsules continue falling toward the paddle.
- **Auto-fire timers (`laserTimer`, `rocketTimer`, `droneShootTimer`)**: NOT halted. If `paddle.hasLaser`, `paddle.hasRockets`, or `paddle.hasDrone` are true, they continue firing new projectiles.
- **Dice salvos (`isDiceRolling`, `diceSalvoRemaining`)**: NOT halted. Rolling dice continue to roll, and queued salvo shots (up to 12 pairs) continue spawning rocket projectiles every 0.16s.
- **Game status (`status`)**: Remains `GameStatus.playing` throughout the entire 0.95s transition!

### 2.3 Leftover Steel Bricks, Walls, and Paddle Interaction
Because `status == GameStatus.playing`, the update loop in `GameController.update()` runs every frame:
1. **Steel bricks**: Alive steel bricks (`b.isSteel == true`) remain in `bricks`. Balls hit them and bounce (`_checkBallBrickCollision`, line 1419), playing `GameSfx.hitBrick`. Rockets hit them and explode (`_explodeArea`, line 958).
2. **Walls**: Balls hit screen edges and bounce, playing `GameSfx.hitWall` or `GameSfx.wallBounce8` (lines 1365–1398).
3. **Paddle**: Balls continue hitting the paddle, bouncing, and triggering sounds (`_checkBallPaddleCollision`, line 1459).
4. **Bottom of screen / Life Loss**: If a ball falls past `screenHeight` (line 1436), it is removed from `balls`. If `balls.isEmpty`, line 1454 calls `_loseLife()`:
   ```dart
   1454:     if (balls.isEmpty) {
   1455:       _loseLife();
   1456:     }
   ```
   This means the player can lose a life or even trigger game over (`_onGameOver()`) during the celebration transition while the "BÖLÜM GEÇİLDİ!" banner is visible!

### 2.4 Victory and Game Over Handlers
In `_onVictory()` (lines 2209–2221) and `_onGameOver()` (lines 2163–2172):
- Neither method clears `balls`, `projectiles`, `capsules`, `diceSalvoRemaining`, or auto-fire timers.
- While `status` changes to `GameStatus.victory` or `GameStatus.gameOver`, the frozen entities remain in the lists and continue to be rendered behind the semi-transparent dialog overlay in `pause_game_over.dart`.

---

## 3. Investigation Area 2: `levelTransitionTimer` Logic & Game Loop

### 3.1 Code Locations
- `lib/engine/game_controller.dart`:
  - `update()`: lines 595–690
- `lib/ui/game_canvas.dart`:
  - `_drawLevelClearCelebration()`: lines 4035–4082
  - `paint()`: lines 211–239
  - ticker: lines 34–47

### 3.2 Current `update(dt)` Execution Flow
In `lib/engine/game_controller.dart` lines 607–635:
```dart
607:     if (bossWarningTimer > 0) {
608:       bossWarningTimer -= dt;
609:       if (bossWarningTimer < 0) bossWarningTimer = 0;
610:     }
611:     if (levelTransitionTimer > 0) {
612:       levelTransitionTimer -= dt;
613:       if (levelTransitionTimer <= 0) {
614:         levelTransitionTimer = 0;
615:         resetPaddleAndBall();
616:         loadLevelBricks();
617:         status = GameStatus.ready;
618:       }
619:     }
620: 
621:     if (status != GameStatus.playing) {
622:       final splash = ...
631:       if (!splash) return;
632:       particles.update(dt);
633:       frameTick.ping();
634:       return;
635:     }
636: 
637:     // Bullet time ...
675:     particles.update(effectiveDt);
676:     paddle.update(effectiveDt);
677:     _updateEasterEgg(effectiveDt);
678:     _updatePowerUpTimers(effectiveDt);
679:     _updateCombo(effectiveDt);
680:     _updateProjectiles(effectiveDt);
681:     _updateCapsules(effectiveDt);
682:     _updateBricks(effectiveDt);
683:     _updateAnomalies(effectiveDt);
684:     _updateBalls(effectiveDt);
685:     _updateDice(effectiveDt);
686:     _checkGameProgress();
687:     frameTick.ping();
688:     _syncHud();
```

### 3.3 Critical Bugs Identified
1. **Simulation is NOT frozen during `levelTransitionTimer > 0`**:
   Because `status` remains `GameStatus.playing` during the 0.95s transition, line 621 (`if (status != GameStatus.playing)`) evaluates to `false`. Execution proceeds to lines 675–689, running ALL gameplay simulation methods every frame!
2. **`levelTransitionTimer` ticks while paused, gameOver, or victory**:
   Lines 611–619 are executed before line 621. The Flutter `Ticker` in `GameCanvas` calls `widget.controller.update()` every frame while `AudioManager.instance.appInForeground` is true. Therefore:
   - If the player pauses (`status = GameStatus.paused`) during the 0.95s celebration banner, `levelTransitionTimer` continues counting down!
   - When it reaches zero, it calls `resetPaddleAndBall()`, `loadLevelBricks()`, and sets `status = GameStatus.ready;`, immediately unpausing the game and dismissing the pause state!
   - Similarly, if `status == GameStatus.gameOver` or `GameStatus.victory` were set while `levelTransitionTimer > 0`, the timer expiry would overwrite status with `GameStatus.ready`.
3. **Particles update during transition vs normal gameplay**:
   Currently, during `levelTransitionTimer > 0`, `particles.update(effectiveDt)` runs with `effectiveDt`, which may be modified by bullet-time or slow-motion. Instead, celebration particles should update with full `dt` while simulation is frozen.

---

## 4. Investigation Area 3: Classic Mode Level 238 Victory Condition

### 4.1 Code Locations
- `lib/engine/game_controller.dart`:
  - `portalLevels`: lines 21–26 (uses `List.generate(238, ...)`)
  - `_checkGameProgress()`: lines 2183–2206
- `lib/models/level_design.dart`:
  - `getWorldIndex()`: lines 92–99 (World 6 for levels 196–238)
  - `buildClassicLevel()`: line 180 (`if (level == 238) return 29; // OmegaFinal Apex`)
- `lib/engine/i18n.dart`: lines 45, 334 (`'classic_desc': '238 Bölüm & Efsanevi Zorluklar'`)

### 4.2 Current Defect
In `_checkGameProgress()`:
```dart
2183:     if (remainingBreakable == 0 && levelTransitionTimer <= 0) {
2184:       if (currentMode == GameMode.daily) {
2185:         _onVictory();
2186:       } else {
2187:         levelTransitionTimer = 0.95;
              ...
2194:         stats.level++;
2195:         stats.score += 250 * stats.level;
2196:         if (currentMode == GameMode.classic) {
2197:           save.saveClassicSession(level: stats.level, score: stats.score, lives: stats.lives);
2198:         }
              ...
```
When a player finishes Level 238 in Classic mode:
- The game treats it as an ordinary level transition: it increments `stats.level` to 239, saves a classic session for level 239, and attempts to load level 239!
- `_onVictory()` is NEVER called for Classic mode upon clearing level 238.
- To fix: Check `if (currentMode == GameMode.daily || (currentMode == GameMode.classic && stats.level >= 238))`:
  Award level 238 gold and score, then call `_onVictory()`.

---

## 5. Investigation Area 4: Pointer Drag State Reset on Level Transition

### 5.1 Code Locations
- `lib/ui/game_canvas.dart`:
  - `_GameCanvasState` state fields: lines 24–30
  - `onPointerDown`: lines 64–92
  - `onPointerMove`: lines 93–117
  - `onPointerUp`: lines 118–131

### 5.2 Mechanics of the Auto-Launch Bug
In `lib/ui/game_canvas.dart`:
```dart
27:   double _pointerStartX = 0;
28:   bool _pointerMoved = false;
29:   Offset? _chaosPointerDownPos;

90:             _pointerStartX = event.localPosition.dx;
91:             _pointerMoved = false;

112:             if (!_pointerMoved && (event.localPosition.dx - _pointerStartX).abs() < 8) {
113:               return;
114:             }
115:             _pointerMoved = true;
116:             widget.controller.movePaddleBy(dx);

127:             if (!_pointerMoved &&
128:                 (controller.status == GameStatus.ready || controller.hasStuckBall)) {
129:               controller.launchBall();
130:             }
```
Consider the following real user flow:
1. The player is dragging the paddle during Level 1.
2. The ball hits the last breakable brick. Level 1 completes, starting `levelTransitionTimer = 0.95`.
3. The player holds their finger on the screen (or taps/touches during the banner).
   - If they touched down during the transition banner, `onPointerDown` sets `_pointerMoved = false`.
   - Even if they were dragging earlier, if they hold still or tap during the transition, `_pointerMoved` is `false`.
4. After 0.95s, `levelTransitionTimer` expires, resetting paddle and ball, loading Level 2, and setting `status = GameStatus.ready`.
5. The player lifts their finger from the screen (`onPointerUp`).
6. Because `controller.status == GameStatus.ready` AND `!_pointerMoved` is `true`:
   `controller.launchBall()` is invoked immediately!
7. The ball launches into Level 2 without the player's intentional tap to start.

### 5.3 Solution Design
To eliminate the auto-launch bug:
1. **Level-Scoped Touch Tracking**: Record the level at touch-down:
   `int _pointerDownLevel = -1;`
   `bool _canLaunchOnUp = false;`
2. **Invalidate in-flight touches across transitions**:
   - In `onPointerDown`:
     Only allow launch eligibility (`_canLaunchOnUp = true`) if `controller.status == GameStatus.ready` AND `controller.levelTransitionTimer <= 0` (or `controller.hasStuckBall`). Record `_pointerDownLevel = controller.stats.level`.
     If `controller.levelTransitionTimer > 0`, invalidate: `_canLaunchOnUp = false`, `_pointerMoved = true`, `_chaosPointerDownPos = null`.
   - In `onPointerMove`:
     If `controller.levelTransitionTimer > 0`, ignore paddle movement (`movePaddleBy`).
   - In `onPointerUp`:
     Only launch if `_canLaunchOnUp == true` AND `_pointerDownLevel == controller.stats.level` AND `controller.levelTransitionTimer <= 0` AND `!_pointerMoved` AND `(controller.status == GameStatus.ready || controller.hasStuckBall)`.
   - In `_ticker`:
     If `controller.stats.level != _lastTrackedLevel` or `controller.levelTransitionTimer > 0`:
     Reset touch tracking (`_canLaunchOnUp = false`, `_pointerMoved = true`, `_chaosPointerDownPos = null`).
   - In `onPointerCancel`:
     Reset touch tracking.

---

## 6. Investigation Area 5: Existing Test Coverage in `test/`

### 6.1 Baseline Test Suite Status
- Total tests: 92 passing tests in `test/game_test.dart` (run time: ~3s).
- Flutter test execution succeeds with exit code 0.

### 6.2 Tests Related to Level Transition and Victory
- Line 2208: `All bricks cleared triggers levelTransitionTimer celebration`:
  ```dart
  test('All bricks cleared triggers levelTransitionTimer celebration', () {
    final gc = GameController();
    gc.setDimensions(360, 640);
    gc.startNewGame(GameMode.classic);
    gc.launchBall();
    for (final b in gc.bricks) {
      b.hp = 0;
      b.isAlive = false;
    }
    gc.update(0.016);
    expect(gc.levelTransitionTimer > 0, true);
  });
  ```
  This is the only test for level clear. It only checks `gc.levelTransitionTimer > 0`.
- Line 1281: `GameController claimVictoryBonus grants +200 gold and is single-use per victory`.
- Line 1240: `GameController reviveWithOneLife grants 1 life, resets ball, and allows only 1 revive per game`.

### 6.3 Missing Test Scenarios to Add
1. **Immediate clearing of balls, projectiles, capsules, dice salvos, and auto-fire timers upon level clear**:
   Verify that when breakable bricks reach 0, `balls.isEmpty`, `projectiles.isEmpty`, `capsules.isEmpty`, `diceSalvoRemaining == 0`, `isDiceRolling == false`, `paddle.hasLaser == false`, etc.
2. **Simulation freeze during `levelTransitionTimer > 0`**:
   Verify that while `levelTransitionTimer > 0`, calling `update(dt)` decreases `levelTransitionTimer` and updates particles, but does NOT move balls, fire weapons, or decrease lives (`balls.isEmpty` does NOT trigger `_loseLife()`).
3. **`levelTransitionTimer` does not tick while paused, gameOver, or victory**:
   Verify that when `status` is `GameStatus.paused`, `GameStatus.gameOver`, or `GameStatus.victory`, calling `update(dt)` leaves `levelTransitionTimer` unchanged.
4. **Classic mode level 238 clear triggers `_onVictory()`**:
   Verify that starting at level 238 in Classic mode and clearing all breakable bricks triggers `status == GameStatus.victory`, awards gold/score, clears session, and does not set `levelTransitionTimer`.
5. **Widget test for pointer drag reset across level transitions**:
   Verify with `testWidgets` that holding a pointer during level transition does not trigger `launchBall()` upon release in the new level.

---

## 7. Concrete Implementation Plan for Implementer Agent

### Step 1: Add `_haltBackgroundGameplay()` in `GameController`
Create a centralized helper method in `lib/engine/game_controller.dart`:
```dart
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
  paddle.hasRockets = false;
  paddle.hasDrone = false;
  paddle.rocketAmmo = 0;
  activePowerUps.removeWhere((p) =>
      p.type == PowerUpType.laser ||
      p.type == PowerUpType.rocket ||
      p.type == PowerUpType.drone);
}
```

### Step 2: Update `_checkGameProgress()` in `GameController`
```dart
void _checkGameProgress() {
  if (currentMode == GameMode.zen || currentMode == GameMode.chaos) return;

  final remainingBreakable = bricks.where((b) {
    if (!b.isAlive) return false;
    if (b.isSteel) return false;
    if (b.isTuft && b.tuftFilled) return false;
    return true;
  }).length;
  if (remainingBreakable == 0 && levelTransitionTimer <= 0) {
    _haltBackgroundGameplay();
    if (currentMode == GameMode.daily ||
        (currentMode == GameMode.classic && stats.level >= 238)) {
      if (currentMode == GameMode.classic) {
        final baseGold = 25 + (stats.level * 5).clamp(0, 50);
        final relicBonus = save.hasPermanentRelic ? max(1, (baseGold * 0.05).round()) : 0;
        final levelGold = baseGold + relicBonus;
        stats.goldCollected += levelGold;
        save.addGold(levelGold);
        stats.score += 250 * stats.level;
      }
      _onVictory();
    } else {
      levelTransitionTimer = 0.95;
      final baseGold = 25 + (stats.level * 5).clamp(0, 50);
      final relicBonus = save.hasPermanentRelic ? max(1, (baseGold * 0.05).round()) : 0;
      final levelGold = baseGold + relicBonus;
      stats.goldCollected += levelGold;
      save.addGold(levelGold);
      stats.level++;
      stats.score += 250 * stats.level;
      if (currentMode == GameMode.classic) {
        save.saveClassicSession(level: stats.level, score: stats.score, lives: stats.lives);
      }
      particles.triggerShake(5.0, 0.35);
      particles.spawnBurst(screenWidth / 2, screenHeight * 0.38, const Color(0xFFFFD700), count: 32, speed: 200.0);
      particles.spawnShockwave(screenWidth / 2, screenHeight * 0.38, const Color(0xFFFFD700), maxRadius: 85.0);
      particles.spawnFloatingText(screenWidth / 2, screenHeight * 0.40, '${I18n.tr('level').toUpperCase()} ${stats.level}!', const Color(0xFFFFD54F), isLarge: true);
      particles.spawnFloatingText(screenWidth / 2, screenHeight * 0.48, '+$levelGold 🪙 ${I18n.tr('level_bonus')}', const Color(0xFFFFD54F), isLarge: false);
      audio.playSfx(GameSfx.victory);
    }
  }
}
```

### Step 3: Update `_onVictory()` and `_onGameOver()`
Call `_haltBackgroundGameplay()` inside both `_onVictory()` and `_onGameOver()`.

### Step 4: Refactor `update(dt)` in `GameController`
```dart
void update(double dt) {
  gameTime += dt;

  final hadSplat = activeSplat != null;
  if (activeSplat != null) {
    activeSplat!.update(dt);
    if (activeSplat!.isDead) {
      activeSplat = null;
    }
  }

  // 1. Do NOT tick levelTransitionTimer while paused, gameOver, or victory
  if (status == GameStatus.paused || status == GameStatus.gameOver || status == GameStatus.victory) {
    final splash =
        hadSplat ||
        particles.particles.isNotEmpty ||
        particles.shockwaves.isNotEmpty ||
        particles.floatingTexts.isNotEmpty ||
        particles.shards.isNotEmpty ||
        bossWarningTimer > 0 ||
        particles.shakeTimeLeft > 0;
    if (splash) {
      particles.update(dt);
      frameTick.ping();
    }
    return;
  }

  // 2. While levelTransitionTimer > 0, freeze simulation and only update particles
  if (levelTransitionTimer > 0) {
    levelTransitionTimer -= dt;
    if (levelTransitionTimer <= 0) {
      levelTransitionTimer = 0;
      resetPaddleAndBall();
      loadLevelBricks();
      status = GameStatus.ready;
    }
    particles.update(dt);
    frameTick.ping();
    _syncHud();
    return;
  }

  if (bossWarningTimer > 0) {
    bossWarningTimer -= dt;
    if (bossWarningTimer < 0) bossWarningTimer = 0;
  }

  if (status != GameStatus.playing) {
    final splash =
        hadSplat ||
        particles.particles.isNotEmpty ||
        particles.shockwaves.isNotEmpty ||
        particles.floatingTexts.isNotEmpty ||
        particles.shards.isNotEmpty ||
        bossWarningTimer > 0 ||
        particles.shakeTimeLeft > 0;
    if (!splash) return;
    particles.update(dt);
    frameTick.ping();
    return;
  }

  // Normal gameplay simulation continues here...
```
Also guard line 1454 in `_updateBalls`:
```dart
if (balls.isEmpty && levelTransitionTimer <= 0 && status == GameStatus.playing) {
  _loseLife();
}
```

### Step 5: Reset Pointer Drag State in `lib/ui/game_canvas.dart`
Update `_GameCanvasState` with level-aware touch tracking:
- Add `int _touchStartLevel = -1;` and `bool _canLaunchOnUp = false;`.
- In `onPointerDown`:
  Set `_touchStartLevel = widget.controller.stats.level;`.
  Set `_canLaunchOnUp = (widget.controller.status == GameStatus.ready && widget.controller.levelTransitionTimer <= 0) || widget.controller.hasStuckBall;`.
  If `widget.controller.levelTransitionTimer > 0`, set `_pointerMoved = true; _canLaunchOnUp = false; _chaosPointerDownPos = null;`.
- In `onPointerMove`:
  If `widget.controller.levelTransitionTimer > 0`, do NOT call `movePaddleBy`.
- In `onPointerUp`:
  Only launch if `_canLaunchOnUp && _touchStartLevel == widget.controller.stats.level && widget.controller.levelTransitionTimer <= 0 && !_pointerMoved && (controller.status == GameStatus.ready || controller.hasStuckBall)`.
- In `_ticker`:
  Track `_lastTrackedLevel`. If `level != _lastTrackedLevel` or `controller.levelTransitionTimer > 0`, invalidate: `_canLaunchOnUp = false; _pointerMoved = true; _chaosPointerDownPos = null;`.

### Step 6: Expand Unit & Widget Tests in `test/game_test.dart`
Add dedicated test cases verifying:
1. Clearing all breakable bricks clears balls, projectiles, capsules, dice, and auto-fire timers.
2. `levelTransitionTimer > 0` freezes simulation and causes no life loss.
3. `levelTransitionTimer` does not tick when paused, gameOver, or victory.
4. Level 238 Classic mode clear triggers `_onVictory()` and clears session.
5. Pointer release from previous level does not auto-launch in new level.
