## 2026-10-16T12:02:38Z
You are Explorer 1: FTUE and Early Game Investigator.
Working Directory: c:\Users\USER\Desktop\KIPKIRMATAS\.agents\teamwork\explorer_survey_1
Original User Request: c:\Users\USER\Desktop\KIPKIRMATAS\.agents\teamwork\ORIGINAL_REQUEST.md

Your mission is to explore and survey the codebase for requirements R1, R2, R3, and R4:
- R1: Progressive Feature Unlocking (highestLevel < 7 in SaveManager and MainMenu, getters isShopUnlocked, isWorkshopUnlocked, isAquariumUnlocked, isChaosUnlocked, isLeagueUnlocked; lock badges 🔒 Bölüm X; feedback on tap).
- R2: Mode Identity ("ANA MACERA" vs "ÖZEL MOD" in MainMenu and I18n) & Cross-Mode Workshop Scaling (Workshop upgrades u_crit, u_luck, u_gold apply inside Chaos Mode in GameController as well as Classic Mode).
- R3: Interactive In-Game Visual Onboarding (animated drag guide ◄── KAYDIR ──► below paddle in Level 1; slow-mo pulse and banner ⚡ SÜPER KÖŞE VURUŞU! on first corner hit via firstCornerHitShown; HUD callout ⚡ ULTİ HAZIR! ÇİFT DOKUN! when ultiCharge >= 1.0).
- R4: Early-Game Pacing & Guaranteed Action Drops (ball speed +15% in Levels 1–5; guaranteed action capsule multiBall or fireball in first 3 broken bricks in Levels 1–5 via earlyActionDropGranted).

Specific instructions:
1. Read ORIGINAL_REQUEST.md thoroughly.
2. Investigate the relevant files:
   - lib/storage/save_manager.dart
   - lib/ui/main_menu.dart
   - lib/engine/i18n.dart
   - lib/engine/game_controller.dart
   - lib/ui/game_canvas.dart
3. Identify exact code locations, existing variables/methods, data structures, and how each requirement should integrate cleanly.
4. Note any potential impacts on existing tests in test/game_test.dart.
5. Write your detailed findings, architecture observations, and implementation plan to:
   c:\Users\USER\Desktop\KIPKIRMATAS\.agents\teamwork\explorer_survey_1\survey_report.md
   and write a standard handoff report to:
   c:\Users\USER\Desktop\KIPKIRMATAS\.agents\teamwork\explorer_survey_1\handoff.md
6. Use send_message to report completion back to the orchestrator.
## 2026-10-16T17:46:10Z
You are Explorer 1 (Codebase, Widgets & Flutter Capture Specialist).
Read ORIGINAL_REQUEST.md at c:\Users\USER\Desktop\KIPKIRMATAS\.agents\teamwork\ORIGINAL_REQUEST.md (specifically ## Follow-up — 2026-10-16T17:42:06Z).

Your working directory is:
c:\Users\USER\Desktop\KIPKIRMATAS\.agents\teamwork\explorer_survey_1

Your task:
1. Inspect existing assets: assets/audio/ (cam_kirilma.mp3, glass_shatter.mp3, custom_laser.wav, custom_explosion.wav, bgm.wav), assets/images/fishes/, assets/images/skills/, assets/fonts/Rajdhani*, assets/images/kaunos_games.png. Document their exact paths, file sizes, formats.
2. Inspect the widgets, controllers, and custom painters in the codebase:
   - GameCanvas in lib/ui/game_canvas.dart, GameController in lib/engine/game_controller.dart (check how Fireball, Multi-ball, Ulti, and Corner Hit Slow-Mo banner are rendered).
   - Chaos Mode 3-card perk selection and Wave-10 Chaos Boss brick (BrickType.boss).
   - AquariumView in lib/ui/aquarium_view.dart with swimming fishes.
   - ShopView in lib/ui/shop_view.dart with cosmetic set synergies.
   - TournamentDialog in lib/ui/tournament_dialog.dart with weekly league rankings.
3. Investigate the best method for automated offscreen Flutter capture of 1080x1920 frames:
   - How can a standalone temporary test script in test/ capture high-res 1080x1920 PNG frames directly from these Flutter widgets/painters (e.g. golden test with custom surface size, RepaintBoundary -> toImage, headless widget test rendering to PNG)?
   - How to save these frames to docs/ad_assets/ (e.g., game_canvas_action.png, chaos_perks.png, aquarium_view.png, shop_synergies.png, tournament_league.png, chaos_boss.png)?
   - Ensure the temporary test can be removed so git status on lib/ and test/game_test.dart has zero diff and flutter analyze passes cleanly.
4. Write your comprehensive survey report to:
   c:\Users\USER\Desktop\KIPKIRMATAS\.agents\teamwork\explorer_survey_1\handoff.md
5. Report completion with a summary back to the parent orchestrator via send_message.
