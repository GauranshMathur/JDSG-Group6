#!/usr/bin/env bash
#
# Tests for route.sh. Each case runs the real script with a title and compares
# the JSON it prints.
#
#   .github/actions/pipeline-router/test-route.sh
#
# Worth having because routing decides which checks a pull request gets, and a
# router that silently selects nothing is indistinguishable from a green build:
# every pipeline is skipped, the gate sees nothing that failed, and the pull
# request goes green having tested none of the change.
#
# So the cases below care most about the ways it could under-select — an
# unrecognised tag, a near-miss, an empty fallback — and about the substring
# traps that would make it over-select.
set -euo pipefail

SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/route.sh"
TAGS="app infra doc"
passed=0
failed=0

# run_case <name> <expected json> <fallback> <title>
run_case() {
  local name="$1" want="$2" fallback="$3" title="$4"
  local got

  # || true so a script that exits non-zero is reported as one failed case.
  # Without it, set -e kills the harness at the first crash and every case after
  # it silently never runs — which is how an empty title went unnoticed.
  got="$(TITLE="$title" TAGS="$TAGS" FALLBACK="$fallback" bash "$SCRIPT" 2>/dev/null || true)"

  if [ "$got" = "$want" ]; then
    echo "PASS  $name"
    passed=$((passed + 1))
  else
    echo "FAIL  $name"
    echo "        title '$title'"
    echo "        want  $want"
    echo "        got   $got"
    failed=$((failed + 1))
  fi
}

echo "Testing $SCRIPT"
echo

# --- The ordinary routes -----------------------------------------------------

run_case "a single tag selects its pipeline" \
  '["app"]' "app infra" "[APP] feat(feed): rank posts"

run_case "infra routes to infra alone" \
  '["infra"]' "app infra" "[INFRA] feat(terraform): stand up the cluster"

run_case "doc routes to neither app nor infra" \
  '["doc"]' "app infra" "[DOC] docs: update the roadmap"

run_case "two tags select both, in the order the repository lists them" \
  '["app","infra"]' "app infra" "[APP][INFRA] ci(pipelines): route by title"

run_case "tags separated by other text are both found" \
  '["app","infra"]' "app infra" "[APP] and also [INFRA]: the lot"

run_case "matching is case-insensitive" \
  '["infra"]' "app infra" "[infra] fix: lowercase tag"

run_case "a tag later in the title is still found" \
  '["app"]' "app infra" "fix(feed): order by id [APP]"

# --- Under-selecting is the dangerous direction ------------------------------
# A router that selects nothing produces a green pull request that ran no
# checks, which looks exactly like a passing one.

run_case "no tag falls back rather than selecting nothing" \
  '["app","infra"]' "app infra" "feat: someone forgot the tag"

run_case "a near-miss tag falls back rather than selecting nothing" \
  '["app","infra"]' "app infra" "[DOCS] docs: plural is not the tag"

run_case "an unknown tag falls back" \
  '["app","infra"]' "app infra" "[BACKEND] feat: not a tag here"

run_case "an empty title falls back" \
  '["app","infra"]' "app infra" ""

run_case "brackets with no tag inside fall back" \
  '["app","infra"]' "app infra" "[] feat: empty brackets"

# --- Over-selecting: substrings that must not match --------------------------

run_case "a tag that is a prefix of a longer word does not match" \
  '["app","infra"]' "app infra" "[apple] feat: not the app tag"

run_case "the bare word without brackets does not match" \
  '["app","infra"]' "app infra" "feat: this app change has no tag"

run_case "a tag inside a longer bracketed word does not match" \
  '["app","infra"]' "app infra" "[infrastructure] feat: not the infra tag"

# --- The fallback itself -----------------------------------------------------

run_case "an empty fallback selects nothing when no tag matches" \
  '[]' "" "feat: no tag and nothing to fall back on"

run_case "a comma-separated fallback is split like a spaced one" \
  '["app","infra"]' "app,infra" "feat: no tag at all"

# --- The title is attacker-controlled ----------------------------------------
# Anyone able to open a pull request chooses it. It must be inert text.

run_case "shell metacharacters in the title are text, not code" \
  '["app","infra"]' "app infra" 'evil"; rm -rf /; echo "'

run_case "a command substitution in the title is not evaluated" \
  '["app","infra"]' "app infra" '$(touch /tmp/pwned-by-router) feat: nope'

run_case "backticks in the title are not evaluated" \
  '["app","infra"]' "app infra" '`touch /tmp/pwned-by-router` feat: nope'

run_case "a tag still routes when the title also carries metacharacters" \
  '["infra"]' "app infra" '[INFRA] feat: $(whoami) && echo hi'

if [ -e /tmp/pwned-by-router ]; then
  echo "FAIL  the title was evaluated as shell — /tmp/pwned-by-router exists"
  rm -f /tmp/pwned-by-router
  failed=$((failed + 1))
else
  echo "PASS  no title was evaluated as shell"
  passed=$((passed + 1))
fi

echo
echo "$passed passed, $failed failed"
[ "$failed" -eq 0 ]
