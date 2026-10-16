# Explorer Survey Report: R8, R9 & Baseline Health Check

**Date:** 2026-10-16  
**Investigator:** Explorer 3 (Cosmetics, Chaos & Test Suite Investigator)  
**Target Project:** Kırmataş (`c:\Users\USER\Desktop\KIPKIRMATAS`)  
**Scope:** R8 (Cosmetic Loadout Set Synergies), R9 (Chaos Mode 3-Card Roguelike Perks & Wave-10 Bosses), and Complete Baseline Test Suite / Static Analysis Health Check.

---

## 1. Executive Summary & Baseline Verification

### 1.1 Analyzer Baseline Check
- **Command Executed:** `flutter analyze`
- **Result:** **Exit Code 0 — No issues found! (0 errors, 0 warnings)** (completed in 75.1s).
- **Status:** Baseline analyzer is pristine. All subsequent additions must maintain 0 warnings/errors.

### 1.2 Test Suite Baseline Check
- **Command Executed:** `flutter test`
- **Result:** **Exit Code 0 — All 435 tests passed! (0 failures, 100% pass rate)** in 8 seconds.
- **Suite Breakdown:**
  - `test/game_test.dart`: 107 engine, model, and widget tests.
  - `test/e2e/e2e_requirements_test.dart`: 328 tests across 4 tiers:
    - `tier1_feature_coverage_test.dart`: Isolated feature unit tests.
    - `tier2_boundary_corner_test.dart`: Boundary & edge case tests.
    - `tier3_cross_feature_test.dart`: Pairwise cross-feature interactions.
    - `tier4_real_world_scenarios_test.dart`: End-to-end full gameplay scenarios.
- **Test Harness Architecture:**
  - `TestWidgetsFlutterBinding.ensureInitialized()` is standard.
  - Mock handlers in `setUpAll`:
    - `xyz.luan/audioplayers.global` -> returns `1`
    - `xyz.luan/audioplayers` -> returns `1`
  - SharedPreferences initialization via `SharedPreferences.setMockInitialValues({})`.
  - Responsive screen sizing in widget tests: `tester.view.physicalSize = const Size(800, 1200); addTearDown(tester.view.resetPhysicalSize);`.

---

## 2. Requirement R8: Cosmetic Loadout Set Synergies

### 2.1 Problem Analysis
Currently, players equip Ball, Paddle, and Trail skins purely for visual aesthetics. Veteran and build-crafting players have no mechanical incentive to discover thematic loadout combinations. R8 introduces **Cosmetic Loadout Set Synergies** that dynamically compute active bonuses from the equipped `(paddleId, ballId, trailId)` trio, display an active synergy badge in `ShopView`, and apply gameplay benefits in `GameController`.

### 2.2 Existing Cosmetic Architecture
- **File:** `lib/models/cosmetics.dart`
  - `Rarity` enum (`common`, `rare`, `epic`, `legendary`).
  - `BallSkin.allSkins` (11 skins: `classic`, `pembe`, `plazma`, `zumrut`, `altin`, `golge`, `isilti`, `ates`, `kara_delik_top`, `gokkusagi`, `elmas_top`).
  - `PaddleSkin.allSkins` (8 skins: `pclassic`, `ppink`, `pice`, `pbat`, `pcyber`, `pdark`, `pgold`, `pnebula`).
  - `TrailSkin.allTrails` (7 trails: `t1`, `t2`, `spark`, `fire`, `rainbow`, `ghost`, `plasma`).
  - `SaveManager` (`lib/storage/save_manager.dart`) stores:
    - `save.activeBall` (String, default `'classic'`)
    - `save.activePaddle` (String, default `'pclassic'`)
    - `save.activeTrail` (String, default `'t1'`)
- Currently, there is **no `CosmeticCatalog` class** or **`CosmeticSynergy` enum/class** in `lib/models/cosmetics.dart`.

### 2.3 Proposed Architecture for R8

#### A. Model Definitions (`lib/models/cosmetics.dart`)
1. **`enum CosmeticSynergy`**:
   - Values:
     - `none`: Default state without set bonuses.
     - `fireSunset`:
       - Display Name: `🔥 Ateş / Günbatımı Sinerjisi` (`🔥 Fire / Sunset Synergy`)
       - Description: `+%15 Patlama Yarıçapı & Kombo Momentumu`
       - Attributes: `explosionRadiusBonus = 0.15`, `comboMomentumBonus = 0.15`
       - Theme Color: `Color(0xFFFF5722)`
     - `iceCrystal`:
       - Display Name: `❄️ Buz / Kristal Sinerjisi` (`❄️ Ice / Crystal Synergy`)
       - Description: `Buz/Zırhlı Bloklara Ekstra Hasar & Yavaşlama Direnci`
       - Attributes: `extraIceArmoredDamage = 1`, `slowResistance = 0.50`
       - Theme Color: `Color(0xFF00E5FF)`
     - `cosmicLegendary`:
       - Display Name: `👑 Kozmik Efsanevi Set` (`👑 Cosmic Legendary Set`)
       - Description: `+%15 Puan ve Altın Çarpanı`
       - Attributes: `scoreMultiplier = 1.15`, `goldMultiplier = 1.15`
       - Theme Color: `Color(0xFFFFD700)`

2. **`CosmeticCatalog` Class**:
   ```dart
   class CosmeticCatalog {
     static CosmeticSynergy getActiveSynergy(String? paddleId, String? ballId, String? trailId) {
       final pId = paddleId ?? 'pclassic';
       final bId = ballId ?? 'classic';
       final tId = trailId ?? 't1';

       // 1. Fire / Sunset synergy:
       final isFireBall = bId == 'ates';
       final isFireTrail = tId == 'fire' || tId == 'spark';
       final isFirePaddle = pId == 'pbat';
       if ((isFireBall && isFireTrail) || (isFireBall && isFirePaddle) || (isFirePaddle && isFireTrail)) {
         return CosmeticSynergy.fireSunset;
       }

       // 2. Ice / Crystal synergy:
       final isIcePaddle = pId == 'pice';
       final isIceBall = bId == 'elmas_top' || bId == 'plazma';
       final isIceTrail = tId == 'plasma' || tId == 't2';
       if ((isIcePaddle && isIceBall) || (isIcePaddle && isIceTrail)) {
         return CosmeticSynergy.iceCrystal;
       }

       // 3. Cosmic Legendary Set: 3x Epic / Legendary
       final bRarity = BallSkin.getById(bId).rarity;
       final pRarity = PaddleSkin.getById(pId).rarity;
       final tRarity = TrailSkin.getById(tId).rarity;
       final isBallHigh = bRarity == Rarity.epic || bRarity == Rarity.legendary;
       final isPaddleHigh = pRarity == Rarity.epic || pRarity == Rarity.legendary;
       final isTrailHigh = tRarity == Rarity.epic || tRarity == Rarity.legendary;
       if (isBallHigh && isPaddleHigh && isTrailHigh) {
         return CosmeticSynergy.cosmicLegendary;
       }

       return CosmeticSynergy.none;
     }
   }
   ```

#### B. ShopView UI Badge (`lib/ui/shop_view.dart`)
- **Location:** In `ShopView.build()`, right above `TabBarView` inside the `Scaffold` body.
- **Implementation:**
  - A dedicated `_buildActiveSynergyBadge(BuildContext context, SaveManager save)` widget.
  - Key: `const Key('active_cosmetic_synergy_badge')`.
  - When active (`synergy != CosmeticSynergy.none`):
    - Renders a styled cyberpunk/neon banner with glowing border, icon, synergy title (`synergy.nameTr`), and bonus pill tag.
  - When `synergy == CosmeticSynergy.none`:
    - Shows an informative subtle hint row encouraging the player to combine matching themes to unlock synergies.

#### C. Gameplay Bonus Integration (`lib/engine/game_controller.dart`)
- **Controller Property:**
  ```dart
  CosmeticSynergy get activeCosmeticSynergy => CosmeticCatalog.getActiveSynergy(save.activePaddle, save.activeBall, save.activeTrail);
  ```
- **Application points:**
  1. **Explosion Radius:**
     - Location: `_explodeArea(double cx, double cy, {double radius = 60.0})` (lines 2323-2346).
     - Modification:
       ```dart
       final synergyMult = activeCosmeticSynergy == CosmeticSynergy.fireSunset ? 1.15 : 1.0;
       final effectiveRadius = radius * synergyMult;
       ```
  2. **Combo Momentum:**
     - Location: `_registerCombo(int basePoints)` (lines 2358-2384).
     - Modification:
       ```dart
       final momentumMult = activeCosmeticSynergy == CosmeticSynergy.fireSunset ? 1.15 : 1.0;
       comboTimer = 2.4 * momentumMult;
       ```
  3. **Ice / Armored Brick Extra Damage:**
     - Location: brick hit processing (lines 2181-2187).
     - Modification:
       ```dart
       int dmg = 1;
       if (activeCosmeticSynergy == CosmeticSynergy.iceCrystal && (b.isIce || b.maxHp > 1 || b.isHeavySteel)) {
         dmg += 1;
       }
       ```
  4. **Slow Debuff Resistance:**
     - Location: `case PowerUpType.slow:` in `_applyPowerUp(type)` (lines 2549-2553).
     - Modification:
       ```dart
       final speedReduction = activeCosmeticSynergy == CosmeticSynergy.iceCrystal ? 0.82 : 0.65;
       for (final b in balls) {
         b.setSpeed(getBaseBallSpeed() * speedReduction);
       }
       ```
  5. **Score and Gold Multipliers:**
     - Location: `_registerCombo()` and coin collection (lines 2275-2282, 2381-2384).
     - Modification:
       ```dart
       if (activeCosmeticSynergy == CosmeticSynergy.cosmicLegendary) {
         multiplier *= 1.15;
         // and in gold awards:
         coins = (coins * 1.15).round();
       }
       ```

---

## 3. Requirement R9: Chaos Mode Roguelike 3-Card Perks & Wave-10 Chaos Bosses

### 3.1 Problem Analysis
Currently, Chaos Mode (`GameMode.chaos`) is a descending brick shooter where each turn drops new rows with +1 Ball pickups and balls are collected at the bottom launcher. While functional, it lacks run-to-run roguelike build variety and climactic milestones. R9 transforms Chaos Mode into a genuine roguelike experience by offering a **3-Card Perk Selection every 5 waves** and spawning **Chaos Boss Bricks every 10 waves** with high HP, warning alarms, and gold/pearl rewards.

### 3.2 Existing Chaos Mode Architecture
- **Files:**
  - `lib/engine/game_controller.dart` (lines 43-60, 262-270, 689-747, 1751-1778, 2835-2842).
  - `lib/models/level_design.dart` (lines 1280-1355: `buildChaosLevel`, `buildChaosRow`).
  - `lib/models/brick.dart` (has `isBoss`, `hp`, `maxHp`, `isBallPickup`).
- **Turn advancement:**
  - `_chaosAdvanceTurn()` executes when all balls return or timeout triggers.
  - If `remainingSolid.isEmpty`, `stats.level++`, stock resets to 3, and `loadLevelBricks()` loads the next wave.
  - Otherwise, bricks descend by `LevelDesign.chaosStep` and a new row is appended via `LevelDesign.buildChaosRow(stats.level, 0, screenWidth)`.

### 3.3 Proposed Architecture for R9

#### A. Chaos Perk System (`lib/engine/game_controller.dart`)
1. **`enum ChaosPerkType`**:
   ```dart
   enum ChaosPerkType {
     emberCore,    // Scorches hit bricks, +1 extra damage per turn/hit
     chainShock,   // Discharges electric arcs to up to 2 neighboring bricks
     microBlast,   // Trigger mini shockwave explosion on solid brick break
     magnetPull,   // Gravitationally pulls +1 ball orbs toward descending balls
     sniperSight,  // 2X extended precision trajectory aiming line
     goldenVolley; // +1 to +3 bonus gold per combo milestone and boss hit

     String get titleTr { ... }
     String get descriptionTr { ... }
     IconData get icon { ... }
     Color get color { ... }
   }
   ```
2. **State & Methods in `GameController`**:
   - `final List<ChaosPerkType> offeredChaosPerks = [];`
   - `final List<ChaosPerkType> activeChaosPerks = [];`
   - `void selectChaosPerk(ChaosPerkType perk)`:
     ```dart
     void selectChaosPerk(ChaosPerkType perk) {
       activeChaosPerks.add(perk);
       offeredChaosPerks.clear();
       audio.playSfx(GameSfx.powerup);
       particles.spawnBurst(screenWidth * 0.5, screenHeight * 0.5, perk.color, count: 20);
       notifyListeners();
     }
     ```
   - **Wave 5/10/15 Trigger:**
     - Inside `_chaosAdvanceTurn()` when `stats.level` increments:
       ```dart
       if (stats.level % 5 == 0) {
         final pool = List<ChaosPerkType>.from(ChaosPerkType.values)..shuffle(_rand);
         offeredChaosPerks
           ..clear()
           ..addAll(pool.take(3));
       }
       ```
   - **Headless Test Compatibility (Crucial Rule):**
     - Automated unit tests call `controller.update(dt)` and expect turns/physics to progress synchronously without waiting for user gestures.
     - Therefore, having `offeredChaosPerks.isNotEmpty` **MUST NOT** freeze the game loop or block `update()`. The player/UI can choose a perk at their leisure while headless simulations continue unhindered.

#### B. `BrickType` Enum & Chaos Boss Brick Integration (`lib/models/brick.dart`, `lib/models/level_design.dart`)
1. **`enum BrickType` in `lib/models/brick.dart`**:
   ```dart
   enum BrickType {
     normal,
     boss,
     steel,
     heavySteel,
     ice,
     dynamite,
     tuft,
     ballPickup,
   }
   ```
2. **`Brick` Backward-Compatible Integration**:
   - Add `BrickType? _explicitType;` to `Brick`.
   - `BrickType get type` returns `_explicitType ?? (isBoss ? BrickType.boss : (isSteel ? BrickType.steel : ...))`.
   - Setting `brick.isBoss = true` automatically aligns with `BrickType.boss`.
   - Constructor allows optional `BrickType? type`.
3. **Wave 10/20/30 Boss Spawn in `LevelDesign.buildChaosLevel` / `buildChaosRow`**:
   - When `wave % 10 == 0`:
     - Spawns a wide, reinforced Chaos Boss Brick at the top row:
       - `isBoss: true`, `type: BrickType.boss`
       - `hp: 40 + (wave ~/ 10) * 30`, `maxHp: ...`
       - `width: bw * 2.2`, `height: chaosBrickH * 1.5`
       - `color: const Color(0xFFFF1744)`
       - `points: 200`
4. **Warning Feedback & Defeat Drops in `GameController`**:
   - In `loadLevelBricks()`:
     ```dart
     if (currentMode == GameMode.chaos && stats.level % 10 == 0) {
       bossWarningTimer = 2.2;
       particles.triggerShake(5.5, 0.40);
       audio.playSfx(GameSfx.bossHit);
     }
     ```
   - In `_destroyBrick(Brick b)`:
     ```dart
     if (b.isBoss) {
       final bonusGold = 100 + (stats.level ~/ 10) * 50;
       save.addGold(bonusGold);
       save.addPearls(2); // If pearls system integrated
       particles.spawnShockwave(b.x + b.width / 2, b.y + b.height / 2, const Color(0xFFFFD700), maxRadius: 100.0);
     }
     ```

#### C. GameCanvas UI Overlay (`lib/ui/game_canvas.dart`)
- **Active Perks HUD Badges:**
  - Render compact perk icon chips at the top/side of the Chaos Mode canvas showing current active perks and stack counts.
- **3-Card Perk Dialog Overlay:**
  - When `controller.offeredChaosPerks.isNotEmpty && controller.currentMode == GameMode.chaos`, show a non-intrusive 3-card bottom/modal overlay allowing the player to tap a card to invoke `controller.selectChaosPerk(perk)`.

---

## 4. Test Harness Structure & Test Plan

### 4.1 Test Conventions in `test/game_test.dart`
- Group name: `Kirmatas Game Engine Tests`.
- Synchronous controller initialization:
  ```dart
  final gc = GameController();
  gc.setDimensions(360, 640);
  gc.startNewGame(GameMode.chaos);
  ```
- Method call mocking handles sound effects and haptics safely without platform channels.
- Widget tests use `testWidgets` with explicit layout pumps:
  ```dart
  testWidgets('...', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(const MaterialApp(home: ...));
    await tester.pump();
  });
  ```

### 4.2 Comprehensive New Test Cases to Implement

#### R8: Cosmetic Loadout Set Synergies
1. **`CosmeticCatalog.getActiveSynergy` returns `fireSunset` for Fire loadout:**
   - Input: `paddleId: 'pbat', ballId: 'ates', trailId: 'fire'`.
   - Expectation: `CosmeticSynergy.fireSunset`.
2. **`CosmeticCatalog.getActiveSynergy` returns `iceCrystal` for Ice loadout:**
   - Input: `paddleId: 'pice', ballId: 'elmas_top', trailId: 'plasma'`.
   - Expectation: `CosmeticSynergy.iceCrystal`.
3. **`CosmeticCatalog.getActiveSynergy` returns `cosmicLegendary` for 3x Epic/Legendary:**
   - Input: `paddleId: 'pgold', ballId: 'gokkusagi', trailId: 'plasma'`.
   - Expectation: `CosmeticSynergy.cosmicLegendary`.
4. **`CosmeticCatalog.getActiveSynergy` returns `none` for default/common loadout:**
   - Input: `paddleId: 'pclassic', ballId: 'classic', trailId: 't1'`.
   - Expectation: `CosmeticSynergy.none`.
5. **`ShopView` displays active synergy badge:**
   - Equip `ates`, `fire`, `pbat` in `SaveManager`.
   - Pump `ShopView`.
   - Expect: Badge is rendered with `Key('active_cosmetic_synergy_badge')` and contains text `'Ateş'`.
6. **`GameController` applies Fire synergy bonus to explosion radius:**
   - Set up `fireSunset` loadout.
   - Trigger `_explodeArea(100, 100, radius: 60)`.
   - Bricks within distance `69.0` (60 * 1.15) are destroyed.
7. **`GameController` applies Ice synergy bonus damage against armored/ice bricks:**
   - Set up `iceCrystal` loadout.
   - Ball hits ice brick with `hp: 2`.
   - Damage applied is 2 instead of 1.

#### R9: Chaos Mode Perks & Wave Bosses
8. **`ChaosPerkType` values and Turkish metadata validation:**
   - All 6 values (`emberCore`, `chainShock`, `microBlast`, `magnetPull`, `sniperSight`, `goldenVolley`) exist with non-empty titles and descriptions.
9. **Chaos Mode offers 3 distinct perks every 5 waves:**
   - In Chaos Mode, simulate clearing waves up to level 5.
   - Expect `gc.offeredChaosPerks.length == 3`.
   - Expect all 3 offered perks are unique.
10. **`selectChaosPerk` stacks perks in `activeChaosPerks` and clears offerings:**
    - Call `gc.selectChaosPerk(gc.offeredChaosPerks.first)`.
    - Expect `gc.activeChaosPerks.length == 1`.
    - Expect `gc.offeredChaosPerks.isEmpty == true`.
11. **Chaos Mode remains non-blocking in headless simulation:**
    - Leave `gc.offeredChaosPerks` unselected.
    - Call `gc.update(0.016)` across multiple ticks.
    - Turns advance and physics update without hanging or throwing.
12. **Chaos Mode Wave 10 spawns `BrickType.boss` with high HP and feedback:**
    - Advance or start at Wave 10.
    - Expect at least one brick has `b.isBoss == true && b.type == BrickType.boss`.
    - Expect `gc.bossWarningTimer > 0`.
13. **Defeating Chaos Boss grants bonus gold and rewards:**
    - Identify Chaos Boss brick.
    - Break boss brick.
    - Expect `save.gold` increases by >= 100.

---

## 5. Dependency & Integration Matrix

| Requirement | Primary Files | Secondary Files | Depends On | Notes |
|---|---|---|---|---|
| **R8** | `lib/models/cosmetics.dart` | `lib/ui/shop_view.dart`, `lib/engine/game_controller.dart` | `SaveManager` active cosmetic IDs | 100% backward compatible; no breaking schema changes. |
| **R9** | `lib/engine/game_controller.dart`, `lib/models/brick.dart` | `lib/models/level_design.dart`, `lib/ui/game_canvas.dart` | `SaveManager.addGold` (and `addPearls` if R5 adds it) | Must keep headless tests non-blocking when perks are offered. |
| **Health** | `test/game_test.dart` | `test/e2e/*` | Flutter test framework | Zero regression allowed across baseline 435 tests. |

---

## 6. Survey Conclusion
- The codebase is exceptionally clean with **0 analyzer issues** and **435/435 passing tests**.
- The architectures for R8 and R9 are thoroughly surveyed, with exact integration points identified.
- Implementation can proceed smoothly without risks of regressions.
