## 2026-10-16T12:33:36Z
You are Worker 1 for Milestone 1: FTUE & Early Game Core (Requirements R1, R2, R3, R4).

Working Directory: c:\Users\USER\Desktop\KIPKIRMATAS\.agents\teamwork\worker_m1
Original User Request: c:\Users\USER\Desktop\KIPKIRMATAS\.agents\teamwork\ORIGINAL_REQUEST.md
Project Document: c:\Users\USER\Desktop\KIPKIRMATAS\PROJECT.md
Explorer Survey Report: c:\Users\USER\Desktop\KIPKIRMATAS\.agents\teamwork\explorer_survey_1\survey_report.md
Explorer Handoff: c:\Users\USER\Desktop\KIPKIRMATAS\.agents\teamwork\explorer_survey_1\handoff.md

Your mission is to implement R1, R2, R3, and R4 completely and cleanly, verify via flutter analyze and flutter test, and add unit/widget tests for R1–R4 in test/game_test.dart.

File Write Ownership (You own these files exclusively for this milestone):
- lib/storage/save_manager.dart
- lib/ui/main_menu.dart
- lib/engine/i18n.dart
- lib/engine/game_controller.dart
- lib/ui/game_canvas.dart
- lib/models/powerup.dart
- test/game_test.dart

Detailed Requirements:
1. R1: Progressive Feature Unlocking:
   - In SaveManager:
     - highestLevel getter/setter wrapping metricHighestClassicLevel.
     - totalGold getter/setter wrapping gold.
     - bool get isShopUnlocked => highestLevel >= 2 || totalGold >= 100;
     - bool get isWorkshopUnlocked => highestLevel >= 3;
     - bool get isAquariumUnlocked => highestLevel >= 5;
     - bool get isChaosUnlocked => highestLevel >= 5;
     - bool get isLeagueUnlocked => highestLevel >= 7;
   - In MainMenu:
     - Guard auto-launch of Fortune Wheel dialog so it only auto-opens if _save.isShopUnlocked.
     - Display lock badges (e.g. 🔒 Bölüm 2, 🔒 Bölüm 3, 🔒 Bölüm 5, 🔒 Bölüm 7) on locked tabs/buttons.
     - On tapping a locked button/tab, show a clean SnackBar feedback (e.g. 'Bu özellik Bölüm X seviyesinde açılır.').
     - Handle PageView page changes gracefully so locked tabs cannot be swiped into by new players.
     - Ensure existing widget tests that test navigation/tabs pass seamlessly.
2. R2: Mode Identity & Cross-Mode Workshop Scaling:
   - In I18n and MainMenu:
     - Turkish translations for classic: 'Ana Macera' and chaos: 'Özel Mod'.
     - Display 'ANA MACERA' for Classic Mode and 'ÖZEL MOD' for Chaos Mode.
   - In GameController:
     - Ensure Workshop upgrades (Crit Damage u_crit, Luck u_luck, Gold Multiplier u_gold) actively apply bonuses inside Chaos Mode as well as Classic Mode.
3. R3: Interactive In-Game Visual Onboarding:
   - In GameController and GameCanvas:
     - Show animated drag guide (◄── KAYDIR ──►) below paddle during first seconds of Level 1 (level == 1 && !isChaosMode && !isZenMode).
     - Trigger brief slow-motion pulse (bulletTimeLeft) and celebratory banner (⚡ SÜPER KÖŞE VURUŞU!) on first corner hit (tracked via firstCornerHitShown).
     - Show glowing interactive HUD callout (⚡ ULTİ HAZIR! ÇİFT DOKUN!) when ultiCharge >= 1.0 (isUltiReady).
     - Add getters in GameController: isChaosMode, isZenMode, level, ultiCharge, isUltiReady, showLevel1DragGuide.
4. R4: Early-Game Pacing & Guaranteed Action Drops:
   - In GameController:
     - Base ball speed boosted +15% during Levels 1–5 (level <= 5 && !isChaosMode && !isZenMode).
     - In lib/models/powerup.dart: add `static const PowerUpType multiBall = PowerUpType.multi;`.
     - Guarantee that one of the first 3 broken bricks in Levels 1–5 drops an action capsule (PowerUpType.multiBall or PowerUpType.fireball), tracked via earlyActionDropGranted per level.
5. Tests:
   - In test/game_test.dart, add comprehensive unit & widget tests covering R1, R2, R3, R4.
   - Run flutter analyze (must be 0 issues) and flutter test (all existing 435 tests + new tests must pass).

## 2026-10-16T13:00:28Z
**Context**: Milestone 1 (R1–R4 FTUE & Early Game Core)
**Content**: Please ensure your implementation covers all four requirements:
- R1: SaveManager progressive unlocks & MainMenu lock badges/feedback
- R2: Mode identity ('Ana Macera' / 'Özel Mod') & Chaos workshop scaling
- R3: In-game onboarding (drag guide, corner hit banner/slow-mo, ulti ready callout)
- R4: Early-game pacing (+15% ball speed levels 1-5 & guaranteed action drop)
and that new automated tests for R1–R4 are added to test/game_test.dart with all 435 existing tests passing.
**Action**: Continue implementation and verification, then deliver handoff.md.
