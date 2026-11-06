#!/bin/bash
# Builds, tests, packages and relaunches Master Dock.
# Usage: ./rebuild.sh
set -e
cd "$(dirname "$0")"
bash ./build_and_test.sh
bash ./package_app_bundle.sh
killall MasterDock 2>/dev/null || true
sleep 1
open MasterDock.app
echo "✅ Master Dock rebuilt and relaunched."
