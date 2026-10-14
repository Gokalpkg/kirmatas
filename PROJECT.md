# Project: Kırmataş Quality & Visual Overhaul

## Architecture
- **Engine Layer**: `lib/engine/game_controller.dart` manages the game loop (`update`), status state-machine (`GameStatus`), ball physics, weapons, power-ups, black hole gravitational pull, and level progression/victory conditions.
- **Models Layer**:
  - `lib/models/black_hole.dart`: Gravitational anomaly state, dimensions, influence geometry.
  - `lib/models/powerup.dart`: PowerUp definitions, durations, icons, labels.
  - `lib/models/level_design.dart`: Level layouts, brick counts, mode-specific parameters.
  - `lib/models/ball.dart`: Ball physics, state flags (`isFireball`, `isPierce`).
- **UI / Canvas Layer**:
  - `lib/ui/game_canvas.dart`: High-performance custom painter for balls, particles, black holes, field boundaries, paddle, and user input handling (`onPointerDown`, `onPointerMove`, `onPointerUp`).
  - `lib/ui/pixel_art.dart`: Pixel art bitmap definitions for power-up capsules.
- **Localization Layer**: `lib/l10n/i18n.dart` (and `lib/engine/i18n.dart`): Multilingual string tables (TR / EN).
- **Test Infrastructure**: `test/game_test.dart` and dedicated test suites under `test/e2e/`.

## Feature Inventory
| # | Feature | Description | Milestone | Source |
|---|---------|-------------|-----------|--------|
| 1 | F1.1 | Clear and halt active balls, projectiles, capsules, weapon timers (laser, rocket, drone), and dice salvos on level clear (`_checkGameProgress`) | M1 | ORIGINAL_REQUEST §R1 |
| 2 | F1.2 | Clear and halt active balls, projectiles, capsules, and weapon/dice timers on `_onVictory` and `_onGameOver` | M1 | ORIGINAL_REQUEST §R1 |
| 3 | F1.3 | Freeze gameplay simulation (`_updateBalls`, `_updateProjectiles`, `_updateCapsules`, `_updatePowerUpTimers`, `_updateDice`, `_updateBricks`, `_updateAnomalies`, `paddle.update`) during `levelTransitionTimer > 0`, updating only particles | M1 | ORIGINAL_REQUEST §R1 |
| 4 | F1.4 | Freeze `levelTransitionTimer` countdown while game status is `paused`, `gameOver`, or `victory` | M1 | ORIGINAL_REQUEST §R1 |
| 5 | F1.5 | Classic mode level 238 clear triggers `_onVictory()` instead of advancing to level 239 | M1 | ORIGINAL_REQUEST §R1 |
| 6 | F1.6 | Reset pointer drag and touch launch state across level transitions so releasing previous touch never auto-launches in new level | M1 | ORIGINAL_REQUEST §R1 |
| 7 | F2.1 | Remove 6-point Claude starburst polygon (`claudeStar` / `innerStar`) from `lib/ui/game_canvas.dart` | M2 | ORIGINAL_REQUEST §R2 |
| 8 | F2.2 | Unify `PowerUpType.pierce` and `PowerUpType.fireball` state (`isFireball = true` / `isPierce = true`) so both pierce breakable bricks and melt steel bricks | M2 | ORIGINAL_REQUEST §R2 |
| 9 | F2.3 | High-FPS (zero `MaskFilter.blur`) Golden-Flame "Yakıcı Top" visual: multi-layered swirling golden-amber flame petals curling opposite velocity vector + molten gold armored core with rotating solar crest inside sphere | M2 | ORIGINAL_REQUEST §R2 |
| 10 | F2.4 | Update localization strings in `i18n.dart` to `"🔥 YAKICI TOP!"` (TR) and `"🔥 SEARING BALL!"` (EN) for fireball and pierce | M2 | ORIGINAL_REQUEST §R2 |
| 11 | F2.5 | Update falling capsule and `PixelArt` icon for pierce / fireball to golden-flame theme | M2 | ORIGINAL_REQUEST §R2 |
| 12 | F3.1 | Expand gravitational influence radius `maxInfluenceDist = max(135.0, bh.radius * (bh.isVortexTrap ? 6.5 : (bh.isSupercharged ? 6.0 : 5.5)))` in `lib/models/black_hole.dart` and `lib/engine/game_controller.dart` | M3 | ORIGINAL_REQUEST §R3 |
| 13 | F3.2 | Strong responsive distance falloff `pow(proximity, 0.85)` + high `basePull` (520-850 px/s²) + tangential swirl (80-160 px/s²) producing visible deflection across entire field for all black hole radii ($r=20..34$) | M3 | ORIGINAL_REQUEST §R3 |
| 14 | F3.3 | Render visible animated gravitational pull field boundary ring and inward-spiraling gravity waves matching `maxInfluenceDist` in `_drawBlackHoles` (`lib/ui/game_canvas.dart`) | M3 | ORIGINAL_REQUEST §R3 |
| 15 | F3.4 | Implement `case PowerUpType.vortex:` in `applyPowerUp` (`lib/engine/game_controller.dart`) to spawn an active `BlackHole` in the open play zone between bricks and paddle | M3 | ORIGINAL_REQUEST §R3 |
| 16 | F4.1 | Requirement-driven comprehensive E2E test suite (Tiers 1-4) covering all features F1.1-F3.4 | E2E_TRACK / M4 | ORIGINAL_REQUEST §Acceptance |
| 17 | F4.2 | Adversarial coverage hardening (Tier 5) to uncover and resolve edge-case vulnerabilities | M4 | Project Architecture |

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| M1 | Post-Level Background Gameplay Halt | F1.1, F1.2, F1.3, F1.4, F1.5, F1.6 in `game_controller.dart` & `game_canvas.dart` | none | PLANNED |
| M2 | Golden-Flame "Yakıcı Top" Power-Up | F2.1, F2.2, F2.3, F2.4, F2.5 in `game_canvas.dart`, `game_controller.dart`, `pixel_art.dart`, `i18n.dart` | none | PLANNED |
| M3 | Black Holes & Gravitational Fields + Vortex | F3.1, F3.2, F3.3, F3.4 in `black_hole.dart`, `game_controller.dart`, `game_canvas.dart` | none | PLANNED |
| E2E | Requirement-Driven E2E Test Suite | Test runner & Tiers 1-4 suites for all F1.1–F3.4 features, publishing `TEST_READY.md` | none | IN_PROGRESS |
| M4 | Final Milestone: 100% E2E Pass & Hardening | Phase 1 (Pass 100% Tiers 1-4) + Phase 2 (Tier 5 Adversarial Coverage Hardening) | M1, M2, M3, E2E | PLANNED |

## Interface Contracts

### M1: Background Gameplay Halt Contract
- `GameController._haltBackgroundGameplay()`:
  - Clears `balls.clear()`, `projectiles.clear()`, `capsules.clear()`.
  - Resets `isDiceRolling = false`, `diceSalvoRemaining = 0`, `diceRollTimer = 0.0`, `diceDisplayTimer = 0.0`.
  - Resets weapon timers and paddle weapon flags: `laserTimer = 0.0`, `rocketTimer = 0.0`, `droneShootTimer = 0.0`, `paddle.hasLaser = false`, `paddle.hasRockets = false`, `paddle.hasDrone = false`.
- `GameController.update(dt)`:
  - When `levelTransitionTimer > 0`: only run `particles.update(dt)`, `frameTick.ping()`, `_syncHud()`.
  - When `status == GameStatus.paused || status == GameStatus.gameOver || status == GameStatus.victory`: do NOT decrement `levelTransitionTimer`.
- `_GameCanvasState`:
  - Reset `_canLaunchOnUp = false` or check `_touchStartLevel == controller.stats.level` to prevent cross-level auto-launch.

### M2: Golden-Flame "Yakıcı Top" Contract
- `PowerUpType.fireball` & `PowerUpType.pierce`:
  - Both apply `b.isFireball = true` AND `b.isPierce = true` to all active balls.
  - Steel brick check: `(ball.isFireball || ball.isPierce)` melts steel brick.
  - PowerUp labels: `"🔥 YAKICI TOP!"` (TR) / `"🔥 SEARING BALL!"` (EN).
- `GameCanvas`:
  - `claudeStar` and `innerStar` polygons completely removed.
  - Searing ball visual: Multi-layered organic Bezier flame petals curling opposite velocity vector (`atan2(-vy, -vx)`), molten gold core with rotating golden solar ring/crest inside sphere (zero `MaskFilter.blur`). Distinct from Corner Shot supersonic jet afterburner.
- `PixelArt`:
  - `PowerUpType.pierce` capsule matrix updated to flame motif with golden-amber palette.

### M3: Black Hole Physics & Boundary Contract
- `BlackHole`:
  - `double get maxInfluenceDist => max(135.0, radius * (isVortexTrap ? 6.5 : (isSupercharged ? 6.0 : 5.5)));`
- `GameController._updateBalls(dt)`:
  - `final maxInfluenceDist = bh.maxInfluenceDist;`
  - `final proximity = 1.0 - (dist / maxInfluenceDist).clamp(0.0, 1.0);`
  - `final falloff = pow(proximity, 0.85);`
  - `final basePull = (bh.isVortexTrap ? 850.0 : (bh.isSupercharged ? 680.0 : 520.0)) * (bh.radius / 26.0);`
  - `final pull = basePull * falloff;`
  - Tangential swirl with `spinDrag = (bh.isVortexTrap ? 120.0 : (bh.isSupercharged ? 160.0 : 85.0)) * falloff;`
- `GameController.applyPowerUp(PowerUpType.vortex)`:
  - Spawns active `BlackHole` with duration `9.0` in open play zone: $y \in [\text{lowestAliveBrickY} + 45.0, \text{paddle.y} - 75.0]$.
- `GameCanvas._drawBlackHoles`:
  - Draws outer gravitational boundary ring at `bh.maxInfluenceDist` and animated inward-spiraling gravity waves.

## Code Layout
- `lib/engine/game_controller.dart`: Engine simulation loop, level transitions, power-up effects, ball physics.
- `lib/models/black_hole.dart`: Black hole model & geometric properties.
- `lib/models/powerup.dart`: Power-up definitions & attributes.
- `lib/models/ball.dart`: Ball entity state.
- `lib/ui/game_canvas.dart`: Custom painter & touch event listeners.
- `lib/ui/pixel_art.dart`: Capsule sprite matrices.
- `lib/l10n/i18n.dart`: Localization strings.
- `test/game_test.dart`: Primary unit & widget test suite.
- `test/e2e/`: Requirement-driven E2E test suites (Tiers 1-4).
