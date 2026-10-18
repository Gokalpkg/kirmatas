# Project: Kırmataş Büyük Evrim Paketi

## Architecture
Kırmataş Arcade & Eco-Tank evolutionary upgrade targeting menu decluttering, game feel/juice, economy balance, thematic progression, and player retention.
- **Frontend / UI**:
  - `lib/ui/main_menu.dart`: Decluttered layout with dynamic "Etkinlikler & Lig" Live-Ops card, cleaned bottom dock (Shop, Aquarium, Workshop), and header profile badge.
  - `lib/ui/settings_dialog.dart`: Extracted dedicated settings dialog containing audio/haptics, language, tour, and isolated progress backup (export/import).
  - `lib/ui/tournament_dialog.dart`: Upgraded dual-tab Events & League hub (Tab 1: Haftalık Lig, Tab 2: Günlük Görevler & Blitz).
  - `lib/ui/sector_map_view.dart`: Thematic 20-level worlds/sectors path with Sector Boss indicators and Sektör Zafer Sandığı visual milestones.
  - `lib/ui/crate_opening_dialog.dart`: Sektör Zafer Sandığı (Sector Victory Crate) opening sequence upon clearing every 20th boss level.
  - `lib/ui/hud_overlay.dart` & `lib/ui/upgrades_view.dart`: Aquarium fish passive synergy badges and live indicators.
  - `lib/ui/daily_login_dialog.dart`: Upgraded 7-day login streak calendar with guaranteed Day 7 legendary reward.
  - `lib/ui/offline_earnings_dialog.dart`: 12-hour capped offline earnings celebration pop-up.
- **Game Engine & Audio**:
  - `lib/engine/game_controller.dart`: Near-miss paddle edge detection (hitOffset >= 0.90) with 0.2s bullet time; Last life tension trigger (`stats.lives == 1`); Combo fever tracking (x3, x5) with coin drop multiplier; Aquarium fish passive synergies (explosion radius, paddle width, crit rate, gold multiplier); Sector Boss spawning on level 20, 40, 60...
  - `lib/ui/game_canvas.dart`: Fullscreen neon edge flash for near-miss; breathing red vignette for last life; glowing fire ball trail for x3/x5 combo fever.
  - `lib/engine/audio_manager.dart`: Near-miss sfx, heartbeat bass audio pulse on 1.0s interval.
- **Data & Economy**:
  - `lib/storage/save_manager.dart`: Two-currency crystallization (Gold for core upgrades/power, Pearls for rare fish/legendary cosmetics/cosmic mastery); category shard to pearl conversion; atomic pending crate management; 7-day login streak logic; 12h offline timestamp tracking.
  - `lib/models/thematic_world_data.dart`: 12 Thematic Worlds (20 levels each) with boss definitions and names, co-existing with 14 checkpoint sectors in `SectorData`.
  - `lib/models/aquarium_synergy.dart`: Passive synergies computed from unlocked rare/epic/legendary fish in Eco-Tank.

## Feature Inventory
| # | Feature | Description | Milestone | Source |
|---|---------|-------------|-----------|--------|
| 1 | Dynamic Etkinlikler & Lig Hub Card | Unified Main Menu card merging Tournament & Daily Quests into a single live-ops entry point | M1 | ORIGINAL_REQUEST §R1 |
| 2 | Isolated Progress Backup in Settings | Extract `SettingsDialog` to `lib/ui/settings_dialog.dart` containing progress code export/import | M1 | ORIGINAL_REQUEST §R1 |
| 3 | Two-Currency Economy Crystallization | Gold (upgrades, core) and Pearls (rare fish, legendary cosmetics, cosmic mastery); shard conversion | M1 | ORIGINAL_REQUEST §R1 |
| 4 | 20-Level Thematic Worlds (12 Worlds) | Group 238 levels into 12 thematic worlds (Neon Şehir, Lav Sektörü, Kaunos Resifi, etc.) | M2 | ORIGINAL_REQUEST §R2 |
| 5 | Sector Bosses on Every 20th Level | Boss brick (`isBoss: true`), escort guards, and custom HP/color on levels 20, 40, 60, ..., 238 | M2 | ORIGINAL_REQUEST §R2 |
| 6 | Sektör Zafer Sandığı (Victory Crate) | Award and open guaranteed victory crate upon defeating each 20th level sector boss | M2 | ORIGINAL_REQUEST §R2 |
| 7 | Checkpoint & Progress Backward Compatibility | Preserve `SectorData.allSectors` (14 sectors), player level, stars, and high scores 100% | M2 | ORIGINAL_REQUEST §R2 |
| 8 | Near-Miss Paddle Edge Slow-Mo & Flash | 0.2s bullet time + neon edge flash + sfx when ball is saved at outer edge (hitOffset >= 0.90) | M3 | ORIGINAL_REQUEST §R3 |
| 9 | Last Life Tension Vignette & Heartbeat | Pulsing red vignette + rhythmic heartbeat bass audio when player has exactly 1 life | M3 | ORIGINAL_REQUEST §R3 |
| 10 | Combo Fever Fire Trail & Gold Multiplier | Glowing fire trail on balls at combo >= 3, and coin drop multiplier at combo >= 5 | M3 | ORIGINAL_REQUEST §R3 |
| 11 | Rare Fish Passive Power Synergies | Unlocked aquarium fish grant passive bonuses: explosion radius, paddle size, crit chance, gold | M4 | ORIGINAL_REQUEST §R4 |
| 12 | Aquarium Synergy Badges in HUD & Upgrades | Render stylish badges in `HudOverlay` and `UpgradesView` displaying active fish buffs | M4 | ORIGINAL_REQUEST §R4 |
| 13 | 7-Day Login Streak Calendar | Escalating daily rewards with Day 7 guaranteed legendary fish or crystal crate | M5 | ORIGINAL_REQUEST §R5 |
| 14 | 12-Hour Capped Offline Earnings Pop-up | Neon celebration window greeting returning players with offline accumulated gold/pearls | M5 | ORIGINAL_REQUEST §R5 |
| 15 | Aquarium In-App Reminder / Notification | Reminder trigger & banner when tank is full or fish need care | M5 | ORIGINAL_REQUEST §R5 |
| 16 | Comprehensive E2E Verification & Audit | All 701 baseline tests pass + new test suites for R1-R5 + narrow layout stress tests | M6 | ORIGINAL_REQUEST §Acceptance Criteria |

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| 1 | M1: Menü Temizliği & İki Ana Para Birimi Odaklı Ekonomi | Dynamic Etkinlikler & Lig card, SettingsDialog extraction, Gold & Pearl economy unification | none | DONE (757 tests pass, 0 lints, zero overflow) |
| 2 | M2: Klasik Mod Dünya / Sektör Haritası | 20-level thematic worlds, Sector Bosses on lvl 20, 40, 60..., Sektör Zafer Sandığı, backward compatibility | none | PLANNED |
| 3 | M3: Arcade Adrenalin & Vuruş Hissi Paketi | Near-miss 0.2s slow-mo & neon flash, last life red vignette & heartbeat bass, combo fever fire trail & gold | none | PLANNED |
| 4 | M4: Akvaryum ➔ Ana Oyun Güç Köprüsü | Rare fish passive synergies (paddle size, explosion radius, crit, gold) and HUD/Upgrades badges | none | PLANNED |
| 5 | M5: Oyuncu Bağlılığı & Retention | 7-day streak calendar, 12h capped offline earnings celebration pop-up, aquarium reminder notification | M1 | PLANNED |
| 6 | M6: Final E2E Test Suite & Adversarial Hardening | Verify 100% test pass (701 + new tests), zero RenderFlex overflow on 320px-390px, zero analyze warnings | M1, M2, M3, M4, M5 | PLANNED |

## Interface Contracts
### MainMenu ↔ SettingsDialog & TournamentDialog
- `SettingsDialog.show(context, {VoidCallback? onOpenTour})`: dedicated dialog containing audio, haptics, language, tour, and progress backup.
- `TournamentDialog.show(context, {required SaveManager save, VoidCallback? onJoinTournament, int initialTab})`: dual-tab modal bottom sheet.
  - Tab 0: Weekly League (`HAFTALIK LİG ŞAMPİYONASI`, `MÜCADELEYE KATIL`).
  - Tab 1: Daily Quests (`GÜNLÜK GÖREVLER`).

### SectorData & ThematicWorldData ↔ LevelDesign & GameController
- `SectorData.allSectors`: Remains 14 sectors (17 levels each) for backward compatibility and existing tests.
- `ThematicWorldData.allWorlds`: 12 worlds (20 levels each) for thematic sector map display and boss generation.
- `LevelDesign.isSectorBossLevel(int level)`: Returns true if `(level > 0 && level % 20 == 0) || level == 238`. Included in `isBossLevelNumber(level)`.
- `GameController._onLevelCleared()`: When clearing level where `isSectorBossLevel(stats.level)` is true, grants `PendingCrate` with `CrateType.victory` / `CrateType.coral` / `CrateType.legendary`.

### Aquarium ↔ GameController & HUD
- `AquariumSynergy.compute(List<String> unlockedFish)`: Returns passive buffs:
  - `double paddleWidthBonus`: Extra paddle width.
  - `double explosionRadiusBonus`: Extra explosion radius for dynamite/fireball.
  - `double critChanceBonus`: Extra brick critical strike chance.
  - `double goldGainMultiplier`: Extra gold from gameplay.
- Read in `GameController` during paddle hit, explosion, brick damage, and coin drops.
- Rendered in `HudOverlay` as synergy badge and `UpgradesView` as dedicated section.

### Retention ↔ SaveManager
- `SaveManager.claimDailyLoginReward()`: Day 7 awards guaranteed legendary fish or crate.
- `SaveManager.computeOfflineEarnings()`: Capped strictly at `min(elapsedHours, 12.0)`.
- `OfflineEarningsDialog.show(context, {required int gold, required int pearls, required double elapsedHours})`.

## Code Layout
- UI Modules:
  - `lib/ui/main_menu.dart`
  - `lib/ui/settings_dialog.dart` (New)
  - `lib/ui/tournament_dialog.dart`
  - `lib/ui/sector_map_view.dart`
  - `lib/ui/game_canvas.dart`
  - `lib/ui/hud_overlay.dart`
  - `lib/ui/upgrades_view.dart`
  - `lib/ui/daily_login_dialog.dart`
  - `lib/ui/offline_earnings_dialog.dart` (New)
  - `lib/ui/crate_opening_dialog.dart`
- Engine & Models:
  - `lib/engine/game_controller.dart`
  - `lib/engine/audio_manager.dart`
  - `lib/models/level_design.dart`
  - `lib/models/thematic_world_data.dart` (New)
  - `lib/models/aquarium_synergy.dart` (New)
  - `lib/models/cosmetics.dart`
  - `lib/storage/save_manager.dart`
- Tests:
  - `test/game_test.dart`
  - `test/main_menu_tour_test.dart`
  - `test/milestone1_adversarial_test.dart`
  - `test/evolution_r1_test.dart` (New)
  - `test/evolution_r2_test.dart` (New)
  - `test/evolution_r3_test.dart` (New)
  - `test/evolution_r4_test.dart` (New)
  - `test/evolution_r5_test.dart` (New)
