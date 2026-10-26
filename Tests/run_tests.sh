#!/bin/zsh
# Builds App.swift + Tests/main.swift into a throwaway binary (the app's own @main entry
# is renamed so the test main takes over) and runs it.
set -euo pipefail
cd "${0:A:h}/.." || exit 1
OUT="$(mktemp -d)"
swiftc -parse-as-library -Xfrontend -entry-point-function-name -Xfrontend foldertop_app_main \
  App.swift Tests/main.swift -o "${OUT:?}/foldertop_tests" 2>&1 | grep -E "error" || true
"${OUT:?}/foldertop_tests"
