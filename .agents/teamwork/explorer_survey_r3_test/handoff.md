# Handoff Report: R3 Black Holes & Test Infrastructure Survey

**Agent Folder**: `c:\Users\USER\Desktop\KIPKIRMATAS\.agents\teamwork\explorer_survey_r3_test\`  
**Target Milestone**: Survey Requirement R3 & Test Suite  
**Date**: 2026-10-11  

---

## 1. Observation

### Obs 1: BlackHole Model
- **File**: `lib/models/black_hole.dart` (lines 1–32)
- Attributes defined:
  - `double x`, `double y`, `double radius`, `double mass`, `double rotation = 0.0`, `double timeLeft = 5.0`
  - `final bool isVortexTrap`, `final bool isSupercharged`
  - `final Map<int, double> ballAngles = {}`, `ballAccumulatedAngles = {}`, `ballOrbitLaps = {}`
- No `maxInfluenceDist` getter currently exists on the model.

### Obs 2: Gravitational Pull Physics in Controller
- **File**: `lib/engine/game_controller.dart` (lines 1203–1267)
- Verbatim logic:
  ```dart
  1203: final maxInfluenceDist = bh.radius * (bh.isVortexTrap ? 4.2 : (bh.isSupercharged ? 3.8 : 3.5));
  ...
  1245: final normalizedDist = (dist / maxInfluenceDist).clamp(0.0, 1.0);
  1246: final proximity = 1.0 - normalizedDist;
  1249: final basePull = (bh.isVortexTrap ? 340.0 : (bh.isSupercharged ? 300.0 : 230.0)) * (bh.radius / 28.0);
  1250: final pull = basePull * proximity * proximity;
  ...
  1264: final spinDrag = (bh.isVortexTrap ? 55.0 : (bh.isSupercharged ? 85.0 : 35.0)) * proximity;
  ```
- For $r = 20.0$, `maxInfluenceDist` is $70.0\text{ px}$. At $d = 56.0\text{ px}$ ($\text{proximity} = 0.2$), $\text{proximity}^2 = 0.04$, yielding $\text{pull} = 164.3 \times 0.04 = 6.57\text{ px/s}^2$. Per frame at 60 FPS ($dt = 0.016$), velocity delta is $\Delta v = 0.105\text{ px/s}$. On a $450\text{ px/s}$ ball, frame deflection is $\approx 0.013^\circ$, and total transit deflection is $< 0.6^\circ$.

### Obs 3: Canvas Rendering
- **File**: `lib/ui/game_canvas.dart` (lines 2061–2169, method `_drawBlackHoles`)
- Halo radius multiplier is only:
  ```dart
  2070: final haloRadiusMult = bh.isVortexTrap ? 3.4 : (bh.isSupercharged ? 3.2 : 2.8);
  ```
  For $r = 20$, halo extends only to $56\text{ px}$.
- Accretion disk arms reach only $r \times (0.55 + 0.35 \times (i \% 5)) \le 1.6 \times r$.
- Event horizon and photon ring are drawn at $0.45 \times r$ and $0.48 \times r$.
- There is no rendering of `maxInfluenceDist` and no inward-spiraling gravity waves.

### Obs 4: Missing `PowerUpType.vortex` in `applyPowerUp`
- **File**: `lib/models/powerup.dart` (line 24):
  `vortex('Girdap', Color(0xFFE040FB), 9.0, PowerUpKind.buff, Icons.cyclone),`
- **File**: `lib/engine/game_controller.dart` (lines 1870–2010):
  `applyPowerUp(PowerUpType type)` checks `type.isInstant` (false because duration is 9.0), adds to `activePowerUps`, then enters `switch (type)`.
  In `switch (type)` (lines 1947–2010), there is NO `case PowerUpType.vortex:`. It falls through to `default: break;`.
  No `BlackHole` is spawned when collecting the vortex capsule.

### Obs 5: Test Infrastructure & Existing Suite
- **Command**: `flutter test`
  - Output: `00:08 +92: All tests passed!` (92 tests, 0 failures, exit code 0).
- **Command**: `flutter analyze`
  - Output: `No issues found! (ran in 60.9s)` (0 issues, exit code 0).
- Existing black hole tests in `test/game_test.dart`:
  - Lines 266–284: `Black holes pull ball with gravitational force` ($v_x > 0$)
  - Lines 651–685: `All black holes from smallest (r=20) to largest (r=34)...` ($v_x > 0.5$ for $r=20$, $v_x > 1.0$ for $r=34$, $v_{x,34} > v_{x,20}$)
  - Lines 687–727: `Supercharged exotic black hole accelerates balls...` ($v_x > 0.8$, slingshot at exit)
  - Lines 729–760: Widget test rendering `GameCanvas` with active black hole
  - Lines 1099–1130: Orbital deflection & laps
  - Lines 1177–1197: Black hole spawn zone between alive bricks and paddle
  - Lines 2044–2065: Gravitational field pull & base speed floor

---

## 2. Logic Chain

1. **Deflection Defect Link**:
   From Obs 2, standard and small black holes ($r=20\dots 34$) had an influence radius of only $3.5 \times r$ ($70\dots 119\text{ px}$). The quadratic falloff `proximity * proximity` reduced pull by $75\%$ to $96\%$ over the majority of that distance. Combined with a low `basePull` of $230\text{ px/s}^2$, fast balls ($300\dots 600\text{ px/s}$) crossed the field with negligible velocity alteration ($\Delta v < 0.5\text{ px/s}$, deflection $< 1^\circ$).
2. **Formula Upgrade**:
   Replacing `maxInfluenceDist` with $\max(135.0, \text{radius} \times (\dots 5.5 \dots 6.5))$ guarantees an active radius of at least $135\text{ px}$ even for the smallest black hole ($r=20$). Replacing `proximity * proximity` with `pow(proximity, 0.85)` boosts force at the periphery by $4.9\times$ to $14\times$. Increasing `basePull` to $520\dots 850\text{ px/s}^2$ and swirl to $80\dots 140\text{ px/s}^2$ increases cumulative velocity change on crossing balls to $>15\text{ px/s}$, resulting in a clear $5^\circ \dots 25^\circ$ deflection.
3. **Canvas Inconsistency Link**:
   From Obs 3, the canvas currently paints only the inner halo ($2.8\times \dots 3.4\times r$) and inner accretion arcs ($\le 1.6\times r$). Players cannot see the expanded boundary at $\max(135.0, \dots)$ or the inward pull. Drawing a dedicated boundary ring and inward-spiraling gravity waves with animated phase will provide the visual feedback matching the physics.
4. **Power-Up Disconnect Link**:
   From Obs 4, `PowerUpType.vortex` drops from bricks as a capsule, but collecting it produces only a floating label without gameplay effect. Adding `case PowerUpType.vortex:` in `applyPowerUp` to spawn an active `BlackHole` with `timeLeft = 9.0` in the open zone between `lowestAliveBrickY + 45.0` and `paddle.y - 75.0` fulfills the requirement.
5. **Test Safety Link**:
   From Obs 5, all existing tests assert lower bounds ($v_x > 0$, $v_x > 0.5$, $v_x > 0.8$) and large distances for slingshot exit ($d \approx 305\text{ px} > 168\text{ px}$). Strengthening the pull will preserve 100% pass rate of the existing 92 tests while enabling new strict tests for R3 acceptance criteria.

---

## 3. Caveats

- **No caveats**: All 4 areas specified in the dispatch objective (physics, canvas rendering, power-up handling, test suite) were thoroughly examined with exact line numbers and code paths verified.
- **Assumptions**: The 9.0s duration of `PowerUpType.vortex` in `powerup.dart` matches the spawned `BlackHole.timeLeft`. If the implementer prefers a distinct duration, `bh.timeLeft` can be parameterized.

---

## 4. Conclusion

The implementation of R3 requires edits across 3 existing source files and adding new unit/widget tests in 1 test file:

1. **`lib/models/black_hole.dart`**:
   - Add `import 'dart:math';`
   - Expose helper getter `double get maxInfluenceDist => max(135.0, radius * (isVortexTrap ? 6.5 : (isSupercharged ? 6.0 : 5.5)));`
2. **`lib/engine/game_controller.dart`**:
   - In `_updateBalls`:
     - Calculate `maxInfluenceDist = bh.maxInfluenceDist`.
     - Use `final falloff = pow(proximity, 0.85);`.
     - Use `basePull = (bh.isVortexTrap ? 850.0 : (bh.isSupercharged ? 680.0 : 520.0)) * (bh.radius / 26.0);`.
     - Use `spinDrag = (bh.isVortexTrap ? 120.0 : (bh.isSupercharged ? 160.0 : 85.0)) * falloff;`.
   - In `applyPowerUp`:
     - Add `case PowerUpType.vortex:` to spawn an active `BlackHole` in the open play zone between bricks and the paddle.
3. **`lib/ui/game_canvas.dart`**:
   - In `_drawBlackHoles`:
     - Draw animated outer gravitational boundary ring matching `bh.maxInfluenceDist`.
     - Draw inward-spiraling gravity waves contracting from `bh.maxInfluenceDist` to the event horizon.
4. **`test/game_test.dart`**:
   - Add test cases verifying:
     - `maxInfluenceDist >= 135.0` for all black holes ($r=20\dots 34$).
     - High-speed ball deflection angle / velocity change $> 5^\circ$ across field.
     - `PowerUpType.vortex` spawns an active `BlackHole` in open play zone.

---

## 5. Verification Method

To independently verify after implementation:
1. **Run Unit & Widget Tests**:
   ```pwsh
   flutter test test/game_test.dart
   ```
   *Expected outcome*: 100% tests pass (92 existing + new R3 tests).
2. **Run Linter / Static Analysis**:
   ```pwsh
   flutter analyze
   ```
   *Expected outcome*: `No issues found!`.
3. **Files to Inspect**:
   - `lib/models/black_hole.dart` (getter `maxInfluenceDist`)
   - `lib/engine/game_controller.dart` (`_updateBalls`, `applyPowerUp`)
   - `lib/ui/game_canvas.dart` (`_drawBlackHoles`)
   - `test/game_test.dart` (new test cases for R3)
4. **Invalidation Conditions**:
   - Any black hole having `maxInfluenceDist < 135.0`.
   - `flutter analyze` emitting warnings or errors.
   - Any test failure in `flutter test`.
   - Collecting `PowerUpType.vortex` failing to add a `BlackHole` to `controller.blackHoles`.
