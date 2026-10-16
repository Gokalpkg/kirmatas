## 2026-10-16T13:42:16Z
You are Worker 3 for Milestone 2: Endgame Economy & Progression (Requirements R5, R6, R7).

Working Directory: c:\Users\USER\Desktop\KIPKIRMATAS\.agents\teamwork\worker_m2
Original User Request: c:\Users\USER\Desktop\KIPKIRMATAS\.agents\teamwork\ORIGINAL_REQUEST.md
Project Document: c:\Users\USER\Desktop\KIPKIRMATAS\PROJECT.md
Explorer Survey Report: c:\Users\USER\Desktop\KIPKIRMATAS\.agents\teamwork\explorer_survey_2\survey_report.md
Explorer Handoff: c:\Users\USER\Desktop\KIPKIRMATAS\.agents\teamwork\explorer_survey_2\handoff.md

Your mission is to implement R5, R6, and R7 completely and cleanly, verify via flutter analyze and flutter test, and add comprehensive unit/widget tests for R5, R6, R7 in test/game_test.dart.

File Write Ownership (You own these files exclusively for this milestone):
- lib/storage/save_manager.dart
- lib/ui/upgrades_view.dart
- lib/engine/game_controller.dart
- lib/ui/sector_map_view.dart
- lib/ui/tournament_dialog.dart (create this file)
- lib/ui/main_menu.dart
- test/game_test.dart

Detailed Requirements:
1. R5: Infinite "Cosmic Mastery" (Paragon) Gold & Pearl Sink:
   - In SaveManager:
     - Manage `pearls` (int getter/setter, persistent, `void addPearls(int amount)`).
     - `int get cosmicGoldMasteryLevel` (persistent).
     - `int get cosmicGoldMasteryCost => 1000 + cosmicGoldMasteryLevel * 500;`
     - `bool upgradeCosmicGoldMastery()` (spends gold, increments level, returns true on success).
     - `int get cosmicPearlMasteryLevel` (persistent).
     - `int get cosmicPearlMasteryCost => 5 + cosmicPearlMasteryLevel * 3;`
     - `bool upgradeCosmicPearlMastery()` (spends pearls, increments level, returns true on success).
   - In GameController:
     - Cosmic Gold Mastery bonuses: +2% brick/crit damage per level (`1.0 + save.cosmicGoldMasteryLevel * 0.02`), +2% gold gain per level on coin drops and level rewards (`1.0 + save.cosmicGoldMasteryLevel * 0.02`).
     - Cosmic Pearl Mastery bonuses: +2% ultimate charge rate per level (`1.0 + save.cosmicPearlMasteryLevel * 0.02`), +1% luck / capsule drop bonus per level (`save.cosmicPearlMasteryLevel * 0.01`).
   - In UpgradesView:
     - Render a dedicated section: **"🌌 KOZMİK USTALIK (SONSUZ SEVİYE)"** with upgrade cards for Gold Mastery and Pearl Mastery showing current levels, bonuses, and cost buttons.
     - Display current Pearl currency count in the AppBar (next to Gold).
2. R6: Daily Seeded Blitz ("Günün Operasyonu") & Infinite Prestige Sectors:
   - In GameController and SaveManager:
     - `void startDailyBlitz({DateTime? date})`: launch deterministic daily challenge seeded by date `YYYYMMDD`.
     - `bool get isDailyBlitzCompletedToday` tracked in SaveManager (deterministic date check).
     - `bool claimDailyBlitzReward()` awarding 250 Gold + 3 Pearls + 1 Cosmetic Shard (e.g. 'balls' category shard), callable only once per day (sets isDailyBlitzCompletedToday).
     - For levels > 238: remove hardcoded classic victory at 238; compute `int get prestigeTier => level > 238 ? ((level - 239) ~/ 17) + 1 : 0;`.
     - Procedurally scale brick HP (`hp += prestigeTier`) and gold multiplier (`prestigeGoldMultiplier = 1.0 + prestigeTier * 0.20`).
     - DO NOT modify `SectorData.allSectors.length == 14` (preserving existing test line 2891).
   - In SectorMapView:
     - Display Prestige Sector Omega when level > 238.
3. R7: Seasonal Championship Titles, Frames & Dynamic League Rivals:
   - Create `lib/ui/tournament_dialog.dart`:
     - Displays weekly league leaderboard with 15-player division.
     - Dynamically generates rival scores bracketing the player's active league tier and score pace.
   - In SaveManager:
     - `int get leagueTier` (0..4), `int get weeklyTournamentScore`.
     - `String get seasonalTitle`: computed across 5 tiers:
       - Tier 0: 'Çaylak Kırıcı'
       - Tier 1: 'Neon Avcısı'
       - Tier 2: 'Plazma Lordu'
       - Tier 3: 'Elmas Hükümdarı'
       - Tier 4: 'Kozmik İmparator'
   - In MainMenu:
     - Display active seasonal title and tier frame badge on the profile header.
     - Add button/card to open TournamentDialog.
4. Tests:
   - Add comprehensive unit and widget tests in test/game_test.dart covering R5, R6, R7.
   - Verify `flutter analyze` has 0 issues and `flutter test` passes 100%.
