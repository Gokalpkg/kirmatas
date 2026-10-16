## 2026-10-16T18:05:32Z

You are Worker 1 (Turkish Promo Video Studio Builder).
Read ORIGINAL_REQUEST.md at c:\Users\USER\Desktop\KIPKIRMATAS\.agents\teamwork\ORIGINAL_REQUEST.md (specifically ## Follow-up — 2026-10-16T17:42:06Z).
Read PROJECT.md at c:\Users\USER\Desktop\KIPKIRMATAS\PROJECT.md.

Read the handoff reports from the survey specialists:
- c:\Users\USER\Desktop\KIPKIRMATAS\.agents\teamwork\explorer_survey_1\handoff.md (catalog of all assets, real 1080x1920 PNG frames in docs/ad_assets/)
- c:\Users\USER\Desktop\KIPKIRMATAS\.agents\teamwork\explorer_survey_2\handoff.md (Kurzgesagt vector math, Hasan Usta pivot engine, Canvas 60 FPS architecture)
- c:\Users\USER\Desktop\KIPKIRMATAS\.agents\teamwork\explorer_survey_3\handoff.md (WebM 1080x1920 60 FPS MediaRecorder exporter, Web Audio pipeline, SAPI voiceover, TikTok captions)

Your working directory is:
c:\Users\USER\Desktop\KIPKIRMATAS\.agents\teamwork\worker_m2_tr

Write Ownership:
You EXCLUSIVELY own `docs/kirmatas_reklam_tr.html` and any Turkish voiceover assets in `docs/ad_assets/`.
DO NOT modify `lib/`, `test/game_test.dart`, or `docs/kirmatas_ad_en.html`.

MANDATORY INTEGRITY WARNING:
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A teamwork_preview_auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

Your Goal:
Build the complete, self-contained HTML5 video studio and 1080x1920 60 FPS WebM exporter:
`docs/kirmatas_reklam_tr.html`

Full Acceptance Criteria to satisfy:
1. Canvas 1080x1920 (9:16 portrait) running at 60 FPS with responsive phone preview frame (e.g. 360x640px) and interactive UI:
   - Timeline scrubber bar with progress indicator and draggable seek.
   - Play/Pause toggle button.
   - 4 Scene jump buttons: [0.0s Uzay], [3.5s Hasan Usta], [7.5s Oynanış], [13.5s Kaos Boss].
   - Speech Voiceover toggle (TTS / Audio buffers).
   - One-click "🎥 18 Sn HD Videoyu Kaydet & İndir (.webm / 1080x1920)" button with real-time export progress bar.
2. Scene 1 (0.0s – 3.5s — The Curiosity Hook):
   - Kurzgesagt-style flat vector space-to-atmosphere animation.
   - Procedural vector Earth curvature with 5-stage atmospheric limb gradient (#00f5d4, #38bdf8, #4338ca, #ffffff) and 3-layer parallax starfield.
   - Vector satellite/astronaut releasing a gleaming chrome Fe-56 iron marble (14g) with specular star glint.
   - Speedometer gauge sweeping 0 -> 40,000 km/h and temperature gauge sweeping 0 -> 3,000°C.
   - Mach 32 supersonic bow shock cone with flame gradient and expanding shock rings.
3. Scene 2 (3.5s – 7.5s — The "Hasan Usta" Comedic Pivot):
   - Cloud plunge reveals stylized İzmir skyline (Saat Kulesi) and neon storefront "İZMİR KUMRUCUSU HASAN USTA (1984)".
   - Sudden matrix slow-mo snap at t = 4.5s (time dilation 0.12), white flash, 808 sub-bass drop and glass crack SFX (`cam_kirilma.mp3`).
   - Glowing Kırmataş Cosmic Legendary Paddle streaks in, intercepting the meteor at hit offset 0.88 with slow-mo banner `⚡ SÜPER KÖŞE VURUŞU!`.
   - At t = 5.5s, time accelerates; meteor shatters into 30 blazing Fireballs fanning out to pulverize an authentic 7x8 Kırmataş brick wall with 200+ particle shards and combo banners (`🔥 30x ATEŞ TOPU!`, `💥 45 KOMBO!`).
4. Scene 3 (7.5s – 13.5s — Real In-Game Footage Showcase):
   - Smoothly transitions through real captured Flutter gameplay frames from `docs/ad_assets/`:
     * `docs/ad_assets/game_canvas_action.png` (Multi-Ball + Fireball + Ulti callout `⚡ ULTİ HAZIR! ÇİFT DOKUN!`).
     * `docs/ad_assets/chaos_perks.png` (Chaos Mode 3-Card Roguelike Perk selection) + `shop_synergies.png` (Cosmetic Set Synergies).
     * `docs/ad_assets/aquarium_view.png` (Eco-Tank with swimming fishes) + `tournament_league.png` (Weekly League #1 rank).
   - Enhanced with live 60 FPS particle/ball overlays, swimming fish sprites, and real SFX.
5. Scene 4 (13.5s – 18.0s — Wave-10 Chaos Boss & Kaunos Games CTA):
   - Real Wave-10 Chaos Boss encounter (`docs/ad_assets/chaos_boss.png`) with boss warning alarm, armor shatter, and `assets/images/kaunos_games.png` high-converting end card with Turkish download CTA ("HEMEN ÜCRETSİZ İNDİR").
6. Audio Pipeline:
   - Web Audio API master graph mixing SFX, BGM, and Voiceover to both speakers and MediaRecorder `audioDest`.
   - Real SFX loaded from `assets/audio/` (and/or base64 encoded for offline portability): `cam_kirilma.mp3`, `glass_shatter.mp3`, `custom_laser.wav`, `custom_explosion.wav`, `custom_bounce.wav`.
   - BGM looping with dynamic 71% ducking during active voiceover narration.
   - Voiceover: Synthesize/record clean Turkish voiceover audio (or generate via PowerShell SAPI `Microsoft Tolga` into `docs/ad_assets/voice_tr_*.wav`) and route to `audioDest` so exported `.webm` video contains full voiceover, with Web Speech API live preview.
7. Dynamic TikTok/Reels captions:
   - Lower third centered (`y = 1600` on 1080x1920) with font `Rajdhani` / sans-serif.
   - Word-by-word timing with active word highlight (`#FFE600`), 1.2x bounce punch, 14px black outline, and frosted glass pill box.
8. One-click 1080x1920 60 FPS `.webm` HD Video Recorder & Downloader:
   - `canvas.captureStream(60)` + `audioDest.stream` merged into `MediaStream`.
   - MediaRecorder VP9 12 Mbps + Opus 192 kbps.
   - Real-time progress percentage indicator during 18.0s recording.
   - Automatic download of `kirmatas_reklam_tr.webm`.
