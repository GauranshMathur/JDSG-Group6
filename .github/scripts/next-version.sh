#!/usr/bin/env bash
#
# Derives the next SemVer from Conventional Commit prefixes since the last v* tag.
#
#   feat                     -> minor
#   fix, perf                -> patch
#   `type!:` or a BREAKING CHANGE footer -> major, except below 1.0 (see below)
#   docs, chore, test, ci    -> nothing
#
# Prints two lines to stdout, ready to append to $GITHUB_OUTPUT:
#
#   bump=minor
#   version=0.2.0
#
# A release-less push prints `bump=none` and an empty version, and the caller
# skips the rest of the pipeline. Diagnostics go to stderr so stdout stays
# machine-readable.
#
# Hand-rolled rather than an off-the-shelf action: github-tag-action, the obvious
# choice, cannot bootstrap. With no existing tag it has no range to diff against,
# reports "Analysis of 0 commits" and declines to release, so the very first
# version never gets cut. Treating "no tag" as "consider the whole history" is
# the only difference, and it is not worth a dependency that gets it wrong.
#
# Tested by test-next-version.sh next to this file. Run that before changing it —
# this logic has been wrong twice, and both times the suite passed.
set -euo pipefail

log() { echo "$@" >&2; }

latest_tag=$(git tag -l 'v*' --sort=-v:refname | head -n1 || true)

if [ -z "$latest_tag" ]; then
  range=""
  previous="0.0.0"
  log "No previous tag; considering the full history."
else
  range="${latest_tag}..HEAD"
  previous="${latest_tag#v}"
  log "Previous tag ${latest_tag}; considering ${range}."
fi

# Subject then body per commit, with a record separator so one commit's
# BREAKING CHANGE footer cannot be misread as belonging to the next.
commits=$(git log --format=$'%s%n%b\x1e' ${range:+"$range"})

bump="none"
while IFS= read -r -d $'\x1e' commit; do
  [ -z "${commit//[[:space:]]/}" ] && continue

  # The first non-blank line, not simply the first line. Every record after the
  # newest begins with the newline that terminated the previous one, so taking
  # line 1 yields an empty subject and the commit goes unclassified — which
  # silently under-bumps whenever the release-worthy commit is not the newest
  # one in the range.
  subject=$(printf '%s\n' "$commit" | grep -m1 -v '^[[:space:]]*$' || true)

  if printf '%s\n' "$commit" | grep -qE '^BREAKING[ -]CHANGE:' ||
     printf '%s\n' "$subject" | grep -qE '^[a-z]+(\([^)]*\))?!:'; then
    bump="major"
    break
  elif printf '%s\n' "$subject" | grep -qE '^feat(\([^)]*\))?:'; then
    bump="minor"
  elif printf '%s\n' "$subject" | grep -qE '^(fix|perf)(\([^)]*\))?:'; then
    [ "$bump" = "minor" ] || bump="patch"
  fi
done <<< "$commits"

IFS=. read -r major minor patch <<< "$previous"

# SemVer 9: while the major version is 0, anything may change at any time and
# the public API is not considered stable. So a breaking change below 1.0 bumps
# the minor rather than declaring 1.0.0.
#
# Without this, any commit carrying a BREAKING CHANGE footer silently promotes a
# proof of concept to a stable release. Reaching 1.0 should be a deliberate act,
# not a side effect of a commit message.
if [ "$bump" = "major" ] && [ "$major" -eq 0 ]; then
  log "Breaking change below 1.0: bumping the minor rather than declaring 1.0.0."
  bump="minor"
fi

case "$bump" in
  major) major=$((major + 1)); minor=0; patch=0 ;;
  minor) minor=$((minor + 1)); patch=0 ;;
  patch) patch=$((patch + 1)) ;;
  none)
    log "No release-worthy commits since ${latest_tag:-the start of history}."
    echo "bump=none"
    echo "version="
    exit 0
    ;;
esac

log "Bump: ${bump}. Next version: ${major}.${minor}.${patch}."
echo "bump=$bump"
echo "version=${major}.${minor}.${patch}"
