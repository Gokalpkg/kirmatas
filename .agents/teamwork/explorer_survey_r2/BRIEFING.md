# BRIEFING — 2026-10-11T18:20:45Z

## Mission
Investigate requirement R2: Transform Piercing / Fireball Power-Up into Golden-Flame 'Yakıcı Top' (Remove Claude-Style Starburst Icon) across models, engine, canvas rendering, pixel art / capsule icons, and tests.

## 🔒 My Identity
- Archetype: explorer
- Roles: investigation, synthesis
- Working directory: c:\Users\USER\Desktop\KIPKIRMATAS\.agents\teamwork\explorer_survey_r2
- Original parent: baa54a84-727c-4da2-ac66-31c3676013db
- Milestone: survey

## 🔒 Key Constraints
- Read-only investigation — do NOT implement
- Zero MaskFilter.blur (high-FPS)
- Remove Claude-style 6-pointed starburst icon
- Multi-layered swirling golden-amber and solar-orange organic flame tongues / fire petals curling opposite velocity vector
- Molten gold armored core with rotating golden solar ring/crest inside the sphere
- Distinct from Corner Shot directional jet afterburner

## Current Parent
- Conversation ID: baa54a84-727c-4da2-ac66-31c3676013db
- Updated: 2026-10-11T18:20:45Z

## Investigation State
- **Explored paths**:
  - `ORIGINAL_REQUEST.md`: Acceptance criteria and technical requirements.
  - `lib/models/powerup.dart`: `PowerUpType.fireball` and `PowerUpType.pierce` definitions.
  - `lib/models/ball.dart`: `isFireball`, `isPierce`, `trailLength` cap logic.
  - `lib/engine/i18n.dart`: `pup_fireball` and `pup_pierce` localization across all 9 languages.
  - `lib/engine/game_controller.dart`: `applyPowerUp`, `_removePowerUp`, `_hitBrick` (steel melting), `_updateBalls` (reflection bypass), `_splitBalls`, laser combo, trail particles.
  - `lib/ui/game_canvas.dart`: `claudeStar` / `innerStar` starburst polygon in lines 2960–3048, ball core in lines 3320–3365, trail rendering lines 2759–2805, ambient light line 271, capsules line 3873.
  - `lib/ui/pixel_art.dart`: Bitmaps and drawing for `fireball` and `pierce`.
  - `lib/engine/asset_cache.dart`: Skill image caching and fallback mechanism.
  - `test/game_test.dart`: Existing tests for fireball, pierce, steel melting, and canvas rendering.
- **Key findings**:
  - `claudeStar` & `innerStar` exist strictly in `lib/ui/game_canvas.dart:2981-3033` and can be cleanly excised and replaced.
  - Both `isFireball` and `isPierce` should be set to true on powerup pickup, and steel melting in `_hitBrick` should check `(ball.isFireball || ball.isPierce)`.
  - Expiry in `_removePowerUp` must guard against clearing flags when the other powerup is still active in `activePowerUps`.
  - Zero `MaskFilter.blur` architecture using Bezier flame petals curling opposite velocity vector (`atan2(-vy, -vx)`) and molten gold armored core with rotating 8-ray solar crest.
  - Corner Shot differentiation is clean: Mach supersonic jet cones vs organic curling solar flame petals.
  - `flutter analyze` has 0 issues, `flutter test` passes all 92 tests.
- **Unexplored areas**: None, survey complete.

## Key Decisions Made
- Mapped all 5 sub-areas of R2 with line-precise locations.
- Formulated zero-blur organic Bezier flame petal architecture.
- Documented dual-active powerup expiration safety edge case.
- Prepared comprehensive analysis.md and handoff.md.

## Artifact Index
- DISPATCH.md — incoming instructions log
- progress.md — liveness heartbeat
- analysis.md — detailed findings
- handoff.md — 5-component handoff report
