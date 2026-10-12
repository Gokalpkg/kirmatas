import 'package:flutter_test/flutter_test.dart';
import 'e2e_test_helpers.dart';
import 'tier1_feature_coverage_test.dart' as tier1;
import 'tier2_boundary_corner_test.dart' as tier2;
import 'tier3_cross_feature_test.dart' as tier3;
import 'tier4_real_world_scenarios_test.dart' as tier4;

/// Comprehensive Requirement-Driven E2E Test Suite for Kırmataş Quality & Visual Overhaul.
///
/// Covers Tiers 1 to 4 across all features F1.1 through F3.4:
/// - Tier 1: Feature Coverage (>=5 test cases per feature in isolation)
/// - Tier 2: Boundary & Corner Cases (>=5 test cases per feature covering boundary conditions)
/// - Tier 3: Cross-Feature Combinations (pairwise interactions)
/// - Tier 4: Real-World Application Scenarios (5 comprehensive end-to-end gameplay flows)
void main() {
  setupE2ETestEnvironment();

  group('Kırmataş Quality & Visual Overhaul — Comprehensive E2E Requirements Suite', () {
    tier1.main();
    tier2.main();
    tier3.main();
    tier4.main();
  });
}
