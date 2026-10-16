# Challenger 2 Handoff Report: EN Video Ad Empirical Verification

## 1. Observation

### 1.1 Specification Verification (`docs/kirmatas_ad_en.html`)
- **Canvas Resolution**: Tag defined at line 53:
  ```html
  <canvas id="adCanvas" width="1080" height="1920" class="w-full h-full block cursor-pointer" title="Click to Play / Pause"></canvas>
  ```
  Constants at lines 207-208:
  ```javascript
  const W = 1080, H = 1920;
  const DURATION = 18.0;
  ```
- **Frame Rate**: Defined at line 1935:
  ```javascript
  const videoStream = canvas.captureStream(60);
  ```
- **Scene Partitioning**: Handled in `renderFrame(now)` at lines 1803-1818:
  ```javascript
  const currentSceneIdx = currentTime < 3.5 ? 0 : (currentTime < 7.5 ? 1 : (currentTime < 13.5 ? 2 : 3));
  if (currentTime < 3.5) {
    drawScene1(currentTime);
  } else if (currentTime < 7.5) {
    drawScene2(currentTime);
  } else if (currentTime < 13.5) {
    drawScene3(currentTime);
  } else {
    drawScene4(currentTime);
  }
  ```

### 1.2 Timeline Seeking Empirical Stress Test Results
An automated headless test harness simulated CanvasRenderingContext2D, DOM, and Web Audio API, executing over 100,000 parameter validations across rendering primitives:
- **Prescribed Sub-Second Timestamps**:
  * `t = 0.5s`  -> PASS | HUD: `"00.7s / 18.0s", "3%"` | 0 NaN/undefined
  * `t = 2.13s` -> PASS | HUD: `"02.3s / 18.0s", "12%"` | 0 NaN/undefined
  * `t = 3.5s`  -> PASS | HUD: `"03.7s / 18.0s", "20%"` | 0 NaN/undefined
  * `t = 4.5s`  -> PASS | HUD: `"04.7s / 18.0s", "26%"` | 0 NaN/undefined
  * `t = 5.5s`  -> PASS | HUD: `"05.7s / 18.0s", "31%"` | 0 NaN/undefined
  * `t = 7.5s`  -> PASS | HUD: `"07.7s / 18.0s", "42%"` | 0 NaN/undefined
  * `t = 11.2s` -> PASS | HUD: `"11.4s / 18.0s", "63%"` | 0 NaN/undefined
  * `t = 13.5s` -> PASS | HUD: `"13.7s / 18.0s", "76%"` | 0 NaN/undefined
  * `t = 16.8s` -> PASS | HUD: `"17.0s / 18.0s", "94%"` | 0 NaN/undefined
  * `t = 18.0s` -> PASS | HUD: `"00.2s / 18.0s", "0%"` | 0 NaN/undefined
  * Result: **10/10 Passed (100%)**.
- **Dense Scrubbing Stress Test**: 500 rapid random seek jumps across `[0.0s, 18.0s]` resulted in **500/500 Passed (0 NaN/undefined, 0 exceptions)** under monotonic frame increments.
- **Continuous 60 FPS Loop**: 1,080 consecutive frames (18.0s) executed cleanly with **1,080/1,080 Passed (0 NaN/undefined, 0 exceptions)**.
- **Boundary Vulnerability Discovered (V2)**:
  In `docs/kirmatas_ad_en.html` line 670:
  ```javascript
  const prog = Math.min(1.0, t / 3.5);
  const marbleY = 320 + Math.pow(prog, 2.4) * 1200;
  ```
  If `t < 0` (e.g. from an out-of-bounds seek or negative delta), `prog` is negative. In IEEE 754 / JavaScript, `Math.pow(negative, 2.4)` evaluates to `NaN`. This propagates `NaN` into `marbleY`, radial gradients (`rad.y0`, `rad.y1`), arcs, and glint lines.

### 1.3 Real In-Game Captured Frames Verification (`docs/ad_assets/`)
All 6 in-game captures exist as genuine 1080x1920 PNG files and match their embedded base64 strings in `docs/kirmatas_ad_en.html` byte-for-byte:
1. `game_canvas_action.png`: 854,106 bytes | 1080x1920 | embedded as `IMAGE_ASSETS['img_action']` (100% byte match)
2. `chaos_perks.png`: 251,846 bytes | 1080x1920 | embedded as `IMAGE_ASSETS['img_perks']` (100% byte match)
3. `aquarium_view.png`: 157,713 bytes | 1080x1920 | embedded as `IMAGE_ASSETS['img_aquarium']` (100% byte match)
4. `shop_synergies.png`: 316,779 bytes | 1080x1920 | embedded as `IMAGE_ASSETS['img_synergies']` (100% byte match)
5. `tournament_league.png`: 83,612 bytes | 1080x1920 | embedded as `IMAGE_ASSETS['img_league']` (100% byte match)
6. `chaos_boss.png`: 241,582 bytes | 1080x1920 | embedded as `IMAGE_ASSETS['img_boss']` (100% byte match)
7. `assets/images/kaunos_games.png`: 662,182 bytes | embedded as `IMAGE_ASSETS['img_kaunos']` (100% byte match)

**CRITICAL FINDING (V1 — Missing Rendering of `img_synergies` and `img_league`)**:
Analysis of all `ctx.drawImage` calls in `docs/kirmatas_ad_en.html` shows:
- Line 1263: `ctx.drawImage(loadedImages.img_action, 0, 0, W, H);` -> DRAWN
- Line 1329: `ctx.drawImage(loadedImages.img_perks, 0, 0, W, H);` -> DRAWN
- Line 1363: `ctx.drawImage(loadedImages.img_aquarium, 0, 0, W, H);` -> DRAWN
- Line 1461: `ctx.drawImage(loadedImages.img_boss, 0, 0, W, H);` -> DRAWN
- Line 1531: `ctx.drawImage(loadedImages.img_kaunos, 540 - logoW / 2, 420, logoW, logoH);` -> DRAWN
- **`loadedImages.img_synergies`**: **0 occurrences of drawImage**. Defined in `IMAGE_ASSETS`, loaded into memory (~316 KB), but replaced entirely by a procedural canvas rectangle (lines 1333–1351) instead of rendering the captured image.
- **`loadedImages.img_league`**: **0 occurrences of drawImage**. Defined in `IMAGE_ASSETS`, loaded into memory (~83 KB), but replaced entirely by a procedural canvas card (lines 1370–1388) instead of rendering the captured image.
- *Comparison*: In `docs/kirmatas_reklam_tr.html`, line 1132 renders `imgShop` as an inset overlay (`ctx.drawImage(imgShop, 0, 500, W, 800, 60, 1140, W - 120, 420);`), and line 1180 renders `imgLeague` (`ctx.drawImage(imgLeague, 0, 200, W, 1000, 520, 220, 500, 720);`). In `docs/kirmatas_ad_en.html`, only 4 of the 6 in-game captures are ever drawn.

### 1.4 Web Audio API & MediaRecorder Pipeline
- **Audio Graph**:
  * Line 260-276: `masterGain` connected to `audioCtx.destination` and `audioDest`.
  * `sfxGain` (0.85), `voiceGain` (1.0), and `bgmGain` (0.35) connect to `masterGain`.
  * Ducking function `duckBgm(active)` line 299-305 drops `bgmGain` to 0.10 during narration.
  * Polyphonic SFX: `playSoundBuffer` handles sample playback; `playTone` handles oscillator synthesis; `updateBgmBeat` maintains a 128 BPM electronic kick/hi-hat groove.
- **MediaRecorder Export Stream**:
  * Lines 1935-1940: Combines `canvas.captureStream(60).getVideoTracks()` with `audioDest.stream.getAudioTracks()` into a merged `MediaStream`.
  * Lines 1943-1952: Requests `video/webm;codecs=vp9,opus` at `videoBitsPerSecond: 12000000` (12 Mbps).
  * Automatically records 18.0s, creates a Blob, and triggers download of `kirmatas_ad_en.webm`.

### 1.5 Codebase Cleanliness & Flutter Analyzer
- `git diff lib/ test/game_test.dart` -> 0 lines output (completely clean, 0 diff).
- `git status --porcelain lib/ test/game_test.dart` -> empty (0 uncommitted or untracked changes in core dirs).
- `flutter analyze` output verbatim:
  ```
  Analyzing KIPKIRMATAS...
  No issues found! (ran in 11.6s)
  ```
  Exit code: 0 (0 errors, 0 warnings).

---

## 2. Logic Chain

1. **Specs & Timeline (Item 1)**: Directly inspecting `docs/kirmatas_ad_en.html` confirms the `<canvas>` element is hardcoded to `width="1080" height="1920"`, `const DURATION = 18.0;`, and `canvas.captureStream(60)`. All four scene draw functions (`drawScene1` through `drawScene4`) exist and execute in strict time windows (`0–3.5s`, `3.5–7.5s`, `7.5–13.5s`, `13.5–18.0s`).
2. **Timeline Scrubbing (Item 2)**: The empirical Node.js mock harness evaluated seeking across all 10 prescribed timestamps (`t = 0.5s` through `18.0s`), 500 random timestamps, and 1,080 continuous frames. Under normal non-negative time values, zero NaN, undefined, or runtime exceptions occurred. However, boundary testing uncovered that for `t < 0`, line 670 evaluates `Math.pow(prog, 2.4)` with a negative base, yielding `NaN`.
3. **Capture Embedding & Rendering (Item 3)**: Comparing disk files in `docs/ad_assets/` against the base64 dictionary `IMAGE_ASSETS` proves that all 6 real captures are embedded byte-for-byte. However, AST and text analysis of `ctx.drawImage` calls confirms that `loadedImages.img_synergies` and `loadedImages.img_league` are never drawn anywhere in the English ad, whereas the Turkish ad draws both as insets.
4. **Audio & Video Pipeline (Item 4)**: Inspection and execution of `initAudio()` and `exportWebMVideo()` confirms that the Web Audio API graph connects SFX, Voice, and BGM through `masterGain` to both hardware destination and `audioDest` (MediaStreamDestination). `MediaRecorder` captures both video and audio tracks at 60 FPS and 12 Mbps.
5. **Codebase Cleanliness (Item 5)**: Running `git diff lib/ test/game_test.dart` returned empty output, and `flutter analyze` completed with 0 issues, confirming that core game source code remains untouched.

---

## 3. Caveats

- Node.js headless environment mocked browser APIs (`HTMLCanvasElement`, `CanvasRenderingContext2D`, `AudioContext`, `MediaRecorder`). While geometric assertions and mathematical inputs were strictly validated, GPU rasterization performance on low-end mobile devices was not measured.
- Web Speech API fallback was mocked in headless mode; synthesized WAV buffers (`voice_en_scene*.wav`) were confirmed present and valid.
- The omission of `img_synergies` and `img_league` in `kirmatas_ad_en.html` does not cause a JavaScript runtime crash because the images are loaded into `loadedImages` but never referenced; rather, it is a visual omission of 2 required captured frames.

---

## 4. Conclusion

- **Overall Assessment**: **PARTIALLY PASSED with 1 HIGH FINDING and 1 LOW FINDING**.
- **Passing Items**:
  1. Item 1 (Specs): 1080x1920, 60 FPS, 18.0s DURATION, 4 scenes verified.
  2. Item 2 (Scrubbing): 10/10 prescribed timestamps, 500/500 random seeks, and 1,080/1,080 frames verified free of NaN/undefined during non-negative playback.
  3. Item 4 (Audio/Video Pipeline): Web Audio graph, dynamic BGM ducking, polyphonic SFX, and 12 Mbps WebM MediaRecorder export verified.
  4. Item 5 (Code Cleanliness): 0 diff in `lib/` and `test/game_test.dart`, `flutter analyze` passes with 0 issues.
- **Defects to Report**:
  - **[HIGH] Finding V1**: In `docs/kirmatas_ad_en.html`, `img_synergies` (`shop_synergies.png`) and `img_league` (`tournament_league.png`) are embedded in `IMAGE_ASSETS` and loaded into memory, but are **NEVER drawn** on the canvas in Scene 3 (only 4 of 6 captures rendered). In contrast, `kirmatas_reklam_tr.html` renders both via `ctx.drawImage` insets.
  - **[LOW] Finding V2**: In `docs/kirmatas_ad_en.html` line 670, `const prog = Math.min(1.0, t / 3.5);` lacks `Math.max(0, ...)`. If `t < 0`, `Math.pow(prog, 2.4)` produces `NaN`, breaking marble and gradient rendering.

---

## 5. Verification Method

To independently verify these findings, run the following commands in PowerShell from `c:\Users\USER\Desktop\KIPKIRMATAS`:

1. **Verify Codebase Cleanliness**:
   ```powershell
   git diff lib/ test/game_test.dart
   flutter analyze
   ```
   *Expected*: Empty git diff, `flutter analyze` exits 0 with 0 issues.

2. **Verify Missing `drawImage` for `img_synergies` and `img_league`**:
   ```powershell
   node -e "const html = require('fs').readFileSync('docs/kirmatas_ad_en.html', 'utf8'); console.log('img_synergies drawImage:', html.includes('drawImage(loadedImages.img_synergies')); console.log('img_league drawImage:', html.includes('drawImage(loadedImages.img_league'));"
   ```
   *Expected*: Both print `false`.

3. **Verify Negative t NaN Vulnerability**:
   ```powershell
   node -e "console.log('Math.pow(-0.1, 2.4) =', Math.pow(-0.1, 2.4));"
   ```
   *Expected*: Prints `NaN`.
