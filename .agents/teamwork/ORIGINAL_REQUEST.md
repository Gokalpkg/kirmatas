# Original User Request

## Initial Request — 2026-10-16T11:59:42Z

Implement a comprehensive 9-part player-experience and endgame overhaul for the Flutter brick-breaker game **Kırmataş** (`com.kaunos.kirmatas`), resolving all 4 First-Time User Experience (FTUE) issues and all 5 Endgame (183-hour veteran) issues without breaking any existing functionality or tests.

Working directory: `c:\Users\USER\Desktop\KIPKIRMATAS`
Integrity mode: development

## Requirements

### R1. Progressive Feature Unlocking (Sorun 1 — FTUE Cognitive Overload)
For brand-new players (`highestLevel < 7`), progressively unlock menus and modes in `SaveManager` (`lib/storage/save_manager.dart`) and `MainMenu` (`lib/ui/main_menu.dart`) so new players are not overwhelmed on first launch, while keeping everything unlocked for existing players (`highestLevel >= 7`):
- Level 1: Classic Mode ("ANA MACERA") is open and highlighted.
- Level 2+: Shop & Rewards Hub / Fortune Wheel unlock (`bool get isShopUnlocked => highestLevel >= 2 || totalGold >= 100;`).
- Level 3+: Workshop / Upgrades unlock (`bool get isWorkshopUnlocked => highestLevel >= 3;`).
- Level 5+: Aquarium (Eko-Tank) and Chaos Mode ("ÖZEL MOD") unlock (`bool get isAquariumUnlocked => highestLevel >= 5;`, `bool get isChaosUnlocked => highestLevel >= 5;`).
- Level 7+: Weekly League, Zen Mode, and Daily Blitz unlock (`bool get isLeagueUnlocked => highestLevel >= 7;`).
Display clear lock badges (`🔒 Bölüm X`) on locked buttons/tabs in `MainMenu` and show a clean snackbar/feedback when tapped before unlock. Ensure existing widget tests that expect navigation tabs/buttons work seamlessly.

### R2. Mode Identity & Cross-Mode Workshop Scaling (Sorun 2 — Classic vs. Chaos Identity)
Clearly distinguish Classic Mode as **"ANA MACERA"** and Chaos Mode as **"ÖZEL MOD"** in `MainMenu` (`lib/ui/main_menu.dart`) and `I18n` (`lib/engine/i18n.dart`). Ensure Workshop (`SaveManager` upgrades: Crit Damage `u_crit`, Luck `u_luck`, Gold Multiplier `u_gold`, and Cosmic Mastery) actively apply their bonuses inside Chaos Mode (`GameController` in `lib/engine/game_controller.dart`) as well as Classic Mode.

### R3. Interactive In-Game Visual Onboarding (Sorun 3 — Interactive Tutorial)
In `GameController` (`lib/engine/game_controller.dart`) and `GameCanvas` (`lib/ui/game_canvas.dart`):
- Show an animated drag hand/arrow guide (`◄── KAYDIR ──►`) below the paddle during the first seconds of Level 1 (`level == 1 && !isChaosMode && !isZenMode`).
- Trigger a brief slow-motion pulse and celebratory floating banner (`⚡ SÜPER KÖŞE VURUŞU!`) on the player's first corner hit (`firstCornerHitShown` flag).
- Show a glowing interactive HUD callout (`⚡ ULTİ HAZIR! ÇİFT DOKUN!`) when the Ultimate bar reaches 100% (`ultiCharge >= 1.0`).

### R4. Early-Game Pacing & Guaranteed Action Drops (Sorun 4 — Early Pacing)
In `GameController` (`lib/engine/game_controller.dart`):
- Boost initial ball base speed by +15% during Levels 1–5 (`level <= 5 && !isChaosMode && !isZenMode`) so early gameplay feels snappy and responsive (while respecting all existing physics/tunneling tests).
- Guarantee that one of the first 3 broken bricks in Levels 1–5 drops a high-dopamine action capsule (`PowerUpType.multiBall` or `PowerUpType.fireball`) tracked via `earlyActionDropGranted` per level.

### R5. Infinite "Cosmic Mastery" (Paragon) Gold & Pearl Sink (Sorun 5 — 183h Economy Inflation)
In `SaveManager` (`lib/storage/save_manager.dart`), `UpgradesView` (`lib/ui/upgrades_view.dart`), and `GameController` (`lib/engine/game_controller.dart`):
- Add uncapped `cosmicGoldMasteryLevel` (upgraded with Gold via `upgradeCosmicGoldMastery()`, cost scaling e.g. `1000 + cosmicGoldMasteryLevel * 500`) granting +2% brick/crit damage bonus and +2% gold gain per level across all modes.
- Add uncapped `cosmicPearlMasteryLevel` (upgraded with Pearls via `upgradeCosmicPearlMastery()`, cost scaling e.g. `5 + cosmicPearlMasteryLevel * 3`) granting +2% ultimate charge rate and +1% luck/dice bonus per level.
- Render a dedicated **"🌌 KOZMİK USTALIK (SONSUZ SEVİYE)"** section in `UpgradesView` so endgame players always have a meaningful sink for surplus Gold and Pearls.

### R6. Daily Seeded Blitz ("Günün Operasyonu") & Infinite Prestige Sectors (Sorun 6 — Post-238 Endgame)
In `SaveManager`, `GameController`, `SectorMapDialog`, and `MainMenu`:
- Add **"Günün Operasyonu (Daily Blitz)"**: a deterministic daily challenge level seeded by the current date (`YYYYMMDD`, e.g. `startDailyBlitz()`) with a daily bonus reward (250 Gold + 3 Pearls + 1 Cosmetic Shard via `claimDailyBlitzReward()`) tracked once per day (`isDailyBlitzCompletedToday`) in `SaveManager`.
- Support **Infinite Sector Omega / Prestige Levels beyond Level 238** (`level > 238`): procedurally scale brick HP, boss layouts, and prestige gold multipliers (`int get prestigeTier => level > 238 ? ((level - 239) ~/ 17) + 1 : 0`) so Classic Mode never dead-ends after Sector 14.

### R7. Seasonal Championship Titles, Frames & Dynamic League Rivals (Sorun 7 — League Progression)
In `SaveManager`, `TournamentDialog` (`lib/ui/tournament_dialog.dart`), and `MainMenu`:
- Award persistent **Seasonal Titles & Avatar Frames** based on league tier and tournament rank (e.g., *Çaylak Kırıcı*, *Neon Avcısı*, *Plazma Lordu*, *Elmas Hükümdarı*, *Kozmik İmparator* via `SaveManager.instance.seasonalTitle`) displayed in `MainMenu` and `TournamentDialog`.
- Make league rival score generation scale dynamically and realistically around the player's active league tier and weekly score pace.

### R8. Cosmetic Loadout Set Synergies (Sorun 8 — Build Depth)
In `CosmeticCatalog` (`lib/models/cosmetics.dart`), `ShopView` (`lib/ui/shop_view.dart`), and `GameController`:
- Compute an active `CosmeticSynergy` from the equipped Paddle + Ball + Trail combination (`CosmeticCatalog.getActiveSynergy(paddleId, ballId, trailId)`):
  - **🔥 Ateş / Günbatımı Sinerjisi**: +15% explosion radius and combo momentum.
  - **❄️ Buz / Kristal Sinerjisi**: extra damage against ice/armored bricks and slow-debuff resistance.
  - **👑 Kozmik Efsanevi Set (3x Epic/Legendary)**: +15% score and gold multiplier.
- Display the active synergy badge in `ShopView` and apply its gameplay bonuses in `GameController`.

### R9. Chaos Mode Roguelike 3-Card Perks & Wave-10 Chaos Bosses (Sorun 9 — Chaos Mode Depth)
In `GameController` (`lib/engine/game_controller.dart`) and `GameCanvas` (`lib/ui/game_canvas.dart`):
- Every 5 waves in Chaos Mode (Waves 5, 10, 15, ...), offer a **3-Card Roguelike Perk Selection** (`ChaosPerkType`: `emberCore`, `chainShock`, `microBlast`, `magnetPull`, `sniperSight`, `goldenVolley`) via `offeredChaosPerks` and `selectChaosPerk(ChaosPerkType)`. Selected perks stack for the run in `activeChaosPerks` and appear as badges/hud indicators, while keeping automated headless tests non-blocking.
- Every 10 waves in Chaos Mode (Waves 10, 20, 30, ...), spawn a special **Chaos Boss Brick** (`BrickType.boss`) with high HP, boss warning feedback, and bonus gold/pearl drop on destruction.

## Acceptance Criteria

### Programmatic Verification
- [ ] `flutter analyze` exits with code 0 (zero errors, zero warnings).
- [ ] All existing 435 tests in `test/game_test.dart` pass without regression (`flutter test`).
- [ ] New automated unit and widget tests in `test/game_test.dart` verify all 9 requirements:
  1. R1 progressive unlock getters (`isShopUnlocked`, `isWorkshopUnlocked`, `isAquariumUnlocked`, `isChaosUnlocked`, `isLeagueUnlocked`).
  2. R2 Chaos Mode workshop stat scaling (crit, luck, gold).
  3. R3 Interactive onboarding flags and HUD rendering.
  4. R4 Early-game guaranteed action capsule drop in levels 1–5.
  5. R5 Infinite Cosmic Mastery (`cosmicGoldMasteryLevel`, `cosmicPearlMasteryLevel`) upgrades and persistence.
  6. R6 Daily Blitz (`startDailyBlitz`, `claimDailyBlitzReward`) and post-238 Prestige (`prestigeTier`) scaling.
  7. R7 Seasonal title progression (`seasonalTitle`) and dynamic league rivals.
  8. R8 Cosmetic Set Synergy detection (`CosmeticCatalog.getActiveSynergy`) and ShopView rendering.
  9. R9 Chaos Mode 3-card roguelike perk selection (`selectChaosPerk`, `activeChaosPerks`) and Wave-10 Chaos Boss brick spawn.


## Follow-up — 2026-10-16T17:42:06Z

Build two viral 9:16 (1080x1920, 60 FPS) promotional video advertisements (**Turkish TR** and **English US/UK** editions) for the Flutter brick-breaker & aquarium game **Kırmataş**, combining a smooth Kurzgesagt/infographic-style "What-If" animated opener (*"Uzaydan Dünya'ya tek bir demir bilye bıraksaydın ne olurdu?"* / *"What if you dropped a single iron marble from space?"*) and an unexpected comedic/clever pivot ("İzmir Kumrucusu Hasan Usta" style twist) with **real, captured in-game screens, animations, and original audio/image assets** from the Kırmataş codebase, leaving the game source code completely clean afterward.

Working directory: c:\Users\USER\Desktop\KIPKIRMATAS
Integrity mode: development

## Requirements

### R1. Real In-Game Visual Capture & Clean Codebase Restoration
- Render and capture genuine, high-resolution (1080x1920 portrait) in-game screenshots/frame sequences directly from the actual Kırmataş Flutter widgets and custom painters (`GameCanvas` in active Fireball/Multi-Ball & Corner Hit Slow-Mo & Ulti states, Chaos Mode 3-card roguelike perk selection, Wave-10 Chaos Boss brick, `AquariumView` with real fishes, `ShopView` with set synergies, and `TournamentDialog` weekly league) using an automated Flutter test/offscreen golden capture script.
- Save the captured real gameplay frames and asset bundle into `docs/ad_assets/` (or inline base64 data URIs) so the video players use authentic Kırmataş visuals, real skill icons (`assets/images/skills/*.png`), real fish sprites (`assets/images/fishes/*.png`), the `Rajdhani` font (`assets/fonts/`), and real game audio (`assets/audio/cam_kirilma.mp3`, `glass_shatter.mp3`, `custom_laser.wav`, `custom_explosion.wav`, `bgm.wav`).
- Remove any temporary capture test/code after extracting the frames so `git status` on `lib/` and `test/game_test.dart` has zero leftover modifications.

### R2. Smooth "What-If" Animated Hook & Clever Pivot ("Bağlama") Engine (0s – 8s)
- **Scene 1 (0s – 3.5s — The Curiosity Hook):** Smooth, eye-pleasing 2D/vector space-to-atmosphere animation showing an astronaut/satellite releasing a gleaming iron marble above Earth, zooming into atmospheric entry with glowing plasma waves, shockwave rings, speedometer counter climbing to **40,000 km/h (25,000 mph)** and temperature hitting **3,000°C (5,000°F)**.
- **Scene 2 (3.5s – 7.5s — The "Hasan Usta" Style Twist/Pivot):** Just as the blazing meteor-marble plummets through the clouds toward the city below, instead of creating a crater, the camera zooms into a glowing **Kırmataş Cosmic Paddle** catching the meteor with a slow-motion **`⚡ SÜPER KÖŞE VURUŞU!`** impact, shattering the meteor into **30 blazing Fireballs** that obliterate a wall of real Kırmataş bricks and trigger the real in-game showcase.

### R3. Real Kırmataş Gameplay Showcase & Culturally Tailored TR + EN Editions (7.5s – 18s)
- **Scene 3 (7.5s – 13.5s — Real In-Game Footage Showcase):** Seamlessly transition through real captured Kırmataş gameplay frames enhanced with live 60 FPS particle/ball overlays, real skill icons, real swimming fishes, and authentic game SFX:
  1. Real `GameCanvas` Multi-Ball + Fireball + Ulti Lightning board wipe (`⚡ ULTİ HAZIR! ÇİFT DOKUN!`).
  2. Real Chaos Mode 3-Card Roguelike Perk selection + `ShopView` Cosmic Set Synergy.
  3. Real `AquariumView` Eco-Tank with swimming fish sprites (`arowana_red.png`, `discus_blue.png`, `angel_ruby.png`, etc.) + `TournamentDialog` Weekly League #1 leaderboard.
- **Scene 4 (13.5s – 18.0s — Wave-10 Chaos Boss & Call to Action):** Real Wave-10 Chaos Boss encounter + high-converting end card featuring `assets/images/kaunos_games.png` and store download callout.
- Deliver two distinct self-contained HTML5 video studios & `.webm` (1080x1920 60 FPS) exporters:
  - `docs/kirmatas_reklam_tr.html`: Turkish narrative, "Hasan Usta" style humorous twist, competitive/stress-relief angle, synchronized Turkish voiceover (Web Speech API + real audio mixer) & TikTok captions.
  - `docs/kirmatas_ad_en.html`: US/UK narrative, "Brain Itch / Oddly Satisfying + Wait, it has Roguelike perks & an Aquarium?!" angle, synchronized English voiceover & dynamic captions.

## Acceptance Criteria

### Real In-Game Captures & Cleanliness
- [ ] At least 5 distinct real high-resolution PNG captures rendered by Flutter from Kırmataş (`GameCanvas` action, Chaos Perks/Boss, `AquariumView`, `ShopView`, `TournamentDialog`) exist in `docs/ad_assets/` (or embedded as verified `data:image/png;base64,...` images) and are visibly rendered inside both video ads.
- [ ] Real game audio files (`cam_kirilma.mp3`, `glass_shatter.mp3`, `custom_explosion.wav`, `custom_laser.wav`, `bgm.wav`) and real sprite assets (`fishes/*.png`, `skills/*.png`) are loaded and played during the video timeline.
- [ ] `lib/` and `test/game_test.dart` have zero leftover modifications (`git diff lib/ test/game_test.dart` is empty) and `flutter analyze` passes with 0 issues.

### Video Ad Deliverables (TR & EN)
- [ ] Both `docs/kirmatas_reklam_tr.html` and `docs/kirmatas_ad_en.html` exist, render at 1080x1920 (9:16 vertical) at 60 FPS, include interactive scene scrubbing, live audio + voiceover synthesis, and a functional one-click **1080x1920 `.webm` HD Video Recorder & Downloader**.
- [ ] Both files follow all 4 narrative beats: (1) Space Marble What-If Animated Hook, (2) 40,000 km/h Cosmic Paddle Twist/Pivot, (3) Real Kırmataş In-Game Footage Showcase (Gameplay, Roguelike Chaos, Aquarium, League), and (4) Boss + Download CTA.


## 2026-10-16T18:04:43Z

Upgrade the visual identity and UI craftsmanship of the **Kırmataş** Flutter mobile game (`c:\Users\USER\Desktop\KIPKIRMATAS`) using the **"Kaunos Kehribarı & 3D Taş/Kristal" (Warm Carved Terracotta-Amber, Forged Gold & Deep Abyssal Jade)** art direction as the base. Eliminate all generic "AI-generated" UI patterns (system emojis `🔒⭐🗺️🌌`, stock business Material icons, clashing neon/rainbow SaaS gradients, pill-badge clutter, and flat borderless containers) while keeping 100% of existing gameplay mechanics, Eco-Tank background, Black Holes, Portals, and 562 tests intact with zero regressions.

Working directory: c:\Users\USER\Desktop\KIPKIRMATAS
Integrity mode: development

## Requirements

### R1. Handcrafted Custom Iconography & Tactile 3D Frame System
Replace system emojis (`🔒`, `⭐`, `🗺️`, `🌌`) and generic business Material icons across the Main Menu, HUD, Shop, Workshop, and Dialogs with custom-painted `CustomPainter` game emblems (Stamped Gold Coin, Astral Pearl, Carved Padlock, Sector Compass/Map, Fate Wheel, Craftsman Anvil, and Eco-Tank Crest) in a new `lib/ui/kaunos_ui.dart` design system module. Build reusable tactile 3D game card and button primitives featuring physical bottom lip depth (`boxShadow` offset bevel), warm top inner specular highlights, forged bronze/amber borders, and tactile press animations.
IMPORTANT BACKWARD-COMPATIBILITY NOTE FOR EXISTING TESTS:
- Existing widget tests in `test/game_test.dart` and `test/milestone1_adversarial_test.dart` check for lock text substrings such as `'Bölüm 2'`, `'Bölüm 3'`, `'Bölüm 5'`, `'Bölüm 7'`, `'MACERAYA BAŞLA'`, `'ANA MACERA'`, `'ÖZEL MOD'`, `Icons.lock` (or lock badge text), `Key('active_cosmetic_synergy_badge')`, `🌌 KOZMİK USTALIK (SONSUZ SEVİYE)` (check `test/game_test.dart` before removing any text string asserted by tests!). Where tests assert a specific text string or icon, preserve the text/key compatibility while upgrading the visual container and custom emblem around it.

### R2. Main Menu Overhaul ("Kaunos Kehribarı & Derin Kristal" Base)
Redesign `lib/ui/main_menu.dart` on top of the existing `EcoTankBackground`:
- **Crest Header:** Enhance the `KIRMATAS` title into a handcrafted carved amber-gold crest emblem header with custom crystal/diamond side ornaments and forged bronze-gold frame.
- **Hero Classic & Chaos Cards:** Style the Classic Hero card in warm sunset terracotta-amber (`#C85A32` → `#96381B`) with a forged gold border (`#F5B041`), physical 3D bottom lip (`#4A1808`), clean typography hierarchy, and a tactile 3D gold play trigger. Style the Chaos card in deep sea jade (`#1E4D58` → `#13333B`) with a carved teal-gold border (`#48A9A6`) and warm amber action button.
- **Top Bar & Bottom Dock:** Style the top currency/league bar, rewards bar (`GİRİŞ`, `ÇARK`, `HEDİYE`), and bottom navigation dock as carved obsidian-bronze & warm amber stone tablets with physical 3D depth instead of translucent SaaS floating pills.

### R3. Cohesive Visual Polish Across Secondary Views, Dialogs & HUD
Apply the same warm carved amber, bronze, and deep jade tactile aesthetic across `shop_view.dart`, `upgrades_view.dart`, `sector_map_view.dart`, `hud_overlay.dart`, `pause_game_over.dart`, `fortune_wheel_dialog.dart`, `daily_login_dialog.dart`, `daily_quests_dialog.dart`, and `tournament_dialog.dart`, preserving all widget keys, callbacks, localization strings, and progressive unlock behaviors.

## Verification Resources

- Existing test suite in `test/` (`flutter test` — 562 tests covering gameplay physics, progressive unlocks R1–R9, narrow mobile layouts `320x480`, `360x640`, `390x844`, and `1.3x` text scaling).
- Static analyzer (`flutter analyze`).

## Acceptance Criteria

### Visual Authenticity & Craftsmanship
- [ ] `lib/ui/kaunos_ui.dart` provides reusable custom-painted emblems (`CustomPainter`) and 3D tactile carved stone/amber cards & buttons.
- [ ] Main Menu Hero cards, Top Bar, Rewards Bar, and Bottom Dock use the warm terracotta-amber (`#C85A32`/`#F5B041`) and deep jade (`#1E4D58`/`#48A9A6`) 3D tactile bevel system with physical bottom shadows and specular highlights.

### Stability, Layout Safety & Zero Regressions
- [ ] `flutter analyze` exits with 0 errors and 0 warnings.
- [ ] `flutter test` passes 100% of the existing 562 tests plus new verification tests for `kaunos_ui.dart` and the redesigned UI components.
- [ ] Zero `RenderFlex` overflow errors on `320x480`, `360x640`, and `390x844` viewports at both `1.0x` and `1.3x` text scale factors.
