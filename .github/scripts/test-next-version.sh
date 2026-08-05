#!/usr/bin/env bash
#
# Tests for next-version.sh. Each case builds a throwaway git repository with a
# known history, runs the script against it, and compares the output.
#
#   .github/scripts/test-next-version.sh
#
# This exists because the version logic has been wrong twice, and both times the
# mistake shipped a wrong tag:
#
#   * v0.0.1 instead of v0.1.0 — only the newest commit in the range was ever
#     classified, because every record after the first began with a newline and
#     `head -n1` returned an empty subject. Seven tests passed against the bug,
#     because every one of them put the release-worthy commit newest.
#   * v1.0.0 instead of v0.2.0 — a BREAKING CHANGE footer bumped the major with
#     no special case for 0.x, promoting a proof of concept to a stable release.
#
# So: when adding a case, put the interesting commit somewhere other than the
# newest position, and check the test fails before the fix that makes it pass.
set -euo pipefail

SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/next-version.sh"
passed=0
failed=0

# run_case <name> <expected version> <expected bump> <tag or ""> <subject...>
# Commits are given oldest first.
run_case() {
  local name="$1" want_version="$2" want_bump="$3" tag="$4"
  shift 4

  local repo
  repo="$(mktemp -d)"
  (
    cd "$repo"
    git init -q
    git config user.email t@example.com
    git config user.name Test
    git config commit.gpgsign false

    git commit -q --allow-empty -m "chore: initial"
    [ -n "$tag" ] && git tag "$tag"

    local subject
    for subject in "$@"; do
      # A literal \n in the argument separates subject from body, so footers
      # like BREAKING CHANGE can be placed in the body where they belong.
      git commit -q --allow-empty -m "$(printf '%b' "$subject")"
    done
  )

  local out
  out="$(cd "$repo" && bash "$SCRIPT" 2>/dev/null)"
  rm -rf "$repo"

  local got_version got_bump
  got_version="$(printf '%s\n' "$out" | grep '^version=' | cut -d= -f2-)"
  got_bump="$(printf '%s\n' "$out" | grep '^bump=' | cut -d= -f2-)"

  if [ "$got_version" = "$want_version" ] && [ "$got_bump" = "$want_bump" ]; then
    echo "PASS  $name"
    passed=$((passed + 1))
  else
    echo "FAIL  $name"
    echo "        want version='$want_version' bump='$want_bump'"
    echo "        got  version='$got_version' bump='$got_bump'"
    failed=$((failed + 1))
  fi
}

echo "Testing $SCRIPT"
echo

# --- Bootstrapping, with no tag to diff against ------------------------------

run_case "no tag, a feature -> the first minor" \
  "0.1.0" "minor" "" "feat: the feed"

run_case "no tag, only a fix -> a patch from 0.0.0" \
  "0.0.1" "patch" "" "fix: a typo"

# --- The ordinary bumps ------------------------------------------------------

run_case "feat -> minor" \
  "0.2.0" "minor" "v0.1.3" "feat: accounts"

run_case "fix -> patch" \
  "0.1.4" "patch" "v0.1.3" "fix: a bug"

run_case "perf -> patch" \
  "0.1.4" "patch" "v0.1.3" "perf: fewer queries"

run_case "docs and chore alone -> no release" \
  "" "none" "v0.1.3" "docs: a rewrite" "chore: tidy"

run_case "a scope does not stop the prefix matching" \
  "0.2.0" "minor" "v0.1.3" "feat(auth): sign in"

# --- Breaking changes below 1.0 ----------------------------------------------
# Each of these returned a 1.x before the 0.x rule existed.

run_case "BREAKING CHANGE footer below 1.0 -> minor, not 1.0.0" \
  "0.2.0" "minor" "v0.1.3" "feat: accounts\n\nBREAKING CHANGE: posting needs an account."

run_case "bang below 1.0 -> minor, not 1.0.0" \
  "0.2.0" "minor" "v0.1.3" "feat!: require an account to post"

run_case "bang with a scope below 1.0 -> minor" \
  "0.2.0" "minor" "v0.1.3" "feat(auth)!: require an account"

run_case "breaking from 0.0.x stays below 1.0" \
  "0.1.0" "minor" "v0.0.2" "feat!: something drastic"

# --- Breaking changes at or above 1.0 ----------------------------------------
# The rule above must not swallow a real major bump.

run_case "BREAKING CHANGE footer at 1.x -> major" \
  "2.0.0" "major" "v1.2.3" "feat: accounts\n\nBREAKING CHANGE: posting needs an account."

run_case "bang at 1.x -> major" \
  "2.0.0" "major" "v1.2.3" "feat!: require an account to post"

# --- Position in the range ---------------------------------------------------
# The v0.0.1 bug passed every test that put the interesting commit newest.

run_case "a feat older than the newest commit is still seen" \
  "0.2.0" "minor" "v0.1.3" "feat: accounts" "docs: write it up" "chore: tidy"

run_case "a breaking change older than the newest commit is still seen" \
  "0.2.0" "minor" "v0.1.3" "feat!: require an account" "docs: write it up"

run_case "the largest bump in the range wins, whatever the order" \
  "0.2.0" "minor" "v0.1.3" "fix: a bug" "feat: accounts" "fix: another bug"

run_case "a fix after a feat does not downgrade the bump" \
  "0.2.0" "minor" "v0.1.3" "feat: accounts" "fix: a bug"

# --- Things that look like prefixes but are not ------------------------------

run_case "a subject merely mentioning a prefix does not release" \
  "" "none" "v0.1.3" "docs: explain what feat: and fix: mean"

# --- CI's pipeline-routing tag -----------------------------------------------
# ci.yml routes a pull request by a tag in its title, and squash merging makes
# that title the commit subject. Every pattern in the script is anchored at ^,
# so before the tag was stripped these all returned bump=none: no tag, no image,
# and an exit code of 0 saying everything was fine.
#
# The interesting commit is deliberately not the newest in the multi-commit
# cases, per the note at the top of this file.

run_case "[INFRA] before a feat still bumps the minor" \
  "0.2.0" "minor" "v0.1.3" "[INFRA] feat(terraform): stand up the cluster"

run_case "[APP] before a fix still bumps the patch" \
  "0.1.4" "patch" "v0.1.3" "[APP] fix(feed): order by id"

run_case "a tagged feat older than the newest commit is still seen" \
  "0.2.0" "minor" "v0.1.3" "[APP] feat: accounts" "[DOC] docs: write it up"

run_case "two tags are both stripped" \
  "0.2.0" "minor" "v0.1.3" "[APP][INFRA] feat: the lot"

run_case "a tagged breaking change below 1.0 is still capped at minor" \
  "0.2.0" "minor" "v0.1.3" "[APP] feat!: require an account" "[DOC] docs: note it"

run_case "a tagged docs commit still does not release" \
  "" "none" "v0.1.3" "[DOC] docs: a rewrite"

run_case "a tag on a non-releasing type does not accidentally release" \
  "" "none" "v0.1.3" "[INFRA] chore: bump the provider"

echo
echo "$passed passed, $failed failed"
[ "$failed" -eq 0 ]
