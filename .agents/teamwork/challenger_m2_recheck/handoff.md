# Challenger Milestone 2 Recheck Empirical Report

**Verdict**: **REQUEST_CHANGES**

---

## 1. Observation

### 1.1 Existing Test Suite Runs
- `flutter test test/reviewer2_m2_stress_test.dart`
  - Output: `All tests passed! (9 tests)`
  - Note: In `test/reviewer2_m2_stress_test.dart` lines 56-60, the layout test for `UpgradesView` relied solely on `expect(tester.takeException(), isNull)`. In Flutter's widget test framework, `RenderFlex` layout overflows invoke `FlutterError.reportError` and do **not** populate `tester.takeException()` unless `FlutterError.onError` is actively intercepted.
- `flutter test test/game_test.dart`
  - Output: `All tests passed! (125 tests)`

### 1.2 Empirical Stress Test Suite (`test/challenger_m2_recheck_layout_stress_test.dart`)
We built and executed a dedicated stress harness capturing `FlutterError.onError` across viewports: `320x568` (iPhone SE 1st gen), `360x640` (standard compact Android), `390x844` (modern mobile), `300x700` (ultra-narrow foldable), and `320x480` (ultra-compact height), with text scaling (1.3x) and boundary currency values (6-digit and 9-digit gold, 4-digit and 6-digit pearls).

#### A. Verified Fixes (Passing with 0 Overflows):
1. **`MainMenuScreen` (`lib/ui/main_menu.dart`)**:
   - Zero RenderFlex overflow across all screen dimensions (`320x568`, `360x640`, `390x844`, `300x700`, `320x480`).
   - Seasonal title header, gold pill, dock buttons, collapsible arcade mode drawer, and chaos cards all flex and truncate with ellipsis properly.
   - Zero RenderFlex overflow with `TextScaler.linear(1.3)`.
2. **`TournamentDialog` (`lib/ui/tournament_dialog.dart`)**:
   - Zero RenderFlex overflow across all screen dimensions (`320x568`, `360x640`, `390x844`, `300x700`, `320x480`) and across League Tiers 0, 2, and 4.
   - Dynamic height `screenHeight * (isCompact ? 0.92 : 0.85)` leaves ample room for the scrollable leaderboard list.
3. **`SectorMapView` (`lib/ui/sector_map_view.dart`)**:
   - Zero RenderFlex overflow on `320x568`, `360x640`, `390x844` with highestLevel = 500 (Prestige Sector Omega active).
4. **`FortuneWheelDialog` (`lib/ui/fortune_wheel_dialog.dart`)**:
   - Zero RenderFlex overflow on target dimensions `320x568`, `360x640`, `390x844`.
5. **`UpgradesView` Cosmic Mastery Section 4 (`lib/ui/upgrades_view.dart:498, 546, 635`)**:
   - Zero RenderFlex overflow on Section 4 header, mastery cards, and upgrade cost buttons across `360x640` and `390x844`.

#### B. Defect Discovered (Active RenderFlex Overflows on 320x568):
In `lib/ui/upgrades_view.dart` on viewport `Size(320.0, 568.0)`:
1. **Verbatim Error 1 (Section 2 Header)**:
   ```
   ══╡ EXCEPTION CAUGHT BY RENDERING LIBRARY ╞═════════════════════════════════════════════════════════
   The following assertion was thrown during layout:
   A RenderFlex overflowed by 20 pixels on the right.
   The relevant error-causing widget was:
     Row Row:file:///C:/Users/USER/Desktop/KIPKIRMATAS/lib/ui/upgrades_view.dart:280:15
   constraints: BoxConstraints(w=288.0, 0.0<=h<=Infinity)
   size: Size(288.0, 19.0)
   direction: horizontal
   ```
   - Source: `lib/ui/upgrades_view.dart:280`:
     ```dart
     Row(
       children: [
         const Icon(Icons.auto_awesome_rounded, color: Color(0xFFFFD54F), size: 18),
         const SizedBox(width: 6),
         Text(
           I18n.tr('permanent_upgrades'),
           style: const TextStyle(...),
         ),
       ],
     ),
     ```
   - In Turkish (`'KALICI GELİŞTİRMELER'`), the unconstrained `Text` inside the unconstrained `Row` exceeds the 288px available width by 20px.

2. **Verbatim Error 2 (Section 3 Header)**:
   ```
   ══╡ EXCEPTION CAUGHT BY RENDERING LIBRARY ╞═════════════════════════════════════════════════════════
   The following assertion was thrown during layout:
   A RenderFlex overflowed by 34 pixels on the right.
   The relevant error-causing widget was:
     Row Row:file:///C:/Users/USER/Desktop/KIPKIRMATAS/lib/ui/upgrades_view.dart:399:15
   constraints: BoxConstraints(w=288.0, 0.0<=h<=Infinity)
   size: Size(288.0, 19.0)
   direction: horizontal
   ```
   - Source: `lib/ui/upgrades_view.dart:399`:
     ```dart
     Row(
       children: [
         const Icon(Icons.flash_on_rounded, color: Color(0xFFFF4081), size: 18),
         const SizedBox(width: 6),
         Text(
           I18n.tr('pre_match_boosts'),
           style: const TextStyle(...),
         ),
       ],
     ),
     ```
   - In Turkish (`'MAÇ ÖNCESİ DESTEKLERİ'`), the unconstrained `Text` inside `Row` exceeds the 288px available width by 34px.

3. **Verbatim Error 3 (AppBar Actions Row)**:
   ```
   ══╡ EXCEPTION CAUGHT BY RENDERING LIBRARY ╞═════════════════════════════════════════════════════════
   The following assertion was thrown during layout:
   A RenderFlex overflowed by 8.8 pixels on the right.
   The relevant error-causing widget was:
     AppBar AppBar:file:///C:/Users/USER/Desktop/KIPKIRMATAS/lib/ui/upgrades_view.dart:19:19
   constraints: BoxConstraints(0.0<=w<=320.0, 0.0<=h<=56.0)
   ```
   - When player reaches endgame gold (e.g. 9-digits: `save.gold = 999999999`), the trailing actions container in `AppBar` overflows by 8.8px on 320px width screens.

4. **Secondary Non-Target Edge Case (`FortuneWheelDialog`)**:
   - On `320x480` (ultra-compact height), `lib/ui/fortune_wheel_dialog.dart:469` `Column` overflows bottom by 51px. (Note: On the target `320x568`, `360x640`, and `390x844` viewports, it passes with 0 overflows).

---

## 2. Logic Chain

1. *Premise*: Worker 4 addressed the Cosmic Mastery section header at line 498 by wrapping its text in `Flexible(child: Text(..., overflow: TextOverflow.ellipsis, maxLines: 1))`.
2. *Observation*: The two preceding section headers on the same screen — Section 2 (`permanent_upgrades` at line 280) and Section 3 (`pre_match_boosts` at line 399) — were left as bare `Text` widgets inside unconstrained `Row` containers.
3. *Observation*: On `320x568` screen width, `ListView(padding: EdgeInsets.symmetric(horizontal: 16))` imposes a maximum horizontal constraint of `320 - 32 = 288.0px`.
4. *Deduction*: Under the default language (`tr`), `'KALICI GELİŞTİRMELER'` and `'MAÇ ÖNCESİ DESTEKLERİ'` with letterSpacing 1.2 and accompanying icons measure 308px and 322px respectively, directly causing a 20px and 34px RenderFlex overflow on the right edge.
5. *Observation*: `test/reviewer2_m2_stress_test.dart` used `tester.takeException() == null` without an active `FlutterError.onError` listener, thus allowing these layout errors to pass silently without failing the test runner.
6. *Conclusion*: Because RenderFlex overflows actively occur on the primary target viewport `320x568`, the layout remediation for Milestone 2 is incomplete. Changes must be requested before Milestone 2 can be approved.

---

## 3. Caveats

- MainMenu, TournamentDialog, SectorMapView, and UpgradesView Section 4 (Cosmic Mastery) are fully verified and robust against extreme screen sizes, high-tier game states, and text scaling.
- The defect is localized strictly to `lib/ui/upgrades_view.dart` at lines 280, 399, and optionally the AppBar actions padding at line 41-88.
- No gameplay logic, economy multipliers, prestige calculations, or save persistence are affected.

---

## 4. Conclusion

**Verdict: REQUEST_CHANGES**

### Required Remediation for Worker:
In `lib/ui/upgrades_view.dart`:
1. **Line 280 (Section 2 Header)**:
   Wrap the `Text` in `Flexible`:
   ```dart
   Row(
     children: [
       const Icon(Icons.auto_awesome_rounded, color: Color(0xFFFFD54F), size: 18),
       const SizedBox(width: 6),
       Flexible(
         child: Text(
           I18n.tr('permanent_upgrades'),
           overflow: TextOverflow.ellipsis,
           maxLines: 1,
           style: const TextStyle(...),
         ),
       ),
     ],
   )
   ```
2. **Line 399 (Section 3 Header)**:
   Wrap the `Text` in `Flexible`:
   ```dart
   Row(
     children: [
       const Icon(Icons.flash_on_rounded, color: Color(0xFFFF4081), size: 18),
       const SizedBox(width: 6),
       Flexible(
         child: Text(
           I18n.tr('pre_match_boosts'),
           overflow: TextOverflow.ellipsis,
           maxLines: 1,
           style: const TextStyle(...),
         ),
       ),
     ],
   )
   ```
3. **Line 41-88 (AppBar Actions)**:
   Compact margins/padding (e.g., reduce horizontal padding from 10/12 to 8/8 and right margin to 4/8) and set `Row(mainAxisSize: MainAxisSize.min)` to ensure 9-digit gold and 6-digit pearls fit on 320px width without trailing overflow.
4. **`test/reviewer2_m2_stress_test.dart`**:
   Update `UpgradesView` test to capture `FlutterError.onError` (similar to how `TournamentDialog` was written) so layout regressions are actively flagged by the test runner.

---

## 5. Verification Method

1. Run the empirical stress test demonstrating the failure:
   ```powershell
   flutter test test/challenger_m2_recheck_layout_stress_test.dart --plain-name "UpgradesView at Size(320.0, 568.0) with standard endgame (gold=999999, pearls=9999)"
   ```
   *Expected Current Output*: `A RenderFlex overflowed by 20 pixels on the right`, `A RenderFlex overflowed by 34 pixels on the right`.
   *Expected Post-Fix Output*: `All tests passed!`

2. Run the full adversarial layout suite:
   ```powershell
   flutter test test/challenger_m2_recheck_layout_stress_test.dart
   ```
   *Expected Post-Fix Output*: `All tests passed!`

3. Invalidation Conditions:
   Any RenderFlex overflow error logged or uncaught exception across `320x568`, `360x640`, or `390x844` viewports invalidates approval.
