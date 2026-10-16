# Handoff Report — Explorer 2: Animation, Narrative & Canvas 60 FPS Engine Specialist

## 1. Observation

### Codebase Observations
1. **Existing Prototype**:
   - File: `docs/kirmatas_turkce_reklam.html` (906 lines, 31,145 bytes).
   - Canvas resolution: Line 100 sets `const W = 1080, H = 1920;`, with CSS presentation container at 243x432px (Line 13).
   - Old duration: Line 101 sets `const DURATION = 15.0;` with 4 scenes (`0-3.5s`, `3.5-7.5s`, `7.5-11.5s`, `11.5-15.0s`).
   - Old visual hook: Scene 1 simply spawned bouncing fireballs on a grid of bricks (`updateAndDrawScene1And2`, lines 331–410). It lacked any Kurzgesagt space-to-atmosphere animation, speedometer, temperature gauge, or comedic pivot.
   - Recording pipeline: Lines 850–900 implement `canvas.captureStream(60)` and `MediaRecorder({ mimeType, videoBitsPerSecond: 8000000 })`, routing audio via `audioDest = audioCtx.createMediaStreamDestination()`.

2. **In-Game Physics & Visual Verifications in Flutter Source**:
   - `lib/engine/game_controller.dart`:
     * Line 2160–2161: `final isCornerHit = hitOffset.abs() >= 0.78;` defines the corner hit as the outer 22% of the paddle.
     * Line 2200–2214: On corner hit, sets `ball.cornerBoostTimer = 3.2`, triggers slow-motion pulse `stats.bulletTimeLeft = 0.75`, triggers screen shake `particles.triggerShake(6.0, 0.28)`, emits golden shockwave `particles.spawnShockwave(..., Color(0xFFFFD700), maxRadius: 85.0)`, and displays banner `'⚡ SÜPER KÖŞE VURUŞU!'`.
     * Line 3198–3240: `triggerUlti()` activates lucky dice roll (`jackpot_dice` / `dice_legendary_12`), spawning screen-wide shockwaves, gold showers, and dual-cannon salvo projectiles (`diceSalvoRemaining`).
     * Line 364: `bool firstCornerHitShown = false;`.
   - `lib/models/cosmetics.dart`:
     * Paddle skins include Cosmic Legendary (`'pc_cosmic'`, cyan/rose/gold gradient glow), Fire/Sunset set, and Ice/Crystal set.
   - `assets/audio/`:
     * Available authentic audio assets: `assets/audio/cam_kirilma.mp3` (25KB), `glass_shatter.mp3` (25KB), `custom_explosion.wav` (44KB), `custom_laser.wav` (22KB), `custom_bounce.wav` (8.8KB), and `bgm.wav` (14.7MB).
   - `assets/fonts/`:
     * Authentic font: `assets/fonts/Rajdhani-Bold.ttf` (400KB), `Rajdhani-SemiBold.ttf` (390KB), `Rajdhani-Regular.ttf` (377KB).

3. **New Follow-Up Specifications (`ORIGINAL_REQUEST.md`)**:
   - Master Timeline duration: **18.0 seconds** at 60 FPS (1080x1920 portrait 9:16).
   - Scene 1 (0.0s – 3.5s): Kurzgesagt "What-If" Space-to-Atmosphere Hook:
     * Flat vector art, deep cosmic palette, 3-layer parallax starfield, Earth curvature with atmospheric limb glow.
     * Vector satellite/astronaut releasing gleaming chrome Fe-56 iron marble (14g / 0.5 oz).
     * Plunge acceleration, Speedometer climbing to **40,000 km/h** (TR) / **25,000 mph** (EN), Temperature climbing to **3,000°C** (TR) / **5,000°F** (EN), bow shock plasma cone and expanding Mach shockwave rings.
   - Scene 2 (3.5s – 7.5s): "Hasan Usta" Comedic Twist / Pivot Engine:
     * Cloud plunge revealing İzmir skyline (Saat Kulesi, Kordon, İzmir Kumrucusu Hasan Usta sign) in TR edition, and metropolitan skyline in EN edition.
     * Sudden camera snap and matrix slow-motion freeze at t = 4.5s.
     * Kırmataş Cosmic Legendary Paddle streaks in, intercepting the 40,000 km/h meteor with `⚡ SÜPER KÖŞE VURUŞU!`.
     * Shatters into **30 blazing Fireballs** obliterating a wall of real Kırmataş bricks (neon, crystal, armored, dynamite).
   - Scene 3 (7.5s – 13.5s): Real in-game footage showcase (GameCanvas Ulti board wipe, Chaos 3-card perks, Eco-tank aquarium, Weekly League).
   - Scene 4 (13.5s – 18.0s): Wave-10 Chaos Boss battle + high-converting Kaunos Games CTA download card.
   - Deliverables: Two standalone HTML5 video studio files:
     * `docs/kirmatas_reklam_tr.html` (Turkish edition)
     * `docs/kirmatas_ad_en.html` (English US/UK edition)

---

## 2. Logic Chain

1. *Supporting Observations 1 & 3*: The transition from a 15-second prototype to an 18-second narrative requires restructuring the timeline into 4 strictly calibrated mathematical intervals:
   - Scene 1: `0.0s <= t < 3.5s` (Hook)
   - Scene 2: `3.5s <= t < 7.5s` (Pivot)
   - Scene 3: `7.5s <= t < 13.5s` (In-Game Showcase)
   - Scene 4: `13.5s <= t <= 18.0s` (Boss & CTA)

2. *Supporting Observations 2 & 3 (Kurzgesagt Vector Architecture)*:
   - Rendering Kurzgesagt aesthetic on HTML5 Canvas requires mathematical vector geometry instead of raster images:
     * Earth Curvature: `ctx.arc(540, 2400, 1200, 0, Math.PI * 2)` with a 5-stop radial gradient creating the exosphere, mesosphere, stratosphere, and troposphere limb glow (`#00f5d4`, `#38bdf8`, `#4338ca`, `#ffffff`).
     * Continental masses: Procedural bezier paths drawn with `#059669` and `#10b981`.
     * Parallax Starfield: 3 depth layers updated via `(baseY - speed * t) % H`.
     * Gleaming Chrome Marble: Radial gradient shader centered at `(cx - R*0.35, cy - R*0.35)` with an 8-point rotating specular glint star flare.
     * Speedometer & Thermometer HUD: Vector arc meter sweeping `0 -> 40,000 km/h` (`speed = Math.floor(Math.pow((t - 1.2)/2.3, 2.4) * 40000)`) and thermometer tube filling `0 -> 3,000°C`.
     * Supersonic Bow Shock: Quadratic bezier envelope `ctx.quadraticCurveTo(mx, my + 50, mx + 90, my - 30)` with multi-stop flame gradient (`#ffffff` -> `#00f5d4` -> `#f43f5e` -> `#ff5500`) and detached Mach shock rings.

3. *Supporting Observations 2 & 3 (Hasan Usta Pivot Engine Architecture)*:
   - The comedic twist relies on precise comedic contrast:
     * Serious scientific doom setup: High-tech NASA/Kurzgesagt voiceover warning of kinetic disaster.
     * Ground zero reveal: Stylized Turkish street corner in İzmir with illuminated sign `"İZMİR KUMRUCUSU HASAN USTA (1984)"` and Konak Clock Tower.
     * Hard slow-mo cut at t = 4.5s: Time dilation factor drops to `0.12`, screen flashes white, audio cuts to an 808 sub-bass drop and crystal resonance.
     * Cosmic Paddle Interception: `easeOutBack` interpolation slides the paddle into position `hitOffset = 0.88`, triggering the authentic game banner `⚡ SÜPER KÖŞE VURUŞU!`.
     * 30-Fireball Wall Obliteration: At t = 5.5s, time accelerates back to 1.2x. The meteor bursts into 30 projectile balls fanning out between `-15°` and `-165°`. Each ball has an incandescent trail, colliding with a 7x8 brick matrix, spawning 200+ glass shards, dynamite chain explosions, and floating combat text (`🔥 30x ATEŞ TOPU!`, `💥 45 KOMBO!`).

4. *Supporting Observations 1 & 3 (HTML5 Canvas 60 FPS Loop & Video Recording)*:
   - High-DPI & Format: Buffer is locked at 1080x1920. Display is scaled via CSS `width: 360px; height: 640px; aspect-ratio: 9/16;` with rounded phone bezels. This eliminates any downsampling blur while keeping CPU load light.
   - Deterministic Scrubbing: The animation state is calculated purely as a function of `currentTime`. When a user scrubs or clicks scene jump buttons (`[0s]`, `[3.5s]`, `[7.5s]`, `[13.5s]`), all visual positions, HUD values, and brick states update immediately without desynchronization.
   - Particle Memory Management: To prevent garbage collection frame drops during 60 FPS video recording, particles are maintained in an object pool (max 350 active particles) with recycling.
   - Export Pipeline: `canvas.captureStream(60)` coupled with `MediaRecorder({ mimeType: 'video/webm;codecs=vp9', videoBitsPerSecond: 12000000 })` and Web Audio destination track allows instantaneous in-browser rendering and download of broadcast-quality 1080x1920 portrait video.

5. *Supporting Observation 3 (Multi-Language Tailoring)*:
   - Turkish (`docs/kirmatas_reklam_tr.html`): Features İzmir Clock Tower, Hasan Usta sign, metric units (`40,000 km/h`, `3,000°C`), Turkish TTS narration (`tr-TR`), and Turkish TikTok captions.
   - English (`docs/kirmatas_ad_en.html`): Features metropolitan skyline, "Joe's Corner Diner", imperial units (`25,000 mph`, `5,400°F`), English TTS narration (`en-US`), and English viral captions.

---

## 3. Caveats

1. **Browser SpeechSynthesis Rate Differences**: The Web Speech API `SpeechSynthesisUtterance` can speak at slightly different speeds depending on the underlying OS voice engine (e.g. Windows SAPI vs Chrome Google TTS vs macOS). The animation timeline uses programmatic sub-second time markers rather than waiting on TTS end events, ensuring video visuals always transition at exact timestamps (`3.5s`, `7.5s`, `13.5s`, `18.0s`).
2. **Real Asset Integration Dependency**: Scenes 3 & 4 will render real captured gameplay frames (`docs/ad_assets/*.png`). Explorer 1 is designing the offscreen Flutter capture test. As a safeguard, the HTML5 canvas engine should feature programmatic fallback rendering (high-fidelity procedural game simulation) in case raster screenshots are loading or offline.
3. **Hardware Acceleration during 1080p WebM Export**: Encoding 1080x1920 at 60 FPS via VP9 MediaRecorder requires standard GPU/CPU video encoding support in Chromium/Edge/Firefox. The video bitrate should be set to 10-12 Mbps for optimal balance of pristine visual quality and encoding speed.

---

## 4. Conclusion

The architecture for the Kurzgesagt space-to-atmosphere hook, the Hasan Usta İzmir comedic pivot engine, and the 60 FPS HTML5 Canvas engine is thoroughly designed and verified against the Kırmataş codebase:
- **Scene 1 (0–3.5s)**: Delivers authentic Kurzgesagt vector aesthetic, Earth limb atmospheric gradient, gleaming Fe-56 chrome marble, dynamic speedometer (`0 -> 40,000 km/h`), temperature gauge (`0 -> 3,000°C`), and supersonic plasma bow shock.
- **Scene 2 (3.5–7.5s)**: Delivers the comedic twist with cloud plunge, İzmir skyline / Hasan Usta storefront, matrix slow-motion freeze at t = 4.5s, Kırmataş Cosmic Paddle corner deflection, and explosive 30-fireball brick wall obliteration.
- **Canvas Engine**: Operates on a fixed 1080x1920 buffer at 60 FPS with deterministic timeline scrubbing, object-pooled particle systems, responsive 9:16 phone preview, and one-click WebM video exporter.
- **Multi-Language**: Fully supports both Turkish TR (`docs/kirmatas_reklam_tr.html`) and English EN (`docs/kirmatas_ad_en.html`).

All design components are ready for implementation by the builder/implementer agents without requiring any modifications to `lib/` or `test/game_test.dart`.

---

## 5. Verification Method

To independently verify the architecture and deliverables once implemented:

1. **Codebase Cleanliness & Zero Regression**:
   ```pwsh
   git status --porcelain lib/ test/game_test.dart
   ```
   *Expected output*: Empty (0 modified files in `lib/` and `test/game_test.dart`).

2. **Static Analysis & Game Tests**:
   ```pwsh
   flutter analyze
   flutter test test/game_test.dart
   ```
   *Expected output*: 0 issues reported, all 435 tests passing.

3. **HTML5 Video Ad Files Verification**:
   - Inspect files:
     * `docs/kirmatas_reklam_tr.html`
     * `docs/kirmatas_ad_en.html`
   - Verification checklist:
     * Internal canvas has `width="1080"` and `height="1920"`.
     * Master timeline constant `DURATION = 18.0`.
     * Scene 1 (0–3.5s) contains procedural vector Earth curvature, parallax starfield, Fe-56 iron marble, speedometer (40,000 km/h / 25,000 mph), and temperature gauge (3,000°C / 5,000°F).
     * Scene 2 (3.5–7.5s) contains İzmir / Hasan Usta skyline, slow-mo snap at 4.5s, Kırmataş paddle corner hit with banner `⚡ SÜPER KÖŞE VURUŞU!`, and 30 fireballs obliterating the brick wall.
     * Scene 3 (7.5–13.5s) displays real gameplay, Chaos perks, Aquarium, and Weekly League.
     * Scene 4 (13.5–18.0s) displays Wave-10 Chaos Boss and Kaunos Games CTA end card.
     * Timeline scrubber bar, 4 scene jump buttons, play/pause toggle, and HD WebM video export function cleanly.

4. **Invalidation Conditions**:
   - Any modifications to `lib/` or regressions in `test/game_test.dart`.
   - Failure of the canvas to render at 1080x1920 or drop below 60 FPS during standard playback.
   - Missing speedometer, temperature gauge, or Hasan Usta comedic pivot sequence.
   - Failure of the one-click WebM video export.
