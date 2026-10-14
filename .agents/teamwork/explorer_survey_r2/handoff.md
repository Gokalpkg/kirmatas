# Handoff Report: Requirement R2 — Golden-Flame "Yakıcı Top" Survey

## 1. Observation

Direct code observations with exact line numbers and quotations:

### A. Claude Starburst in `lib/ui/game_canvas.dart`
- **Lines 2960–3048**:
  ```dart
  if (isFireball) {
    // === CAPSULE FIREBALL: Radiant Claude-Style Starburst & Molten Star Flare (ZERO BLUR LAG) ===
    final flick = 0.72 + 0.28 * sin(time * 26);
    final starRot1 = time * 3.8;
    final starRot2 = -time * 4.6;
    ...
    // 2. Rotating 6-Point Claude Starburst Polygon (Outer Fiery Geometry)
    const int starPoints = 6;
    final double outerR = ball.radius * (2.25 + 0.35 * flick);
    final double innerR = ball.radius * (0.95 + 0.15 * flick);

    final Path claudeStar = Path();
    for (int i = 0; i < starPoints * 2; i++) {
      final double angle = starRot1 + i * (pi / starPoints);
      final double r = (i % 2 == 0) ? outerR : innerR;
      final double px = cos(angle) * r;
      final double py = sin(angle) * r;
      if (i == 0) {
        claudeStar.moveTo(px, py);
      } else {
        claudeStar.lineTo(px, py);
      }
    }
    claudeStar.close();
    ...
    // 3. Counter-Rotating Inner 6-Point Claude Starburst Glint (Pure White-Gold Shimmer)
    final double innerOuterR = ball.radius * (1.55 + 0.22 * flick);
    final double innerInnerR = ball.radius * 0.65;
    final Path innerStar = Path();
    ...
    // 4. Sparkling Stellar Pips on Star Vertices & Claude Rays
    ...
  }
  ```
- **Lines 3336–3352** (Ball Core):
  ```dart
  final coreColor = ball.isPurple
      ? const Color(0xFFAA00FF)
      : (isFireball
          ? const Color(0xFFFF6D00)
          : (isCornerBoost
              ? cbFlameBase
              : (ball.isBomb ? const Color(0xFFFF5252) : skinMain)));
  ...
  if (isFireball) {
    // Blazing white-gold molten star center
    _fill.color = const Color(0xFFFFF9C4);
    canvas.drawCircle(Offset.zero, ball.radius * 0.55, _fill);
    _fill.color = Colors.white;
    canvas.drawCircle(Offset.zero, ball.radius * 0.30, _fill);
  }
  ```
- **Lines 271–273** (Ambient Point Light):
  ```dart
  final ballColor = ball.isFireball
      ? const Color(0xFFFF1744)
      : (ball.isPurple ? const Color(0xFFD500F9) : c.activeBallSkin.glowColor);
  ```
- **Lines 2759–2805** (Fireball Trail):
  Layered passes using scarlet `Color(0xFFFF1744)` (Pass 1) and amber `Color(0xFFFF6D00)` (Pass 2).

### B. PowerUp Model & Localization
- **`lib/models/powerup.dart` (lines 12, 18, 43)**:
  ```dart
  fireball('Ateş', Color(0xFFFF6D00), 4.5, PowerUpKind.buff, Icons.local_fire_department),
  pierce('Delici', Color(0xFF00E5FF), 6.0, PowerUpKind.buff, Icons.arrow_upward),
  ...
  String get label => _label.isNotEmpty ? I18n.tr('pup_$name') : I18n.tr('pup_$name');
  ```
- **`lib/engine/i18n.dart` (lines 262, 268, 551, 557)**:
  - English: `'pup_fireball': 'Fireball'`, `'pup_pierce': 'Piercing Ball'`
  - Turkish: `'pup_fireball': 'Ateş Topu'`, `'pup_pierce': 'Delici Top'`

### C. Controller State in `lib/engine/game_controller.dart`
- **Lines 1973–1987 (`applyPowerUp`)**:
  ```dart
  case PowerUpType.fireball:
    for (final b in balls) {
      b.isFireball = true;
    }
    break;
  ...
  case PowerUpType.pierce:
    for (final b in balls) {
      b.isPierce = true;
    }
    break;
  ```
- **Lines 2035–2049 (`_removePowerUp`)**:
  ```dart
  case PowerUpType.fireball:
    for (final b in balls) {
      b.isFireball = false;
    }
    break;
  ...
  case PowerUpType.pierce:
    for (final b in balls) {
      b.isPierce = false;
    }
    break;
  ```
- **Lines 1590 (`_updateBalls`) & 1654–1664 (`_hitBrick`)**:
  ```dart
  // Line 1590: Ball skips reflection when isFireball or isPierce:
  if (!ball.isFireball && !ball.isPierce && !b.isTuft) { ... reflection ... }

  // Lines 1654-1664: Steel brick ONLY destroyed by isFireball:
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
  ```

### D. Corner Shot Contrast in `lib/ui/game_canvas.dart`
- **Lines 3050–3180**: Corner Shot uses forward bow shock arc (`pi / 1.4` arc ahead of ball), swept Mach lines slicing backwards, rigid conical exhaust plume (`lineTo`), and twin vector nozzles at `±22°`.

### E. PixelArt in `lib/ui/pixel_art.dart`
- **Lines 18–27 & 218–227**:
  `PowerUpType.fireball` is an 8x8 flame matrix. `PowerUpType.pierce` is an 8x8 upward arrow matrix.

### F. Build & Test Baseline
- `flutter test test/game_test.dart`: Exited with code 0. All 92 tests passed.
- `flutter analyze`: Exited with code 0. "No issues found!".

---

## 2. Logic Chain

1. **State Unification Requirement**:
   - Observation C shows that `PowerUpType.pierce` only set `b.isPierce = true`, and `b.isSteel` in line 1655 only checked `ball.isFireball`.
   - Therefore, picking up `pierce` did not melt steel bricks.
   - By changing `applyPowerUp` so both `case PowerUpType.fireball:` and `case PowerUpType.pierce:` set `b.isFireball = true` AND `b.isPierce = true`, and updating `_hitBrick` to check `(ball.isFireball || ball.isPierce)`, both power-ups achieve identical steel-melting and brick-piercing behavior.
   - Observation C (`_removePowerUp`) reveals that if a player picks up both `fireball` and `pierce`, expiry of one must NOT clear flags if the other remains in `activePowerUps`.

2. **Visual Replacement & Claude Starburst Removal**:
   - Observation A shows the exact block (lines 2960–3048) where `claudeStar` and `innerStar` polygons are created and drawn.
   - Removing this block eliminates the Claude starburst completely without affecting any other game element.
   - Replacing it with multi-layered organic flame tongues curling along `atan2(-ball.vy, -ball.vx)` using quadratic Bezier curves, combined with a rotating 8-ray golden solar crest inside the sphere core (Observation A, lines 3336–3352), fulfills all visual requirements.
   - Observation D confirms that Corner Shot relies on rigid cones and bow arcs, making the organic swirling flame petals and solar crest visually distinct.
   - Zero `MaskFilter.blur` is maintained across all drawing steps, ensuring 60/120 FPS.

3. **Capsule & PixelArt Unification**:
   - Observation E shows `PowerUpType.pierce` uses an arrow bitmap and cyan color `0xFF00E5FF`.
   - Updating `PowerUpType.pierce` in `pixel_art.dart` to a flame motif and changing its color to golden amber (`0xFFFF9100`) unifies capsule visuals.

4. **Localization & Naming**:
   - Observation B shows labels are derived from `I18n.tr('pup_$name')`.
   - Updating `pup_fireball` and `pup_pierce` to `"🔥 YAKICI TOP!"` (TR) and `"🔥 SEARING BALL!"` (EN) ensures floating pickup banners and HUD badges display the exact unified name.

---

## 3. Caveats

- **Asset PNGs**: `assets/images/skills/pierce.png` and `fireball.png` exist on disk. `AssetCache` loads image assets first; if `pierce.png` is an arrow, falling capsules will draw the cached image unless `AssetCache.getSkillImage` is mapped to return the fireball image for both or `pierce.png` is replaced. The fallback `PixelArt.draw` is fully customizable via code.
- **Duration**: Current durations are `4.5`s for fireball and `6.0`s for pierce. Requirement R2 specifies unifying the state and name; preserving or aligning these durations (e.g., standardizing to 5.0s or keeping current durations) does not break any tests.
- No other caveats.

---

## 4. Conclusion

Requirement R2 is thoroughly surveyed, isolated, and ready for clean implementation:
1. **Model & Controller**: Unify `PowerUpType.fireball` and `PowerUpType.pierce` in `applyPowerUp`, `_removePowerUp`, `_hitBrick`, `_splitBalls`, and `i18n.dart`.
2. **Canvas Visual**: Delete `claudeStar` / `innerStar` in `lib/ui/game_canvas.dart:2960-3048` and replace with high-performance (zero blur) organic Bezier flame petals curling opposite velocity vector + molten gold armored core with rotating 8-ray solar crest ring.
3. **Capsules & Icons**: Update `PowerUpType.pierce` in `pixel_art.dart` to flame bitmap and golden-amber color.
4. **Tests**: Add unit and widget tests verifying steel melting for pierce, unified state flags, localized label strings, and exception-free canvas rendering.

---

## 5. Verification Method

To independently verify the implementation:
1. **Analyze command**:
   ```pwsh
   flutter analyze
   ```
   Must produce `No issues found!`.
2. **Test command**:
   ```pwsh
   flutter test test/game_test.dart
   ```
   Must pass all tests (currently 92 passing).
3. **Specific test assertions to check**:
   - `controller.applyPowerUp(PowerUpType.pierce)` sets both `isFireball == true` and `isPierce == true`.
   - Ball with `PowerUpType.pierce` destroys `Brick(isSteel: true)`.
   - Floating text banner matches `"🔥 YAKICI TOP!"` (or `"🔥 SEARING BALL!"` in EN).
   - In `lib/ui/game_canvas.dart`, no instances of `claudeStar` or `innerStar` remain.
   - `GameCanvas` renders with `Ball(isFireball: true)` and `Ball(isPierce: true)` without exceptions.
