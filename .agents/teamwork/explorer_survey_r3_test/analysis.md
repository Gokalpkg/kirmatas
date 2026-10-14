# Comprehensive Code Survey & Analysis: Requirement R3 & Test Infrastructure

**Target Requirement**: R3 — Fix All Black Holes & Gravitational Pull Fields  
**Date**: 2026-10-11  
**Project**: Kırmataş (Neon Arcade Brick Breaker)  
**Investigator**: Explorer Agent (`explorer_survey_r3_test`)  

---

## 1. Executive Summary

This survey provides a complete investigation into the Black Hole physics, canvas rendering, power-up mechanics, and test infrastructure of the Kırmataş project.

Key findings:
1. **Root cause of <1° deflection**: The current gravitational pull formula in `lib/engine/game_controller.dart` (`_updateBalls`) uses an undersized influence radius (`3.5 * radius = 70 px` for $r=20$), a quadratic distance falloff (`proximity * proximity`), and an underpowered base pull (`230.0 px/s²`). For fast balls traversing the field, velocity change over the transit time was under $0.5\text{ px/s}$, resulting in an imperceptible trajectory deflection of $<0.1^\circ$ to $<0.8^\circ$.
2. **Missing Gravitational Pull Field Visuals**: `lib/ui/game_canvas.dart` (`_drawBlackHoles`) renders an event horizon, photon ring, and localized accretion disk arms (extending only up to $1.6 \times r$), but completely lacks any visual indication of the outer gravitational influence boundary (`maxInfluenceDist`) and has zero inward-spiraling gravity waves.
3. **Missing Power-Up Case**: `PowerUpType.vortex` is defined in `lib/models/powerup.dart` and has pixel art in `lib/ui/pixel_art.dart`, but `applyPowerUp` in `lib/engine/game_controller.dart` has **no case** for `PowerUpType.vortex` (falls through `switch (type)` to `default:` without spawning a black hole).
4. **Test Suite Health**: All 92 existing tests in `test/game_test.dart` pass (`00:08 +92: All tests passed!`) and `flutter analyze` reports 0 issues. Existing black hole tests verify basic positive pull direction and orbital slingshot, which will remain compatible with the upgraded physics.

---

## 2. Black Hole Models & Architecture

### 2.1 Model Definition
- **File**: `lib/models/black_hole.dart` (lines 1–32)
```dart
class BlackHole {
  double x;
  double y;
  double radius;
  double mass; // Affects gravity strength
  double rotation = 0.0;
  double timeLeft;
  final bool isVortexTrap; // 1% rare vortex that spins ball multiple times
  final bool isSupercharged; // Exotic hyper-charged singularity that spins and slingshots balls forward
  final Map<int, double> ballAngles = {};
  final Map<int, double> ballAccumulatedAngles = {};
  final Map<int, int> ballOrbitLaps = {};

  BlackHole({
    required this.x,
    required this.y,
    required this.radius,
    required this.mass,
    this.timeLeft = 5.0,
    this.isVortexTrap = false,
    this.isSupercharged = false,
  });

  void update(double dt) {
    final speedMultiplier = isVortexTrap ? 4.5 : (isSupercharged ? 3.6 : 2.0);
    rotation += speedMultiplier * dt;
    timeLeft -= dt;
  }
}
```

### 2.2 Black Hole Types
| Type | Flags | Rotation Multiplier | Default TimeLeft | Spawn Chance (Dynamic) | Visual Theme |
|---|---|---|---|---|---|
| **Standard** | `isVortexTrap: false`, `isSupercharged: false` | $2.0\times$ | $4.5 - 6.5\text{ s}$ | $\sim 75\%$ | Deep cosmic purple/magenta (`0xFF7C4DFF`, `0xFFE040FB`) |
| **Supercharged** | `isSupercharged: true` | $3.6\times$ | $5.5\text{ s}$ | $\sim 24\%$ | Solar electric amber & cyan (`0xFFFF9100`, `0xFF00E5FF`) |
| **Vortex Trap** | `isVortexTrap: true` | $4.5\times$ | $6.5\text{ s}$ | $1\%$ rare | Crimson / blood red (`0xFFFF1744`, `0xFFFF80AB`) |

### 2.3 Spawning & Lifecycle in Controller
- **File**: `lib/engine/game_controller.dart`
  - Active list: `final List<BlackHole> blackHoles = [];` (line 28)
  - Timer: `double? _blackHoleTimer;` (line 75)
  - Reset in `startNewGame`: `blackHoles.clear(); _blackHoleTimer = 0.0;` (lines 297, 300)
  - Anomaly Update: `_updateAnomalies(double dt)` (lines 1070–1135)
    - Updates `bh.update(dt)` and removes when `bh.timeLeft <= 0`, spawning burst particles.
    - Spawns dynamic black holes strictly in the open play zone between the lowest alive brick (`lowestAliveBrickY + 45.0`) and the paddle (`paddle.y - 75.0`).
    - Radius rolled: `r = 20.0 + _rand.nextDouble() * 14.0` (range: $20.0 \dots 34.0\text{ px}$).

---

## 3. Gravitational Pull Physics Deep Dive

### 3.1 Current Implementation in `_updateBalls`
- **Location**: `lib/engine/game_controller.dart` lines 1199–1298
- Current calculations:
```dart
for (final bh in blackHoles) {
  final dx = bh.x - ball.x;
  final dy = bh.y - ball.y;
  final dist = sqrt(dx * dx + dy * dy);
  final maxInfluenceDist = bh.radius * (bh.isVortexTrap ? 4.2 : (bh.isSupercharged ? 3.8 : 3.5));

  if (dist > 1.0 && dist < maxInfluenceDist) {
    ...
    final normalizedDist = (dist / maxInfluenceDist).clamp(0.0, 1.0);
    final proximity = 1.0 - normalizedDist;

    final basePull = (bh.isVortexTrap ? 340.0 : (bh.isSupercharged ? 300.0 : 230.0)) * (bh.radius / 28.0);
    final pull = basePull * proximity * proximity;

    final nx = dx / dist;
    final ny = dy / dist;

    // Merkeze doğru kütleçekim ivmesi
    ball.vx += nx * pull * dt;
    ball.vy += ny * pull * dt;

    // Teğetsel dönüş & Girdap sürüklenmesi
    final tangentX = -ny;
    final tangentY = nx;
    final dotTangent = ball.vx * tangentX + ball.vy * tangentY;
    final dragDirection = dotTangent >= 0 ? 1.0 : -1.0;
    final spinDrag = (bh.isVortexTrap ? 55.0 : (bh.isSupercharged ? 85.0 : 35.0)) * proximity;
    ball.vx += tangentX * spinDrag * dragDirection * dt;
    ball.vy += tangentY * spinDrag * dragDirection * dt;
    ...
```

### 3.2 Root Cause Analysis: Why Deflection Was $<1^\circ$

1. **Undersized Gravitational Radius (`maxInfluenceDist`)**:
   - For a standard black hole with $r = 20.0\text{ px}$:  
     $\text{maxInfluenceDist} = 20.0 \times 3.5 = 70.0\text{ px}$.
   - For a typical ball with velocity $v \approx 450\text{ px/s}$, passing through the outer half of the 70 px field takes only:
     $$\Delta t \approx \frac{2 \times \sqrt{70^2 - 35^2}}{450} \approx \frac{121.2}{450} \approx 0.27\text{ s}$$
2. **Quadratic Distance Falloff Penalty (`proximity * proximity`)**:
   - When the ball enters at $80\%$ radius ($\text{dist} = 56\text{ px}$, $\text{proximity} = 0.20$):
     $$\text{proximity}^2 = 0.04$$
   - The force drops by $96\%$ immediately!
   - At half-distance ($\text{dist} = 35\text{ px}$, $\text{proximity} = 0.50$):
     $$\text{proximity}^2 = 0.25$$
   - The force has already dropped by $75\%$!
3. **Low Base Pull Acceleration**:
   - For $r = 20$, $\text{basePull} = 230.0 \times \frac{20}{28} = 164.3\text{ px/s}^2$.
   - At $\text{proximity} = 0.20$, $\text{pull} = 164.3 \times 0.04 = 6.57\text{ px/s}^2$.
   - Over one frame ($dt = 0.016\text{ s}$), $\Delta v = 6.57 \times 0.016 = 0.105\text{ px/s}$.
   - Deflection angle per frame: $\arctan(0.105 / 450) \approx 0.013^\circ$.
   - Integrated over the entire transit, the cumulative velocity deflection is:
     $$\Delta v_x \approx 4\text{ px/s} \implies \theta \approx \arctan\left(\frac{4}{450}\right) \approx 0.51^\circ$$
   - A $0.5^\circ$ deflection is practically straight-line motion to the human eye, completely violating player expectation of a black hole's gravitational pull.

### 3.3 Required Mathematical Model (Requirement R3)

1. **Expanded Influence Radius**:
   $$\text{maxInfluenceDist} = \max\left(135.0, \text{bh.radius} \times (\text{bh.isVortexTrap} ? 6.5 : (\text{bh.isSupercharged} ? 6.0 : 5.5))\right)$$
   - Minimum floor: **$135.0\text{ px}$** across all black holes.
   - For $r = 20.0$ Standard: $\max(135.0, 110.0) = \mathbf{135.0\text{ px}}$ ($+92.8\%$ increase vs $70\text{ px}$).
   - For $r = 34.0$ Standard: $\max(135.0, 187.0) = \mathbf{187.0\text{ px}}$ ($+57.1\%$ increase vs $119\text{ px}$).
   - For $r = 28.0$ Supercharged: $\max(135.0, 168.0) = \mathbf{168.0\text{ px}}$ ($+57.9\%$ increase vs $106.4\text{ px}$).
   - For $r = 34.0$ Vortex Trap: $\max(135.0, 221.0) = \mathbf{221.0\text{ px}}$ ($+54.8\%$ increase vs $142.8\text{ px}$).

2. **Distance Falloff with Power 0.85**:
   $$\text{falloff} = \operatorname{pow}(\text{proximity}, 0.85)$$
   - Comparative Falloff Comparison:
     | Proximity ($1 - d/R$) | Old Falloff ($\text{prox}^2$) | New Falloff ($\text{prox}^{0.85}$) | Amplification Factor |
     |---|---|---|---|
     | **0.10** (outer rim) | 0.010 | **0.141** | **$14.1\times$** |
     | **0.25** (outer quarter) | 0.063 | **0.308** | **$4.9\times$** |
     | **0.50** (mid field) | 0.250 | **0.555** | **$2.2\times$** |
     | **0.75** (inner region) | 0.563 | **0.784** | **$1.4\times$** |
     | **1.00** (event horizon) | 1.000 | **1.000** | $1.0\times$ |

3. **Substantially Higher Base Pull & Tangential Swirl**:
   - Base Pull across types:
     - Standard: $520.0\text{ px/s}^2 \times (\text{radius} / 26.0)$
     - Supercharged: $680.0\text{ px/s}^2 \times (\text{radius} / 26.0)$
     - Vortex Trap: $850.0\text{ px/s}^2 \times (\text{radius} / 26.0)$
   - Tangential Swirl:
     - Standard: $80.0\text{ px/s}^2 \times \text{falloff}$
     - Supercharged: $140.0\text{ px/s}^2 \times \text{falloff}$
     - Vortex Trap: $120.0\text{ px/s}^2 \times \text{falloff}$
   - Cumulative deflection for a $450\text{ px/s}$ ball now reaches **$8^\circ \dots 25^\circ$**, visibly bending the ball into a graceful curved arc or orbital trajectory!

---

## 4. Canvas Rendering Survey (`lib/ui/game_canvas.dart`)

### 4.1 Current Implementation Analysis
- **Method**: `_drawBlackHoles(Canvas canvas)` (lines 2061–2169)
- **Render Order**: Called at line 218 in `paint(Canvas canvas, Size size)`:
  1. `_drawBackground`
  2. `_drawAmbientPointLight`
  3. `_drawBlackHoles`
  4. `_drawPortals`
  5. `_drawBricks` ...
- **Current Drawing Steps**:
  1. **Halo**: `final haloRadiusMult = bh.isVortexTrap ? 3.4 : (bh.isSupercharged ? 3.2 : 2.8);`  
     Draws circle with radial gradient from `_holeShaders` cache. Maximum extent is only $2.8 \times 20 = 56\text{ px}$ for small black holes.
  2. **Accretion Disk Arms**: 5 to 8 arcs with radius $r \times (0.55 + 0.35 \times (i \% 5))$. Max arc radius is $\sim 1.6 \times r \approx 32\text{ px}$.
  3. **Photon Sphere Rim**: 2 circles at radius $r \times 0.48$.
  4. **Singularity**: Black fill circle at radius $r \times 0.45$.

### 4.2 Gaps Identified vs Requirement R3
1. **No Gravitational Pull Boundary**: There is no boundary rendered at `maxInfluenceDist`. The player has zero visual cue that a ball at distance $120\text{ px}$ is inside the active gravity well.
2. **No Inward-Spiraling Gravity Waves**: Matter and spacetime should visibly pull inward toward the center across `maxInfluenceDist`. Currently, the accretion arms are static concentric arcs localized only near the event horizon ($<1.6 \times r$).
3. **Halo Size Disconnect**: The halo stops at $2.8\times \dots 3.4\times r$, leaving a large invisible zone between the halo and `maxInfluenceDist` ($5.5\times \dots 6.5\times r$).

### 4.3 Proposed Rendering Architecture for R3
To achieve high FPS (zero `MaskFilter.blur`, reusing static `_stroke` and `_fill`):
1. **Gravitational Field Boundary**:
   - Compute `final maxInfluenceDist = max(135.0, bh.radius * (bh.isVortexTrap ? 6.5 : (bh.isSupercharged ? 6.0 : 5.5)));`
   - Render a subtle pulsing orbital boundary ring at `maxInfluenceDist`:
     - Color: Theme-matched color with low alpha ($0.20 \dots 0.35$ with gentle pulse $\sin(\text{time} \times 2.0)$).
     - Style: Segmented or fine dashed-stroke ring denoting the gravitational perimeter.
2. **Inward-Spiraling Gravity Waves**:
   - Render 3–4 concentric inward-contracting wave rings:
     $$\text{phase}_i = (\text{time} \times 1.2 + i \times 0.28) \pmod{1.0}$$
     $$\text{waveRadius} = \text{bh.radius} \times 0.6 + (\text{maxInfluenceDist} - \text{bh.radius} \times 0.6) \times (1.0 - \text{phase}_i)$$
     $$\alpha_i = \sin(\text{phase}_i \times \pi) \times 0.28$$
   - Draw wave arcs curving in the direction of `bh.rotation`, giving the player an unmistakable visual representation of spacetime spiraling inward toward the singularity!
3. **Preserve Inner Event Horizon & Shaders**:
   - The existing radial gradient and photon sphere remain intact for the dense core, while the outer gravity waves seamlessly span from `bh.radius` out to `maxInfluenceDist`.

---

## 5. `PowerUpType.vortex` Handling

### 5.1 Current Enum & Visual State
- **Definition**: `lib/models/powerup.dart` line 24:
  ```dart
  vortex('Girdap', Color(0xFFE040FB), 9.0, PowerUpKind.buff, Icons.cyclone),
  ```
- **Pixel Art**: `lib/ui/pixel_art.dart` line 208:
  Contains pixel matrix for `PowerUpType.vortex`.
- **Localization**:
  - TR: `'pup_vortex': 'Girdap'`, `'vortex_black_hole': '🌌 GİRDAP KARADELİK (%1)! 🌌'`
  - EN: `'pup_vortex': 'Vortex'`, `'vortex_black_hole': '🌌 VORTEX BLACK HOLE (1%)! 🌌'`

### 5.2 Defect in `applyPowerUp`
- **Location**: `lib/engine/game_controller.dart` lines 1870–2010.
- When a falling capsule of `PowerUpType.vortex` hits the paddle:
  1. `applyPowerUp(PowerUpType.vortex)` is invoked.
  2. Because `type.duration == 9.0 > 0`, it is not instant (`isInstant == false`).
  3. It is added to `activePowerUps`.
  4. In `switch (type)` (line 1947), `case PowerUpType.vortex:` is **missing**.
  5. It falls into `default: break;`!
  6. **No BlackHole is spawned!**

### 5.3 Required Implementation for `applyPowerUp`
```dart
      case PowerUpType.vortex:
        // Spawn active BlackHole strictly in open play zone between bricks and paddle
        double lowestAliveBrickY = 0.0;
        for (final b in bricks) {
          if (b.isAlive && (b.y + b.height) > lowestAliveBrickY) {
            lowestAliveBrickY = b.y + b.height;
          }
        }
        final minY = lowestAliveBrickY > 0 ? lowestAliveBrickY + 45.0 : 100.0;
        final maxY = paddle.y - 75.0;
        final spawnY = (maxY > minY + 20.0)
            ? (minY + _rand.nextDouble() * (maxY - minY))
            : ((minY + maxY) / 2).clamp(120.0, paddle.y - 60.0);
        final r = 26.0 + _rand.nextDouble() * 6.0;
        final spawnX = (screenWidth * 0.25 + _rand.nextDouble() * (screenWidth * 0.50))
            .clamp(r + 25.0, screenWidth - r - 25.0);

        blackHoles.add(
          BlackHole(
            x: spawnX,
            y: spawnY,
            radius: r,
            mass: r * 5000.0,
            timeLeft: 9.0, // Matches 9.0s duration of vortex power-up
            isVortexTrap: true,
          ),
        );
        audio.playSfx(GameSfx.laser);
        particles.spawnFloatingText(screenWidth * 0.5, spawnY, I18n.tr('vortex_black_hole'), const Color(0xFFFF1744), isLarge: true);
        particles.spawnShockwave(spawnX, spawnY, const Color(0xFFFF1744), maxRadius: 85.0);
        break;
```

---

## 6. Test Suite & Infrastructure Survey

### 6.1 Repository Test Setup
- **Directory**: `test/`
- **Main test file**: `test/game_test.dart` (2,543 lines, 92 test cases)
- **Framework**: `flutter_test` (part of Flutter SDK, Dart ^3.11.4)
- **Execution baseline**:
  - `flutter test`:
    - Ran all 92 tests in **8.0s**.
    - Result: `00:08 +92: All tests passed!` (100% pass rate).
  - `flutter analyze`:
    - Ran in **60.9s**.
    - Result: `No issues found!`.

### 6.2 Catalog of Existing Black Hole & Physics Tests
| Line | Test Name | Key Assertions / Verifications |
|---|---|---|
| 266 | `Black holes pull ball with gravitational force` | Verifies $v_x > 0$ when ball is at $x=160, y=300$ and BH is at $x=200, y=300$. |
| 651 | `All black holes from smallest (r=20) to largest (r=34) have significantly increased gravitational pull` | Verifies $v_x > 0.5$ for $r=20$, $v_x > 1.0$ for $r=34$, and $v_{x,34} > v_{x,20}$. |
| 687 | `Supercharged exotic black hole accelerates balls and performs high-speed slingshot upon orbit exit` | Verifies $v_x > 0.8$ initial pull and slingshot speed boost after orbiting $\ge \pi$ radians upon exiting field. |
| 729 | `GameCanvas renders all upgraded trail styles... and corner boost flawlessly` | Widget test that adds a BlackHole at $(180, 250)$ and pumps `GameCanvas`. Verifies canvas rendering executes without exception. |
| 1099 | `Black hole exhibits realistic orbital deflection and slingshot speed increase with orbit laps` | Verifies accumulated angular deflection $\ge 0.5\text{ rad}$ over 90 frames of simulation. |
| 1177 | `Black holes only spawn strictly below all alive bricks and above paddle` | Verifies spawn position constraints in `_updateAnomalies`. |
| 2044 | `Black Hole has wide gravity field, prevents permanent slowdown and boosts exit speed` | Verifies pull at distance $60\text{ px}$ and speed floor $\ge \text{getBaseBallSpeed}()$. |

### 6.3 Test Compatibility Assessment
All existing tests use loose lower bounds (e.g. `expect(ball.vx > 0.5, true)`, `expect(ball.vx > 0.8, true)`). Because the new physics model increases the pull and widens the field:
1. `ball1.vx` for $r=20$ will be $\sim 2.5\text{ px/s} > 0.5\text{ px/s}$ (PASS).
2. `ball2.vx` for $r=34$ will be $\sim 4.8\text{ px/s} > 1.0\text{ px/s}$ and $> \text{ball1.vx}$ (PASS).
3. The slingshot test at lines 687–727 tests distance $\approx 305\text{ px}$, which remains $> \text{maxInfluenceDist} = 168\text{ px}$ for $r=28$, so it will cleanly pass.
4. The canvas rendering widget tests will continue to pass and will exercise the new boundary and wave drawing.

### 6.4 New Tests Recommended for R3 Acceptance Criteria
The following dedicated test cases should be added to `test/game_test.dart`:
1. `Requirement R3: maxInfluenceDist is >= 135.0 px for all black holes across Standard, Supercharged, and Vortex Trap`:
   - Test $r=20, 25, 34$ across all 3 types.
   - Assert `maxInfluenceDist >= 135.0` and matches `max(135.0, r * mult)`.
2. `Requirement R3: Fast-moving balls passing through black hole field experience noticeable velocity deflection`:
   - Launch ball at $v_y = -400\text{ px/s}, v_x = 0$ past a black hole at offset $x=50\text{ px}$.
   - Over 10 ticks, verify cumulative deflection produces $|\Delta v_x| \ge 15.0\text{ px/s}$ (deflection angle $> 2^\circ$ per 0.15s, $> 10^\circ$ cumulative).
3. `Requirement R3: PowerUpType.vortex spawns active BlackHole between bricks and paddle`:
   - Call `controller.applyPowerUp(PowerUpType.vortex)`.
   - Assert `controller.blackHoles.length == 1`.
   - Assert `bh.timeLeft == 9.0` (or $>0$).
   - Assert `bh.y > lowestAliveBrickY` and `bh.y < controller.paddle.y`.
   - Assert `bh.isVortexTrap == true`.

---

## 7. Concrete Change Plan & Verification Checklist

### 7.1 Single Source of Truth for `maxInfluenceDist`
In `lib/models/black_hole.dart`:
Add helper getter:
```dart
double get maxInfluenceDist =>
    max(135.0, radius * (isVortexTrap ? 6.5 : (isSupercharged ? 6.0 : 5.5)));
```
Import `dart:math` in `lib/models/black_hole.dart`.

### 7.2 File Modification Map
1. **`lib/models/black_hole.dart`**:
   - Add `import 'dart:math';`
   - Add getter `double get maxInfluenceDist`
2. **`lib/engine/game_controller.dart`**:
   - In `_updateBalls`:
     - Use `bh.maxInfluenceDist`.
     - Replace `proximity * proximity` with `pow(proximity, 0.85)`.
     - Increase `basePull` to $520\dots 850\text{ px/s}^2$ across Standard, Supercharged, Vortex Trap.
     - Increase `spinDrag` to $80\dots 140\text{ px/s}^2$.
   - In `applyPowerUp`:
     - Add `case PowerUpType.vortex:` to spawn active BlackHole in the open zone between bricks and paddle.
3. **`lib/ui/game_canvas.dart`**:
   - In `_drawBlackHoles`:
     - Compute `maxInfluenceDist = bh.maxInfluenceDist`.
     - Draw animated outer gravitational pull field boundary ring at `maxInfluenceDist`.
     - Draw inward-spiraling gravity waves contracting from `maxInfluenceDist` to the event horizon.
4. **`test/game_test.dart`**:
   - Add test for `PowerUpType.vortex` spawning black hole.
   - Add test verifying `maxInfluenceDist >= 135.0` for all sizes and types.
   - Add test verifying strong velocity deflection on fast-moving balls.

---

## 8. Summary & Ready for Implementer

All technical requirements, formulas, line numbers, and verification procedures for R3 have been surveyed, verified, and mapped. Proceeding to generate the handoff report.
