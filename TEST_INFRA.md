# E2E Test Infra: Kırmataş Quality & Visual Overhaul

## Test Philosophy
- Opaque-box, requirement-driven derived from `ORIGINAL_REQUEST.md` and user-facing specifications.
- Independent of internal implementation mechanics.
- Methodology: Category-Partition, Boundary Value Analysis, Pairwise Combinatorial, and Real-World Application Workload.

## Feature Inventory
| # | Feature | Source (requirement) | Tier 1 | Tier 2 | Tier 3 |
|---|---------|----------------------|:------:|:------:|:------:|
| 1 | F1.1 Level clear halts active balls, weapons, capsules | ORIGINAL_REQUEST §R1 | 5 | 5 | ✓ |
| 2 | F1.2 Victory & GameOver halt active entities | ORIGINAL_REQUEST §R1 | 5 | 5 | ✓ |
| 3 | F1.3 Simulation freezes during levelTransitionTimer > 0 | ORIGINAL_REQUEST §R1 | 5 | 5 | ✓ |
| 4 | F1.4 Freeze transition timer on pause/victory/gameover | ORIGINAL_REQUEST §R1 | 5 | 5 | ✓ |
| 5 | F1.5 Classic mode level 238 clear triggers _onVictory | ORIGINAL_REQUEST §R1 | 5 | 5 | ✓ |
| 6 | F1.6 Touch release doesn't auto-launch in next level | ORIGINAL_REQUEST §R1 | 5 | 5 | ✓ |
| 7 | F2.1 Remove 6-point Claude starburst polygon | ORIGINAL_REQUEST §R2 | 5 | 5 | ✓ |
| 8 | F2.2 Unify fireball & pierce as Searing Ball | ORIGINAL_REQUEST §R2 | 5 | 5 | ✓ |
| 9 | F2.3 Golden-flame swirling petals & solar core visual | ORIGINAL_REQUEST §R2 | 5 | 5 | ✓ |
| 10 | F2.4 Localization labels to "🔥 YAKICI TOP!" / "🔥 SEARING BALL!" | ORIGINAL_REQUEST §R2 | 5 | 5 | ✓ |
| 11 | F2.5 Capsule & pixel art golden-flame theme | ORIGINAL_REQUEST §R2 | 5 | 5 | ✓ |
| 12 | F3.1 Black Hole influence radius max(135.0, r * mult) | ORIGINAL_REQUEST §R3 | 5 | 5 | ✓ |
| 13 | F3.2 Gravity falloff pow(0.85) + base pull & swirl | ORIGINAL_REQUEST §R3 | 5 | 5 | ✓ |
| 14 | F3.3 Canvas gravity field boundary & spiral waves | ORIGINAL_REQUEST §R3 | 5 | 5 | ✓ |
| 15 | F3.4 PowerUpType.vortex spawns Black Hole in play zone | ORIGINAL_REQUEST §R3 | 5 | 5 | ✓ |

## Test Architecture
- Test runner: `flutter test`
- Location: `test/game_test.dart` and `test/e2e/e2e_requirements_test.dart`
- Expected pass criteria: 100% tests pass with exit code 0; `flutter analyze` reports 0 issues.

## Real-World Application Scenarios (Tier 4)
| # | Scenario | Features Exercised | Complexity |
|---|----------|--------------------|------------|
| 1 | Full Level Clear & Transition Safety | F1.1, F1.3, F1.4, F1.6 | High |
| 2 | Victory Apex at Level 238 in Classic Mode | F1.2, F1.4, F1.5 | High |
| 3 | Searing Ball Steel Melt & Multi-Brick Destruction | F2.2, F2.3, F2.4 | High |
| 4 | Gravitational Slingshot & Black Hole Deflection across Sizes | F3.1, F3.2, F3.3 | High |
| 5 | Vortex Power-Up Capsule Collect & Hazard Navigation | F3.1, F3.4, F1.1 | High |
