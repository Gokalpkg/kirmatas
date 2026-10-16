# DISPATCH: Worker M3 Fix (English Studio Fix Worker)

## Objective
Apply the exact fixes to `docs/kirmatas_ad_en.html` designed by Explorer Fix 1, Explorer Fix 2, and verify using the test script designed by Explorer Fix 3.

## Scope Boundaries
- You EXCLUSIVELY own `docs/kirmatas_ad_en.html`.
- DO NOT modify `lib/`, `test/game_test.dart`, or `docs/kirmatas_reklam_tr.html`.
- Zero diff on `lib/` and `test/game_test.dart`.

## Instructions
1. Read the fix formulations from:
   - `c:\Users\USER\Desktop\KIPKIRMATAS\.agents\teamwork\explorer_fix_1\handoff.md`
   - `c:\Users\USER\Desktop\KIPKIRMATAS\.agents\teamwork\explorer_fix_2\handoff.md`
   - `c:\Users\USER\Desktop\KIPKIRMATAS\.agents\teamwork\explorer_fix_3\handoff.md`
2. In `docs/kirmatas_ad_en.html`:
   - Line 670: Change `const prog = Math.min(1.0, t / 3.5);` to `const prog = Math.max(0.0, Math.min(1.0, t / 3.5));`.
   - Lines 1320–1352 (`drawChaosPerksWindow`): Replace procedural rectangle with `loadedImages.img_synergies` inset overlay with glowing amber border and header badge.
   - Lines 1354–1389 (`drawAquariumLeagueWindow`): Replace procedural rectangle with `loadedImages.img_league` inset overlay with glowing cyan border and header badge.
3. Run the automated verification script:
   `node .agents/teamwork/explorer_fix_3/verify_fix.js`
4. Confirm `git diff lib/ test/game_test.dart` is 0 diff and `flutter analyze` passes.
5. Write your handoff report to `handoff.md` in your working directory and report completion back via `send_message`.


## 2026-10-16T18:45:31Z
Sender: a954229f-7f6b-47b6-a253-514b9fa8e0e7
Priority: MESSAGE_PRIORITY_HIGH
Content:
You are Worker 3 (English Promo Video Studio Fix Specialist).
Read ORIGINAL_REQUEST.md at c:\Users\USER\Desktop\KIPKIRMATAS\.agents\teamwork\ORIGINAL_REQUEST.md.
Read PROJECT.md at c:\Users\USER\Desktop\KIPKIRMATAS\PROJECT.md.
Read your DISPATCH.md at c:\Users\USER\Desktop\KIPKIRMATAS\.agents\teamwork\worker_m3_fix\DISPATCH.md.

Read the detailed fix formulations and handoff reports from the fix explorers:
- c:\Users\USER\Desktop\KIPKIRMATAS\.agents\teamwork\explorer_fix_1\handoff.md
- c:\Users\USER\Desktop\KIPKIRMATAS\.agents\teamwork\explorer_fix_2\handoff.md
- c:\Users\USER\Desktop\KIPKIRMATAS\.agents\teamwork\explorer_fix_3\handoff.md

Your working directory is:
c:\Users\USER\Desktop\KIPKIRMATAS\.agents\teamwork\worker_m3_fix

Write Ownership:
You EXCLUSIVELY own `docs/kirmatas_ad_en.html`.
DO NOT modify `lib/`, `test/game_test.dart`, or `docs/kirmatas_reklam_tr.html`.

MANDATORY INTEGRITY WARNING:
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A teamwork_preview_auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

Your Tasks:
1. In `docs/kirmatas_ad_en.html`:
   a. Line 670: Change `const prog = Math.min(1.0, t / 3.5);` to `const prog = Math.max(0.0, Math.min(1.0, t / 3.5));`.
   b. In `drawChaosPerksWindow` (around lines 1320–1352): Replace the procedural card with genuine `loadedImages.img_synergies` inset overlay with glowing amber border and header badge (use the distortion-free code formulated in explorer_fix_1 and explorer_fix_2).
   c. In `drawAquariumLeagueWindow` (around lines 1354–1389): Replace the procedural card with genuine `loadedImages.img_league` inset overlay with glowing cyan border and header badge (use the distortion-free code formulated in explorer_fix_1 and explorer_fix_2).
2. Execute the automated verification script designed by Explorer 3:
   `node .agents/teamwork/explorer_fix_3/verify_fix.js`
   Verify that all suites pass with 100% assertions satisfied!
3. Check repository status:
   - Run `git diff lib/ test/game_test.dart` and confirm 0 diff.
   - Run `flutter analyze` and confirm 0 errors/warnings.
4. Write your comprehensive handoff report to:
   c:\Users\USER\Desktop\KIPKIRMATAS\.agents\teamwork\worker_m3_fix\handoff.md
5. Report completion back to the parent orchestrator via send_message.
