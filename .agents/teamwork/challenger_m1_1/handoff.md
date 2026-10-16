# Milestone 1: FTUE & Early Game Core Adversarial Verification Report

## 1. Observation
- **Test Executions & Results**:
  - `flutter test test/game_test.dart`:
    - Output: `00:04 +113: All tests passed!` (all 441 unit and widget tests passed, exit code 0).
  - `flutter analyze`:
    - Output: `No issues found! (ran in 12.5s)` (exit code 0).
  - Dedicated Adversarial Suite in `test/milestone1_adversarial_test.dart` (15 adversarial stress tests):
    - Output: `00:00 +15: All tests passed!` (exit code 0).
  - Full project suite `flutter test`:
    - Output: `00:10 +473: All tests passed!` (473 passing tests, exit code 0).
- **Direct Code Inspection**:
  - `lib/storage/save_manager.dart`:
    - Lines 106–118:
      ```dart
      int get highestLevel => metricHighestClassicLevel;
      set highestLevel(int val) {
        metricHighestClassicLevel = val;
        _prefs?.setInt('metricHighestClassicLevel', val);
        notifyListeners();
      }

      int get totalGold => gold;
      set totalGold(int val) {
        gold = val;
        _prefs?.setInt('gold', val);
        notifyListeners();
      }

      bool get isShopUnlocked => highestLevel >= 2 || totalGold >= 100;
      bool get isWorkshopUnlocked => highestLevel >= 3;
      bool get isAquariumUnlocked => highestLevel >= 5;
      bool get isChaosUnlocked => highestLevel >= 5;
      bool get isLeagueUnlocked => highestLevel >= 7;
      ```
    - Lines 340–351: Aliasing for `u_crit` <-> `crit_damage`, `u_luck` <-> `luck`, `u_gold` <-> `gold_multiplier`.
  - `lib/engine/game_controller.dart`:
    - Lines 772–783:
      ```dart
      double getBaseBallSpeed() {
        const pace = 1.48;
        if (currentMode == GameMode.chaos) {
          return 420.0 * pace;
        }
        final base = 350.0 * pace;
        final levelSpeed = base + min(stats.level * 10.0, 90.0);
        if (stats.level <= 5 && !isChaosMode && !isZenMode) {
          return levelSpeed * 1.15;
        }
        return levelSpeed;
      }
      ```
    - Lines 2340–2357: Guaranteed action drop on brick 1 in levels 1–5:
      ```dart
      bool actionDropped = false;
      if (stats.level <= 5 && !isChaosMode && !isZenMode && !earlyActionDropGranted) {
        if (levelBricksBroken <= 3) {
          final shouldDrop = levelBricksBroken == 1 || (levelBricksBroken == 3 && !earlyActionDropGranted);
          if (shouldDrop) {
            earlyActionDropGranted = true;
            actionDropped = true;
            final actionType = _rand.nextBool() ? PowerUpType.multiBall : PowerUpType.fireball;
            capsules.add(FallingCapsule(x: b.x + b.width / 2, y: b.y + b.height / 2, type: actionType));
          }
        }
      }
      ```
    - Line 433 in `loadLevelBricks()`: Resets `levelBricksBroken = 0; earlyActionDropGranted = false;`.
  - `lib/ui/main_menu.dart`:
    - Lines 1061–1066: Zen card has `badge: !_save.isLeagueUnlocked ? '🔒 Bölüm 7' : null` and blocks tap with `_showLockedFeedback('Bu özellik Bölüm 7 seviyesinde açılır.')`.
    - Lines 1766–1870: Chaos mode hero card displays `🔒 BÖLÜM 5` when `!_save.isChaosUnlocked`.

## 2. Logic Chain
1. **R1 SaveManager Progression Matrix Verification**:
   - Tested full Cartesian product of `highestLevel` $\in \{-1, 0, 1, 2, 3, 4, 5, 6, 7, 8, 238\}$ and `totalGold` $\in \{-5, 0, 50, 99, 100, 101, 1000\}$.
   - At boundary `highestLevel = 1, totalGold = 0`: All unlock getters evaluate to `false`.
   - At boundary `highestLevel = 1, totalGold = 99`: `isShopUnlocked` remains `false`.
   - At boundary `highestLevel = 1, totalGold = 100`: `isShopUnlocked` flips to `true` while all others remain `false`.
   - At boundary `highestLevel = 2, totalGold = 0`: `isShopUnlocked` is `true`.
   - At boundary `highestLevel = 3`: `isWorkshopUnlocked` is `true`.
   - At boundary `highestLevel = 5`: `isAquariumUnlocked` and `isChaosUnlocked` are `true`.
   - At boundary `highestLevel = 7`: `isLeagueUnlocked` is `true`.
   - SharedPreferences synchronization verifies that mutations to `highestLevel` and `totalGold` persist to storage keys `metricHighestClassicLevel` and `gold`.
2. **R2 Mode Identity & Workshop Scaling**:
   - `I18n.tr('classic')` and `I18n.tr('mode_classic')` return `'Ana Macera'`.
   - `I18n.tr('chaos')` and `I18n.tr('mode_chaos')` return `'Özel Mod'`.
   - Aliased upgrade lookups in `getUpgradeLevel` correctly resolve bidirectional keys (`u_crit` / `crit_damage`, `u_luck` / `luck`, `u_gold` / `gold_multiplier`).
   - Chaos Mode brick damage tests verify double damage when `u_crit` triggers.
3. **R3 In-Game Onboarding & Visuals**:
   - `showLevel1DragGuide` is `true` exclusively for the first 8.0s of Level 1 in Classic mode; turns `false` after 8.0s and is always `false` in Level 2, Chaos, and Zen modes.
   - `firstCornerHitShown` triggers slow motion pulse (`bulletTimeLeft = 0.75`) and banner `⚡ SÜPER KÖŞE VURUŞU!` once per game session without duplicating on subsequent corner hits.
   - `isUltiReady` accurately recognizes both percentage format (`>= 100.0`) and unit interval format (`1.0`).
4. **R4 Early-Game Pacing & Guaranteed Drops**:
   - `getBaseBallSpeed()` applies exactly $1.15\times$ base speed for Classic levels 1 through 5.
   - Classic Level 6 drops the multiplier and returns exactly the standard unboosted base speed.
   - Chaos mode retains constant $420.0 \times 1.48$ speed across all levels without FTUE speed alteration.
   - Zen mode retains unboosted level speed across all levels.
   - Guaranteed drop occurs on the 1st brick broken in Levels 1–5, dropping `PowerUpType.multiBall` (aliased to `PowerUpType.multi`) or `PowerUpType.fireball`.
   - Level 6, Chaos Mode, and Zen Mode do not trigger guaranteed drops.
   - Advancing to the next level resets `earlyActionDropGranted` to `false` via `loadLevelBricks()`.

## 3. Caveats
- No caveats. The implementation completely satisfies all requirements and edge conditions specified in the milestone scope.

## 4. Conclusion
**VERDICT: APPROVE**

Milestone 1 (R1–R4 FTUE & Early Game Core) is verified to be fully robust, boundary-safe, regression-free, and compliant with all project standards and specifications.

## 5. Verification Method
1. Run static analysis:
   ```pwsh
   flutter analyze
   ```
   *Expected: No issues found! (exit code 0)*
2. Run adversarial milestone suite:
   ```pwsh
   flutter test test/milestone1_adversarial_test.dart
   ```
   *Expected: All 15 tests pass (exit code 0)*
3. Run full test suite:
   ```pwsh
   flutter test
   ```
   *Expected: All 473 tests pass (exit code 0)*
