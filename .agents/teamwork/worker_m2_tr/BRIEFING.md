# BRIEFING — 2026-10-16T18:14:30Z

## Mission
Build the complete Turkish Promo Video Studio & 1080x1920 60 FPS WebM Exporter in `docs/kirmatas_reklam_tr.html`.

## 🔒 My Identity
- Archetype: worker_m2_tr
- Roles: implementer, qa, specialist
- Working directory: c:\Users\USER\Desktop\KIPKIRMATAS\.agents\teamwork\worker_m2_tr
- Original parent: a954229f-7f6b-47b6-a253-514b9fa8e0e7
- Milestone: M2 - Turkish Promo Video Studio

## 🔒 Key Constraints
- EXCLUSIVELY own `docs/kirmatas_reklam_tr.html` and Turkish voiceover assets in `docs/ad_assets/`.
- DO NOT modify `lib/`, `test/game_test.dart`, or `docs/kirmatas_ad_en.html`.
- Canvas resolution: 1080x1920 (9:16 portrait) at 60 FPS.
- Zero fake/hardcoded results; genuine canvas rendering, vector animation, audio pipeline, captions, and WebM exporter.
- `flutter analyze` must remain 0 errors/warnings.

## Current Parent
- Conversation ID: a954229f-7f6b-47b6-a253-514b9fa8e0e7
- Updated: 2026-10-16T18:14:30Z

## Task Summary
- **What to build**: Complete, self-contained HTML5 video studio and 1080x1920 60 FPS WebM exporter (`docs/kirmatas_reklam_tr.html`).
- **Success criteria**:
  1. Responsive phone preview with timeline scrubber, play/pause, scene jump buttons, voiceover toggle, and WebM export.
  2. Scene 1 (0.0-3.5s): Kurzgesagt style vector space-to-atmosphere animation with Fe-56 chrome marble, gauges, Mach 32 bow shock.
  3. Scene 2 (3.5-7.5s): Hasan Usta İzmir Kumrucusu pivot, slow-mo snap (0.12x) at 4.5s with paddle corner deflection, brick pulverization (30 fireballs, 200+ particles, combos).
  4. Scene 3 (7.5-13.5s): In-game gameplay footage showcase from real 1080x1920 PNG assets with dynamic ball/particle/fish overlays.
  5. Scene 4 (13.5-18.0s): Wave-10 Chaos Boss encounter, boss warning, armor shatter, Kaunos Games end card with Turkish CTA.
  6. Audio Pipeline: Web Audio API master graph mixing SFX, BGM, and Voiceover (SAPI wav / Web Audio synth) ducking BGM during voiceover.
  7. TikTok/Reels dynamic captions with word-by-word highlight and bounce punch.
  8. One-click 1080x1920 60 FPS .webm export.
- **Interface contracts**: PROJECT.md, survey specialist handoffs.
- **Code layout**: `docs/kirmatas_reklam_tr.html`, `docs/ad_assets/`.

## Key Decisions Made
- Pre-rendered Turkish SAPI voiceover files with `Microsoft Tolga` tuned to duration budgets and bundled via base64 for 100% offline portability and direct Web Audio capture.
- Embedded data URIs for all 7 images and 9 audio assets into `docs/ad_assets/ad_data_tr.js` to prevent any browser canvas tainting or file:/// CORS issues.
- Implemented 71% dynamic BGM ducking during active voiceover lines in Web Audio API.

## Artifact Index
- `docs/kirmatas_reklam_tr.html` — Turkish Promo Video Studio & Exporter (59 KB)
- `docs/ad_assets/ad_data_tr.js` — Offline Base64 asset bundle (4.4 MB)
- `docs/ad_assets/voice_tr_scene*.wav` — Tuned 16-bit PCM SAPI Tolga voice recordings
- `.agents/teamwork/worker_m2_tr/handoff.md` — Final Handoff Report

## Change Tracker
- **Files modified**: `docs/kirmatas_reklam_tr.html`, `docs/ad_assets/voice_tr_scene*.wav`, `docs/ad_assets/ad_data_tr.js`
- **Build status**: PASS (`flutter analyze`: No issues found!)
- **Pending issues**: None

## Quality Status
- **Build/test result**: PASS (0 errors, 0 warnings)
- **Lint status**: PASS (0 issues)
- **Tests added/modified**: `git diff lib/ test/game_test.dart` is clean (0 diff)

## Loaded Skills
- None requested
