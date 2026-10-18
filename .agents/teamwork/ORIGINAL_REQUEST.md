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


## 2026-10-16T22:03:15Z

Uygulama genelinde (Ana Menü, Sandıklar/Crates, HUD, Mağaza, Atölye ve Dialoglar) %75 1.1 "Kozmik Kristal & Gözlemevi" ve %25 1.3 "3D Kristal & Dövme Altın/Bevel" hibrit görsel tasarım sistemini eksiksiz uygulamak.

Working directory: c:\Users\USER\Desktop\KIPKIRMATAS
Integrity mode: development

## Requirements

### R1. Kozmik Kristal & 3D Bevel Tasarım Sistemi (Kaunos UI)
- `lib/ui/kaunos_ui.dart` (veya ilgili UI modülleri) üzerinde derin füme/obsidyen kristal cam paneller (`#05070F` tabanlı yarı saydam zemin, ince kristal kenarlıklar ve yansımalar) oluşturulacak.
- Tüm kartlar ve interaktif butonlar %25 1.3 dokunuşu ile 3D fiziksel alt derinlik (5px bevel gölgesi), üst kenar kristal ışık kırılması (specular rim) ve basıldığında içeri göçen dokunsal (tactile) basma animasyonuna sahip olacak.
- Ana `OYNA` butonu, 1.1'in zarif kristal çerçevesi içinde 1.3'ün 3 boyutlu dövme altın/kehribar tetiği olarak render edilecek.

### R2. Sandık (Crates) Kalitesi ve Açılış Animasyonları
- Sandıklar generic/yapay zeka görünümünden arındırılacak; her nadirlik seviyesine (Normal, Nadir, Epik, Efsanevi) uygun dövme altın, obsidyen ve kristal detaylı 3D derinlikli sandık görselleri ve parçacık efektleri uygulanacak.
- Sandık açılış sekansı ve ödül sunumu kristal ışıltı ve taktil hissiyatla güçlendirilecek.

### R3. Ana Ekran, HUD ve Alt Menülerin Dönüşümü
- Ana Menüdeki `GÜNLÜK GÖREVLER`, `KOZMİK MAĞAZA`, `SEKTÖR HARİTASI`, `KOLEKSİYON` kartları yeni hibrit tasarım diliyle güncellenecek.
- Oyun içi HUD (Can barı, kombo göstergeleri, tuğla sayaçları, duraklatma ve güçlendirme rozetleri) kristal & 3D bevel stiline uyarlanacak.
- Eko-Akvaryum arka planı, karadelikler ve portal efektleri bozulmadan yeni UI ile mükemmel kontrast oluşturacak şekilde korunacak.

### R4. Geriye Dönük Uyumluluk ve Test Bütünlüğü
- 562 otomatik testin tamamı (`flutter test`) sıfır regresyon ile 562/562 geçmeye devam edecek.
- Testlerin aradığı tüm anahtar metinler (`Bölüm 2`, `Bölüm 3`, `MACERAYA BAŞLA`, `ÖZEL MOD` vb.) ve semantikleri birebir korunacak.
- `flutter analyze` 0 hata ve 0 uyarı verecek.

## Acceptance Criteria

### Görsel ve Arayüz Bütünlüğü
- [ ] Ana Menü, Sandıklar, HUD ve Mağaza %75 1.1 + %25 1.3 hibrit tasarım diline tam olarak dönüştürüldü.
- [ ] Butonlarda ve panellerde 3D alt bevel ve dokunsal basma hissiyatı çalışıyor.
- [ ] Sandıklar ve ödül ekranları kristal ve dövme altın işçiliğiyle kaliteli bir görünüme kavuştu.

### Stabilite ve Testler
- [ ] `flutter analyze` komutu 0 hata ve 0 uyarı ile tamamlanıyor.
- [ ] `flutter test` komutu 562/562 testi firesiz başarıyla geçiyor.


## 2026-10-17T10:23:20Z

Produce the upgraded **Kırmataş** viral vertical video ads (`31.5s` Bilgi + Absürt "What-If" Edition and `20s` Fast Edition in `1080x1920` MP4 & WebM) in `C:\Users\USER\Desktop\KIRMATAS_VIDEO` (and mirror to `C:\Users\USER\Desktop\KIRMATAS_REKLAM_PAKETI`) by replacing all synthetic 2D gameplay drawings with **100% authentic, high-resolution frame sequences rendered directly by the Kırmataş Flutter engine (`GameCanvas`, `_GameWorldPainter`, `HudOverlay`, `TournamentDialog`)** with the real `Rajdhani` font and sprite assets loaded, and integrating an irresistible absurd "What-If" science hook with ElevenLabs voiceover.

Working directory: c:\Users\USER\Desktop\KIPKIRMATAS
Integrity mode: development

## Requirements

### R1. 100% Genuine Flutter Engine Gameplay Frame Sequence Capture
- Capture real multi-second gameplay frame sequences directly from the actual Kırmataş Flutter widgets (`GameCanvas` / `_GameWorldPainter`, `HudOverlay`, `offeredChaosPerks` overlay, `TournamentDialog`, and `AquariumView`) at `1080x1920` resolution (`pixelRatio: 3.0`) with the real `Rajdhani` font family (`assets/fonts/Rajdhani-*.ttf`) and all game image assets (`assets/images/skills/*.png`, `assets/images/fishes/*.png`) loaded into memory so there are zero missing-glyph boxes (`████`) and zero fake 2D substitutes.
- Record authentic multi-frame sequences of: (1) Cosmic Paddle launching the ball into a level packed with real 3D Dynamite (`isDynamite`), Steel X-Girder (`isSteel`), Ice (`isIce`), and Neon/Cosmic bricks with real fracture cracks and shard physics, (2) 30 blazing Fireballs + falling power-up capsules + Drone/Bee + Ulti Lightning wiping the board, (3) the real in-game `⚡ KAOS GÜÇLENDİRMESİ SEÇ` overlay, and (4) the real `TournamentDialog` weekly league leaderboard & level-clear celebration.

### R2. Compelling "Bilgi + Absürt What-If" Narrative, ElevenLabs Voiceover & Final MP4/WebM Assembly
- Use the open ElevenLabs browser session (or high-clarity Turkish documentary narrator voiceover) for the "Bilgi + Absürt What-If" script (*"Gökdelenden küçücük bir demir bilye bıraksan ne olur? Normalde hava direnci yüzünden 150 km hızı geçemez ve asla alev almaz. Ama bu bilyede hava direnci bir anda sıfırlandı! Ses duvarını aştı, plazmaya dönüştü ve tüm şehri yok edecek güce ulaştı! Tam çatıya çarpacakken... bir şey araya girdi. İşte Kırmataş!"*).
- Assemble and export `KIRMATAS_REKLAM_32SN_BILGI_MERAK.mp4` (and `.webm`), `KIRMATAS_REKLAM_20SN_TEST.mp4` (and `.webm`), and the standalone real gameplay clips in `4_Oyun_Kaydi/` using the genuine Flutter frame sequences.

## Acceptance Criteria

### Genuine Flutter Visuals & Clean Codebase
- [ ] Every frame in the gameplay section (`17.8s–26.9s` in the 32s video and `8.9s–17.0s` in the 20s video) and in `4_Oyun_Kaydi/` comes directly from the Kırmataş Flutter `_GameWorldPainter` / widget tree with real `Rajdhani` typography (zero `████` boxes) and real 3D Dynamite/Steel/Ice/Neon bricks.
- [ ] `flutter analyze` passes with 0 errors and no temporary test files remain in `test/`.


## 2026-10-17T10:30:37Z

ÖNEMLİ GÜNCELLEME (Kullanıcının Son İsteği):
1. **Şaşırtıcı "What-If" Girişi (0.0 – 17.4 sn — Belgesel Anlatıcı Sesi):**
   Kullanıcı girişin şaşırtıcı bir What-If senaryosu ile başlamasını istedi: *"Ya yerçekimi bir anda dursaydı... ve saniyeler sonra yüz katıyla geri çarpsaydı ne olurdu? Bu çocuk gökdelenden küçücük bir bilye bıraktı. Normalde hava direnci yüzünden bilye bir hızdan sonra hızlanamaz ve asla alev almaz. Ama bu bilyede fizik kuralları kırıldı! Alev aldı ve bir şehri yok edecek güce ulaştı! Tam çatıya çarpacakken... bir şey araya girdi."*
2. **17.8. Saniyede ("İşte Kırmataş!") Aşırı Heyecanlı / Enerjik Sesin Devreye Girmesi:**
   Kullanıcı: *"ve işte kırmataşta aşırı heyecanlı bir ses devreye girsin"*.
   17.4–17.8 sn arasındaki SİYAH KARE + TAM SESSİZLİK sonrasındaki beyaz flaş + raket vuruşu anında (17.8 sn) **aşırı heyecanlı ikinci ses** (`Cavit - Energetic and Fast-Paced`, ElevenLabs'tan `C:\Users\USER\Downloads\` klasörüne indiriliyor) devreye girecek:
   *"İŞTE KIRMATAŞ!! Otuz ateş topuyla ekranı temizle, kaos kartlarını topla, ligde zirveye çık! Ücretsiz indir, hemen oyna!"*
3. **%100 Gerçek Flutter Oyun Görüntüleri (`GameCanvas` / `_GameWorldPainter` + `Rajdhani` fontu + gerçek `assets/images/`):**
   Oyun içi sahnelerin tamamı (17.8–26.9 sn) gerçek Flutter motorundan yüksek çözünürlüklü kare dizisi (frame sequence) olarak kaydedilmeli; `Rajdhani` fontu yüklü olmalı (`████` kutuları kesinlikle olmamalı) ve gerçek 3D Dinamit (`isDynamite`), Çelik (`isSteel`), Buz (`isIce`) blokları, 30 ateş topu, gerçek `⚡ KAOS GÜÇLENDİRMESİ SEÇ` ekranı ve `TournamentDialog` lig ekranı yer almalı.


## 2026-10-17T10:34:31Z

ElevenLabs tarayıcı ajanı yeni 2 sesli üretimi tamamladı ve `C:\Users\USER\Downloads\` klasörüne indirdi! Lütfen doğrudan bu gerçek ElevenLabs MP3 dosyalarını kullanın:

1. **BÖLÜM 1 (0.0 – 17.4 sn — Şaşırtıcı Yerçekimi What-If Girişi — `Meloxia Turkish Pro`)**:
   - Dosya yolu: `C:\Users\USER\Downloads\ElevenLabs_2026-10-17T10_31_27_Meloxia Turkish Pro_pvc_sp112_s60_sb80_se0_b_m2.mp3`
   - Metin: *"Ya yerçekimi bir anda dursaydı... ve saniyeler sonra yüz katıyla geri çarpsaydı ne olurdu? Bu çocuk gökdelenden küçücük bir bilye bıraktı. Normalde hava direnci yüzünden bilye bir hızdan sonra hızlanamaz ve asla alev almaz. Ama bu bilyede fizik kuralları kırıldı! Alev aldı ve bir şehri yok edecek güce ulaştı! Tam çatıya çarpacakken... bir şey araya girdi."*
   - (Not: Bu dosya ~23 sn ise hafif tempo/sessizlik kırpımı (`atempo` veya sessizlik kısaltması) ile tam `0.0 - 17.4 sn` aralığına oturtun; `17.4 - 17.8 sn` arası TAM SESSİZLİK + SİYAH KARE olsun!)

2. **BÖLÜM 2 (17.8 – 31.5 sn — Aşırı Heyecanlı / Enerjik Ses — `Cavit - Energetic and Fast-Paced`)**:
   - Dosya yolu: `C:\Users\USER\Downloads\ElevenLabs_2026-10-17T10_33_27_Cavit - Energetic and Fast-Paced_pvc_sp114_s50_sb75_se0_b_m2.mp3`
   - Metin: *"İŞTE KIRMATAŞ!! Otuz ateş topuyla ekranı temizle, kaos kartlarını topla, ligde zirveye çık! Ücretsiz indir, hemen oyna!"*
   - Tam `17.8 sn`'deki beyaz flaş + raket vuruşu ile patlayarak devreye girsin!
   - Ayrıca `3_Ses/` klasörüne hem ayrı ayrı (`BOLUM1_Meloxia_WhatIf.mp3`, `BOLUM2_Cavit_Heyecanli_Iste_Kirmatas.mp3`) hem de birleştirilmiş `SESLENDIRME_32SN_TEK_PARCA.mp3` ve `TAM_MIKSLI_SES_32SN.wav` olarak kaydedin.


## 2026-10-17T10:42:26Z

SES GÜNCELLEMESİ (Kullanıcının Talebi Üzerine):
Kullanıcı sesi beğenmediği ve "daha kaliteli, Türkçeye uygun doğal bir ses kullan, sana bırakıyorum halledersin" dediği için, Microsoft Edge Neural'ın en üst düzey stüdyo kalitesindeki doğal Türkçe ses aktörü **`tr-TR-AhmetNeural` (Doğal İstanbul Türkçesi Belgesel & Reklam Spikeri)** ile tüm ses dosyaları sıfırdan en yüksek kalitede üretildi ve `C:\Users\USER\Desktop\KIRMATAS_VIDEO\3_Ses\` klasörüne kaydedildi:

1. **Bölüm 1 (0.0 – 21.7 sn — Şaşırtıcı Yerçekimi What-If Girişi)**:
   - Dosya: `C:\Users\USER\Desktop\KIRMATAS_VIDEO\3_Ses\BOLUM1_Ahmet_WhatIf_17sn_Kusursuz.mp3` (veya `BOLUM1_Ahmet_WhatIf_Tam17sn.mp3`)
   - Ton: Belgesel anlatıcısı, sakin, merak uyandıran, mükemmel Türkçe tonlama.
   - 21.7 – 22.1 sn arası: **TAM SESSİZLİK + SİYAH KARE**!

2. **Bölüm 2 (22.1 – 29.2 sn — Patlayıcı Oyun Girişi "İşte Kırmataş!")**:
   - Dosya: `C:\Users\USER\Desktop\KIRMATAS_VIDEO\3_Ses\BOLUM2_Ahmet_IsteKirmatas_6sn.mp3` (veya `BOLUM2_Ahmet_Aksiyon_Tam8sn.mp3`)
   - Ton: Yüksek tempolu, heyecanlı, dinamik aksiyon spikeri.

3. **Bölüm 3 (29.2 – 32.2 sn — Bitiş Kartı CTA)**:
   - Dosya: `C:\Users\USER\Desktop\KIRMATAS_VIDEO\3_Ses\BOLUM3_Ahmet_BitisKarti_CTA_3sn.mp3`
   - Ton: "Ücretsiz indir, hemen oyna!"

4. **Tek Parça Seslendirme**:
   - Dosya: `C:\Users\USER\Desktop\KIRMATAS_VIDEO\3_Ses\SESLENDIRME_32SN_TEK_PARCA_AHMET_DOGAL_TURKCE.mp3`

Lütfen Milestone 2 (Audio & Voiceover Assembly) ve Milestone 3 (Video Compositing) aşamalarında bu yeni ve çok daha kaliteli `AhmetNeural` seslerini birincil ses olarak kullanın!


## 2026-10-17T11:15:03Z

KULLANICI ONAYI VE MİMARİ GÜNCELLEME:

1. **Kullanıcı Kurgu Onayı (31.5 sn Tam Kurgu)**:
   - `0.0 – 21.1 sn`: Sakin, merak uyandıran, grameri kusursuz belgesel What-If anlatımı (`C:\Users\USER\Desktop\KIRMATAS_VIDEO\3_Ses\BOLUM1_Ahmet_Kusursuz_17sn.mp3`, tam 21.10 sn).
   - `21.1 – 21.5 sn`: **SİYAH KARE + TAM SESSİZLİK** (Tüm ses ve müzik kesilir).
   - `21.5 – 28.5 sn`: **BEYAZ FLAŞ + KOZMİK RAKET VURUŞU + %100 GERÇEK FLUTTER OYUNU** (1080x1920 kareler) + `BOLUM2_Ahmet_IsteKirmatas_Aksiyon.mp3` ("İşte Kırmataş! Otuz ateş topuyla ekranı temizle, kaos kartlarını topla, ligde zirveye çık!").
   - `28.5 – 31.5 sn`: **BİTİŞ KARTI** + `BOLUM3_Ahmet_HemenOyna_CTA.mp3` ("Ücretsiz indir, hemen oyna!").

2. **Görsellerdeki Basit Çizimler Temizlendi**:
   - `1_Gorseller/` içindeki tüm basit geometrik çizimler (`K6`'daki çöp adam ve düz koni) tamamen kaldırıldı ve yerine gerçek 3D CGI render'lar konuldu:
     - `K1`: `A_Cocuk_Bilyeyi_Birakiyor.jpg` (Gerçek 3D çocuk, gökdelen çatısı ve bilye)
     - `K5`: `E_Cocugun_Saskin_Tepkisi_1sn.png` (Gerçek 3D şok tepkisi)
     - `K6`: `D_Raket_Sahnesi_Baslangic.png` (Gerçek hacimsel alev topu, kıvılcımlar ve 3D Kozmik Raket)
     - `K7`: `C_Bilye_Renkli_Bloklari_Kiriyor.jpg` (Gerçek 3D parçalanan bloklar)

3. **Adli Denetim Düzeltmesi (TextPainter Font Bağlama)**:
   - `auditor_5_m1_1`'in tespit ettiği ham `TextPainter` çağrılarındaki `Ahem` kutucuklarını önlemek için font yükleyicide varsayılan yazı tipine `Rajdhani` bağlanarak kareler pürüzsüzleştiriliyor. M2 (Audio Mix) ve M3 (Video Compositing) için tüm hazırlıklar tamam. Devam edebilirsiniz!


## 2026-10-17T14:16:06Z

Produce and package a suite of story-driven mobile game video commercials and promotional assets for the brick-breaker game Kırmataş into the Desktop folder C:\Users\USER\Desktop\Kirmatas_Reklam_Videolari.

Working directory: c:\Users\USER\Desktop\KIPKIRMATAS
Integrity mode: development

## Requirements

### R1. Desktop Video Archive & Verification
Verify and organize all produced Cantina MP4 commercials in C:\Users\USER\Desktop\Kirmatas_Reklam_Videolari:
1. 01_Ilk_Drama_Reklami.mp4 (https://d2k000xfhitl0u.cloudfront.net/6ad3549391abaa83580b7d3a%2Fout_01a149bd-e027-7e71-8b58-2d82f895f142.mp4)
2. 02_Penthouse_Kasli_Karpuz_ve_Dolgun_Kizlar.mp4 (https://d2k000xfhitl0u.cloudfront.net/6ad3549391abaa83580b7d3a%2Fout_01a149ea-1ef4-7330-97f7-5c315d610e7c.mp4)
3. 03_Sinematik_Malikane_Yuzlesmesi.mp4 (https://d2k000xfhitl0u.cloudfront.net/6ad3549391abaa83580b7d3a%2Fout_01a14a09-1ed1-7b7e-ad71-eccfca170038.mp4)
4. 04_500_Tuglali_Kasa_Tuzagi_Kurtarma.mp4 (https://d2k000xfhitl0u.cloudfront.net/6ad3549391abaa83580b7d3a%2Fout_01a14a1b-5419-748c-8c91-f0475d69f3a4.mp4)
5. 05_YuzdeYuz_Meyve_Cekici_Strawberry_Diva_Acilis.mp4 (https://d2k000xfhitl0u.cloudfront.net/6ad3549391abaa83580b7d3a%2Fout_01a14a31-4a83-75a2-bb05-81ead1e881e4.mp4)
Also download all individual scene MP4 clips into a Scenes subfolder so the user has both merged master videos and raw clips.

### R2. Underdog / Hidden Power Commercial Variants & Hook Overlay Versions
In addition to the new Cantina renders being produced, use FFmpeg (or Python moviepy/opencv/ffmpeg scripts if available) to create ready-to-post social media variants inside C:\Users\USER\Desktop\Kirmatas_Reklam_Videolari with:
- Burned-in top hook banners (English: "WHAT WAS HE SMASHING ALL NIGHT?!" / "HE WAS HIDING HIS LEVEL 999 POWER!", Turkish: "HERKES ONU EZİK SANDI AMA REKORU KIRDI!").
- Complete production script & storyboard catalog (README_VIDEOLAR.md) in C:\Users\USER\Desktop\Kirmatas_Reklam_Videolari detailing all English and Turkish underdog/rags-to-riches storylines.

## Acceptance Criteria
- [ ] C:\Users\USER\Desktop\Kirmatas_Reklam_Videolari contains all master MP4 files, scene clips, and social-ready hook variants.
- [ ] Every MP4 file in C:\Users\USER\Desktop\Kirmatas_Reklam_Videolari is verified as a valid playable video (>1MB).
- [ ] README_VIDEOLAR.md is present in C:\Users\USER\Desktop\Kirmatas_Reklam_Videolari with full documentation.
