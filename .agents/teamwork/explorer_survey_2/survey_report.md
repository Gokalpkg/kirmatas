# Comprehensive Survey Report: Endgame & Economy (R5, R6, R7)

**Author:** Explorer 2 (Endgame and Economy Investigator)  
**Date:** 2026-10-16  
**Scope:** Requirements R5 (Cosmic Mastery Paragon Sinks), R6 (Daily Seeded Blitz & Infinite Prestige Sectors), R7 (Seasonal Championship Titles, Frames & Dynamic League Rivals)  
**Target Codebase:** Kırmataş (`com.kaunos.kirmatas`)

---

## Executive Summary

This survey provides an exact architectural blueprint, code locations, state models, and test impact analysis for implementing Requirements R5, R6, and R7. The baseline codebase is completely healthy: `flutter analyze` passes with zero issues, and all 435 tests in `test/game_test.dart` pass cleanly.

Requirements R5, R6, and R7 address the 183-hour veteran economy inflation, post-238 sector dead-end, and competitive league replayability. None of these features require breaking existing storage structures, physics loops, or test assertions. All additions are strictly additive, backwards-compatible, and seamlessly integrated into the existing reactive Flutter architecture.

---

## 1. Requirement R5: Infinite Cosmic Mastery (Paragon) Gold & Pearl Sink

### 1.1 Objective & Design
- Create uncapped endgame sinks for veteran players who accumulate surplus Gold and Pearls.
- **Cosmic Gold Mastery (`cosmicGoldMasteryLevel`)**:
  - Upgraded with Gold via `SaveManager.instance.upgradeCosmicGoldMastery()`.
  - Cost scaling: `1000 + cosmicGoldMasteryLevel * 500` (e.g. 1000, 1500, 2000, 2500...).
  - Gameplay effect: +2% brick/crit damage bonus and +2% gold gain per level across all modes.
- **Cosmic Pearl Mastery (`cosmicPearlMasteryLevel`)**:
  - Upgraded with Pearls via `SaveManager.instance.upgradeCosmicPearlMastery()`.
  - Cost scaling: `5 + cosmicPearlMasteryLevel * 3` (e.g. 5, 8, 11, 14, 17...).
  - Gameplay effect: +2% ultimate charge rate and +1% luck/dice bonus per level.
- **UI in `UpgradesView` (`lib/ui/upgrades_view.dart`)**:
  - Render a dedicated section: **"🌌 KOZMİK USTALIK (SONSUZ SEVİYE)"**.
  - Show current level, active cumulative stat bonus, cost button, and affordability state.
  - Display both Gold and Pearls chips in the `UpgradesView` AppBar.

### 1.2 Code Locations & Exact Integration Points

#### A. `lib/storage/save_manager.dart`
- **Existing Currency State (lines 15, 38)**:
  `SaveManager` currently tracks `int gold = 300;` and `categoryShards`. It does not yet track `pearls`.
- **New State Variables to Add**:
  ```dart
  int pearls = 0;
  int cosmicGoldMasteryLevel = 0;
  int cosmicPearlMasteryLevel = 0;
  ```
- **Serialization in `init()` (around line 124)**:
  ```dart
  pearls = _prefs?.getInt('pearls') ?? 0;
  cosmicGoldMasteryLevel = _prefs?.getInt('cosmicGoldMasteryLevel') ?? 0;
  cosmicPearlMasteryLevel = _prefs?.getInt('cosmicPearlMasteryLevel') ?? 0;
  ```
- **Methods to Add**:
  ```dart
  int get cosmicGoldMasteryCost => 1000 + cosmicGoldMasteryLevel * 500;
  int get cosmicPearlMasteryCost => 5 + cosmicPearlMasteryLevel * 3;

  Future<void> addPearls(int count) async {
    if (count <= 0) return;
    pearls += count;
    await _prefs?.setInt('pearls', pearls);
    notifyListeners();
  }

  Future<bool> spendPearls(int count) async {
    if (count <= 0) return true;
    if (pearls < count) return false;
    pearls -= count;
    await _prefs?.setInt('pearls', pearls);
    notifyListeners();
    return true;
  }

  Future<bool> upgradeCosmicGoldMastery() async {
    final cost = cosmicGoldMasteryCost;
    if (gold < cost) return false;
    final ok = await spendGold(cost);
    if (!ok) return false;
    cosmicGoldMasteryLevel++;
    await _prefs?.setInt('cosmicGoldMasteryLevel', cosmicGoldMasteryLevel);
    notifyListeners();
    return true;
  }

  Future<bool> upgradeCosmicPearlMastery() async {
    final cost = cosmicPearlMasteryCost;
    if (pearls < cost) return false;
    final ok = await spendPearls(cost);
    if (!ok) return false;
    cosmicPearlMasteryLevel++;
    await _prefs?.setInt('cosmicPearlMasteryLevel', cosmicPearlMasteryLevel);
    notifyListeners();
    return true;
  }
  ```

#### B. `lib/ui/upgrades_view.dart`
- **AppBar Actions (lines 41-65)**:
  Currently displays only `save.gold`. Add a matching Pearl currency chip:
  ```dart
  Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: const Color(0xFF22162B),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0x66E040FB)),
    ),
    child: Row(
      children: [
        const Icon(Icons.lens_blur_rounded, color: Color(0xFFE040FB), size: 16),
        const SizedBox(width: 5),
        Text('${save.pearls}', style: const TextStyle(color: Color(0xFFE040FB), fontWeight: FontWeight.w900, fontSize: 14)),
      ],
    ),
  ),
  ```
- **New Section in `ListView` (after Section 3 or before Section 1)**:
  Place **"🌌 KOZMİK USTALIK (SONSUZ SEVİYE)"**:
  - Cosmic Gold Card:
    - Icon: `Icons.stars_rounded` in `Color(0xFFFFD54F)`
    - Title: `I18n.tr('cosmic_gold_title')` / "Kozmik Altın Ustalığı"
    - Subtitle: "+${save.cosmicGoldMasteryLevel * 2}% Tuğla/Kritik Hasar & +${save.cosmicGoldMasteryLevel * 2}% Altın"
    - Level Badge: `Sv. ${save.cosmicGoldMasteryLevel}`
    - Button: Cost `save.cosmicGoldMasteryCost` with gold icon; disabled if `save.gold < cost`.
  - Cosmic Pearl Card:
    - Icon: `Icons.all_inclusive_rounded` in `Color(0xFFE040FB)`
    - Title: `I18n.tr('cosmic_pearl_title')` / "Kozmik İnci Ustalığı"
    - Subtitle: "+${save.cosmicPearlMasteryLevel * 2}% Ulti Hızı & +${save.cosmicPearlMasteryLevel}% Şans Bonusu"
    - Level Badge: `Sv. ${save.cosmicPearlMasteryLevel}`
    - Button: Cost `save.cosmicPearlMasteryCost` with pearl icon; disabled if `save.pearls < cost`.

#### C. `lib/engine/game_controller.dart`
- **Damage Bonus Application (lines 2181-2187)**:
  ```dart
  int dmg = 1;
  final critLvl = save.getUpgradeLevel('crit_damage');
  final cosmicGold = save.cosmicGoldMasteryLevel;
  final cosmicDmgBonus = cosmicGold * 0.02;

  // Base damage chance or crit boost:
  if (critLvl > 0 && _rand.nextDouble() < (critLvl * 0.035 + cosmicDmgBonus * 0.5)) {
    dmg = 2;
    if (_rand.nextDouble() < cosmicDmgBonus) dmg += 1; // Extra mastery punch
    particles.spawnFloatingText(b.x + b.width / 2, b.y - 8, 'KRİTİK!', const Color(0xFFFF5252));
  } else if (cosmicDmgBonus > 0 && _rand.nextDouble() < cosmicDmgBonus) {
    dmg = 2; // Cosmic mastery strike
  }
  b.hp -= dmg;
  ```
- **Gold Bonus Application (lines 698-701, 2277-2281, 2874-2876)**:
  ```dart
  // In coin drops (_destroyBrick, line 2277):
  int coins = 2 + _rand.nextInt(4);
  if (stats.combo >= 5) coins += 2;
  if (save.cosmicGoldMasteryLevel > 0) {
    coins = (coins * (1.0 + save.cosmicGoldMasteryLevel * 0.02)).round();
  }
  stats.goldCollected += coins;
  save.addGold(coins);

  // In level clear gold (_onLevelClear, lines 698, 2874):
  double goldMultiplier = 1.0 + (save.cosmicGoldMasteryLevel * 0.02);
  final levelGold = (baseGoldCalc * goldMultiplier).round();
  ```
- **Ultimate Charge Rate Bonus (lines 1884, 2223-2224)**:
  ```dart
  // In _chargeDiceFromGlass (line 2223):
  final batteryLvl = save.getUpgradeLevel('battery');
  final pearlMastery = save.cosmicPearlMasteryLevel;
  final ultiGain = (1.0 + (batteryLvl * 0.4)) * (1.0 + (pearlMastery * 0.02));
  stats.ultiCharge = (stats.ultiCharge + ultiGain).clamp(0.0, 100.0);

  // In corner hit (line 1884):
  final cornerGain = 3.0 * (1.0 + (pearlMastery * 0.02));
  stats.ultiCharge = (stats.ultiCharge + cornerGain).clamp(0.0, 100.0);
  ```
- **Luck / Dice Bonus (lines 2422, 2754)**:
  ```dart
  // In _rollCapsuleDrop (line 2422):
  final luckLevel = save.upgrades['luck'] ?? 0;
  final pearlMastery = save.cosmicPearlMasteryLevel;
  final dropChance = 0.14 + luckLevel * 0.04 + (pearlMastery * 0.01);

  // In triggerUlti double dice jackpot (line 2754):
  final jackpotChance = 0.25 + (pearlMastery * 0.01);
  isDoubleDice = _rand.nextDouble() < jackpotChance;
  ```

---

## 2. Requirement R6: Daily Seeded Blitz ("Günün Operasyonu") & Infinite Prestige Sectors

### 2.1 Objective & Design
- **Daily Seeded Blitz ("Günün Operasyonu")**:
  - Deterministic daily challenge level seeded by current date `YYYYMMDD` (e.g., `20261016`).
  - Executed via `GameController.startDailyBlitz()`.
  - Once per day completion tracked via `SaveManager.instance.isDailyBlitzCompletedToday`.
  - Completion bonus awarded via `SaveManager.instance.claimDailyBlitzReward()`:
    - +250 Gold
    - +3 Pearls
    - +1 Cosmetic Shard (e.g. `balls`)
- **Infinite Prestige Sectors (Beyond Level 238)**:
  - Sector 14 ends at Level 238. Levels beyond 238 (`level > 238`) trigger Prestige Omega Tiers:
    `int get prestigeTier => level > 238 ? ((level - 239) ~/ 17) + 1 : 0;`
  - Brick HP scaling: `hp += prestigeTier;` (and Boss HP `+ prestigeTier * 25`).
  - Prestige Gold Multiplier: `1.0 + (prestigeTier * 0.20)`.
  - Prevent classic mode from stopping or declaring victory at Level 238 (modify line 2863 of `game_controller.dart`).
  - In `SectorMapView`, render Prestige Omega indicator and infinite tier milestone banner.

### 2.2 Code Locations & Exact Integration Points

#### A. `lib/storage/save_manager.dart`
- **Fields to Add**:
  ```dart
  String? lastDailyBlitzDate;
  ```
- **Getters & Methods**:
  ```dart
  bool get isDailyBlitzCompletedToday {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    return lastDailyBlitzDate == today;
  }

  Future<bool> claimDailyBlitzReward() async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    if (lastDailyBlitzDate == today) return false;
    lastDailyBlitzDate = today;
    await _prefs?.setString('lastDailyBlitzDate', today);

    await addGold(250);
    await addPearls(3);
    await addShard('balls', 1);
    notifyListeners();
    return true;
  }

  int get prestigeTier {
    final lvl = classicSavedLevel ?? metricHighestClassicLevel;
    return lvl > 238 ? ((lvl - 239) ~/ 17) + 1 : 0;
  }

  static int calculatePrestigeTier(int level) {
    return level > 238 ? ((level - 239) ~/ 17) + 1 : 0;
  }
  ```

#### B. `lib/engine/game_controller.dart`
- **Prestige Tier Getters**:
  ```dart
  int get prestigeTier => stats.level > 238 ? ((stats.level - 239) ~/ 17) + 1 : 0;
  double get prestigeGoldMultiplier => prestigeTier > 0 ? (1.0 + prestigeTier * 0.20) : 1.0;
  ```
- **`startDailyBlitz()` Method**:
  ```dart
  void startDailyBlitz({DateTime? date}) {
    final targetDate = date ?? DateTime.now();
    startNewGame(GameMode.daily);
    // Explicitly load daily bricks with YYYYMMDD seed
    bricks = LevelDesign.buildDailyLevel(targetDate, screenWidth, screenHeight);
    _hasLoadedBricks = bricks.isNotEmpty;
    _loadedBricksRef = bricks;
    status = GameStatus.ready;
    notifyListeners();
  }
  ```
- **Deterministic Seeding in `LevelDesign.buildDailyLevel` (`lib/models/level_design.dart` line 1358)**:
  Current code:
  `final seed = date.year * 1000 + date.month * 100 + date.day;`
  Format to exact YYYYMMDD:
  `final seed = date.year * 10000 + date.month * 100 + date.day;`
- **Infinite Level Flow in Classic Mode (`lib/engine/game_controller.dart` line 2862)**:
  Current code:
  ```dart
  if (currentMode == GameMode.daily ||
      (currentMode == GameMode.classic && stats.level >= 238) ||
      (currentMode == GameMode.shapes && stats.level >= 38)) {
    if (AdManager.instance.registerLevelClear()) pendingLevelInterstitial = true;
    _onVictory();
  }
  ```
  Modified code:
  ```dart
  if (currentMode == GameMode.daily) {
    if (AdManager.instance.registerLevelClear()) pendingLevelInterstitial = true;
    save.claimDailyBlitzReward();
    _onVictory();
  } else if (currentMode == GameMode.shapes && stats.level >= 38) {
    if (AdManager.instance.registerLevelClear()) pendingLevelInterstitial = true;
    _onVictory();
  } else {
    // Classic Mode continues past 238 into Prestige Tiers!
    levelTransitionTimer = 0.65;
    ...
  ```
- **Brick HP Scaling in Prestige Levels (`lib/models/level_design.dart` lines 875, 1078)**:
  When `level > 238`:
  `final prestige = ((level - 239) ~/ 17) + 1;`
  In boss levels: `bossHp += prestige * 25;`
  In normal grid bricks: `if (!isSteel && !isHeavySteel && !isIce && !isDynamite) hp += prestige;`

#### C. `lib/ui/sector_map_view.dart` & `MainMenu`
- **`SectorMapView` (`lib/ui/sector_map_view.dart` line 332)**:
  Update header text:
  ```dart
  Text(
    highest > 238
        ? 'Prestij $prestigeTier  •  Bölüm $highest (Sonsuz Omega)'
        : 'Bölüm $highest / 238  •  %$percent Tamamlandı',
    style: const TextStyle(color: Color(0xFFFFD54F), fontSize: 11.5, fontWeight: FontWeight.w700),
  ),
  ```
  Add Prestige Omega milestone card at the end of the 14-sector list if `highest >= 238`.
- **`MainMenu` (`lib/ui/main_menu.dart` line 1525)**:
  Update badge:
  ```dart
  Text(
    _save.prestigeTier > 0
        ? 'PRESTİJ ${_save.prestigeTier} • SEKTÖR 14/14 🌌'
        : 'SEKTÖR ${_save.highestUnlockedSector}/14 🗺️',
    style: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.w900),
  ),
  ```
  Also in `_buildTopRewardsBar` or arcade section, add a direct "GÜNÜN OPERASYONU" launch tile displaying reward badge or completion tick.

---

## 3. Requirement R7: Seasonal Championship Titles, Frames & Dynamic League Rivals

### 3.1 Objective & Design
- **Seasonal Championship Titles & Avatar Frames**:
  - Tiers (0 to 4):
    0: *Çaylak Kırıcı* (Bronze Frame)
    1: *Neon Avcısı* (Neon Cyan Glowing Frame)
    2: *Plazma Lordu* (Plasma Purple Shimmering Frame)
    3: *Elmas Hükümdarı* (Diamond Frost Pulsing Frame)
    4: *Kozmik İmparator* (Cosmic Radiant Gold/Rainbow Frame)
  - Accessible via `SaveManager.instance.seasonalTitle` and `SaveManager.instance.leagueTier`.
  - Displayed prominently in `MainMenu` (Profile header pill) and `TournamentDialog`.
- **Dynamic League Rivals**:
  - Generates 14 realistic bot rivals + the player (15-person division).
  - Scores dynamically scale with the active tier and weekly pace:
    - Tier 0: 500 – 2,500 pts
    - Tier 1: 2,000 – 8,000 pts
    - Tier 2: 7,000 – 20,000 pts
    - Tier 3: 18,000 – 50,000 pts
    - Tier 4: 45,000 – 120,000 pts
  - Player's weekly tournament points are tracked in `weeklyTournamentScore` and ranked accurately in the division.
- **`TournamentDialog` (`lib/ui/tournament_dialog.dart`)**:
  - Modal bottom sheet / dialog displaying division countdown, player profile avatar with animated frame, seasonal title, current rank, and division leaderboard (Top 3 promotion zone ⬆️, Safe zone, Bottom 5 demotion zone ⬇️).

### 3.2 Code Locations & Exact Integration Points

#### A. `lib/storage/save_manager.dart`
- **Fields to Add**:
  ```dart
  int leagueTier = 0; // 0..4
  int weeklyTournamentScore = 0;
  String? currentLeagueWeek;
  ```
- **Serialization in `init()`**:
  ```dart
  leagueTier = _prefs?.getInt('leagueTier') ?? 0;
  weeklyTournamentScore = _prefs?.getInt('weeklyTournamentScore') ?? 0;
  currentLeagueWeek = _prefs?.getString('currentLeagueWeek');
  ```
- **Getters & Methods**:
  ```dart
  static const List<String> seasonalTitles = [
    'Çaylak Kırıcı',
    'Neon Avcısı',
    'Plazma Lordu',
    'Elmas Hükümdarı',
    'Kozmik İmparator',
  ];

  String get seasonalTitle => seasonalTitles[leagueTier.clamp(0, seasonalTitles.length - 1)];

  Color get leagueTierColor {
    switch (leagueTier) {
      case 1: return const Color(0xFF00E5FF);
      case 2: return const Color(0xFFE040FB);
      case 3: return const Color(0xFF80D8FF);
      case 4: return const Color(0xFFFFD700);
      default: return const Color(0xFFCD7F32);
    }
  }

  void addTournamentPoints(int points) {
    if (points <= 0) return;
    weeklyTournamentScore += points;
    _prefs?.setInt('weeklyTournamentScore', weeklyTournamentScore);
    notifyListeners();
  }

  void setLeagueTier(int tier) {
    leagueTier = tier.clamp(0, 4);
    _prefs?.setInt('leagueTier', leagueTier);
    notifyListeners();
  }

  List<LeagueRival> getLeagueRivals() {
    final rng = Random(DateTime.now().year * 100 + DateTime.now().month);
    final rivalNames = [
      'DemirBilek', 'PikselUsta', 'NeonFırtına', 'KozmikGezgin',
      'YıldızAvcısı', 'GlitchKing', 'AuraBreaker', 'GölgeSavaşçı',
      'NovaKıran', 'SiberPence', 'KuvarsGozu', 'EterYolcusu',
      'FotonUstası', 'ZirveBekçisi'
    ];

    final minScore = [600, 2500, 8000, 20000, 50000][leagueTier.clamp(0, 4)];
    final maxScore = [2800, 9500, 24000, 55000, 130000][leagueTier.clamp(0, 4)];

    final List<LeagueRival> list = [];
    for (int i = 0; i < rivalNames.length; i++) {
      final score = minScore + rng.nextInt(maxScore - minScore);
      list.add(LeagueRival(name: rivalNames[i], score: score, isPlayer: false));
    }

    list.add(LeagueRival(name: 'SEN', score: weeklyTournamentScore, isPlayer: true));
    list.sort((a, b) => b.score.compareTo(a.score));

    for (int i = 0; i < list.length; i++) {
      list[i].rank = i + 1;
    }
    return list;
  }
  ```

#### B. `lib/ui/tournament_dialog.dart` (New File)
- **Structure**:
  ```dart
  class LeagueRival {
    final String name;
    final int score;
    final bool isPlayer;
    int rank;
    LeagueRival({required this.name, required this.score, required this.isPlayer, this.rank = 0});
  }

  class TournamentDialog extends StatelessWidget {
    final SaveManager save;
    const TournamentDialog({super.key, required this.save});

    static Future<void> show(BuildContext context, {required SaveManager save}) {
      return showModalBottomSheet(
        context: context,
        backgroundColor: const Color(0xFF0F1322),
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        builder: (_) => TournamentDialog(save: save),
      );
    }
    ...
  }
  ```
- **Features in Dialog**:
  - Division header with countdown timer ("3 Gün Kaldı").
  - Player Profile Card with avatar framed in `save.leagueTierColor`.
  - Seasonal title chip (`save.seasonalTitle`).
  - Active rank badge (e.g. `#2 / 15`).
  - Leaderboard view with promotion/safe/demotion visual brackets.
  - Action button: "MÜCADELEYE KATIL" (launches game).

#### C. `lib/ui/main_menu.dart`
- **Header Profile Pill (lines 875-915)**:
  In the top row of `_buildMainMenuHome()`, add a central or left-aligned player profile badge:
  ```dart
  GestureDetector(
    onTap: () => TournamentDialog.show(context, save: _save),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0x99101320),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _save.leagueTierColor, width: 1.5),
        boxShadow: [
          BoxShadow(color: _save.leagueTierColor.withValues(alpha: 0.35), blurRadius: 8),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.military_tech_rounded, color: _save.leagueTierColor, size: 16),
          const SizedBox(width: 6),
          Text(
            _save.seasonalTitle,
            style: TextStyle(color: _save.leagueTierColor, fontWeight: FontWeight.w900, fontSize: 11.5),
          ),
        ],
      ),
    ),
  ),
  ```

---

## 4. Test Impact Analysis & Verification Strategy

### 4.1 Existing Tests (`test/game_test.dart` - 435 tests)
1. **Sector Boundaries Test (`test/game_test.dart:2890`)**:
   - `expect(SectorData.allSectors.length, 14);`
   - `expect(SectorData.allSectors.first.startLevel, 1);`
   - `expect(SectorData.allSectors.last.endLevel, 238);`
   - **Safety Guarantee**: `SectorData.allSectors` remains exactly 14 sectors. Post-238 prestige is calculated dynamically via `prestigeTier = level > 238 ? ((level - 239) ~/ 17) + 1 : 0`, and `SectorData.getSectorForLevel` returns sector 14 for `level > 238`. No existing sector tests will be invalidated.
2. **SaveManager Init & Currency Tests**:
   - `pearls`, `cosmicGoldMasteryLevel`, `cosmicPearlMasteryLevel`, `leagueTier`, `lastDailyBlitzDate` all have safe default initializers (`0`, `0`, `0`, `0`, `null`).
   - All tests calling `await save.init()` or accessing existing upgrades continue to pass unchanged.
3. **GameController Physics & Level Clear Tests**:
   - Level 1-238 layout and physics remain identical.
   - Prestige scaling only activates when `stats.level > 238`.

### 4.2 New Unit & Widget Tests to Add
1. **R5 Unit Tests**:
   - `SaveManager` cosmic gold mastery upgrade: verify cost calculation (`1000 + level*500`), gold deduction, and level increment.
   - `SaveManager` cosmic pearl mastery upgrade: verify cost calculation (`5 + level*3`), pearl deduction, and level increment.
   - `GameController` stat application: verify damage boost, gold multiplier, ulti charge rate scaling, and luck drop rate bonus.
   - `UpgradesView` widget test: verify rendering of "🌌 KOZMİK USTALIK (SONSUZ SEVİYE)" section.
2. **R6 Unit Tests**:
   - `isDailyBlitzCompletedToday` getter and `claimDailyBlitzReward()` awarding 250 Gold, 3 Pearls, 1 Shard.
   - Single claim per calendar day constraint.
   - `startDailyBlitz()` starting deterministic daily mode level.
   - `prestigeTier` calculation across levels (1-238 => 0, 239 => 1, 255 => 1, 256 => 2).
   - Infinite classic mode progression beyond Level 238.
3. **R7 Unit Tests**:
   - `SaveManager.seasonalTitle` mapping from `leagueTier` (0: *Çaylak Kırıcı*, 1: *Neon Avcısı*, 2: *Plazma Lordu*, 3: *Elmas Hükümdarı*, 4: *Kozmik İmparator*).
   - `getLeagueRivals()` generating 15 division competitors with dynamic score scaling.
   - `TournamentDialog` widget test: verifies rendering of title, rank, avatar frame, and division leaderboard.
   - `MainMenu` widget test: verifies display of seasonal title and league badge.

---

## 5. Architectural Synthesis & Implementation Checklist

| Component | Target File | New/Modified Identifiers |
|---|---|---|
| **Pearls & Cosmic Mastery State** | `lib/storage/save_manager.dart` | `pearls`, `cosmicGoldMasteryLevel`, `cosmicPearlMasteryLevel`, `upgradeCosmicGoldMastery()`, `upgradeCosmicPearlMastery()`, `cosmicGoldMasteryCost`, `cosmicPearlMasteryCost`, `addPearls()`, `spendPearls()` |
| **Cosmic Mastery Section** | `lib/ui/upgrades_view.dart` | "🌌 KOZMİK USTALIK (SONSUZ SEVİYE)" section, Gold & Pearl AppBar chips |
| **Cosmic Stat Scaling** | `lib/engine/game_controller.dart` | `cosmicGoldMasteryLevel` dmg/gold bonus, `cosmicPearlMasteryLevel` ulti/luck bonus |
| **Daily Blitz Challenge** | `lib/storage/save_manager.dart` | `lastDailyBlitzDate`, `isDailyBlitzCompletedToday`, `claimDailyBlitzReward()` |
| **Daily Blitz Execution** | `lib/engine/game_controller.dart` | `startDailyBlitz({DateTime? date})`, deterministic YYYYMMDD seed |
| **Prestige Omega Tiers** | `lib/storage/save_manager.dart` & `lib/engine/game_controller.dart` | `prestigeTier`, `prestigeGoldMultiplier`, continuous classic mode progression past 238 |
| **Prestige Map UI** | `lib/ui/sector_map_view.dart` | Prestige Omega header text and milestone badge |
| **Seasonal Titles & League Rivals** | `lib/storage/save_manager.dart` | `leagueTier`, `weeklyTournamentScore`, `seasonalTitle`, `leagueTierColor`, `getLeagueRivals()`, `addTournamentPoints()` |
| **Tournament Dialog** | `lib/ui/tournament_dialog.dart` (NEW) | `TournamentDialog.show()`, `LeagueRival`, animated avatar frames, leaderboard |
| **MainMenu League Profile** | `lib/ui/main_menu.dart` | Profile title badge, avatar frame, tournament launch shortcut |
| **Automated Tests** | `test/game_test.dart` | Comprehensive test suite for R5, R6, R7 |

---

## Conclusion
The survey confirms that R5, R6, and R7 can be cleanly implemented without any architectural friction, without breaking existing tests, and with full fidelity to the user's high-quality game feel standards.
