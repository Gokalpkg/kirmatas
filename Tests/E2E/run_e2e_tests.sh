#!/usr/bin/env bash
# ==============================================================================
# KirmatasIOS — Automated End-to-End (E2E) Test Suite Runner
# ==============================================================================
# Runs the 4-Tier Opaque-Box Test Harness for KirmatasIOS:
#   Tier 1: Feature Coverage (>=5 tests per feature)
#   Tier 2: Boundary & Corner Cases (>=5 tests per feature)
#   Tier 3: Cross-Feature Combinations (Pairwise coverage)
#   Tier 4: Real-World Application Scenarios (5 player sessions)
# Returns exit code 0 when all tests pass; non-zero if any failure occurs.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

echo "==> Setting up KirmatasIOS E2E Test Runner..."
echo "    Project Root: ${PROJECT_ROOT}"
echo "    Test Suite:   ${SCRIPT_DIR}"

if ! command -v swiftc &> /dev/null; then
    echo "ERROR: swiftc compiler not found in PATH." >&2
    exit 1
fi

SWIFT_VERSION=$(swiftc --version | head -n 1)
echo "    Compiler:     ${SWIFT_VERSION}"

BUILD_DIR="${PROJECT_ROOT}/build/e2e"
mkdir -p "${BUILD_DIR}"
BIN_PATH="${BUILD_DIR}/e2e_runner"

echo "==> Compiling E2E Test Suite sources..."
swiftc \
    "${SCRIPT_DIR}/TestAssertions.swift" \
    "${SCRIPT_DIR}/DomainModels.swift" \
    "${SCRIPT_DIR}/Tier1_FeatureCoverage.swift" \
    "${SCRIPT_DIR}/Tier2_BoundaryCornerCases.swift" \
    "${SCRIPT_DIR}/Tier3_CrossFeatureCombinations.swift" \
    "${SCRIPT_DIR}/Tier4_RealWorldScenarios.swift" \
    "${SCRIPT_DIR}/MainTestRunner.swift" \
    -o "${BIN_PATH}" \
    -O

echo "==> Executing E2E Test Suite..."
"${BIN_PATH}"
RUNNER_EXIT_CODE=$?

if [ ${RUNNER_EXIT_CODE} -eq 0 ]; then
    echo "==> [SUCCESS] All E2E test suites passed with exit code 0."
else
    echo "==> [FAILURE] E2E test suite failed with exit code ${RUNNER_EXIT_CODE}." >&2
fi

exit ${RUNNER_EXIT_CODE}
