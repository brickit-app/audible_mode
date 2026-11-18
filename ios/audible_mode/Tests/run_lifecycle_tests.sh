#!/bin/bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
sources="$root/Sources/audible_mode"
output="$(mktemp -d)/audible_mode_lifecycle_tests"

swiftc \
  -module-name AudibleModeLifecycleTests \
  "$sources/utils/constants.swift" \
  "$sources/lifecycle/"*.swift \
  "$root/Tests/LifecycleTests/main.swift" \
  -o "$output"

"$output"
