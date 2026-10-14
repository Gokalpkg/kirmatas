## 2026-10-11T18:27:12Z
You are a Worker agent assigned to Milestone 1: "Post-Level Background Gameplay Halt".
Your working directory is: c:\Users\USER\Desktop\KIPKIRMATAS\.agents\teamwork\worker_m1\
Project root is: c:\Users\USER\Desktop\KIPKIRMATAS

MANDATORY FIRST STEP: Read ORIGINAL_REQUEST.md at:
c:\Users\USER\Desktop\KIPKIRMATAS\.agents\teamwork\ORIGINAL_REQUEST.md

Also read:
- c:\Users\USER\Desktop\KIPKIRMATAS\PROJECT.md
- c:\Users\USER\Desktop\KIPKIRMATAS\.agents\teamwork\explorer_survey_r1\handoff.md
- c:\Users\USER\Desktop\KIPKIRMATAS\.agents\teamwork\explorer_survey_r1\analysis.md

MANDATORY INTEGRITY WARNING:
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A teamwork_preview_auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

Write Ownership:
You exclusively own:
- lib/engine/game_controller.dart
- lib/ui/game_canvas.dart
- test/game_test.dart

Your Implementation Tasks (Milestone 1 / Features F1.1 - F1.6):
1. In lib/engine/game_controller.dart:
   - Implement `_haltBackgroundGameplay()`:
     - Clear `balls`, `projectiles`, `capsules`.
     - Reset `isDiceRolling = false`, `diceSalvoRemaining = 0`, `diceRollTimer = 0.0`, `diceDisplayTimer = 0.0`.
     - Reset auto-fire weapon timers and flags: `laserTimer = 0.0`, `rocketTimer = 0.0`, `droneShootTimer = 0.0`, `paddle.hasLaser = false`, `paddle.hasRockets = false`, `paddle.hasDrone = false`.
   - Call `_haltBackgroundGameplay()` in:
     - `_checkGameProgress()` when all breakable bricks are cleared (`remainingBreakable == 0`).
     - `_onVictory()` .
     - `_onGameOver()`.
   - In `update(dt)`:
     - Do NOT decrement `levelTransitionTimer` while `status == GameStatus.paused`, `GameStatus.gameOver`, or `GameStatus.victory`.
     - When `levelTransitionTimer > 0`, freeze all simulation (`_updateBalls`, `_updateProjectiles`, `_updateCapsules`, `_updatePowerUpTimers`, `_updateDice`, `_updateBricks`, `_updateAnomalies`, `paddle.update`) and ONLY update `particles.update(dt)`, `frameTick.ping()`, `_syncHud()`.
   - In `_updateBalls(dt)`:
     - Prevent `_loseLife()` or game-over while `levelTransitionTimer > 0`.
   - In `_checkGameProgress()`:
     - When `currentMode == GameMode.classic && stats.level >= 238`: grant level 238 score/gold rewards and call `_onVictory()` instead of incrementing to level 239.
2. In lib/ui/game_canvas.dart:
   - In `_GameCanvasState`: reset pointer drag / touch launch eligibility across level transitions (e.g., check `_touchStartLevel == controller.stats.level` and invalidate touch launch when `levelTransitionTimer > 0`), ensuring releasing a touch held from the previous level never auto-launches in the new level.
3. In test/game_test.dart:
   - Add unit/widget tests for all Milestone 1 requirements:
     - Entity clearing on level clear, victory, and game over.
     - Simulation freeze and particle-only updates during `levelTransitionTimer > 0`.
     - `levelTransitionTimer` freeze on paused, gameOver, victory.
     - Level 238 classic mode victory trigger.
     - Pointer drag state safety on level transition.
4. Verify by running:
   - `flutter analyze`
   - `flutter test test/game_test.dart`
   Ensure 0 analyze issues and 100% tests pass.

Write your report to `c:\Users\USER\Desktop\KIPKIRMATAS\.agents\teamwork\worker_m1\handoff.md` and report completion via send_message.
