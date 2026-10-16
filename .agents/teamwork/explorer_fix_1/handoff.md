# Explorer Fix 1 Handoff Report: TR vs EN Scene 3 Inset Drawing Investigation & Fix Formulation

## 1. Observation

### 1.1 Inset Drawing Deficiency in `docs/kirmatas_ad_en.html`
In `docs/kirmatas_ad_en.html`:
- Lines 199 and 201 embed `img_synergies` (from `docs/ad_assets/shop_synergies.png`, 316,779 bytes) and `img_league` (from `docs/ad_assets/tournament_league.png`, 83,612 bytes) in `IMAGE_ASSETS`:
  ```javascript
  199:   'img_synergies': 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAABDgAAAeACAYAAA...',
  201:   'img_league': 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAABDgAAAeACAYAAAArY...',
  ```
- Lines 218-238 load all entries of `IMAGE_ASSETS` into `loadedImages`:
  ```javascript
  236:     loadedImages[key] = img;
  ```
- However, AST and text analysis reveals that **neither `loadedImages.img_synergies` nor `loadedImages.img_league` is ever rendered onto the canvas via `ctx.drawImage`**.
  * `loadedImages.img_synergies`: **0 occurrences of drawImage**.
  * `loadedImages.img_league`: **0 occurrences of drawImage**.

### 1.2 Verbatim Code in `docs/kirmatas_ad_en.html` (Lines 1320–1389)
Currently, `drawChaosPerksWindow` (lines 1320–1352) and `drawAquariumLeagueWindow` (lines 1354–1389) draw procedural canvas rectangles instead of rendering the captured images:
```javascript
1320: function drawChaosPerksWindow(t) {
1321:   if (t >= 9.6 && !sfxTriggeredPerk) {
1322:     sfxTriggeredPerk = true;
1323:     playTone(660, 'sine', 0.25, 0.35, 880);
1324:     spawnFloatingText(540, 480, '👑 COSMIC LEGENDARY SET ACTIVE!', '#f59e0b', true);
1325:   }
1326: 
1327:   // Draw real chaos perks frame
1328:   if (loadedImages.img_perks && loadedImages.img_perks.complete) {
1329:     ctx.drawImage(loadedImages.img_perks, 0, 0, W, H);
1330:   }
1331: 
1332:   // Synergy badge overlay from shop_synergies
1333:   ctx.save();
1334:   const subT = t - 9.5;
1335:   const slideY = Math.min(1.0, subT * 3.0);
1336:   const badgeY = 1380 - (1.0 - slideY) * 200;
1337: 
1338:   ctx.fillStyle = 'rgba(15, 23, 42, 0.95)';
1339:   ctx.strokeStyle = '#f59e0b';
1340:   ctx.lineWidth = 4;
1341:   drawRoundedRect(120, badgeY, 840, 130, 24);
1342:   ctx.fill(); ctx.stroke();
1343: 
1344:   ctx.textAlign = 'center';
1345:   ctx.fillStyle = '#f59e0b';
1346:   ctx.font = '900 36px Rajdhani, sans-serif';
1347:   ctx.fillText('👑 COSMIC LEGENDARY SET SYNERGY', 540, badgeY + 48);
1348:   ctx.fillStyle = '#e2e8f0';
1349:   ctx.font = 'bold 24px Rajdhani, sans-serif';
1350:   ctx.fillText('+15% Score Multiplier • +15% Gold Multiplier', 540, badgeY + 92);
1351:   ctx.restore();
1352: }
1353: 
1354: function drawAquariumLeagueWindow(t) {
1355:   if (t >= 11.6 && !sfxTriggeredAqua) {
1356:     sfxTriggeredAqua = true;
1357:     playTone(523.25, 'sine', 0.2, 0.2, 659.25);
1358:     spawnFloatingText(540, 450, '🐠 ZEN ECO-TANK & TOURNAMENT #1', '#38bdf8', true);
1359:   }
1360: 
1361:   // Draw real aquarium view
1362:   if (loadedImages.img_aquarium && loadedImages.img_aquarium.complete) {
1363:     ctx.drawImage(loadedImages.img_aquarium, 0, 0, W, H);
1364:   }
1365: 
1366:   // Live Swimming Fish Sprites Wagging
1367:   drawSwimmingFishSprites(t);
1368: 
1369:   // Tournament League Overlay Card at Bottom
1370:   ctx.save();
1371:   const cardY = 1320;
1372:   ctx.fillStyle = 'rgba(15, 23, 42, 0.92)';
1373:   ctx.strokeStyle = '#38bdf8';
1374:   ctx.lineWidth = 4;
1375:   drawRoundedRect(140, cardY, 800, 180, 24);
1376:   ctx.fill(); ctx.stroke();
1377: 
1378:   ctx.textAlign = 'left';
1379:   ctx.fillStyle = '#ffd700';
1380:   ctx.font = '900 38px Rajdhani, sans-serif';
1381:   ctx.fillText('🏆 WEEKLY LEAGUE: #1 COSMIC EMPEROR', 180, cardY + 58);
1382:   ctx.fillStyle = '#94a3b8';
1383:   ctx.font = '24px Rajdhani, sans-serif';
1384:   ctx.fillText('Score: 1,482,900 PTS • Tier 7 Promotion Zone', 180, cardY + 102);
1385:   ctx.fillStyle = '#00f5d4';
1386:   ctx.font = 'bold 22px Rajdhani, sans-serif';
1387:   ctx.fillText('✦ Claim Season Title & Avatar Frame', 180, cardY + 140);
1388:   ctx.restore();
1389: }
```

### 1.3 Verbatim Working Implementation in `docs/kirmatas_reklam_tr.html` (Lines 1115–1195)
In contrast, the Turkish ad (`docs/kirmatas_reklam_tr.html`) correctly uses `ctx.drawImage` to render both frames as crisp inset overlays:
- **Shop Synergies Inset** (Lines 1125–1138):
  ```javascript
  1125:     // Sub-card reveal for Shop Cosmic Set Synergies in lower screen
  1126:     const imgShop = ASSETS.images.shop_synergies;
  1127:     if (imgShop && imgShop.complete && imgShop.naturalWidth > 0) {
  1128:       ctx.save();
  1129:       ctx.beginPath();
  1130:       drawRoundedRect(60, 1140, W - 120, 420, 28);
  1131:       ctx.clip();
  1132:       ctx.drawImage(imgShop, 0, 500, W, 800, 60, 1140, W - 120, 420);
  1133:       ctx.restore();
  1134:       drawRoundedRect(60, 1140, W - 120, 420, 28);
  1135:       ctx.strokeStyle = '#f59e0b';
  1136:       ctx.lineWidth = 5;
  1137:       ctx.stroke();
  1138:     }
  ```
- **Tournament League Inset** (Lines 1174–1186):
  ```javascript
  1174:     // Top-right overlay for Tournament League Leaderboard
  1175:     const imgLeague = ASSETS.images.tournament_league;
  1176:     if (imgLeague && imgLeague.complete && imgLeague.naturalWidth > 0) {
  1177:       ctx.save();
  1178:       drawRoundedRect(520, 220, 500, 720, 28);
  1179:       ctx.clip();
  1180:       ctx.drawImage(imgLeague, 0, 200, W, 1000, 520, 220, 500, 720);
  1181:       ctx.restore();
  1182:       drawRoundedRect(520, 220, 500, 720, 28);
  1183:       ctx.strokeStyle = '#00f5d4';
  1184:       ctx.lineWidth = 4;
  1185:       ctx.stroke();
  1186:     }
  ```

---

## 2. Logic Chain

1. **Root Cause Analysis**: The developer of `docs/kirmatas_ad_en.html` copied the structural timeline and asset imports, loaded both `img_synergies` and `img_league`, and even added comments (`// Synergy badge overlay from shop_synergies` and `// Tournament League Overlay Card at Bottom`). However, instead of performing `ctx.clip()` and `ctx.drawImage` with the loaded image references, they drew flat CSS/canvas colored boxes with placeholder text.
2. **Defect Impact**:
   - Only 4 of the 6 captured in-game PNGs (`img_action`, `img_perks`, `img_aquarium`, `img_boss`) are rendered on canvas.
   - Requirement §R3 and Acceptance Criteria ("At least 5 distinct real high-resolution PNG captures rendered by Flutter ... are visibly rendered inside both video ads") are violated in `docs/kirmatas_ad_en.html`.
3. **Fix Strategy for `drawChaosPerksWindow`**:
   - Keep full-screen `loadedImages.img_perks` as base background.
   - Implement an ease-out sliding card (`subT = Math.max(0, t - 9.5)`) at `cardX = 60, cardW = 960, cardH = 430`, sliding from `y = 1390` up to `y = 1140`.
   - Clip the path using `drawRoundedRect(cardX, cardY, cardW, cardH, 28)` and render `loadedImages.img_synergies` with source crop `(sx=0, sy=480, sw=W, sh=820)`.
   - Frame with an amber glow (`rgba(245, 158, 11, 0.50)` shadowBlur 32) and crisp 5px border (`#f59e0b`).
   - Add a floating English header badge (`👑 COSMIC SET SYNERGY: +15% GOLD & SCORE`) in `Rajdhani` bold font.
4. **Fix Strategy for `drawAquariumLeagueWindow`**:
   - Keep full-screen `loadedImages.img_aquarium` as base background with live swimming fishes wagging tails (`drawSwimmingFishSprites`).
   - Add the Tournament League leaderboard as a top-right inset overlay (matching TR structure) at `leagueX = 520, leagueY = 220, leagueW = 500, leagueH = 720`.
   - Crop `tournament_league.png` with 2:1 integer supersampling: `(sx=40, sy=260, sw=1000, sh=1440)` mapped to `(500, 720)` (exact `0.694` aspect ratio, 0 distortion, razor-sharp).
   - Frame with electric cyan/teal glow (`rgba(0, 245, 212, 0.50)` shadowBlur 30) and 4px border (`#00f5d4`).
   - Add a floating English header badge (`🏆 WEEKLY LEAGUE #1 RIVAL`) atop the inset.
   - Retain the bottom HUD callout card at `cardY = 1380` for English narrative clarity.
5. **Bonus Fix Recommendation for Finding V2 (Negative `t` NaN)**:
   - Line 670: `const prog = Math.min(1.0, t / 3.5);`
   - If `t < 0`, `Math.pow(prog, 2.4)` yields `NaN`.
   - Fix: `const prog = Math.max(0.0, Math.min(1.0, t / 3.5));`.

---

## 3. Caveats

- `docs/kirmatas_ad_en.html` must NOT be edited directly by this explorer agent (strictly read-only per mission constraints). The exact replacement code is provided below for the implementer agent.
- `loadedImages.img_synergies` and `loadedImages.img_league` are base64-encoded in `IMAGE_ASSETS`. The replacement code checks `.complete` to guarantee non-blocking rendering if an image is loading or mocked.

---

## 4. Conclusion & Proposed Replacement Code

### Proposed Replacement for `drawChaosPerksWindow` (Lines 1320–1352)

```javascript
function drawChaosPerksWindow(t) {
  if (t >= 9.6 && !sfxTriggeredPerk) {
    sfxTriggeredPerk = true;
    playTone(660, 'sine', 0.25, 0.35, 880);
    spawnFloatingText(540, 480, '👑 COSMIC LEGENDARY SET ACTIVE!', '#f59e0b', true);
  }

  // 1. Draw real chaos perks frame full-screen
  if (loadedImages.img_perks && loadedImages.img_perks.complete) {
    ctx.drawImage(loadedImages.img_perks, 0, 0, W, H);
  }

  // 2. Real Shop Cosmic Set Synergy Inset Overlay (smooth ease-out slide from bottom)
  ctx.save();
  const subT = Math.max(0, t - 9.5);
  const slideProg = Math.min(1.0, subT * 3.2);
  const easeSlide = 1.0 - Math.pow(1.0 - slideProg, 3);

  const cardW = 960, cardH = 430;
  const cardX = (W - cardW) / 2; // 60
  const targetY = 1140;
  const cardY = targetY + (1.0 - easeSlide) * 250;

  // Ambient gold glow
  ctx.shadowColor = 'rgba(245, 158, 11, 0.50)';
  ctx.shadowBlur = 32;
  ctx.fillStyle = 'rgba(15, 23, 42, 0.96)';
  drawRoundedRect(cardX, cardY, cardW, cardH, 28);
  ctx.fill();
  ctx.shadowBlur = 0;

  // Real Captured Inset Image
  if (loadedImages.img_synergies && loadedImages.img_synergies.complete) {
    ctx.save();
    drawRoundedRect(cardX, cardY, cardW, cardH, 28);
    ctx.clip();
    // Crop synergy section from shop_synergies.png (sx=0, sy=480, sw=1080, sh=820)
    ctx.drawImage(loadedImages.img_synergies, 0, 480, W, 820, cardX, cardY, cardW, cardH);
    ctx.restore();
  }

  // Crisp glowing amber border
  ctx.strokeStyle = '#f59e0b';
  ctx.lineWidth = 5;
  drawRoundedRect(cardX, cardY, cardW, cardH, 28);
  ctx.stroke();

  // Floating Header Badge Pill
  const pillW = 660, pillH = 48;
  const pillX = cardX + (cardW - pillW) / 2;
  const pillY = cardY - 24;
  ctx.fillStyle = 'rgba(15, 23, 42, 0.96)';
  ctx.strokeStyle = '#f59e0b';
  ctx.lineWidth = 3;
  drawRoundedRect(pillX, pillY, pillW, pillH, 16);
  ctx.fill();
  ctx.stroke();

  ctx.textAlign = 'center';
  ctx.fillStyle = '#f59e0b';
  ctx.font = '900 26px Rajdhani, sans-serif';
  ctx.fillText('👑 COSMIC SET SYNERGY: +15% GOLD & SCORE', cardX + cardW / 2, pillY + 33);
  ctx.restore();
}
```

---

### Proposed Replacement for `drawAquariumLeagueWindow` (Lines 1354–1389)

```javascript
function drawAquariumLeagueWindow(t) {
  if (t >= 11.6 && !sfxTriggeredAqua) {
    sfxTriggeredAqua = true;
    playTone(523.25, 'sine', 0.2, 0.2, 659.25);
    spawnFloatingText(540, 450, '🐠 ZEN ECO-TANK & TOURNAMENT #1', '#38bdf8', true);
  }

  // 1. Draw real aquarium view full-screen
  if (loadedImages.img_aquarium && loadedImages.img_aquarium.complete) {
    ctx.drawImage(loadedImages.img_aquarium, 0, 0, W, H);
  }

  // 2. Live Swimming Fish Sprites Wagging
  drawSwimmingFishSprites(t);

  // 3. Real Tournament League Leaderboard Inset Overlay (Top-Right, matching TR structure)
  ctx.save();
  const subT = Math.max(0, t - 11.5);
  const slideProg = Math.min(1.0, subT * 3.2);
  const easeSlide = 1.0 - Math.pow(1.0 - slideProg, 3);

  const leagueW = 500, leagueH = 720;
  const targetX = 520;
  const leagueX = targetX + (1.0 - easeSlide) * 200;
  const leagueY = 220;

  // Cyan/teal drop glow
  ctx.shadowColor = 'rgba(0, 245, 212, 0.50)';
  ctx.shadowBlur = 30;
  ctx.fillStyle = 'rgba(15, 23, 42, 0.95)';
  drawRoundedRect(leagueX, leagueY, leagueW, leagueH, 28);
  ctx.fill();
  ctx.shadowBlur = 0;

  // Real Captured Inset Image
  if (loadedImages.img_league && loadedImages.img_league.complete) {
    ctx.save();
    drawRoundedRect(leagueX, leagueY, leagueW, leagueH, 28);
    ctx.clip();
    // Proportional 2:1 supersample crop from tournament_league.png (sx=40, sy=260, sw=1000, sh=1440)
    ctx.drawImage(loadedImages.img_league, 40, 260, 1000, 1440, leagueX, leagueY, leagueW, leagueH);
    ctx.restore();
  }

  // Electric cyan/teal border
  ctx.strokeStyle = '#00f5d4';
  ctx.lineWidth = 4;
  drawRoundedRect(leagueX, leagueY, leagueW, leagueH, 28);
  ctx.stroke();

  // Floating Header Badge atop League Inset
  const badgeW = 380, badgeH = 44;
  const badgeX = leagueX + (leagueW - badgeW) / 2;
  const badgeY = leagueY - 22;
  ctx.fillStyle = 'rgba(15, 23, 42, 0.96)';
  ctx.strokeStyle = '#00f5d4';
  ctx.lineWidth = 3;
  drawRoundedRect(badgeX, badgeY, badgeW, badgeH, 14);
  ctx.fill();
  ctx.stroke();

  ctx.textAlign = 'center';
  ctx.fillStyle = '#00f5d4';
  ctx.font = '900 24px Rajdhani, sans-serif';
  ctx.fillText('🏆 WEEKLY LEAGUE #1 RIVAL', leagueX + leagueW / 2, badgeY + 30);
  ctx.restore();

  // 4. Sleek Bottom English Callout Card
  ctx.save();
  const cardY = 1380;
  ctx.fillStyle = 'rgba(15, 23, 42, 0.92)';
  ctx.strokeStyle = '#38bdf8';
  ctx.lineWidth = 4;
  drawRoundedRect(140, cardY, 800, 150, 24);
  ctx.fill(); ctx.stroke();

  ctx.textAlign = 'left';
  ctx.fillStyle = '#ffd700';
  ctx.font = '900 36px Rajdhani, sans-serif';
  ctx.fillText('🏆 WEEKLY LEAGUE: #1 COSMIC EMPEROR', 180, cardY + 52);
  ctx.fillStyle = '#94a3b8';
  ctx.font = '24px Rajdhani, sans-serif';
  ctx.fillText('Score: 1,482,900 PTS • Tier 7 Promotion Zone', 180, cardY + 94);
  ctx.fillStyle = '#00f5d4';
  ctx.font = 'bold 22px Rajdhani, sans-serif';
  ctx.fillText('✦ Claim Season Title & Avatar Frame', 180, cardY + 128);
  ctx.restore();
}
```

---

### Proposed Fix for Finding V2 (Line 670)

```javascript
// BEFORE (line 670):
const prog = Math.min(1.0, t / 3.5);

// AFTER:
const prog = Math.max(0.0, Math.min(1.0, t / 3.5));
```

---

## 5. Verification Method

1. **Verify Inset Rendering Calls**:
   Execute the following command in PowerShell to verify that `loadedImages.img_synergies` and `loadedImages.img_league` are invoked by `ctx.drawImage` with valid coordinates:
   ```powershell
   node -e "const html = require('fs').readFileSync('docs/kirmatas_ad_en.html', 'utf8'); console.log('img_synergies in drawImage:', html.includes('drawImage(loadedImages.img_synergies')); console.log('img_league in drawImage:', html.includes('drawImage(loadedImages.img_league'));"
   ```
   *Expected after implementer applies fix*: Both print `true`.

2. **Verify Clean Playback & Zero NaN at All Prescribed Timestamps**:
   Run the headless test harness across `t = 9.5s` to `13.5s` (covering the full duration of Windows 2 and 3) verifying that:
   - 0 `NaN` or `undefined` parameters are passed to any `ctx.*` call.
   - `ctx.drawImage` is called twice per frame in Window 2 (`img_perks` + `img_synergies`) and Window 3 (`img_aquarium` + `img_league`).
   - All coordinates remain strictly within the 1080x1920 canvas bounds.

3. **Verify Codebase Cleanliness**:
   ```powershell
   git status --porcelain lib/ test/game_test.dart
   flutter analyze
   ```
   *Expected*: Empty git status, zero analyzer issues.
