# Handoff Report: Codebase, Widgets & Flutter Offscreen Capture Survey

**Agent**: Explorer 1 (Codebase, Widgets & Flutter Capture Specialist)  
**Working Directory**: `c:\Users\USER\Desktop\KIPKIRMATAS\.agents\teamwork\explorer_survey_1`  
**Date**: 2026-10-16  
**Status**: COMPLETE  

---

## 1. Observation

### 1.1 Existing Game Assets Audit
A comprehensive filesystem inspection of the `assets/` directory revealed the following production assets:

#### Audio Assets (`assets/audio/`)
| Filename | File Size | Format | Usage Context |
|---|---|---|---|
| `assets/audio/bgm.wav` | 14,725,608 bytes (14.04 MB) | WAV (PCM) | Primary game soundtrack / looping BGM |
| `assets/audio/cam_kirilma.mp3` | 25,389 bytes | MP3 | Glass fracture sound effect |
| `assets/audio/glass_shatter.mp3` | 25,389 bytes | MP3 | Heavy glass shatter / brick break SFX |
| `assets/audio/custom_laser.wav` | 22,094 bytes | WAV | Laser projectile sound effect |
| `assets/audio/custom_explosion.wav` | 44,144 bytes | WAV | Bomb / Dynamite / Meteor explosion SFX |
| `assets/audio/custom_bounce.wav` | 8,864 bytes | WAV | Paddle / wall bounce SFX |
| `assets/audio/crystal_tap.mp3` | 12,717 bytes | MP3 | Subtle crystal impact |
| `assets/audio/crystal_block.mp3` | 25,389 bytes | MP3 | Armored / crystal block hit |
| `assets/audio/digital_explo1.mp3` | 49,581 bytes | MP3 | Digital explosion effect 1 |
| `assets/audio/digital_explo2.mp3` | 49,581 bytes | MP3 | Digital explosion effect 2 |
| `assets/audio/ui_fx1.mp3` | 49,581 bytes | MP3 | Ultimate activation / fanfare |
| `assets/audio/glass_glow.mp3` | 49,581 bytes | MP3 | Neon glow effect |
| `assets/audio/glass_neon1.mp3` | 25,389 bytes | MP3 | Neon brick hit 1 |
| `assets/audio/glass_neon2.mp3` | 25,389 bytes | MP3 | Neon brick hit 2 |

#### Fonts (`assets/fonts/`)
| Filename | File Size | Format |
|---|---|---|
| `assets/fonts/Rajdhani-Bold.ttf` | 400,680 bytes | TrueType Font (Bold) |
| `assets/fonts/Rajdhani-SemiBold.ttf` | 390,340 bytes | TrueType Font (SemiBold) |
| `assets/fonts/Rajdhani-Medium.ttf` | 384,348 bytes | TrueType Font (Medium) |
| `assets/fonts/Rajdhani-Regular.ttf` | 377,860 bytes | TrueType Font (Regular) |

#### Brand & Studio Logo (`assets/images/`)
| Filename | File Size | Format | Dimensions |
|---|---|---|---|
| `assets/images/kaunos_games.png` | 662,182 bytes | PNG | High-res studio logo / branding |

#### Aquarium Fish Sprites (`assets/images/fishes/`, 18 files)
| Filename | File Size | Filename | File Size |
|---|---|---|---|
| `angel_aqua.png` | 149,159 bytes | `angel_ruby.png` | 144,211 bytes |
| `angel.png` | 149,231 bytes | `arowana_red.png` | 226,880 bytes |
| `arowana_silver.png` | 211,621 bytes | `arowana.png` | 212,908 bytes |
| `betta_blue.png` | 96,290 bytes | `betta_orange.png` | 96,045 bytes |
| `betta.png` | 98,861 bytes | `discus_blue.png` | 228,392 bytes |
| `discus_green.png` | 222,483 bytes | `discus.png` | 207,923 bytes |
| `guppy_blue.png` | 128,215 bytes | `guppy_green.png` | 126,301 bytes |
| `guppy.png` | 125,007 bytes | `tetra_gold.png` | 359,002 bytes |
| `tetra_purple.png` | 362,449 bytes | `tetra.png` | 317,306 bytes |

#### Skill / Powerup Icons (`assets/images/skills/`, 23 files)
| Filename | File Size | Filename | File Size |
|---|---|---|---|
| `bomb.png` | 51,265 bytes | `chrono.png` | 103,586 bytes |
| `clumsy.png` | 130,322 bytes | `doublescore.png` | 111,286 bytes |
| `drone.png` | 69,491 bytes | `fastball.png` | 53,600 bytes |
| `fireball.png` | 73,774 bytes | `invis.png` | 55,241 bytes |
| `laser.png` | 75,199 bytes | `life.png` | 86,396 bytes |
| `lightning.png` | 74,327 bytes | `lock.png` | 71,972 bytes |
| `mirror.png` | 102,137 bytes | `multi.png` | 66,876 bytes |
| `net.png` | 178,631 bytes | `pierce.png` | 58,606 bytes |
| `reverse.png` | 70,587 bytes | `rocket.png` | 99,764 bytes |
| `shield.png` | 73,534 bytes | `shrink.png` | 58,102 bytes |
| `slow.png` | 74,158 bytes | `sticky.png` | 64,240 bytes |
| `vortex.png` | 278,850 bytes | `wide.png` | 54,089 bytes |

---

### 1.2 Codebase Widgets, Controllers & Painters Inspection

1. **`GameCanvas` & `_GameWorldPainter` (`lib/ui/game_canvas.dart:18-5615`)**:
   - `GameCanvas` sets dimensions on `controller.setDimensions(maxWidth, maxHeight)` (line 69).
   - Renders the custom world via `CustomPaint(size: Size(...), painter: _GameWorldPainter(widget.controller))` (line 187-190).
   - **Fireball & Ball Trails (`lib/ui/game_canvas.dart:3439-3580`)**:
     - Controlled by `ball.isFireball`.
     - In `_drawBalls`, fireball trails generate intense amber/gold undulating starlight filaments (`Color(0xFFFFAB00)`), shimmering fiery orbs (`Color(0xFFFF6D00)` to `Color(0xFFFFD700)`), and luminous halos (`_ca(skin.glowColor, 0.45)`).
   - **Ulti Ready Callout Banner (`lib/ui/game_canvas.dart:5374-5415`)**:
     - Condition: `c.isUltiReady` (`!isChaosMode && (stats.diceCharge >= stats.diceChargeMax || stats.ultiCharge >= 100.0)`).
     - Renders a pulsing golden callout at `y = size.height * 0.22`:
       `⚡ ULTİ HAZIR! ÇİFT DOKUN!` with gold shadow `Color(0xFFFF6D00)`.
   - **Super Corner Hit Slow-Mo Banner (`lib/engine/game_controller.dart:2198-2214`)**:
     - Triggers on `isCornerHit = hitOffset.abs() >= 0.78`.
     - Sets slow-mo: `stats.bulletTimeLeft = 0.75;`
     - Spawns screen shockwave: `particles.spawnShockwave(ball.x, pr.top, const Color(0xFFFFD700), maxRadius: 85.0);`
     - Spawns floating celebratory banner: `particles.spawnFloatingText(screenWidth / 2, screenHeight * 0.38, '⚡ SÜPER KÖŞE VURUŞU!', const Color(0xFFFFD700), isLarge: true);`

2. **Chaos Mode 3-Card Perk Selection & Boss Brick (`lib/ui/game_canvas.dart:200-344`)**:
   - When `c.offeredChaosPerks.isNotEmpty`:
     - Displays `chaos_perk_selection_overlay` modal over the live playfield.
     - Header: `⚡ KAOS GÜÇLENDİRMESİ SEÇ` + `Dalga ${c.stats.level} Ödülü — Bu koşu boyunca birikir`.
     - Renders 3 selectable cards with icons, Turkish title (`perk.titleTr`), and descriptions (`perk.descriptionTr`).
     - In the HUD above, `active_chaos_perks_hud` displays all stacked perk badges with counters (e.g. `x2`).
   - **Wave-10 Chaos Boss Brick (`lib/models/level_design.dart:1327-1347`, `lib/ui/game_canvas.dart:2227-2270`, `5244-5270`)**:
     - Boss brick type: `BrickType.boss` (`isBoss: true`).
     - Rendered via `_drawBoss` with Dark Titanium Mecha hull (`Color(0xFF141724)`), dual thruster exhaust pulses (`Color(0xFFFF5722)`), left/right wing armor plates, arcade hazard stripes, and boss HP gauge.
     - Warning banner rendered via `_drawBossWarningBanner` when `c.bossWarningTimer > 0` with top/bottom animated hazard warning stripes.

3. **`AquariumView` & `EcoTankBackground` (`lib/ui/aquarium_view.dart`, `lib/ui/eco_tank_background.dart`)**:
   - `AquariumView` hosts `EcoTankBackground(key: _tankKey)` with deep oceanic gradient water (`LinearGradient` with `0xFF0C1726`, `0xFF09131F`, `0xFF040A10`), realistic swaying kelp plants, ascending bubbles, food pellets, and tap reaction heart particles.
   - Fish sprites loaded dynamically from `AssetCache.instance.getFishImage(f.item.id)` using real fish PNG files (`arowana_red.png`, `discus_blue.png`, etc.) with dynamic pitch tilting, swim wagging, and flip transitions.
   - Includes interactive Fish Hoard Chest (`FishHoardChest`) with animated coin yields.

4. **`ShopView` & Cosmetic Set Synergies (`lib/ui/shop_view.dart:418-474`)**:
   - Renders active synergy banner `active_cosmetic_synergy_badge`:
     - 🔥 **Ateş / Günbatımı Sinerjisi** (`CosmeticSynergy.fireSunset`): `+15% Patlama Yarıçapı ve Kombo İvmesi`.
     - ❄️ **Buz / Kristal Sinerjisi** (`CosmeticSynergy.iceCrystal`): `Buz/Zırhlı Bloklara Ekstra Hasar & Yavaşlatma Direnci`.
     - 👑 **Kozmik Efsanevi Set** (`CosmeticSynergy.cosmicLegendary`): `+15% Skor ve Altın Çarpanı`.
   - Also displays current Gold, Pearls, Category Crates (Top, Raket, İz, Arka Plan), and shard inventory.

5. **`TournamentDialog` (`lib/ui/tournament_dialog.dart:1-371`)**:
   - Modal bottom sheet displaying `HAFTALIK LİG ŞAMPİYONASI`.
   - Displays player league tier badge (`save.leagueTierColor`), current rank, seasonal title (e.g. `Kozmik İmparator`), rivals leaderboard, promotion zone, and demotion zone.

---

### 1.3 Offscreen Flutter 1080x1920 Automated Capture Findings
We empirically investigated offscreen headless capture using Flutter's widget test framework:
- By configuring `tester.view.physicalSize = const Size(1080, 1920)` and `tester.view.devicePixelRatio = 1.0`, Flutter creates an exact 1080x1920 viewport.
- Wrapping the target widget inside a `RepaintBoundary(key: repaintKey)` allows extracting the rasterized texture via `RenderRepaintBoundary.toImage(pixelRatio: 1.0)`.
- **Key Technical Discovery**: Calling `boundary.toImage()`, `AssetCache.instance.init()`, or file write I/O inside standard `testWidgets` executes asynchronous engine raster tasks on Skia/Impeller threads. In Flutter's test runner, these calls must be wrapped inside:
  ```dart
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    File('docs/ad_assets/$filename').writeAsBytesSync(byteData!.buffer.asUint8List());
    image.dispose();
  });
  ```
- **Audio Mocking Discovery**: Accessing `AudioManager.instance` or letting `GameController.update()` run while `sfxVolume > 0` triggers real audio playback calls that look for `xyz.luan/audioplayers/events/*` channels. Setting `SaveManager.instance.sfxVolume = 0` and `SaveManager.instance.bgmVolume = 0` in test setup prevents unmocked stream exceptions.

---

## 2. Logic Chain

1. **Premise 1**: The promotional video advertisements require authentic, high-fidelity in-game gameplay frames at 1080x1920 (9:16 vertical 60 FPS) directly from Kırmataş's widgets and painters (`ORIGINAL_REQUEST.md`).
2. **Premise 2**: Running `flutter test` provides a headless Skia/Impeller environment capable of rendering any Flutter widget hierarchy without an emulator or physical device.
3. **Execution**: We engineered a temporary test script (`test/capture_ad_assets_test.dart`) that:
   - Sets `tester.view.physicalSize = const Size(1080, 1920)` and `devicePixelRatio = 1.0`.
   - Pre-initializes `AssetCache.instance.init()` inside `tester.runAsync()`.
   - Instantiates 6 distinct game scenes (`game_canvas_action.png`, `chaos_perks.png`, `aquarium_view.png`, `shop_synergies.png`, `tournament_league.png`, `chaos_boss.png`).
   - Rasterizes each via `boundary.toImage(pixelRatio: 1.0)` and writes to `docs/ad_assets/`.
4. **Result Verification**: All 6 files were generated and verified via `System.Drawing.Image` to be precisely 1080x1920 pixels with nonzero bytes:
   - `game_canvas_action.png`: 854,106 bytes (1080x1920)
   - `chaos_perks.png`: 251,846 bytes (1080x1920)
   - `aquarium_view.png`: 157,713 bytes (1080x1920)
   - `shop_synergies.png`: 316,779 bytes (1080x1920)
   - `tournament_league.png`: 83,612 bytes (1080x1920)
   - `chaos_boss.png`: 241,582 bytes (1080x1920)
5. **Codebase Cleanliness**: The temporary test files were deleted after capture. `git diff lib/ test/game_test.dart` is zero, `git status --porcelain test/` is clean, and `flutter analyze` verified 0 errors, 0 warnings.

---

## 3. Caveats

1. **Audio Player in Web Ad Exporters**: The audio assets (`assets/audio/*.mp3`, `*.wav`) are in standard web-compatible formats (PCM WAV and MP3). The video ad HTML files can reference them directly via relative paths (`../assets/audio/...`) or inline base64 data URIs.
2. **Web Font Loading**: The `Rajdhani` fonts are TrueType (`.ttf`). In standalone HTML files, they can be loaded via `@font-face` referencing `../assets/fonts/Rajdhani-Bold.ttf` or embedded as base64 WOFF/TTF data URIs for 100% self-contained offline portability.
3. **No Codebase Pollution**: All production code under `lib/` remains untouched and 100% clean.

---

## 4. Conclusion

1. **Assets**: All requested audio (`cam_kirilma.mp3`, `glass_shatter.mp3`, `custom_laser.wav`, `custom_explosion.wav`, `bgm.wav`), fonts (`Rajdhani-*`), fish sprites (18 PNGs), skill icons (23 PNGs), and branding (`kaunos_games.png`) are completely verified and ready for integration.
2. **Widgets & Render Mechanics**: The exact state configurations for rendering Fireball, Multiball, Ulti Callout, Super Corner Hit slow-mo, Chaos Roguelike 3-Card perk selection, Wave-10 Chaos Boss brick with warning banner, AquariumView with live fishes, ShopView set synergies, and TournamentDialog weekly league have been mapped and validated.
3. **Automated Capture Recipe**: The headless test capture pipeline (`tester.view.physicalSize = Size(1080, 1920)` + `tester.runAsync()`) executes in under 5 seconds, producing genuine 1080x1920 PNG frames directly in `docs/ad_assets/`.
4. **Deliverables Ready**: All 6 real in-game 1080x1920 PNG assets are committed in `docs/ad_assets/` and available for the video ad generators (`docs/kirmatas_reklam_tr.html` and `docs/kirmatas_ad_en.html`).

---

## 5. Verification Method

To independently verify all findings and assets:

1. **Verify Captured 1080x1920 Frames**:
   ```powershell
   powershell -Command "Add-Type -AssemblyName System.Drawing; Get-ChildItem 'docs/ad_assets/*.png' | ForEach-Object { `$img = [System.Drawing.Image]::FromFile(`$_.FullName); [PSCustomObject]@{ File = `$_.Name; Resolution = `"`$(`$img.Width)x`$(`$img.Height)`"; SizeBytes = `$_.Length }; `$img.Dispose() }"
   ```
   *Expected Output*: Exactly 6 files (`aquarium_view.png`, `chaos_boss.png`, `chaos_perks.png`, `game_canvas_action.png`, `shop_synergies.png`, `tournament_league.png`), all showing `Resolution = 1080x1920`.

2. **Verify Codebase Cleanliness**:
   ```powershell
   git diff lib/ test/game_test.dart
   ```
   *Expected Output*: Empty output (zero diff).

3. **Verify Static Analysis**:
   ```powershell
   flutter analyze
   ```
   *Expected Output*: `No issues found!`.

---

### Reference: Complete Standalone Capture Script Recipe
For future reference or automated pipeline re-runs, the complete tested script is:
```dart
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kirmatas/engine/asset_cache.dart';
import 'package:kirmatas/engine/audio_manager.dart';
import 'package:kirmatas/engine/game_controller.dart';
import 'package:kirmatas/models/ball.dart';
import 'package:kirmatas/models/brick.dart';
import 'package:kirmatas/models/cosmetics.dart';
import 'package:kirmatas/models/game_state.dart';
import 'package:kirmatas/models/powerup.dart';
import 'package:kirmatas/storage/save_manager.dart';
import 'package:kirmatas/ui/aquarium_view.dart';
import 'package:kirmatas/ui/game_canvas.dart';
import 'package:kirmatas/ui/shop_view.dart';
import 'package:kirmatas/ui/tournament_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers.global'),
      (MethodCall methodCall) async => 1,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers'),
      (MethodCall methodCall) async => 1,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers.global/events'),
      (MethodCall methodCall) async => null,
    );
    AudioManager.instance.isBgmAllowed = false;
  });

  Future<void> captureWidget({
    required WidgetTester tester,
    required Widget widget,
    required String filename,
  }) async {
    final GlobalKey repaintKey = GlobalKey();
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(
      RepaintBoundary(
        key: repaintKey,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData.dark(),
          home: Scaffold(
            backgroundColor: const Color(0xFF070B14),
            body: widget,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));

    await tester.runAsync(() async {
      final boundary = repaintKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData!.buffer.asUint8List();

      final dir = Directory('docs/ad_assets');
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }
      final file = File('docs/ad_assets/$filename');
      file.writeAsBytesSync(pngBytes);
      image.dispose();
      print('Captured: docs/ad_assets/$filename (${pngBytes.length} bytes)');
    });
  }

  group('Capture 1080x1920 Game Assets Suite', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await SaveManager.instance.init();
      SaveManager.instance.sfxVolume = 0;
      SaveManager.instance.bgmVolume = 0;
    });

    testWidgets('1. Capture game_canvas_action.png', (tester) async {
      final gc = GameController();
      gc.setDimensions(1080, 1920);
      gc.startNewGame(GameMode.classic, explicitStartLevel: 1);
      gc.balls.clear();
      gc.balls.addAll([
        Ball(x: 540, y: 1100, vx: 220, vy: -420, isFireball: true),
        Ball(x: 420, y: 1250, vx: -260, vy: -380, isFireball: true),
        Ball(x: 680, y: 1180, vx: 300, vy: -350),
      ]);
      gc.stats.ultiCharge = 100.0;
      gc.particles.spawnFloatingText(540, 1920 * 0.38, '⚡ SÜPER KÖŞE VURUŞU!', const Color(0xFFFFD700), isLarge: true);
      gc.particles.spawnShockwave(540, 1920 * 0.38, const Color(0xFFFFD700), maxRadius: 160);
      await captureWidget(tester: tester, widget: GameCanvas(controller: gc), filename: 'game_canvas_action.png');
    });

    testWidgets('2. Capture chaos_perks.png', (tester) async {
      final gc = GameController();
      gc.setDimensions(1080, 1920);
      gc.startNewGame(GameMode.chaos, explicitStartLevel: 5);
      gc.offeredChaosPerks.clear();
      gc.offeredChaosPerks.addAll([ChaosPerkType.emberCore, ChaosPerkType.chainShock, ChaosPerkType.microBlast]);
      gc.activeChaosPerks.clear();
      gc.activeChaosPerks.addAll([ChaosPerkType.goldenVolley, ChaosPerkType.magnetPull]);
      await captureWidget(tester: tester, widget: GameCanvas(controller: gc), filename: 'chaos_perks.png');
    });

    testWidgets('3. Capture aquarium_view.png', (tester) async {
      await tester.runAsync(() async => await AssetCache.instance.init());
      SaveManager.instance.unlockedFish = ['arowana_red', 'discus_blue', 'angel_ruby', 'betta_blue', 'tetra_gold', 'guppy_blue'];
      SaveManager.instance.fishFood = 45;
      await captureWidget(tester: tester, widget: const AquariumView(), filename: 'aquarium_view.png');
    });

    testWidgets('4. Capture shop_synergies.png', (tester) async {
      SaveManager.instance.activePaddle = 'paddle_inferno';
      SaveManager.instance.activeBall = 'ball_sunset';
      SaveManager.instance.activeTrail = 't1';
      SaveManager.instance.gold = 3500;
      SaveManager.instance.pearls = 42;
      await captureWidget(tester: tester, widget: const ShopView(), filename: 'shop_synergies.png');
    });

    testWidgets('5. Capture tournament_league.png', (tester) async {
      SaveManager.instance.highestLevel = 14;
      SaveManager.instance.leagueTier = 4;
      await captureWidget(tester: tester, widget: TournamentDialog(save: SaveManager.instance), filename: 'tournament_league.png');
    });

    testWidgets('6. Capture chaos_boss.png', (tester) async {
      final gc = GameController();
      gc.setDimensions(1080, 1920);
      gc.startNewGame(GameMode.chaos, explicitStartLevel: 10);
      gc.bossWarningTimer = 1.1;
      await captureWidget(tester: tester, widget: GameCanvas(controller: gc), filename: 'chaos_boss.png');
    });
  });
}
```
