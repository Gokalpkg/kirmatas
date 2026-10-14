# In-Depth Code Survey: Requirement R2 — Golden-Flame "Yakıcı Top"

## 1. Executive Summary

Requirement R2 unifies and transforms the existing Piercing (`PowerUpType.pierce`) and Fireball (`PowerUpType.fireball`) power-ups into the unified **"🔥 YAKICI TOP!"** (**"🔥 SEARING BALL!"** in English). 
Historically, Fireball melted steel bricks and displayed a 6-pointed Claude-style starburst polygon (`claudeStar` / `innerStar`) in `lib/ui/game_canvas.dart`, whereas Pierce only bypassed regular brick reflection without melting steel bricks and lacked distinct canvas visuals.

This survey establishes the complete blueprint to:
1. **Unify Mechanics & State**: Ensure both `PowerUpType.pierce` and `PowerUpType.fireball` trigger the dual searing state (`isFireball = true` and `isPierce = true`), pierces all regular breakable bricks, and melts steel bricks instantly upon impact.
2. **Remove Claude Starburst Visuals**: Completely excise `claudeStar`, `innerStar`, starburst polygon vertices, and scarlet `#FFFF1744` outer corona from `lib/ui/game_canvas.dart` (lines 2960–3048).
3. **Implement High-FPS Golden-Flame "Yakıcı Top" Visuals**:
   - Zero `MaskFilter.blur` (preserving 60/120 FPS performance).
   - Multi-layered swirling golden-amber (`#FFB300`, `#FFA000`) and solar-orange (`#FF6D00`, `#FF8F00`) organic flame tongues and fire petals curling opposite the velocity vector (`atan2(-vy, -vx)`).
   - Molten gold armored power-up core with a rotating golden solar ring/crest inside the sphere (lines 3320–3365).
   - Strictly distinct from Corner Shot (Köşe Vuruşu), which uses straight supersonic Mach jet cones, shock diamonds, bow shock arcs, and twin flanking nozzles.
4. **Update Capsules & PixelArt Icons**: Upgrade `PowerUpType.pierce` and `PowerUpType.fireball` in `lib/ui/pixel_art.dart` so both capsules display the golden-flame theme instead of cyan arrows.
5. **Localization & Floating Banners**: Update `lib/engine/i18n.dart` and `lib/models/powerup.dart` to display **"🔥 YAKICI TOP!"** (TR) / **"🔥 SEARING BALL!"** (EN).

---

## 2. Power-Up Models & Engine Mechanics

### 2.1 Model Definitions (`lib/models/powerup.dart`)
- **`PowerUpType` enum**:
  ```dart
  // Lines 12 & 18:
  fireball('Ateş', Color(0xFFFF6D00), 4.5, PowerUpKind.buff, Icons.local_fire_department),
  pierce('Delici', Color(0xFF00E5FF), 6.0, PowerUpKind.buff, Icons.arrow_upward),
  ```
  - `fireball` currently has base duration `4.5`s and color `Color(0xFFFF6D00)`.
  - `pierce` currently has base duration `6.0`s and color `Color(0xFF00E5FF)` (cyan arrow).
  - Both use `PowerUpType.label` which calls `I18n.tr('pup_$name')`.
  - **Proposed Unification**:
    - Update `pierce` color to golden-amber / solar orange (`Color(0xFFFF9100)` or `Color(0xFFFFB300)`).
    - Update `pierce` icon to `Icons.local_fire_department` or `Icons.whatshot`.
    - Both maintain valid durations (or standardize to 5.0s / 6.0s).

### 2.2 Localization (`lib/engine/i18n.dart`)
- `pup_fireball` and `pup_pierce` appear across 9 language tables:
  - English (`en`, lines 262, 268):
    - Current: `'pup_fireball': 'Fireball'`, `'pup_pierce': 'Piercing Ball'`
    - Proposed: Both unified as `'🔥 SEARING BALL!'`
  - Turkish (`tr`, lines 551, 557):
    - Current: `'pup_fireball': 'Ateş Topu'`, `'pup_pierce': 'Delici Top'`
    - Proposed: Both unified as `'🔥 YAKICI TOP!'`
  - Other supported languages (`fr`, `de`, `es`, `it`, `ru`, `ko`, `ja`):
    - Harmonize with the fiery searing ball name (e.g. `'🔥 Balle Brûlante!'`, `'🔥 Sengball!'`, etc.).

### 2.3 Game Controller State & Mechanics (`lib/engine/game_controller.dart`)
1. **Activation (`applyPowerUp`, lines 1973–1987)**:
   ```dart
   case PowerUpType.fireball:
   case PowerUpType.pierce:
     for (final b in balls) {
       b.isFireball = true;
       b.isPierce = true;
     }
     break;
   ```
   Both power-ups must activate both `b.isFireball = true` and `b.isPierce = true`.
2. **Deactivation (`_removePowerUp`, lines 2035–2049)**:
   Currently, each case independently sets its respective flag to `false`.
   **Critical Edge Case**: If the player collects `fireball` and then `pierce`, when `fireball` expires, the ball must NOT lose `isFireball`/`isPierce` if `pierce` is still active!
   ```dart
   case PowerUpType.fireball:
   case PowerUpType.pierce:
     final stillActive = activePowerUps.any((p) => p.type == PowerUpType.fireball || p.type == PowerUpType.pierce);
     if (!stillActive) {
       for (final b in balls) {
         b.isFireball = false;
         b.isPierce = false;
       }
     }
     break;
   ```
3. **Collision & Steel Brick Melting (`_hitBrick`, lines 1654–1664)**:
   ```dart
   if (b.isSteel) {
     if (ball != null && (ball.isFireball || ball.isPierce)) {
       // Yakıcı Top melts steel!
       _destroyBrick(b);
     } else {
       b.jelly = 1.0;
       particles.spawnBurst(b.x + b.width / 2, b.y + b.height / 2, Colors.grey, count: 6);
       audio.playSfx(GameSfx.steel);
     }
     return;
   }
   ```
   Now both `isFireball` and `isPierce` melt steel bricks.
4. **Collision Reflection Bypass (`_updateBalls`, line 1590)**:
   `if (!ball.isFireball && !ball.isPierce && !b.isTuft)`
   Already exists in line 1590, ensuring the ball pierces through regular breakable bricks without normal velocity reflection.
5. **Multi-Ball & Mirror Cloning (lines 1885–1899, 2076–2106)**:
   Ensure newly spawned split/cloned balls inherit `isFireball: hasYakici, isPierce: hasYakici`.
6. **Laser Combo (lines 780–785)**:
   `final hasFireball = balls.any((b) => b.isFireball || b.isPierce);`
   Ensures Laser + Yakıcı Top triggers flame triple lasers.
7. **Trail Embers (lines 1151–1155)**:
   Replace scarlet burst (`Color(0xFFFF1744)`) with golden burn embers:
   ```dart
   if (ball.isFireball || ball.isPierce) {
     if (_rand.nextDouble() < 0.35) {
       particles.spawnBurnEmber(ball.x, ball.y, color: const Color(0xFFFFB300));
     }
   }
   ```

---

## 3. Canvas Rendering in `lib/ui/game_canvas.dart`

### 3.1 Claude Starburst Removal
In `lib/ui/game_canvas.dart`:
- Lines 2960–3048:
  - Remove `final Path claudeStar = Path();` (outer 6-point starburst polygon).
  - Remove `final Path innerStar = Path();` (inner counter-rotating 6-point starburst).
  - Remove star vertices pips & diamond glints (lines 3034–3048).
  - Remove scarlet `#FFFF1744` heat corona circles.

### 3.2 High-FPS Golden-Flame "Yakıcı Top" Visual Architecture
The replacement visual must achieve three simultaneous goals:
1. **Zero `MaskFilter.blur`**: Use layered alpha geometries and anti-aliased path fills to guarantee 60/120 FPS without shader blur passes.
2. **Organic Swirling Flame Tongues / Fire Petals**:
   - Direction vector opposite velocity:
     ```dart
     final spd = ball.speed;
     final backAngle = (spd > 15.0) ? atan2(-ball.vy, -ball.vx) : (pi / 2);
     final backX = cos(backAngle);
     final backY = sin(backAngle);
     final perpX = -backY;
     final perpY = backX;
     ```
   - Multi-layered swirling flame petals curling backwards:
     - Outer Heat Shimmer: 2-stage radiant alpha circles (`Color(0xFFFF6D00)`, alpha `0.22`, `Color(0xFFFFB300)`, alpha `0.35`).
     - Organic Flame Tongues: 6 to 8 curling flame petals wrapped around the equator and curling backwards opposite the velocity vector using smooth quadratic Bezier paths (`quadraticBezierTo`), undulating with `sin(time * 22.0 + index * 1.05)`.
     - 3-tier color graduation:
       - Base tier: Solar orange (`Color(0xFFFF6D00)`)
       - Mid tier: Radiant golden amber (`Color(0xFFFFB300)`)
       - Core tier: Incandescent white-gold (`Color(0xFFFFF9C4)`)
3. **Molten Gold Armored Power-Up Core with Rotating Solar Ring/Crest Inside Sphere** (lines 3320–3365):
   - Replace the plain orange core circle with:
     - Molten gold armored power-up core base (`Color(0xFFFFB300)` / `Color(0xFFFF8F00)`).
     - Concentric rotating golden solar ring/crest: 8 solar corona crest teeth / radiant solar rays rotating at `time * 2.8`.
     - Blinding white-gold molten center (`Color(0xFFFFF8E1)` and `Colors.white`).
     - Dual specular reflections.

### 3.3 Distinction from Corner Shot Directional Jet
| Attribute | Corner Shot (Köşe Vuruşu) | Yakıcı Top (Golden-Flame) |
|---|---|---|
| **Theme** | Supersonic aerodynamic Mach jet | Blazing organic solar flame / fire |
| **Front** | Curved bow shock arc + swept Mach shock lines slicing backwards | Smooth radiant solar corona |
| **Geometry** | Straight rigid cones (`lineTo`), sharp triangular exhaust, Mach shock diamonds | Curved Bezier flame petals & curling organic fire tongues |
| **Flanking** | Rigid twin nozzles at ±22° | Swirling petal curls undulating with sine waves |
| **Core** | Standard ball skin core or white flash | Molten gold armored core + rotating 8-ray solar crest ring |
| **Colors** | Ball/Trail skin dependent (or rainbow) | Dedicated solar gold, amber, and flame orange palette |

### 3.4 Trail Updates (`lib/ui/game_canvas.dart`)
- Lines 2759–2805:
  - Pass 1 (Outer): Change from scarlet `0xFFFF1744` to solar amber/orange `Color(0xFFFF6D00)`.
  - Pass 2 (Mid): Radiant golden amber `Color(0xFFFFB300)`.
  - Pass 3 (Core): Solar gold `Color(0xFFFFEB3B)`.
  - Pass 4 (Needle): Incandescent white needle `Colors.white`.
- Line 271 (Ambient Point Light):
  - Change `const Color(0xFFFF1744)` to `const Color(0xFFFF9800)` / `Color(0xFFFFB300)`.

---

## 4. Capsule & PixelArt Rendering

### 4.1 PixelArt Matrices (`lib/ui/pixel_art.dart`)
- Currently:
  - `PowerUpType.fireball` is an 8x8 flame matrix with deep orange / white pixels.
  - `PowerUpType.pierce` is an 8x8 cyan arrow pointing upward:
    ```dart
    PowerUpType.pierce: [
      [0, 0, 0, 1, 1, 0, 0, 0],
      [0, 0, 1, 2, 2, 1, 0, 0],
      [0, 1, 1, 2, 2, 1, 1, 0],
      [1, 1, 0, 2, 2, 0, 1, 1],
      [0, 0, 0, 2, 2, 0, 0, 0],
      [0, 0, 0, 2, 2, 0, 0, 0],
      [0, 0, 0, 1, 1, 0, 0, 0],
      [0, 0, 0, 0, 0, 0, 0, 0],
    ],
    ```
- **Update**:
  - Update `PowerUpType.pierce` matrix to represent a blazing golden flame / solar flame motif identical or aligned with the golden-flame theme.
  - Update `PowerUpType.pierce` color to golden amber (`Color(0xFFFF9100)` or `Color(0xFFFFB300)`).
  - In `PixelArt.draw`, the tile background border and outer aura will glow with the new golden-flame color.

### 4.2 Capsule Asset Fallback & Rendering (`lib/ui/game_canvas.dart` line 3873 & `lib/engine/asset_cache.dart`)
- `_drawCapsules`:
  - When `cap.type == PowerUpType.pierce` or `PowerUpType.fireball`:
    - If `AssetCache.getSkillImage(cap.type)` is loaded, draw it.
    - If `pierce.png` is an old cyan arrow asset, map `PowerUpType.pierce` to use `fireball.png` in `AssetCache.getSkillImage` or update both to the golden flame asset so in-game falling capsules display the golden flame icon.

---

## 5. Existing Tests & Verification Plan

### 5.1 Existing Tests in `test/game_test.dart`
- **Line 78**: `All 24 powerups exist and have valid kinds and labels`
  - Asserts 24 powerups, non-empty labels, duration >= 0. (Passes with new labels).
- **Line 160**: `Corner boosted ball does not melt steel, but actual Fireball does`
  - Asserts `steelBrick.isAlive == false` after applying `fireball`.
- **Line 311**: `Multi-ball split preserves fireball, bomb, and pierce flags`
  - Asserts `first.isFireball == true`, `first.isPierce == true`, and split balls inherit both.
- **Line 335**: `Mirror powerup preserves active ball powerups`
  - Asserts mirror ball inherits `isFireball == true`.
- **Line 578**: `GameCanvas renders without exception with damaged bricks, fireball, and corner boost balls`
  - Renders `Ball(isFireball: true)` in `GameCanvas`.

### 5.2 Required New Test Coverage
1. **Pierce Melts Steel**: Verify `PowerUpType.pierce` melts `Brick(isSteel: true)`.
2. **Unified State Activation**: Verify `applyPowerUp(PowerUpType.pierce)` sets both `isPierce = true` and `isFireball = true`.
3. **Banner / Display Label**: Verify `PowerUpType.pierce.label` and `PowerUpType.fireball.label` equal `"🔥 YAKICI TOP!"` in Turkish and `"🔥 SEARING BALL!"` in English.
4. **Dual Power-Up Expiry Safety**: Verify collecting `fireball` followed by `pierce` does not clear the flaming state when `fireball` expires.
5. **GameCanvas Rendering Validation**: Verify `GameCanvas` renders both stationary and moving Yakıcı Top balls with zero exceptions and zero `claudeStar` polygons.
