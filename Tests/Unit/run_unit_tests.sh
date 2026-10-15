#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

BUILD_DIR="${PROJECT_ROOT}/build/unit"
mkdir -p "${BUILD_DIR}"
BIN_PATH="${BUILD_DIR}/m1_unit_runner"

echo "==> Compiling Milestone 1 Unit Tests..."
swiftc \
    "${PROJECT_ROOT}/KirmatasIOS/Models/Color+Hex.swift" \
    "${PROJECT_ROOT}/KirmatasIOS/Models/GameState.swift" \
    "${PROJECT_ROOT}/KirmatasIOS/Models/Cosmetics.swift" \
    "${PROJECT_ROOT}/KirmatasIOS/Models/AquariumModel.swift" \
    "${PROJECT_ROOT}/KirmatasIOS/Models/QuestModel.swift" \
    "${PROJECT_ROOT}/KirmatasIOS/Engine/I18n.swift" \
    "${PROJECT_ROOT}/KirmatasIOS/Engine/SaveManager.swift" \
    "${SCRIPT_DIR}/M1UnitTests.swift" \
    -o "${BIN_PATH}" \
    -O

echo "==> Running Milestone 1 Unit Tests..."
"${BIN_PATH}"
