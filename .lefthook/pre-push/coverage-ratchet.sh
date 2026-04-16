#!/bin/bash
# synced_from_colony: true
# sync_pack: elixir
# sync_source: packs/elixir/.lefthook/pre-push/coverage-ratchet.sh
# sync_version: d3fefcef
# Coverage ratchet for generic Elixir projects.
# Stores the integer floor baseline in README.md as:
# <!-- COVERAGE: 70 -->

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
README_FILE="$PROJECT_ROOT/README.md"
TARGET_COVERAGE=90

extract_stored_coverage() {
  if [[ -f "$README_FILE" ]]; then
    raw=$(sed -n 's/.*<!-- COVERAGE: \([0-9.]*\) -->.*/\1/p' "$README_FILE" | head -1)
    echo "${raw%%.*}"
  else
    echo "0"
  fi
}

get_current_coverage() {
  cd "$PROJECT_ROOT"

  if ! MIX_ENV=test mix test --cover --export-coverage default >&2; then
    echo ""
    return 1
  fi

  MIX_ENV=test mix test.coverage 2>&1 | awk '/Total/ { gsub(/%/, "", $2); print $2 }' | head -1
}

main() {
  echo "📊 Running coverage ratchet check..."

  STORED_COVERAGE=$(extract_stored_coverage)
  if [[ -z "$STORED_COVERAGE" ]]; then
    STORED_COVERAGE="0"
  fi

  echo "   Stored coverage: ${STORED_COVERAGE}%"
  echo "   Running tests with coverage..."

  CURRENT_COVERAGE=$(get_current_coverage)
  TEST_EXIT_CODE=$?

  if [[ $TEST_EXIT_CODE -ne 0 ]]; then
    echo ""
    echo "❌ TESTS FAILED!"
    echo "   Fix the failing tests before pushing."
    exit 1
  fi

  if [[ -z "$CURRENT_COVERAGE" ]]; then
    echo "❌ Failed to extract coverage percentage"
    exit 1
  fi

  CURRENT_INT=${CURRENT_COVERAGE%%.*}
  echo "   Current coverage: ${CURRENT_COVERAGE}% (ratchet uses floor: ${CURRENT_INT}%)"

  if (( CURRENT_INT < STORED_COVERAGE )); then
    echo ""
    echo "❌ COVERAGE DECREASED!"
    echo "   Previous: ${STORED_COVERAGE}%"
    echo "   Current:  ${CURRENT_COVERAGE}%"
    echo ""
    echo "   Add tests to restore coverage to at least ${STORED_COVERAGE}%."
    exit 1
  fi

  if (( CURRENT_INT > STORED_COVERAGE )); then
    echo ""
    echo "✨ Coverage improved: ${STORED_COVERAGE}% → ${CURRENT_INT}%"
    echo "   Updating README.md baseline..."
    sed -i '' "s/<!-- COVERAGE: [0-9.]* -->/<!-- COVERAGE: ${CURRENT_INT} -->/" "$README_FILE"
    git reset HEAD -- . >/dev/null 2>&1 || true
    git add "$README_FILE"
    git commit --no-verify -m "chore: update coverage baseline to ${CURRENT_INT}%"
  fi

  if (( CURRENT_INT >= TARGET_COVERAGE )); then
    echo "🎉 Target coverage of ${TARGET_COVERAGE}% reached!"
  else
    REMAINING=$(( TARGET_COVERAGE - CURRENT_INT ))
    echo "   ${REMAINING}% remaining to reach ${TARGET_COVERAGE}% target"
  fi

  echo ""
  echo "✅ Coverage check passed"
}

main "$@"
