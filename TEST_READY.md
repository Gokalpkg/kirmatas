# E2E Test Suite Ready: Kırmataş Quality & Visual Overhaul

## Overview
A comprehensive, requirement-driven opaque-box E2E test suite has been established for the Kırmataş Quality & Visual Overhaul. All test cases strictly reflect the user-facing acceptance criteria and interface contracts specified in `ORIGINAL_REQUEST.md`, `PROJECT.md`, and `TEST_INFRA.md`.

- **Test Suite Location**: `test/e2e/`
- **Primary Master Runner**: `test/e2e/e2e_requirements_test.dart`
- **Static Analysis Status**: `flutter analyze test/e2e/` reports **0 issues** (clean).

---

## Test Runner Commands

### Run Full E2E Test Suite
```bash
flutter test test/e2e/e2e_requirements_test.dart
```

### Run by Specific Tier
```bash
# Tier 1: Feature Coverage (Isolation)
flutter test test/e2e/tier1_feature_coverage_test.dart

# Tier 2: Boundary & Corner Cases
flutter test test/e2e/tier2_boundary_corner_test.dart

# Tier 3: Cross-Feature Combinations
flutter test test/e2e/tier3_cross_feature_test.dart

# Tier 4: Real-World Application Workload Scenarios
flutter test test/e2e/tier4_real_world_scenarios_test.dart
```

### Run Static Analysis
```bash
flutter analyze test/e2e/
```

---

## Coverage Summary Across Tiers 1–4

| Tier | Description | Target Coverage | Implemented Tests | Status |
|------|-------------|:---------------:|:-----------------:|:------:|
| **Tier 1** | Feature Coverage (in isolation) | $\ge 5$ tests / feature | 75 tests | **READY** |
| **Tier 2** | Boundary & Corner Cases | $\ge 5$ tests / feature | 75 tests | **READY** |
| **Tier 3** | Cross-Feature Pairwise Interactions | Multi-feature | 8 tests | **READY** |
| **Tier 4** | Real-World Application Scenarios | 5 Workload Scenarios | 5 tests | **READY** |
| **Total** | **Full Suite** | | **163 tests** | **READY** |

---

## Feature Checklist Table (F1.1 – F3.4)

| # | Feature ID | Feature Description | Requirement Source | Tier 1 (Count) | Tier 2 (Count) | Tier 3 (Cross) | Tier 4 (Scenario) |
|---|:----------:|---------------------|:------------------:|:--------------:|:--------------:|:--------------:|:-----------------:|
| 1 | **F1.1** | Level clear halts active balls, projectiles, capsules, weapon timers, dice salvos | ORIGINAL_REQUEST §R1 | 5 | 5 | ✓ | Scenario 1, 5 |
| 2 | **F1.2** | Victory & GameOver halt active entities, projectiles, weapon timers | ORIGINAL_REQUEST §R1 | 5 | 5 | ✓ | Scenario 2 |
| 3 | **F1.3** | Freeze simulation during `levelTransitionTimer > 0`, updating only particles | ORIGINAL_REQUEST §R1 | 5 | 5 | ✓ | Scenario 1 |
| 4 | **F1.4** | Freeze `levelTransitionTimer` countdown on pause, gameOver, or victory | ORIGINAL_REQUEST §R1 | 5 | 5 | ✓ | Scenario 1, 2 |
| 5 | **F1.5** | Classic mode level 238 clear triggers `_onVictory()` instead of level 239 | ORIGINAL_REQUEST §R1 | 5 | 5 | ✓ | Scenario 2 |
| 6 | **F1.6** | Reset pointer drag and touch launch across level transitions | ORIGINAL_REQUEST §R1 | 5 | 5 | ✓ | Scenario 1 |
| 7 | **F2.1** | Remove 6-point Claude starburst polygon (`claudeStar` / `innerStar`) | ORIGINAL_REQUEST §R2 | 5 | 5 | ✓ | Scenario 3 |
| 8 | **F2.2** | Unify `pierce` & `fireball` state (`isFireball = true` / `isPierce = true`) | ORIGINAL_REQUEST §R2 | 5 | 5 | ✓ | Scenario 3 |
| 9 | **F2.3** | High-FPS Golden-Flame "Yakıcı Top" visual (zero `MaskFilter.blur`) | ORIGINAL_REQUEST §R2 | 5 | 5 | ✓ | Scenario 3 |
| 10 | **F2.4** | Localization labels to `"🔥 YAKICI TOP!"` (TR) / `"🔥 SEARING BALL!"` (EN) | ORIGINAL_REQUEST §R2 | 5 | 5 | ✓ | Scenario 3 |
| 11 | **F2.5** | Falling capsule & PixelArt golden-flame theme matrix | ORIGINAL_REQUEST §R2 | 5 | 5 | ✓ | Scenario 3 |
| 12 | **F3.1** | Black Hole influence radius `maxInfluenceDist = max(135.0, r * mult)` | ORIGINAL_REQUEST §R3 | 5 | 5 | ✓ | Scenario 4, 5 |
| 13 | **F3.2** | Strong gravity falloff `pow(proximity, 0.85)` + high base pull & swirl | ORIGINAL_REQUEST §R3 | 5 | 5 | ✓ | Scenario 4 |
| 14 | **F3.3** | Render gravity boundary ring & inward spiral waves at `maxInfluenceDist` | ORIGINAL_REQUEST §R3 | 5 | 5 | ✓ | Scenario 4 |
| 15 | **F3.4** | `PowerUpType.vortex` spawns active `BlackHole` in open play zone | ORIGINAL_REQUEST §R3 | 5 | 5 | ✓ | Scenario 5 |

---

## Baseline Execution Results & Escalation to Milestone Workers

During the test execution against the current baseline codebase:
- **Passing Tests**: 80 tests passed (including existing physics, boundary verifications, particle updates during transition, touch resets, falling capsule renders, and zero-blur painter checks).
- **Failing Tests**: 83 tests failed due to features not yet implemented in M1, M2, and M3.

### Escalation Items for Implementing Milestone Agents:
1. **For Milestone 1 Worker (`worker_m1`)**:
   - `lib/engine/game_controller.dart`: Implement `_haltBackgroundGameplay()` to clear balls, projectiles, capsules, dice salvos, and weapon timers in `_checkGameProgress()`, `_onVictory()`, and `_onGameOver()`.
   - Freeze `_updateBalls`, `_updateProjectiles`, `_updateCapsules`, `_updatePowerUpTimers`, `_updateDice`, `_updateBricks`, `_updateAnomalies` while `levelTransitionTimer > 0`.
   - Freeze `levelTransitionTimer` from decrementing when `status == GameStatus.paused`, `GameStatus.gameOver`, or `GameStatus.victory`.
   - In `_checkGameProgress()`, check `if (stats.level >= 238) _onVictory();` instead of advancing to level 239.
   - In `lib/ui/game_canvas.dart`: Prevent cross-level touch auto-launch by recording `_touchStartLevel` or resetting launch eligibility on transition.

2. **For Milestone 2 Worker (`worker_m2`)**:
   - `lib/engine/game_controller.dart`: Unify `PowerUpType.fireball` and `PowerUpType.pierce` in `applyPowerUp` to set both `ball.isFireball = true` AND `ball.isPierce = true`, and allow both flags to melt steel bricks.
   - `lib/engine/i18n.dart`: Update `pup_fireball` and `pup_pierce` to `"🔥 YAKICI TOP!"` (TR) and `"🔥 SEARING BALL!"` (EN).
   - `lib/ui/game_canvas.dart`: Completely remove `claudeStar` and `innerStar` polygons and replace with swirling golden flame petals and rotating solar crest core.
   - `lib/ui/pixel_art.dart`: Update `PowerUpType.pierce` matrix to golden flame motif.

3. **For Milestone 3 Worker (`worker_m3`)**:
   - `lib/models/black_hole.dart`: Add getter `double get maxInfluenceDist => max(135.0, radius * (isVortexTrap ? 6.5 : (isSupercharged ? 6.0 : 5.5)));`.
   - `lib/engine/game_controller.dart`: Update `_updateBalls` to use `bh.maxInfluenceDist`, `pow(proximity, 0.85)`, higher `basePull` (520..850 scaled by `radius / 26.0`), and tangential swirl.
   - `lib/engine/game_controller.dart`: Implement `case PowerUpType.vortex:` in `applyPowerUp` to spawn an active `BlackHole` with duration 9.0 in the open play zone.
   - `lib/ui/game_canvas.dart`: Render outer boundary ring and inward-spiraling waves at `maxInfluenceDist`.

When M1, M2, and M3 workers complete their implementations, the entire test suite can be run via:
`flutter test test/e2e/e2e_requirements_test.dart` to verify 100% pass across all 163 tests.
