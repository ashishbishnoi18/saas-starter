#!/usr/bin/env bash
# ai-commit.sh — the pre-commit gate for AI-authored changes.
#
# Runs the same checks CI runs locally before committing, so the git
# log stays green on main. Every AI-agent commit should go through this.
#
# Usage:
#   scripts/ai-commit.sh "<commit message>"
#   scripts/ai-commit.sh -m "<message>"   # also accepted
#
# Exit codes:
#   0  commit succeeded
#   1  formatting failed (see `mix format`)
#   2  compile failed with warnings
#   3  tests failed
#   4  missing commit message
#   5  nothing to commit
set -euo pipefail

# Parse message arg.
msg="${1:-}"
[[ "${msg}" == "-m" ]] && msg="${2:-}"
if [[ -z "${msg}" ]]; then
  echo "usage: scripts/ai-commit.sh \"<commit message>\"" >&2
  exit 4
fi

cd "$(git rev-parse --show-toplevel)"

# 1. Format (auto-fix, then verify)
mix format || { echo "mix format failed" >&2; exit 1; }

# 2. Compile with warnings as errors
mix compile --warnings-as-errors || { echo "compile failed" >&2; exit 2; }

# 3. Tests
mix test --warnings-as-errors || { echo "tests failed" >&2; exit 3; }

# 4. Stage + commit
git add -A
if git diff --cached --quiet; then
  echo "nothing to commit" >&2
  exit 5
fi
git commit -m "$msg"
