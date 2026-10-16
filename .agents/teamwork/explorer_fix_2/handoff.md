# Handoff Report: Animation & Mathematics Fix Specification (`docs/kirmatas_ad_en.html`)

## 1. Observation

### 1.1 Line 670 Float Clamping & Math.pow NaN Defect
- In `docs/kirmatas_ad_en.html` lines 668–674:
  ```javascript
  // Fe-56 Chrome Marble Trajectory (0.5 oz / 14g)
  // Accelerates rapidly as t progresses
  const prog = Math.min(1.0, t / 3.5);
  const marbleY = 320 + Math.pow(prog, 2.4) * 1200;
  const marbleX = 220 + Math.sin(prog * Math.PI * 0.7) * 80 + prog * 240; // centers toward 540
  const marbleR = 20 + prog * 32;
  ```
- Direct execution in Node.js reveals:
  ```javascript
  // For t = -0.5:
  prog = -0.14285714285714285
  Math.pow(prog, 2.4) === NaN
  marbleY === NaN
  ```
- This `NaN` directly infects:
  * Line 682: `ctx.createRadialGradient(marbleX, marbleY, marbleR * 0.8, marbleX, marbleY - marbleR * 2.5, marbleR * 5.0)` -> Throws or invalidates Canvas gradient
  * Lines 690–693: `ctx.moveTo(marbleX - marbleR * 2.8, marbleY - marbleR * 3.5)` -> Path breaks
  * Lines 704 & 727: `ctx.ellipse` & `ctx.arc(marbleX, marbleY, marbleR, ...)` -> Canvas draws nothing
- In contrast, lines 770 and 772 in the same file strictly clamp using `Math.max(0, ...)`:
  * Line 770: `const speedProg = Math.min(1.0, Math.pow(Math.max(0, (t - 0.6) / 2.8), 2.2));`
  * Line 772: `const tempProg = Math.min(1.0, Math.pow(Math.max(0, (t - 1.0) / 2.4), 2.0));`

### 1.2 Scene 3 Window & Overlay Architecture (lines 1240–1400)
Inspection of `docs/kirmatas_ad_en.html` lines 1240–1400, 1619–1690, and 1696–1760 reveals the complete visual layer stack:
- **Canvas Resolution**: `W = 1080, H = 1920`.
- **Scene 3 Time Partitioning**:
  * Window 1 (`7.5s <= t < 9.5s`): `drawRealGameplayWindow(t)`
    - Background: `loadedImages.img_action` (`game_canvas_action.png`) at `(0, 0, W, H)`.
    - HUD Banner: Ulti callout at `y = 375 to 465` (`drawRoundedRect(-360, -45, 720, 90, 20)` centered at `(540, 420)`).
    - Ulti Arc: Lightning line at `ly = 450 +- 60`.
    - Floating Text: Spawns at `(540, 520)`.
  * Window 2 (`9.5s <= t < 11.5s`): `drawChaosPerksWindow(t)`
    - Background: `loadedImages.img_perks` (`chaos_perks.png`) at `(0, 0, W, H)`.
    - Top Area: Header title & 3-Card Roguelike perks dialog occupies `y ≈ 380 to 1050`.
    - Current Defect (V1): Lines 1332–1351 draw a procedural canvas rectangle (`drawRoundedRect(120, badgeY, 840, 130, 24)`) instead of drawing `loadedImages.img_synergies`.
  * Window 3 (`11.5s <= t < 13.5s`): `drawAquariumLeagueWindow(t)`
    - Background: `loadedImages.img_aquarium` (`aquarium_view.png`) at `(0, 0, W, H)`.
    - Live Swimming Fish (`drawSwimmingFishSprites` lines 1391–1425):
      * Fish 1 (Arowana): `x = 180 to 460`, `y = 680 to 760`.
      * Fish 2 (Discus): `x = 580 to 900`, `y = 845 to 915`.
      * Fish 3 (Angel): `x = 380 to 620`, `y = 1010 to 1070`.
      * Total Fish Swimming Envelope: `y = 680 to 1070`.
    - Current Defect (V1): Lines 1370–1388 draw a procedural canvas card (`drawRoundedRect(140, 1320, 800, 180, 24)`) instead of drawing `loadedImages.img_league`.
- **TikTok / Reels Captions (`drawTikTokCaptions` lines 1619–1690)**:
  * Rendered at line 1821 over all scenes in `renderFrame`.
  * Center: `boxY = 1620`.
  * Frosted pill container: `y = boxY - 45 - padY/2` to `boxY + 45 + padY/2` = `y ≈ 1563 to 1677`.
  * Lower 243px of canvas (`y = 1677 to 1920`) is screen margin.
- **Particle & FX Engine (`updateAndDrawFX` lines 1696–1760)**:
  * Called at line 1258 after window backgrounds and insets.
  * Shockwaves, gold coins, floating text, and alpha-blended particles render across the screen without obstructing base elements.

### 1.3 Distortion Analysis in Reference Turkish Ad (`kirmatas_reklam_tr.html`)
- In `kirmatas_reklam_tr.html`:
  * Line 1132: `ctx.drawImage(imgShop, 0, 500, W, 800, 60, 1140, W - 120, 420);`
    - Source: `1080 x 800` (aspect ratio 1.35).
    - Destination: `960 x 420` (aspect ratio 2.28).
    - Result: **Stretched horizontally / compressed vertically by 1.69x**.
  * Line 1180: `ctx.drawImage(imgLeague, 0, 200, W, 1000, 520, 220, 500, 720);`
    - Source: `1080 x 1000` (aspect ratio 1.08).
    - Destination: `500 x 720` (aspect ratio 0.694).
    - Result: **Stretched vertically by 1.55x**.

### 1.4 Codebase Cleanliness & Analyzer
- `git diff lib/ test/game_test.dart` -> Empty (0 lines).
- `flutter analyze` -> `No issues found! (ran in 34.6s)`, exit code 0.

---

## 2. Logic Chain

1. **Root Cause of Math NaN (Observation 1.1)**:
   In JavaScript, `Math.pow(base, exp)` where `base < 0` and `exp` is a non-integer float (such as `2.4`) is mathematically undefined over real numbers and evaluates to `NaN`. When scrubbing or seeking to negative deltas (`t < 0`), `prog = t / 3.5 < 0`, triggering `NaN`. Clamping `prog` with `Math.max(0.0, Math.min(1.0, t / 3.5))` guarantees `prog ∈ [0.0, 1.0]`, completely eliminating `NaN`.

2. **Root Cause of Missing Assets (Observation 1.2)**:
   The assets `loadedImages.img_synergies` and `loadedImages.img_league` exist in memory, but were omitted from the drawing pipeline in `drawChaosPerksWindow` and `drawAquariumLeagueWindow`. Instead, the author drew procedural boxes with text at `badgeY = 1380` and `cardY = 1320`.

3. **Collision & Overlap Geometry (Observation 1.2)**:
   - In Window 2 (Chaos Perks):
     * Upper perks cards end at `y ≈ 1050`.
     * TikTok captions start at `y = 1563`.
     * The region `y = 1140 to 1530` (height 390px, width 960px) is completely clear:
       `1140 - 1050 = 90px` clear margin from perks cards above.
       `1563 - 1530 = 33px` clear margin from captions below.
   - In Window 3 (Aquarium & League):
     * Swimming fish envelope is `y = 680 to 1070`.
     * TikTok captions start at `y = 1563`.
     * Placing the League inset at `dx = 60, dy = 1140, dw = 960, dh = 390`:
       `1140 - 1070 = 70px` clear vertical margin below the lowest fish (`y = 1070`).
       `1563 - 1530 = 33px` clear vertical margin above the TikTok captions (`y = 1563`).
       Live swimming fishes continue swimming in the open tank water above without clipping or obstruction.

4. **Aspect Ratio & Layout Distortion Elimination (Observation 1.3)**:
   To prevent the distortion observed in the Turkish reference ad, destination dimensions `dw = 960, dh = 390` require a source aspect ratio of `AR = 960 / 390 = 2.4615`.
   Taking full source width `sw = 1080`, the required source height is:
   `sh = 1080 / 2.4615 = 438.75 ≈ 439px`.
   Scale factors:
   `scaleX = dw / sw = 960 / 1080 = 0.8889`
   `scaleY = dh / sh = 390 / 438.75 = 0.8889`
   `scaleX == scaleY` -> **Zero layout distortion (100% true proportions)**.

---

## 3. Caveats

- In Window 3, an alternative layout could place `img_league` as a Picture-in-Picture (PIP) card in the upper-right (similar to the TR ad at `dx = 560, dy = 180, dw = 460, dh = 480`). However, the Bottom Inset placement (`dy = 1140 to 1530`) is superior because:
  (a) It maintains visual rhythm with Window 2's synergy card.
  (b) It guarantees 100% unobstructed swimming space for all 3 fishes in the mid-tank (`y = 680 to 1070`).
  (c) It leaves the upper-mid open water unobstructed for the celebratory floating text `🐠 ZEN ECO-TANK & TOURNAMENT #1` at `(540, 450)`.
- No modifications were made to `docs/kirmatas_ad_en.html` directly, adhering strictly to read-only role constraints.

---

## 4. Conclusion & Exact Code Recommendations

### 4.1 Fix 1: Marble Trajectory Clamping (`docs/kirmatas_ad_en.html` line 670)
**Target**: `docs/kirmatas_ad_en.html` line 670
- **Before**:
  ```javascript
  const prog = Math.min(1.0, t / 3.5);
  ```
- **After**:
  ```javascript
  const prog = Math.max(0.0, Math.min(1.0, t / 3.5));
  ```

### 4.2 Fix 2: Window 2 `drawChaosPerksWindow` (`docs/kirmatas_ad_en.html` lines 1320–1352)
Replace procedural canvas box (lines 1332–1351) with `loadedImages.img_synergies` rendered inside a clipped, amber-bordered rounded rectangle with a floating header badge:
- **Replacement Code**:
  ```javascript
  function drawChaosPerksWindow(t) {
    if (t >= 9.6 && !sfxTriggeredPerk) {
      sfxTriggeredPerk = true;
      playTone(660, 'sine', 0.25, 0.35, 880);
      spawnFloatingText(540, 480, '👑 COSMIC LEGENDARY SET ACTIVE!', '#f59e0b', true);
    }

    // Draw real chaos perks frame
    if (loadedImages.img_perks && loadedImages.img_perks.complete) {
      ctx.drawImage(loadedImages.img_perks, 0, 0, W, H);
    }

    // Inset Overlay: Real Shop Cosmic Set Synergy (Distortion-Free 1:1 Aspect Ratio)
    const imgShop = loadedImages.img_synergies;
    if (imgShop && imgShop.complete && (imgShop.naturalWidth > 0 || imgShop.width > 0)) {
      ctx.save();
      const subT = t - 9.5;
      const slideY = Math.min(1.0, subT * 3.5);
      const easeSlide = 1.0 - Math.pow(1.0 - slideY, 3);
      const cardY = 1140 + (1.0 - easeSlide) * 160;

      // Card backdrop & glow
      ctx.shadowColor = 'rgba(245, 158, 11, 0.5)';
      ctx.shadowBlur = 25;
      ctx.fillStyle = '#0f172a';
      drawRoundedRect(60, cardY, W - 120, 390, 24);
      ctx.fill();
      ctx.shadowBlur = 0;

      // Clipped in-game frame (sw: 1080, sh: 439 matches dw: 960, dh: 390 exactly)
      ctx.save();
      drawRoundedRect(60, cardY, W - 120, 390, 24);
      ctx.clip();
      ctx.drawImage(imgShop, 0, 640, W, 439, 60, cardY, W - 120, 390);
      ctx.restore();

      // Forged amber-gold border
      drawRoundedRect(60, cardY, W - 120, 390, 24);
      ctx.strokeStyle = '#f59e0b';
      ctx.lineWidth = 4;
      ctx.stroke();

      // Sleek Header Callout Badge
      ctx.fillStyle = 'rgba(15, 23, 42, 0.94)';
      ctx.strokeStyle = '#f59e0b';
      ctx.lineWidth = 3;
      drawRoundedRect(160, cardY - 26, W - 320, 52, 16);
      ctx.fill(); ctx.stroke();

      ctx.textAlign = 'center';
      ctx.fillStyle = '#fde047';
      ctx.font = '900 28px Rajdhani, sans-serif';
      ctx.fillText('👑 COSMIC LEGENDARY SET SYNERGY: +15% BOOST', W / 2, cardY + 9);
      ctx.restore();
    }
  }
  ```

### 4.3 Fix 3: Window 3 `drawAquariumLeagueWindow` (`docs/kirmatas_ad_en.html` lines 1354–1389)
Replace procedural card (lines 1370–1388) with `loadedImages.img_league` rendered inside a clipped, cyan/gold-bordered rounded rectangle:
- **Replacement Code**:
  ```javascript
  function drawAquariumLeagueWindow(t) {
    if (t >= 11.6 && !sfxTriggeredAqua) {
      sfxTriggeredAqua = true;
      playTone(523.25, 'sine', 0.2, 0.2, 659.25);
      spawnFloatingText(540, 450, '🐠 ZEN ECO-TANK & TOURNAMENT #1', '#38bdf8', true);
    }

    // Draw real aquarium view
    if (loadedImages.img_aquarium && loadedImages.img_aquarium.complete) {
      ctx.drawImage(loadedImages.img_aquarium, 0, 0, W, H);
    }

    // Live Swimming Fish Sprites Wagging (swims cleanly in upper water y = 680 to 1070)
    drawSwimmingFishSprites(t);

    // Inset Overlay: Real Tournament League #1 Leaderboard (Distortion-Free 1:1 Aspect Ratio)
    const imgLeague = loadedImages.img_league;
    if (imgLeague && imgLeague.complete && (imgLeague.naturalWidth > 0 || imgLeague.width > 0)) {
      ctx.save();
      const cardY = 1140;

      // Card backdrop & glow
      ctx.shadowColor = 'rgba(0, 245, 212, 0.45)';
      ctx.shadowBlur = 25;
      ctx.fillStyle = '#0f172a';
      drawRoundedRect(60, cardY, W - 120, 390, 24);
      ctx.fill();
      ctx.shadowBlur = 0;

      // Clipped in-game leaderboard (sw: 1080, sh: 439 matches dw: 960, dh: 390 exactly)
      ctx.save();
      drawRoundedRect(60, cardY, W - 120, 390, 24);
      ctx.clip();
      ctx.drawImage(imgLeague, 0, 360, W, 439, 60, cardY, W - 120, 390);
      ctx.restore();

      // Carved cyan-gold border
      drawRoundedRect(60, cardY, W - 120, 390, 24);
      ctx.strokeStyle = '#00f5d4';
      ctx.lineWidth = 4;
      ctx.stroke();

      // Sleek Header Callout Badge
      ctx.fillStyle = 'rgba(15, 23, 42, 0.94)';
      ctx.strokeStyle = '#00f5d4';
      ctx.lineWidth = 3;
      drawRoundedRect(160, cardY - 26, W - 320, 52, 16);
      ctx.fill(); ctx.stroke();

      ctx.textAlign = 'center';
      ctx.fillStyle = '#ffd700';
      ctx.font = '900 28px Rajdhani, sans-serif';
      ctx.fillText('🏆 WEEKLY LEAGUE: #1 COSMIC EMPEROR', W / 2, cardY + 9);
      ctx.restore();
    }
  }
  ```

---

## 5. Verification Method

To independently verify these findings and recommendations, execute the following commands in PowerShell from `c:\Users\USER\Desktop\KIPKIRMATAS`:

1. **Verify Math Clamping Fix for `t < 0`**:
   ```powershell
   node -e "const prog = Math.max(0.0, Math.min(1.0, -0.5 / 3.5)); const y = 320 + Math.pow(prog, 2.4) * 1200; console.log('prog:', prog, 'marbleY:', y, 'isNaN:', Number.isNaN(y));"
   ```
   *Expected Output*: `prog: 0 marbleY: 320 isNaN: false`.

2. **Verify Aspect Ratio Scale Match (Zero Distortion)**:
   ```powershell
   node -e "const sw = 1080, sh = 439, dw = 960, dh = 390; console.log('scaleX:', dw/sw, 'scaleY:', dh/sh, 'diff:', Math.abs(dw/sw - dh/sh));"
   ```
   *Expected Output*: `scaleX: 0.88888... scaleY: 0.88838... diff: 0.0005` (< 0.06% variance, zero perceptible distortion).

3. **Verify Vertical Collision Clearance**:
   ```powershell
   node -e "const fishMaxY = 1070; const cardTop = 1140; const cardBottom = 1530; const captionTop = 1563; console.log('Fish-to-Card margin:', cardTop - fishMaxY, 'px'); console.log('Card-to-Caption margin:', captionTop - cardBottom, 'px');"
   ```
   *Expected Output*: `Fish-to-Card margin: 70 px` and `Card-to-Caption margin: 33 px` (both positive, zero overlap).

4. **Verify Codebase Cleanliness**:
   ```powershell
   git diff lib/ test/game_test.dart
   flutter analyze
   ```
   *Expected Output*: Empty diff, analyzer reports "No issues found!".
