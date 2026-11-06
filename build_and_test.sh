#!/bin/bash
set -e

BUILD_DIR=".build"
CACHE_DIR="${BUILD_DIR}/cache"
SDK_PATH="/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk"

mkdir -p "${BUILD_DIR}/bin"
mkdir -p "${CACHE_DIR}"

echo "=================================================="
echo "      BUILDING MASTER DOCK MACOS APPLICATION      "
echo "=================================================="

# 1. Build MasterDock executable via SPM
echo "[1/3] Building MasterDock with Swift Package Manager..."
swift build

# Copy built executable to bin
mkdir -p "${BUILD_DIR}/bin"
BUILT_BIN=$(find .build -name MasterDock -type f -perm +111 | grep "debug/MasterDock" | head -n 1)
if [ -n "${BUILT_BIN}" ]; then
    cp "${BUILT_BIN}" "${BUILD_DIR}/bin/MasterDock"
    chmod +x "${BUILD_DIR}/bin/MasterDock"
fi

echo "✅ Successfully built MasterDock executable at ${BUILD_DIR}/bin/MasterDock"

# 2. Build and Run Test Suite via SPM
echo "[2/3] Building MasterDock Test Suite..."
swift build --target MasterDockTests

TEST_BIN=$(find .build -name MasterDockTests -type f -perm +111 | grep "debug/MasterDockTests" | head -n 1)
if [ -n "${TEST_BIN}" ]; then
    cp "${TEST_BIN}" "${BUILD_DIR}/bin/MasterDockTests"
    chmod +x "${BUILD_DIR}/bin/MasterDockTests"
fi

echo "✅ Successfully built MasterDockTests at ${BUILD_DIR}/bin/MasterDockTests"

# 3. Run Test Suite
echo "[3/3] Executing MasterDock Tests..."
swift run MasterDockTests

echo ""
echo "🎉 ALL BUILD & TEST STAGES PASSED SUCCESSFULLY!"
