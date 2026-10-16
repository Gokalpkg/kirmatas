# E2E Test Infra: Kırmataş Player-Experience Overhaul

## Test Philosophy
- Opaque-box, requirement-driven testing. Derived strictly from `ORIGINAL_REQUEST.md` and user-facing specifications.
- Dual objective: (1) Ensure all 435 baseline tests continue passing without regression, (2) Verify all 9 overhaul requirements (R1–R9) through automated unit and widget tests.
- Methodology: Category-Partition + Boundary Value Analysis (BVA) + Pairwise Combinatorial + Real-World Workload Testing across 4 tiers.

## Feature Inventory & Test Mapping
| # | Feature | Source (Requirement) | Tier 1 (Unit/Feature) | Tier 2 (Boundary/Edge) | Tier 3 (Cross-Feature) | Tier 4 (Scenario) |
|---|---------|----------------------|:---------------------:|:----------------------:|:----------------------:|:-----------------:|
| 1 | R1: Progressive Feature Unlocking | ORIGINAL_REQUEST §R1 | 5 | 5 | ✓ | ✓ |
| 2 | R2: Mode Identity & Workshop Scaling | ORIGINAL_REQUEST §R2 | 5 | 5 | ✓ | ✓ |
| 3 | R3: Interactive In-Game Onboarding | ORIGINAL_REQUEST §R3 | 5 | 5 | ✓ | ✓ |
| 4 | R4: Early-Game Pacing & Action Drops | ORIGINAL_REQUEST §R4 | 5 | 5 | ✓ | ✓ |
| 5 | R5: Infinite Cosmic Mastery Sinks | ORIGINAL_REQUEST §R5 | 5 | 5 | ✓ | ✓ |
| 6 | R6: Daily Seeded Blitz & Prestige | ORIGINAL_REQUEST §R6 | 5 | 5 | ✓ | ✓ |
| 7 | R7: Seasonal Titles & League Rivals | ORIGINAL_REQUEST §R7 | 5 | 5 | ✓ | ✓ |
| 8 | R8: Cosmetic Loadout Set Synergies | ORIGINAL_REQUEST §R8 | 5 | 5 | ✓ | ✓ |
| 9 | R9: Chaos Roguelike Perks & Bosses | ORIGINAL_REQUEST §R9 | 5 | 5 | ✓ | ✓ |

## Test Architecture
- **Test Runner**: Flutter Test Runner
  - Command: `flutter test test/game_test.dart`
  - Expected: Exit code 0, 0 failures, 100% pass rate.
- **Static Analysis**: Flutter Analyzer
  - Command: `flutter analyze`
  - Expected: Exit code 0, 0 errors, 0 warnings, 0 lints.
- **Directory Layout**:
  - `test/game_test.dart`: Primary test suite containing both existing baseline tests and new R1–R9 unit & widget tests.
  - `test/e2e/e2e_requirements_test.dart`: Complementary requirement-driven scenario tests.

## Coverage Thresholds
- Baseline Preservation: All 435 existing tests must continue passing.
- Tier 1: ≥5 test cases per feature (happy paths in isolation).
- Tier 2: ≥5 boundary/edge cases per feature (limits, zero/max, unlock transitions).
- Tier 3: Pairwise cross-feature interaction tests (e.g. Chaos Mode + Workshop Scaling + Synergy + Cosmic Mastery).
- Tier 4: Real-world application scenarios (e.g. brand new player FTUE journey from Level 1 to 7; endgame veteran loop post-238).
- Total new test cases planned: ≥50 automated test assertions seamlessly appended to `test/game_test.dart`.
