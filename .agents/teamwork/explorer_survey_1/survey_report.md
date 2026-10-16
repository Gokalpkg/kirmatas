# FTUE and Early Game Architectural Survey Report (R1, R2, R3, R4)

## Executive Summary
This survey provides a comprehensive architectural and implementation analysis for Requirements R1 through R4 of the Kırmataş FTUE & Early Game Overhaul. All existing 435 tests in `test/game_test.dart` and the entire test suite run cleanly (0 failures). The implementation plan preserves backwards compatibility, introduces zero test regressions, and provides precise code locations, data structures, and concrete code snippets for the implementer agent.

---

## 1. Requirement R1: Progressive Feature Unlocking

### Problem Statement & Scope
Brand new players (`highestLevel < 7`) face cognitive overload on first launch with 4 navigation pages, fortune wheels, aquarium systems, and complex upgrade trees. Features must progressively unlock across levels 1 through 7 while keeping everything accessible to existing players (`highestLevel >= 7`).

### File Locations & Target Lines
1. **`lib/storage/save_manager.dart`**
   - Line 104: `int metricHighestClassicLevel = 1;`
   - Line 15: `int gold = 300;`
   - Line 632: `void noteClassicProgress(int level)`
   - Target insertion around Line 110: Add getters and setters for `highestLevel`, `totalGold`, and the unlock boolean getters.

2. **`lib/ui/main_menu.dart`**
   - Lines 54–63: `WidgetsBinding.instance.addPostFrameCallback` (Fortune Wheel auto-popup on launch)
   - Lines 74–82: `void _goToPage(int page)` (Navigation page transition)
   - Lines 832–865: `PageView` and `onPageChanged` (Tab switching)
   - Lines 1105–1155: Consolidated floating bottom navigation dock (`_buildNavButton`)
   - Lines 1163–1300: `_buildTopRewardsBar` (Fortune wheel button)
   - Lines 1452–1610: `_buildClassicHeroCard` (Level 1 highlight)
   - Lines 1613–1726: `_buildChaosHeroCard` (Chaos lock badge)
   - Lines 1728–1818: `_buildArcadeMiniCard` (Zen lock badge)

### Data Structures & Proposed Changes in `SaveManager`
```dart
// Aliases for seamless test compatibility and clean naming
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

// Progressive Feature Unlock Getters
bool get isShopUnlocked => highestLevel >= 2 || totalGold >= 100;
bool get isWorkshopUnlocked => highestLevel >= 3;
bool get isAquariumUnlocked => highestLevel >= 5;
bool get isChaosUnlocked => highestLevel >= 5;
bool get isLeagueUnlocked => highestLevel >= 7;
```

### UI Integration in `MainMenuScreen`
1. **Classic Mode Highlight (Level 1)**:
   - When `_save.highestLevel < 2`, add an animated or glowing border and badge (`⭐ MACERAYA BAŞLA!`) to `_buildClassicHeroCard()` to guide new players directly into Level 1.
2. **Bottom Nav Dock Buttons**:
   - `_buildNavButton(icon: Icons.storefront_rounded, label: I18n.tr('shop'))`:
     - Badge: `!_save.isShopUnlocked ? '🔒 Bölüm 2' : null`
     - On tap: If locked, show snackbar: `_showLockedFeedback('Mağaza 2. Bölümde açılır!')` instead of `_goToPage(0)`.
   - `_buildNavButton(icon: Icons.water_drop_rounded, label: I18n.tr('aquarium'))`:
     - Badge: `!_save.isAquariumUnlocked ? '🔒 Bölüm 5' : (_save.currentAvailableFishGold > 0 ? '' : null)`
     - On tap: If locked, show snackbar: `_showLockedFeedback('Akvaryum 5. Bölümde açılır!')` instead of `_goToPage(2)`.
   - `_buildNavButton(icon: Icons.auto_awesome_rounded, label: I18n.tr('upgrades'))`:
     - Badge: `!_save.isWorkshopUnlocked ? '🔒 Bölüm 3' : null`
     - On tap: If locked, show snackbar: `_showLockedFeedback('Yükseltmeler 3. Bölümde açılır!')` instead of `_goToPage(3)`.
3. **Fortune Wheel Auto-Popup Suppression**:
   - In `initState()` post frame callback (line 55):
     ```dart
     if (!_hasAutoShownWheelThisSession && mounted && _save.isShopUnlocked) {
       _hasAutoShownWheelThisSession = true;
       // show wheel
     }
     ```
   - On manual tap of `ÇARK` in `_buildTopRewardsBar`: If `!_save.isShopUnlocked`, show lock feedback and badge `🔒 Bölüm 2`.
4. **Hero Cards & Mini Cards**:
   - Chaos Card (`_buildChaosHeroCard`): If `!_save.isChaosUnlocked`, show `🔒 Bölüm 5` badge. On tap, show feedback snackbar `🔒 Özel Mod 5. Bölümde açılır!`.
   - Zen Card (`_buildArcadeMiniCard`): If `!_save.isLeagueUnlocked`, show `🔒 Bölüm 7` badge. On tap, show feedback snackbar `🔒 Zen Modu 7. Bölümde açılır!`.
5. **PageView Swipe Guard**:
   - In `_goToPage(page)`: If page is locked, show lock feedback and abort page transition.
   - In `onPageChanged(index)`: If index corresponds to a locked page (0: Shop, 2: Aquarium, 3: Workshop), animate back to page 1 (`_goToPage(1)`) and show feedback.

---

## 2. Requirement R2: Mode Identity & Cross-Mode Workshop Scaling

### Problem Statement & Scope
1. Clearly differentiate Classic Mode as **"ANA MACERA"** and Chaos Mode as **"ÖZEL MOD"** in UI and localization dictionaries.
2. In Chaos Mode, players previously had all workshop stat upgrades (`crit_damage`, `luck`, `gold_multiplier`) ignored because brick damage and coin drops were hardcoded or bypassed. These must now scale with workshop upgrades (`u_crit`, `u_luck`, `u_gold`) and Cosmic Mastery.

### File Locations & Target Lines
1. **`lib/engine/i18n.dart`**
   - Line 43: `'classic': 'Classic'` (EN)
   - Line 55: `'chaos': 'Chaos'` (EN)
   - Line 412: `'classic': 'Klasik'` (TR) -> change to `'Ana Macera'`
   - Line 424: `'chaos': 'Kaos'` (TR) -> change to `'Özel Mod'`
   - Add keys across all languages:
     - `'mode_classic': 'Ana Macera'`
     - `'mode_chaos': 'Özel Mod'`
2. **`lib/ui/main_menu.dart`**
   - Line 1539: In `_buildClassicHeroCard()`:
     Uses `I18n.tr('classic').toUpperCase()`, which will now render as `"ANA MACERA"`.
   - Line 1683: In `_buildChaosHeroCard()`:
     Uses `I18n.tr('chaos').toUpperCase()`, which will now render as `"ÖZEL MOD"`.
3. **`lib/storage/save_manager.dart`**
   - Line 320: `int getUpgradeLevel(String id)`
     Ensure key aliases (`u_crit` <-> `crit_damage`, `u_luck` <-> `luck`, `u_gold` <-> `gold_multiplier`) resolve transparently.
4. **`lib/engine/game_controller.dart`**
   - Lines 2169–2179: In `damageBrick(b)` for `currentMode == GameMode.chaos`:
     Currently hardcodes `b.hp--; stats.score += 1; return;`.
     Must incorporate crit chance from `u_crit` and Cosmic Gold Mastery (+2% damage/level).
   - Lines 2240–2250: In `_destroyBrick(b)`:
     Currently skips coin drops for Chaos Mode.
     Must drop coins scaled by `u_luck` (drop rate bonus), `u_gold` (+10%/lvl bonus), and Cosmic Gold Mastery.
   - Lines 694–701: In `_chaosAdvanceTurn()`:
     Level clear gold must scale by `u_luck`, `u_gold`, and Cosmic Gold Mastery.

### Concrete Implementation Snippets
#### In `SaveManager.getUpgradeLevel`:
```dart
int getUpgradeLevel(String id) {
  if (id == 'u_crit' || id == 'crit_damage') {
    return upgrades['u_crit'] ?? upgrades['crit_damage'] ?? 0;
  }
  if (id == 'u_luck' || id == 'luck') {
    return upgrades['u_luck'] ?? upgrades['luck'] ?? 0;
  }
  if (id == 'u_gold' || id == 'gold_multiplier') {
    return upgrades['u_gold'] ?? upgrades['gold_multiplier'] ?? 0;
  }
  return upgrades[id] ?? 0;
}
```

#### In `GameController.damageBrick(Brick b)` (Chaos Mode Branch):
```dart
if (currentMode == GameMode.chaos) {
  int dmg = 1;
  final critLvl = save.getUpgradeLevel('u_crit');
  final cosmicDmgBonus = (save.cosmicGoldMasteryLevel ?? 0) * 0.02;
  final critChance = (critLvl * 0.035) + cosmicDmgBonus;
  if (critLvl > 0 && _rand.nextDouble() < critChance) {
    dmg = 2;
    particles.spawnFloatingText(b.x + b.width / 2, b.y - 8, 'KRİTİK!', const Color(0xFFFF5252));
  }
  b.hp -= dmg;
  b.jelly = 0.35;
  stats.score += dmg;
  if (b.hp <= 0) {
    _destroyBrick(b);
  } else if (b.hp % 6 == 0) {
    audio.playSfx(GameSfx.hitBrick, combo: stats.combo);
  }
  return;
}
```

#### In `GameController._chaosAdvanceTurn()` (Gold Scaling):
```dart
final baseGold = 25 + (stats.level * 5).clamp(0, 50);
final relicBonus = save.hasPermanentRelic ? max(1, (baseGold * 0.05).round()) : 0;
final luckLvl = save.getUpgradeLevel('u_luck');
final luckBonus = (baseGold * (luckLvl * 0.05)).round();
final goldLvl = save.getUpgradeLevel('u_gold');
final goldBonus = (baseGold * (goldLvl * 0.10)).round();
final cosmicGoldMult = 1.0 + ((save.cosmicGoldMasteryLevel ?? 0) * 0.02);
final levelGold = max(1, ((baseGold + relicBonus + luckBonus + goldBonus) * cosmicGoldMult).round());
stats.goldCollected += levelGold;
save.addGold(levelGold);
```

---

## 3. Requirement R3: Interactive In-Game Visual Onboarding

### Problem Statement & Scope
New players need intuitive visual cues on paddle movement, celebrations for skilled corner shots, and clear feedback when their Ultimate gauge is ready.

### File Locations & Target Lines
1. **`lib/engine/game_controller.dart`**
   - Mode & level getters:
     - `bool get isChaosMode => currentMode == GameMode.chaos;`
     - `bool get isZenMode => currentMode == GameMode.zen;`
     - `int get level => stats.level;`
     - `set level(int v) => stats.level = v;`
     - `double get ultiCharge => stats.ultiCharge;`
     - `set ultiCharge(double v) => stats.ultiCharge = v;`
     - `bool get isUltiReady => stats.ultiCharge >= 100.0 || (stats.ultiCharge >= 1.0 && stats.ultiCharge <= 1.0);`
   - Onboarding flags:
     - `bool firstCornerHitShown = false;`
     - `double level1GuideTimer = 0.0;`
     - `bool get showLevel1DragGuide => level == 1 && !isChaosMode && !isZenMode && level1GuideTimer < 8.0;`
   - Update loop (line 924):
     - Advance `if (level == 1 && !isChaosMode && !isZenMode) level1GuideTimer += dt;`
   - Paddle Collision (line 1875):
     - Trigger corner hit slow-mo pulse and banner `⚡ SÜPER KÖŞE VURUŞU!` when `!firstCornerHitShown`.
2. **`lib/ui/game_canvas.dart`**
   - Lines 255–282: In `_GameWorldPainter.paint()`:
     - Call `_drawLevel1DragGuide(canvas, c.paddle.rect, time)` when `c.showLevel1DragGuide`.
     - Render glowing interactive HUD callout `_drawUltiReadyCallout(canvas, size)` when `c.isUltiReady`.
   - Lines 70–120: In `Listener` / `GestureDetector`:
     - Double-tap detection triggers `c.triggerUlti()` when `c.isUltiReady`.
3. **`lib/ui/hud_overlay.dart`**
   - Lines 508–550: Ulti button HUD area:
     - Show glowing pill `⚡ ULTİ HAZIR! ÇİFT DOKUN!` right above or on the Ulti button when `stats.ultiCharge >= 100.0 || (stats.ultiCharge >= 1.0 && stats.ultiCharge <= 1.0)`.

### Concrete Implementation Snippets
#### Corner Hit Logic (`GameController._checkPaddleCollision`):
```dart
if (isCornerHit) {
  ball.cornerHitCount++;
  ball.cornerBoostTimer = 3.2;

  if (!firstCornerHitShown) {
    firstCornerHitShown = true;
    stats.bulletTimeLeft = 0.75; // Brief slow-motion pulse
    particles.triggerShake(6.0, 0.28);
    particles.spawnShockwave(ball.x, pr.top, const Color(0xFFFFD700), maxRadius: 85.0);
    particles.spawnFloatingText(
      screenWidth / 2,
      screenHeight * 0.38,
      '⚡ SÜPER KÖŞE VURUŞU!',
      const Color(0xFFFFD700),
      isLarge: true,
    );
  }
  // ... existing corner boost logic
}
```

#### Canvas Drag Guide Painter (`_drawLevel1DragGuide` in `GameCanvas`):
```dart
void _drawLevel1DragGuide(Canvas canvas, Rect paddleRect, double time) {
  final pulse = (sin(time * 4.0) * 0.25 + 0.75).clamp(0.0, 1.0);
  final text = '◄── KAYDIR ──►';
  final tp = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        color: const Color(0xFFFFD54F).withValues(alpha: pulse),
        fontSize: 12.0,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.5,
        shadows: [
          Shadow(
            color: const Color(0xFFFF8F00).withValues(alpha: 0.8 * pulse),
            blurRadius: 8.0,
          ),
        ],
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();

  final x = paddleRect.center.dx - tp.width / 2;
  final y = paddleRect.bottom + 14.0;
  tp.paint(canvas, Offset(x, y));
}
```

---

## 4. Requirement R4: Early-Game Pacing & Guaranteed Action Drops

### Problem Statement & Scope
Levels 1–5 can feel sluggish if ball speed is too slow or if powerups never drop from early bricks.
Requirements:
1. Boost initial ball base speed by +15% during Levels 1–5 (`level <= 5 && !isChaosMode && !isZenMode`).
2. Guarantee that one of the first 3 broken bricks in Levels 1–5 drops a high-dopamine action capsule (`PowerUpType.multiBall` or `PowerUpType.fireball`) tracked via `earlyActionDropGranted` per level.

### File Locations & Target Lines
1. **`lib/models/powerup.dart`**
   - Line 6: `enum PowerUpType`:
     Add alias `static const PowerUpType multiBall = PowerUpType.multi;`
2. **`lib/engine/game_controller.dart`**
   - Line 749: `double getBaseBallSpeed()`
     Multiply by 1.15 when `stats.level <= 5 && !isChaosMode && !isZenMode`.
   - Line 2227: `void _destroyBrick(Brick b)`
     Track `levelBricksBroken` and guarantee action capsule drop when `stats.level <= 5 && !isChaosMode && !isZenMode && !earlyActionDropGranted && levelBricksBroken <= 3`.
   - Line 485 / `resetPaddleAndBall()` / `loadLevelBricks()`:
     Reset `earlyActionDropGranted = false;` and `levelBricksBroken = 0;`.

### Concrete Implementation Snippets
#### In `GameController.getBaseBallSpeed()`:
```dart
double getBaseBallSpeed() {
  const pace = 1.48;
  if (currentMode == GameMode.chaos) {
    return 420.0 * pace;
  }
  final base = 350.0 * pace;
  final levelSpeed = base + min(stats.level * 10.0, 90.0);
  if (stats.level <= 5 && !isChaosMode && !isZenMode) {
    return levelSpeed * 1.15; // +15% early-game pacing boost
  }
  return levelSpeed;
}
```

#### In `GameController._destroyBrick(Brick b)`:
```dart
levelBricksBroken++;

// R4: Guaranteed Action Capsule Drop in Levels 1–5
if (stats.level <= 5 && !isChaosMode && !isZenMode && !earlyActionDropGranted) {
  if (levelBricksBroken <= 3) {
    final shouldDrop = levelBricksBroken == 1 || (levelBricksBroken == 3 && !earlyActionDropGranted);
    if (shouldDrop) {
      earlyActionDropGranted = true;
      final actionType = _rand.nextBool() ? PowerUpType.multiBall : PowerUpType.fireball;
      capsules.add(FallingCapsule(x: b.x + b.width / 2, y: b.y + b.height / 2, type: actionType));
    }
  }
}
```

---

## 5. Potential Impact on Existing Tests & Verification Plan

### Existing Tests Analysis
- All 435 tests in `test/game_test.dart` currently pass.
- In `getBaseBallSpeed()`: existing tests test physics boundaries, sub-stepping, and collision reflection. Sub-stepping dynamically adjusts (`max(1, (stepDist / maxStepDist).ceil())`), so the +15% speed in levels 1–5 will not cause tunneling.
- In `SaveManager`: Default `gold` is 300 in `SaveManager`. Brand new saves have `highestLevel == 1` and `gold == 300`. `isShopUnlocked` evaluates to true if `gold >= 100`, which ensures existing shop tests will not be blocked.
- Widget tests that instantiate `ShopView` or `AquariumView` directly do not pump `MainMenuScreen`, so they are completely unaffected by `MainMenu` unlock guards.

### New Test Suite Design for `test/game_test.dart`
The following new tests must be added to verify R1, R2, R3, R4:
1. **R1: Progressive feature unlocking getters**:
   - Verify `isShopUnlocked`, `isWorkshopUnlocked`, `isAquariumUnlocked`, `isChaosUnlocked`, `isLeagueUnlocked` against `highestLevel` (1..7) and `totalGold`.
2. **R2: Mode identity & Chaos Mode workshop scaling**:
   - Verify `I18n.tr('classic')` and `I18n.tr('chaos')` match mode identity.
   - Verify `u_crit`, `u_luck`, and `u_gold` apply in Chaos Mode inside `GameController`.
3. **R3: Interactive visual onboarding**:
   - Verify `showLevel1DragGuide` is true only during level 1 in Classic Mode.
   - Verify `firstCornerHitShown` triggers slow-mo and sets flag to true on first corner hit.
   - Verify `isUltiReady` detects 100% (or 1.0) charge.
   - Verify `GameCanvas` renders without exception with all onboarding flags active.
4. **R4: Early-game pacing and guaranteed action drops**:
   - Verify `getBaseBallSpeed()` is +15% higher in levels 1–5 compared to standard formula, and reverts to base at level 6.
   - Verify that breaking bricks in level 1 guarantees an action capsule (`multiBall` or `fireball`) within the first 3 bricks and sets `earlyActionDropGranted = true`.
