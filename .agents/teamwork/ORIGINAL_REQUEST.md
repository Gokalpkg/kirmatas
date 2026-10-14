# Original User Request

## 2026-10-11T18:12:03Z

Fix post-level/post-victory background gameplay issues, transform the Piercing/Fireball power-up into a distinct golden-flame "Yakıcı Top" (removing the Claude-like 6-point starburst icon), and fix all Black Hole gravitational pull fields in the Flutter Brick Breaker game (`Kırmataş`).

Working directory: c:\Users\USER\Desktop\KIPKIRMATAS
Integrity mode: development

## Requirements

### R1. Stop Background Gameplay After Clearing a Level or Winning
When all breakable bricks in a level are cleared (`_checkGameProgress`) or when the game reaches Victory/Game Over (`_onVictory` / `_onGameOver`):
- Immediately clear/halt active balls, projectiles, falling capsules, active power-up auto-fire timers (laser, rocket, drone), and dice salvos (`isDiceRolling`, `diceSalvoRemaining`) so the ball and weapons never keep bouncing off leftover steel bricks, walls, or paddle behind the "BÖLÜM GEÇİLDİ!" banner or Victory overlay.
- While `levelTransitionTimer > 0`, freeze gameplay simulation (`_updateBalls`, `_updateProjectiles`, `_updateCapsules`, `_updatePowerUpTimers`, `_updateDice`, `_updateBricks`, `_updateAnomalies`) and only update celebration particles (`particles.update(dt)`).
- Do not tick `levelTransitionTimer` while `status == GameStatus.paused`, `GameStatus.gameOver`, or `GameStatus.victory`.
- Ensure Classic mode triggers `_onVictory()` upon clearing level 238, and reset pointer drag state on level transition so releasing a touch from the previous level never auto-launches the ball in the new level.

### R2. Transform Piercing / Fireball Power-Up into Golden-Flame "Yakıcı Top" (Remove Claude-Style Starburst Icon)
- Rename and unify the piercing/fireball power-up (`PowerUpType.pierce` and `PowerUpType.fireball`) as **"🔥 YAKICI TOP!"** (`🔥 SEARING BALL!` in English) so both apply the searing golden-flame power-up state (`isFireball = true` / `isPierce = true`) that pierces regular bricks and melts steel bricks.
- In `lib/ui/game_canvas.dart`, completely remove the 6-pointed Claude-style starburst polygon (`claudeStar` / `innerStar`) from `isFireball`.
- Replace it with an unmistakable, high-FPS (zero `MaskFilter.blur`) **Golden-Flame "Yakıcı Top" Power-Up Visual**:
  - Multi-layered swirling golden-amber and solar-orange organic flame tongues / fire petals wrapping around the ball and curling opposite its velocity vector.
  - A molten gold armored power-up core with a rotating golden solar ring/crest inside the sphere so the player immediately recognizes that the "Yakıcı Top" power-up is active (visually distinct from both normal balls and the directional supersonic jet afterburner of Corner Shot).
  - Update the falling capsule / `PixelArt` icon for `pierce` / `fireball` so it also reflects the golden-flame "Yakıcı Top" theme.

### R3. Fix All Black Holes & Gravitational Pull Fields
- Fix the gravitational pull calculation in `_updateBalls` (`lib/engine/game_controller.dart`) where `proximity * proximity` and low `basePull` (`230.0`) caused standard and small black holes (`r = 20..34`) to exert almost zero deflection (<1° angle change) on fast-moving balls:
  - Expand the gravitational influence radius (`maxInfluenceDist`) for all black holes (`max(135.0, bh.radius * (bh.isVortexTrap ? 6.5 : (bh.isSupercharged ? 6.0 : 5.5)))`).
  - Use a strong, responsive distance falloff (`pow(proximity, 0.85)`) and significantly higher `basePull` across all 3 black hole types (Standard, Supercharged, Vortex Trap) plus noticeable tangential swirl so every black hole—from smallest (`r = 20`) to largest (`r = 34`)—visibly curves and pulls balls across its entire gravitational field.
- In `_drawBlackHoles` (`lib/ui/game_canvas.dart`), render a visible, animated gravitational pull field boundary / inward-spiraling gravity waves matching `maxInfluenceDist` so players clearly see the active pull zone of every black hole.
- In `applyPowerUp` (`lib/engine/game_controller.dart`), implement `case PowerUpType.vortex:` so collecting the Vortex/Black Hole capsule (`vortex.png`) immediately spawns an active `BlackHole` in the open play zone between bricks and the paddle.

## Acceptance Criteria

### Automated & Behavioral Verification
- [ ] When a level is cleared (`remainingBreakable == 0`), `balls`, `projectiles`, `capsules`, and `diceSalvoRemaining` are immediately cleared and no ball/projectile movement or life loss occurs while `levelTransitionTimer > 0`.
- [ ] Both `PowerUpType.pierce` and `PowerUpType.fireball` activate the golden-flame "Yakıcı Top" state, render without the 6-point `claudeStar` polygon, and visually display swirling golden-amber flames and a solar power-up core.
- [ ] Every `BlackHole` (Standard, Supercharged, Vortex Trap, from `r = 20` to `r = 34`) has an active gravitational pull radius `>= 5.5 * radius` (`>= 135 px`) that produces a strong velocity deflection on balls passing through its field, and `PowerUpType.vortex` spawns a functional `BlackHole` when collected.
- [ ] `flutter analyze` reports 0 issues and `flutter test` passes 100% of existing and new unit/widget tests.
