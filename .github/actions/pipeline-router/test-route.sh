#!/usr/bin/env bash
#
# Tests for route.sh. Each case runs the real script with a list of changed
# files and compares the JSON it prints.
#
#   .github/actions/pipeline-router/test-route.sh
#
# Worth having because routing decides which checks a pull request gets, and a
# router that selects nothing is indistinguishable from a green build: every
# pipeline is skipped, the gate sees nothing that failed, and the pull request
# goes green having tested none of the change.
#
# So the cases below care most about the ways it could under-select — an
# unclassified path, an empty diff, a rule that nearly matches — and about the
# anchoring mistakes that would make it match the wrong directory.
set -euo pipefail

SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/route.sh"

# The rules this repository routes on, kept in step with ci.yml.
RULES='app:^web/
app:^\.github/
infra:^infra/
infra:^\.github/
docs:^docs/
docs:\.md$
docs:^LICENSE$'

DEFAULT="app infra"
passed=0
failed=0

# run_case <name> <expected json> <file>...
run_case() {
  local name="$1" want="$2"
  shift 2
  local files got
  files="$(printf '%s\n' "$@")"

  # || true so a script that exits non-zero is reported as one failed case.
  # Without it, set -e kills the harness at the first crash and every case after
  # it silently never runs.
  got="$(FILES="$files" RULES="$RULES" DEFAULT="$DEFAULT" bash "$SCRIPT" 2>/dev/null || true)"

  if [ "$got" = "$want" ]; then
    echo "PASS  $name"
    passed=$((passed + 1))
  else
    echo "FAIL  $name"
    echo "        files $*"
    echo "        want  $want"
    echo "        got   $got"
    failed=$((failed + 1))
  fi
}

echo "Testing $SCRIPT"
echo

# --- The ordinary routes -----------------------------------------------------

run_case "an app change selects the app pipeline" \
  '["app"]' "web/app/models/user.rb"

run_case "an infra change selects the infra pipeline" \
  '["infra"]' "infra/terraform/eks.tf"

run_case "a docs change selects neither app nor infra" \
  '["docs"]' "docs/roadmap.md"

run_case "a root markdown file is documentation" \
  '["docs"]' "README.md"

run_case "LICENSE is documentation" \
  '["docs"]' "LICENSE"

run_case "touching both selects both, in rule order" \
  '["app","infra"]' "web/app/models/user.rb" "infra/terraform/eks.tf"

run_case "several files in one directory select it once" \
  '["app"]' "web/app/models/user.rb" "web/spec/models/user_spec.rb"

run_case "a workflow change selects app and infra, since it can break either" \
  '["app","infra"]' ".github/workflows/ci.yml"

run_case "code and docs together still run the code pipeline" \
  '["app","docs"]' "web/app/models/user.rb" "docs/roadmap.md"

# --- Under-selecting is the dangerous direction ------------------------------
# A router that selects nothing produces a green pull request that ran no
# checks, which looks exactly like a passing one.

run_case "an unclassified path falls back to the defaults" \
  '["app","infra"]' "Makefile"

run_case "an unclassified path pulls in the defaults alongside what matched" \
  '["docs","app","infra"]' "docs/roadmap.md" "Makefile"

run_case "a dotfile at the root is unclassified, not ignored" \
  '["app","infra"]' ".ruby-version"

run_case "a new top-level directory is unclassified, not ignored" \
  '["app","infra"]' "scripts/deploy.sh"


# --- Anchoring: the wrong directory must not match ---------------------------

run_case "a path merely containing web/ does not select app" \
  '["app","infra"]' "vendor/web/thing.rb"

run_case "a directory sharing a prefix does not match" \
  '["app","infra"]' "website/index.html"

run_case "docs in a nested path is not the docs directory" \
  '["app"]' "web/docs/notes.txt"

# --- Rules that overlap ------------------------------------------------------

run_case "a markdown file inside docs selects docs once, not twice" \
  '["docs"]' "docs/ci-cd.md"

run_case "a markdown file inside web is documentation and app" \
  '["app","docs"]' "web/README.md"

# --- Misconfiguration must be loud ------------------------------------------
# Given nothing to work from, the router must refuse rather than select
# nothing — an empty selection is the one result that fails green.

if RULES="$RULES" DEFAULT="$DEFAULT" bash "$SCRIPT" >/dev/null 2>&1; then
  echo "FAIL  no files and no base/head should be an error, not an empty selection"
  failed=$((failed + 1))
else
  echo "PASS  no files and no base/head is an error, not an empty selection"
  passed=$((passed + 1))
fi

# --- The git path, which is the one CI uses ----------------------------------
# Everything above hands the script a file list. CI does not: it passes BASE and
# HEAD and lets the script run the diff, so that path needs exercising too.

git_case() {
  local name="$1" want="$2" file="$3"
  local repo got
  repo="$(mktemp -d)"
  (
    cd "$repo"
    git init -q
    git config user.email t@example.com
    git config user.name Test
    git config commit.gpgsign false
    git commit -q --allow-empty -m "base"
    if [ -n "$file" ]; then
      mkdir -p "$(dirname "$file")"
      echo x > "$file"
      git add -A
      git commit -q -m "change"
    else
      git commit -q --allow-empty -m "nothing"
    fi
  )
  got="$(cd "$repo" && RULES="$RULES" DEFAULT="$DEFAULT" \
    BASE="$(git -C "$repo" rev-parse HEAD~1)" HEAD="$(git -C "$repo" rev-parse HEAD)" \
    bash "$SCRIPT" 2>/dev/null || true)"
  rm -rf "$repo"

  if [ "$got" = "$want" ]; then
    echo "PASS  $name"
    passed=$((passed + 1))
  else
    echo "FAIL  $name"
    echo "        want $want"
    echo "        got  $got"
    failed=$((failed + 1))
  fi
}

git_case "a diff derived from base..head routes the same way" \
  '["app"]' "web/app/models/user.rb"

git_case "a commit changing nothing selects nothing" \
  '[]' ""

echo
echo "$passed passed, $failed failed"
[ "$failed" -eq 0 ]
