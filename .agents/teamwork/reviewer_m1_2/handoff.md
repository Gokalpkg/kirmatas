# Milestone 1 (R1–R4 FTUE & Early Game Core) Review & Adversarial Challenge Report

## Review Summary

**Verdict**: **REQUEST_CHANGES**

**Overall Risk Assessment**: MEDIUM

Milestone 1 implements all required functional primitives for R1, R2, R3, and R4 with zero static analysis issues and 100% test suite pass rate (441/441 tests). There are zero integrity violations or facades. However, adversarial challenge revealed two critical gameplay/UX defects in `GameController` and `GameCanvas` that compromise FTUE and Chaos Mode:
1. In Chaos Mode, destroyed bricks charge `stats.ultiCharge`. Once 100 bricks are destroyed, `stats.ultiCharge` hits 100.0, rendering `'⚡ ULTİ HAZIR! ÇİFT DOKUN!'` permanently on screen because `triggerUlti()` early-exits for Chaos Mode without resetting the charge.
2. In `GameController`, `bool get isUltiReady => stats.ultiCharge >= 100.0 || (stats.ultiCharge >= 1.0 && stats.ultiCharge <= 1.0);` causes a false "Ulti Ready" state at exactly 1% charge for fresh players with default battery upgrade level 0.

---

## 1. Observation

### Verification Commands & Direct Outputs
1. **Static Analysis**:
   - Command: `flutter analyze`
   - Output:
     ```
     Analyzing KIPKIRMATAS...
     No issues found! (ran in 19.1s)
     ```
   - Exit code: `0`

2. **Automated Test Suite**:
   - Command: `flutter test`
   - Output:
     ```
     00:13 +441: All tests passed!
     ```
   - All 435 baseline tests and all 6 new Milestone 1 tests in `test/game_test.dart` passed with exit code `0`.

### Direct File & Code Observations
1. **R1: Progressive Feature Unlocking** (`lib/storage/save_manager.dart:106-125`, `lib/ui/main_menu.dart:73-102, 868-886, 1054-1068, 1183-1215, 1262-1300, 1528-1588`):
   - `SaveManager` exposes getters:
     - `int get highestLevel => metricHighestClassicLevel;`
     - `int get totalGold => gold;`
     - `bool get isShopUnlocked => highestLevel >= 2 || totalGold >= 100;`
     - `bool get isWorkshopUnlocked => highestLevel >= 3;`
     - `bool get isAquariumUnlocked => highestLevel >= 5;`
     - `bool get isChaosUnlocked => highestLevel >= 5;`
     - `bool get isLeagueUnlocked => highestLevel >= 7;`
   - `MainMenu` wraps locked bottom navigation tabs and mode cards with lock badges (`🔒 Bölüm 2`, `🔒 Bölüm 3`, `🔒 Bölüm 5`, `🔒 Bölüm 7`) and intercepts taps to show floating SnackBar notifications via `_showLockedFeedback()`.
   - `PageView.onPageChanged` redirects attempts to swipe into locked pages (Page 0: Shop, Page 2: Aquarium, Page 3: Workshop) back to Page 1 (Main).
   - Classic Mode displays a prominent golden highlight badge `⭐ MACERAYA BAŞLA!` and border glow when `_save.highestLevel < 2`.
   - Fortune Wheel auto-presentation dialog on session startup is guarded by `_save.isShopUnlocked`.

2. **R2: Mode Identity & Cross-Mode Workshop Scaling** (`lib/engine/i18n.dart:413-426`, `lib/storage/save_manager.dart:340-350`, `lib/engine/game_controller.dart:717-724, 2216-2228, 2296-2315`):
   - Turkish localization in `i18n.dart` defines:
     - `'classic': 'Ana Macera'`, `'mode_classic': 'Ana Macera'`
     - `'chaos': 'Özel Mod'`, `'mode_chaos': 'Özel Mod'`
   - `SaveManager.getUpgradeLevel(id)` implements alias lookup for `u_crit` <-> `crit_damage`, `u_luck` <-> `luck`, and `u_gold` <-> `gold_multiplier`.
   - `GameController` applies:
     - `u_crit` in Chaos Mode (`_hitBrick`): `critLvl * 0.035` chance for double damage (`dmg = 2`) and floating `'KRİTİK!'`.
     - `u_luck` in Chaos Mode (`_destroyBrick`): increases coin drop rate (`0.20 + luckLvl * 0.04`).
     - `u_gold` in Chaos Mode (`_destroyBrick` & level clear): scales coin quantity (`coins * (1.0 + goldLvl * 0.10)`) and completion gold.

3. **R3: Interactive In-Game Visual Onboarding** (`lib/engine/game_controller.dart:203-216, 876-879, 1909-1923, 2828-2834`, `lib/ui/game_canvas.dart:72-78, 286-291, 5086-5167`):
   - Level 1 drag guide `◄── KAYDIR ──►` is drawn below the paddle (`paddleRect.bottom + 12.0`) during the first 8 seconds of Level 1 Classic Mode (`showLevel1DragGuide`).
   - First corner hit (`!firstCornerHitShown`) triggers bullet time (`stats.bulletTimeLeft = 0.75`), screen shake, shockwave, and floating banner `'⚡ SÜPER KÖŞE VURUŞU!'`.
   - `GameCanvas` renders glowing callout pill `'⚡ ULTİ HAZIR! ÇİFT DOKUN!'` at 22% screen height when `isUltiReady` is true.
   - `GameCanvas.onPointerDown` detects double taps (<350ms delta) to call `c.triggerUlti()`.

4. **R4: Early-Game Pacing & Guaranteed Drops** (`lib/models/powerup.dart:43`, `lib/engine/game_controller.dart:778-782, 2338-2358`):
   - `PowerUpType.multiBall` is aliased as `static const PowerUpType multiBall = PowerUpType.multi;`.
   - `getBaseBallSpeed()` multiplies base speed by `1.15` (+15%) when `stats.level <= 5 && !isChaosMode && !isZenMode`.
   - In levels 1–5, one of the first 3 destroyed bricks (`levelBricksBroken <= 3`) is guaranteed to drop either `PowerUpType.multiBall` or `PowerUpType.fireball` via `earlyActionDropGranted`.

5. **Integrity Assessment**:
   - Zero hardcoded test outputs or return facades found.
   - Implementations interact genuinely with SharedPreferences, game loop physics, particles, and widget hierarchies.
   - Both `flutter analyze` and `flutter test` were independently verified from shell commands.

---

## 2. Logic Chain

1. **R1 Progressive Unlocking**:
   - `SaveManager` getters accurately reflect the progressive gating criteria specified in `ORIGINAL_REQUEST.md` §R1.
   - `MainMenu` guards both direct taps and gestures into locked views.
   - Bottom navigation items remain visible with badges (`🔒 Bölüm X`), maintaining layout stability and widget test compatibility.

2. **R2 Mode Identity & Scaling**:
   - Turkish translation changes cleanly brand Classic as "Ana Macera" and Chaos as "Özel Mod".
   - Chaos mode incorporates `u_crit`, `u_luck`, and `u_gold` directly into hit damage and reward calculations.

3. **R3 Onboarding & Timing**:
   - The Level 1 drag guide appears cleanly below the paddle without visual overlap.
   - The first corner hit banner and slow-motion pulse trigger exactly once per run.
   - However, the trigger conditions for `isUltiReady` and its relationship with Chaos Mode contain two major design flaws (detailed in Findings).

4. **R4 Early Pacing**:
   - Early base ball speed boost (+15%) provides snappy FTUE feel while respecting physics boundary constraints.
   - Guaranteed early action drops ensure players experience high-dopamine power-ups during their very first session.

---

## 3. Findings & Adversarial Challenges

### [Major] Finding 1: Permanent Stuck Ulti HUD Callout in Chaos Mode
- **Location**: `lib/engine/game_controller.dart:215`, `lib/ui/game_canvas.dart:290`
- **Observed Code**:
  ```dart
  // lib/engine/game_controller.dart:215
  bool get isUltiReady => stats.ultiCharge >= 100.0 || (stats.ultiCharge >= 1.0 && stats.ultiCharge <= 1.0);
  
  // lib/ui/game_canvas.dart:289-291
  if (c.isUltiReady) {
    _drawUltiReadyCallout(canvas, size, time);
  }
  
  // lib/engine/game_controller.dart:2828-2830
  void triggerUlti() {
    if (currentMode == GameMode.chaos) return;
    if (!isUltiReady || isDiceRolling || diceSalvoRemaining > 0) return;
    stats.ultiCharge = 0.0;
  ```
- **Why this is a problem**:
  In Chaos Mode, destroyed bricks continue to invoke `_chargeDiceFromGlass(b)` (line 2284), incrementing `stats.ultiCharge`. After 100 bricks are destroyed, `stats.ultiCharge` reaches 100.0. `isUltiReady` evaluates to `true`, and `GameCanvas` draws `'⚡ ULTİ HAZIR! ÇİFT DOKUN!'`.
  However, `triggerUlti()` explicitly returns early in Chaos Mode (`if (currentMode == GameMode.chaos) return;`) WITHOUT resetting `stats.ultiCharge`. Because `stats.ultiCharge` is clamped at 100.0 and never cleared, the banner **cannot be dismissed and remains permanently glued to the upper screen for the remainder of the Chaos run**.
- **Suggested Fix**:
  Guard `isUltiReady` against Chaos Mode in `lib/engine/game_controller.dart`:
  ```dart
  bool get isUltiReady => !isChaosMode && stats.ultiCharge >= 100.0;
  ```

---

### [Major] Finding 2: False 1% Ulti Charge Trigger in Level 1 FTUE
- **Location**: `lib/engine/game_controller.dart:215`
- **Observed Code**:
  ```dart
  bool get isUltiReady => stats.ultiCharge >= 100.0 || (stats.ultiCharge >= 1.0 && stats.ultiCharge <= 1.0);
  ```
- **Why this is a problem**:
  `stats.ultiCharge` in `GameStats` is a percentage from 0.0 to 100.0 (`// 0.0 to 100.0`). For a brand-new player in Level 1 (with default battery upgrade level 0), `_chargeDiceFromGlass` increments `stats.ultiCharge` from `0.0` to `1.0` on the very first charge cycle.
  Because of `(stats.ultiCharge >= 1.0 && stats.ultiCharge <= 1.0)`, `isUltiReady` evaluates to `true` when the player is only at 1% charge. The user sees `'⚡ ULTİ HAZIR! ÇİFT DOKUN!'` and can double-tap to fire a full ultimate barrage after breaking just one set of glass bricks. Once the charge increments to 2.0, the banner disappears until 100.0. This creates an erratic and confusing FTUE experience.
- **Suggested Fix**:
  Remove the `(stats.ultiCharge >= 1.0 && stats.ultiCharge <= 1.0)` hack. Normalize `ultiCharge` setter/getter if 0..1 scale is desired:
  ```dart
  double get ultiCharge => (stats.ultiCharge / 100.0).clamp(0.0, 1.0);
  set ultiCharge(double v) => stats.ultiCharge = (v <= 1.0 && v > 0) ? v * 100.0 : v;
  bool get isUltiReady => !isChaosMode && stats.ultiCharge >= 100.0;
  ```

---

### [Minor] Finding 3: Asymmetric Alias Shadowing in `SaveManager.getUpgradeLevel`
- **Location**: `lib/storage/save_manager.dart:340-350`
- **Observed Code**:
  ```dart
  int getUpgradeLevel(String id) {
    if (id == 'u_crit' || id == 'crit_damage') {
      return upgrades['u_crit'] ?? upgrades['crit_damage'] ?? 0;
    }
  ```
- **Why this is a problem**:
  If a save map contains both keys (e.g. `u_crit: 2` and `crit_damage: 3`), the null-coalescing operator `??` always selects `u_crit` and ignores the higher `crit_damage` value.
- **Suggested Fix**:
  Use `math.max`:
  ```dart
  int getUpgradeLevel(String id) {
    if (id == 'u_crit' || id == 'crit_damage') {
      return math.max(upgrades['u_crit'] ?? 0, upgrades['crit_damage'] ?? 0);
    }
    if (id == 'u_luck' || id == 'luck') {
      return math.max(upgrades['u_luck'] ?? 0, upgrades['luck'] ?? 0);
    }
    if (id == 'u_gold' || id == 'gold_multiplier') {
      return math.max(upgrades['u_gold'] ?? 0, upgrades['gold_multiplier'] ?? 0);
    }
    return upgrades[id] ?? 0;
  }
  ```

---

### [Minor] Finding 4: PageView Tab Swiping Order Anomaly
- **Location**: `lib/ui/main_menu.dart:868`
- **Description**:
  The page order is Page 0 (Shop, Level 2), Page 1 (Main, Level 1), Page 2 (Aquarium, Level 5), and Page 3 (Workshop, Level 3). A player at Level 3 or 4 who has unlocked Workshop cannot reach Workshop by swiping right from Page 1, because the swipe passes through Page 2 (Aquarium, locked until Level 5), which immediately bounces them back to Page 1 via `onPageChanged`. The player can only access Workshop via the bottom navigation dock.
- **Suggested Fix**:
  Documented as known UX interaction for Milestone 2 navigation tuning.

---

## 4. Verified Claims

- Claim: `flutter analyze` passes with 0 issues → Verified → PASS.
- Claim: All 441 automated tests in `test/game_test.dart` pass without regression → Verified → PASS.
- Claim: Progressive unlock badges (`🔒 Bölüm X`) and SnackBar feedback work on locked menus → Verified → PASS.
- Claim: Mode titles localized to "Ana Macera" and "Özel Mod" in Turkish → Verified → PASS.
- Claim: Level 1 drag guide renders below paddle during first 8 seconds → Verified → PASS.
- Claim: First corner hit triggers slow-mo bullet time and celebratory banner → Verified → PASS.
- Claim: Ball base speed boosted by +15% in Levels 1–5 → Verified → PASS.
- Claim: Guaranteed action capsule drop in Levels 1–5 within first 3 bricks → Verified → PASS.

---

## 5. Caveats

- `SaveManager` defaults `gold` to 300 in clean mock profiles, meaning `isShopUnlocked` evaluates to true unless `totalGold` is explicitly tested at 0. This matches the specification formula `highestLevel >= 2 || totalGold >= 100`.
- In widget tests involving `MainMenuScreen`, `tester.pumpAndSettle()` should be avoided due to infinite ambient animations; use `tester.pump(duration)` instead.

---

## 6. Conclusion

Milestone 1 is cleanly architected and fully functional for standard test paths. However, Findings 1 and 2 represent concrete gameplay and FTUE defects:
1. In Chaos Mode, breaking 100 bricks leaves the Ulti callout permanently stuck on screen.
2. In Level 1 FTUE, the Ulti callout falsely triggers at 1% charge.

**Verdict**: **REQUEST_CHANGES**

Addressing these two targeted fixes in `lib/engine/game_controller.dart` will ensure Milestone 1 is completely sound before Milestone 2 and 3 build further systems upon it.

---

## 7. Verification Method

1. Run static analysis:
   ```pwsh
   flutter analyze
   ```
   *Expected: No issues found! (exit code 0)*
2. Run test suite:
   ```pwsh
   flutter test test/game_test.dart
   flutter test
   ```
   *Expected: All 441 tests pass (exit code 0)*
3. Reproduce Finding 1 (Chaos mode Ulti lockup):
   Initialize `GameController` with `GameMode.chaos`, set `stats.ultiCharge = 100.0`, observe `isUltiReady` is true, call `triggerUlti()`, observe `stats.ultiCharge` remains 100.0 and `isUltiReady` remains true.
4. Reproduce Finding 2 (1% charge false-ready):
   Set `ctrl.stats.ultiCharge = 1.0`, observe `ctrl.isUltiReady` evaluates to `true`.
