# Project: Kırmataş Viral Promotional Video Advertisements (TR & EN Editions)

## Architecture
- Target resolution: 1080x1920 (9:16 portrait), 60 FPS HTML5 Canvas animation loop.
- Deliverables:
  - `docs/kirmatas_reklam_tr.html` (Turkish edition with İzmir Hasan Usta comedic twist)
  - `docs/kirmatas_ad_en.html` (English US/UK edition with Kurzgesagt curiosity hook)
  - `docs/ad_assets/` (6 captured 1080x1920 real Flutter in-game frames, audio assets, voiceover buffers)
- Core components:
  1. Procedural vector Kurzgesagt space-to-atmosphere animation engine (0.0s – 3.5s).
  2. Comedic matrix slow-mo pivot engine with Kırmataş Cosmic Paddle corner hit & 30-Fireball wall wipe (3.5s – 7.5s).
  3. Real Flutter in-game footage showcase with 60 FPS live particle overlays & real sprites (7.5s – 13.5s).
  4. Wave-10 Chaos Boss battle & Kaunos Games CTA end card (13.5s – 18.0s).
  5. Web Audio API polyphonic mixer with real SFX, dynamic BGM ducking, and dual-mode voiceover audio.
  6. Dynamic TikTok/Reels style subtitle captions with word-by-word timing and bounce punch.
  7. One-click 1080x1920 60 FPS `.webm` HD video recorder and downloader (VP9 12 Mbps, Opus 192 kbps).
  8. Codebase cleanliness: Zero modifications in `lib/` and `test/game_test.dart`.

## Feature Inventory
| # | Feature | Description | Milestone | Source |
|---|---------|-------------|-----------|--------|
| 1 | Real In-Game Visual Frame Captures | 6 genuine 1080x1920 PNG frames rendered by Flutter widgets in `docs/ad_assets/` | M1 | ORIGINAL_REQUEST §R1 |
| 2 | Clean Codebase Restoration | Zero leftover diffs in `lib/` and `test/game_test.dart`, `flutter analyze` passes 0 issues | M1, M4 | ORIGINAL_REQUEST §R1 |
| 3 | Real Audio Assets & Voiceover Pipeline | Authentic SFX (`cam_kirilma`, `glass_shatter`, `custom_laser`, `custom_explosion`, `custom_bounce`), BGM, and high-fidelity TR/EN voiceover WAV streams | M1 | ORIGINAL_REQUEST §R1, R3 |
| 4 | Kurzgesagt Space-to-Atmosphere Hook | Procedural Earth limb gradient, parallax stars, chrome Fe-56 marble, speedometer (40,000 km/h / 25,000 mph) & thermometer (3,000°C / 5,000°F) HUD | M2, M3 | ORIGINAL_REQUEST §R2 |
| 5 | Hasan Usta İzmir Comedic Pivot Engine | İzmir skyline / storefront, matrix slow-mo freeze at 4.5s, Cosmic Paddle corner hit `⚡ SÜPER KÖŞE VURUŞU!`, 30 Fireballs brick wall wipe | M2 | ORIGINAL_REQUEST §R2 |
| 6 | English Metropolitan Pivot Engine | City skyline / diner, matrix slow-mo freeze at 4.5s, Cosmic Paddle corner hit, 30 Fireballs brick wall wipe | M3 | ORIGINAL_REQUEST §R2 |
| 7 | Real In-Game Footage Showcase TR | Display `game_canvas_action.png`, `chaos_perks.png`, `aquarium_view.png`, `tournament_league.png` with live particles, swimming fishes, and real audio | M2 | ORIGINAL_REQUEST §R3 |
| 8 | Real In-Game Footage Showcase EN | Display `game_canvas_action.png`, `chaos_perks.png`, `aquarium_view.png`, `tournament_league.png` with English framing, live particles, and real audio | M3 | ORIGINAL_REQUEST §R3 |
| 9 | Wave-10 Chaos Boss & Kaunos CTA TR | Display `chaos_boss.png`, boss warning alarm, armor shatter, and `kaunos_games.png` end card with Turkish download CTA | M2 | ORIGINAL_REQUEST §R3 |
| 10 | Wave-10 Chaos Boss & Kaunos CTA EN | Display `chaos_boss.png`, boss warning alarm, armor shatter, and `kaunos_games.png` end card with English download CTA | M3 | ORIGINAL_REQUEST §R3 |
| 11 | Synchronized Voiceover & TikTok Captions TR | Turkish voiceover audio, Web Speech API preview, dynamic animated word-highlight captions | M2 | ORIGINAL_REQUEST §R3 |
| 12 | Synchronized Voiceover & TikTok Captions EN | English voiceover audio, Web Speech API preview, dynamic animated word-highlight captions | M3 | ORIGINAL_REQUEST §R3 |
| 13 | Interactive Video Studio TR | 18.0s timeline scrubber, play/pause, 4 scene jump buttons, responsive phone mockup preview | M2 | ORIGINAL_REQUEST §R3 |
| 14 | Interactive Video Studio EN | 18.0s timeline scrubber, play/pause, 4 scene jump buttons, responsive phone mockup preview | M3 | ORIGINAL_REQUEST §R3 |
| 15 | 1080x1920 60 FPS WebM HD Exporter TR | In-browser MediaRecorder stream mixer capturing canvas + audio, live progress bar, auto download `kirmatas_reklam_tr.webm` | M2 | ORIGINAL_REQUEST §R3 |
| 16 | 1080x1920 60 FPS WebM HD Exporter EN | In-browser MediaRecorder stream mixer capturing canvas + audio, live progress bar, auto download `kirmatas_ad_en.webm` | M3 | ORIGINAL_REQUEST §R3 |
| 17 | Adversarial Verification & Integrity Audit | Challenger tests and Forensic Auditor verification ensuring genuine implementations and zero cheating | M4 | ORIGINAL_REQUEST §Acceptance Criteria |

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| 1 | M1: Real Asset Pipeline & Audio Embeddings | Verify all 6 captured in-game PNGs in `docs/ad_assets/`, synthesize high-quality voiceover audio WAVs (TR & EN), create base64/relative asset registry | none | DONE |
| 2 | M2: Turkish Promo Video Studio (`docs/kirmatas_reklam_tr.html`) | Build complete self-contained TR studio with Space Hook, Hasan Usta Pivot, Real In-Game Showcase, Boss/CTA, TR Voiceover/Captions, Scrubber & WebM Exporter | M1 | DONE |
| 3 | M3: English Promo Video Studio (`docs/kirmatas_ad_en.html`) | Build complete self-contained EN studio with Space Hook, English Pivot, Real In-Game Showcase, Boss/CTA, EN Voiceover/Captions, Scrubber & WebM Exporter | M1 | DONE |
| 4 | M4: Final Review, Adversarial Stress-Test & Forensic Audit | Reviewer multi-angle inspection, Challenger empirical verification, Forensic Auditor integrity veto check, and zero-diff verification | M2, M3 | DONE |

## Interface Contracts
### Ad Assets ↔ Video Studio HTML Pages
- Captured Frames:
  - `docs/ad_assets/game_canvas_action.png` (1080x1920 PNG, ~854 KB)
  - `docs/ad_assets/chaos_perks.png` (1080x1920 PNG, ~251 KB)
  - `docs/ad_assets/aquarium_view.png` (1080x1920 PNG, ~157 KB)
  - `docs/ad_assets/shop_synergies.png` (1080x1920 PNG, ~316 KB)
  - `docs/ad_assets/tournament_league.png` (1080x1920 PNG, ~83 KB)
  - `docs/ad_assets/chaos_boss.png` (1080x1920 PNG, ~241 KB)
- Core SFX:
  - `cam_kirilma.mp3` (Glass break, 25 KB)
  - `glass_shatter.mp3` (Glass shatter, 25 KB)
  - `custom_laser.wav` (Laser / Ulti wipe, 22 KB)
  - `custom_explosion.wav` (Explosion, 44 KB)
  - `custom_bounce.wav` (Bounce, 8.8 KB)
- Studio Branding: `assets/images/kaunos_games.png`
- Fonts: `Rajdhani-Bold.ttf`, `Rajdhani-SemiBold.ttf`

## Code Layout
- HTML Studios:
  - `docs/kirmatas_reklam_tr.html`
  - `docs/kirmatas_ad_en.html`
- Asset Directory:
  - `docs/ad_assets/`
- Production Code (Must NOT be modified):
  - `lib/`
  - `test/game_test.dart`
