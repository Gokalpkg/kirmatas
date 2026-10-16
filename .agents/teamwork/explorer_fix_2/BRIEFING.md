# BRIEFING — 2026-10-16T18:44:45Z

## Mission
Analyze math bug at line 670 and inspect Scene 3 asset rendering / layout in docs/kirmatas_ad_en.html to formulate exact fix recommendations.

## 🔒 My Identity
- Archetype: explorer
- Roles: Animation & Mathematics Fix Specialist
- Working directory: c:\Users\USER\Desktop\KIPKIRMATAS\.agents\teamwork\explorer_fix_2
- Original parent: a954229f-7f6b-47b6-a253-514b9fa8e0e7
- Milestone: defect analysis & fix specification

## 🔒 Key Constraints
- Read-only investigation — do NOT implement / edit docs/kirmatas_ad_en.html directly
- Document exact code changes / proposed snippets in handoff.md

## Current Parent
- Conversation ID: a954229f-7f6b-47b6-a253-514b9fa8e0e7
- Updated: 2026-10-16T18:44:45Z

## Investigation State
- **Explored paths**:
  * `docs/kirmatas_ad_en.html` (lines 660–680, 1240–1400, 1619–1690, 1696–1760)
  * `docs/kirmatas_reklam_tr.html` (lines 1120–1195, 1325–1380)
  * `lib/ui/tournament_dialog.dart`
  * `docs/ad_assets/` (dimension and aspect ratio checks)
- **Key findings**:
  * Line 670 math bug (`Math.pow(prog, 2.4)` evaluates to NaN for `t < 0` because non-integer exponent on negative base is undefined). Fixed by `Math.max(0.0, Math.min(1.0, t / 3.5))`.
  * In Scene 3, `loadedImages.img_synergies` and `loadedImages.img_league` were omitted from drawing and replaced by procedural canvas boxes.
  * In the TR reference ad, `shop_synergies` and `tournament_league` were stretched/compressed by 1.69x and 1.55x.
  * Designed exact aspect-ratio preserving crops (`sw: 1080, sh: 439` mapped to `dw: 960, dh: 390`) yielding identical scale factor 0.8889 (0.0% distortion).
  * Cleared vertical collision envelope: Swimming fishes end at `y = 1070` (70px margin above card), card spans `y = 1140 to 1530`, TikTok captions start at `y = 1563` (33px margin below card).
- **Unexplored areas**: None.

## Key Decisions Made
- Formulated exact drop-in replacements for line 670 and functions `drawChaosPerksWindow` and `drawAquariumLeagueWindow`.

## Artifact Index
- `handoff.md` — Complete 5-component analysis and fix specification report.
- `progress.md` — Execution status and verification results.
- `DISPATCH.md` — Record of initial dispatch instruction.
