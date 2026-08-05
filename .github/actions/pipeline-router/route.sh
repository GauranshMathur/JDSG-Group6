#!/usr/bin/env bash
#
# Selects which child pipelines a pull request needs, from the files it changes.
#
# Reads:
#
#   RULES     one "pipeline:regex" per line. A file matching the regex selects
#             that pipeline. A pipeline may have several rules; a rule may
#             select a pipeline others also select.
#   DEFAULT   pipelines to add when a changed file matches no rule at all,
#             space- or comma-separated.
#   FILES     newline-separated changed paths. When empty, they are derived
#             from BASE..HEAD with git.
#   BASE/HEAD commits to diff when FILES is not given.
#
# Prints a JSON array to stdout — ["app","infra"] — and appends
# selected=<json> to $GITHUB_OUTPUT when running under Actions. Diagnostics go
# to stderr so stdout stays machine-readable, the same split next-version.sh
# uses.
#
# DEFAULT is the safety property, and the reason this is a script rather than a
# stock paths-filter action: a file type nobody anticipated selects the default
# pipelines and gets checked, instead of matching no filter and silently
# selecting nothing. Deciding it that way round means the failure mode is
# running too much, never too little.
set -euo pipefail

log() { echo "$@" >&2; }

: "${RULES:?RULES is required}"
DEFAULT="${DEFAULT:-}"
FILES="${FILES-}"
BASE="${BASE:-}"
HEAD="${HEAD:-}"

# A composite action's `env:` always *sets* every variable, empty when the input
# was omitted, so "unset" cannot be used to mean "work it out from git". Decide
# on BASE/HEAD instead — and refuse to run at all when given neither, rather
# than treating a misconfiguration as an empty diff. Selecting nothing is the
# one outcome that fails green: every pipeline skips, the gate sees nothing that
# failed, and the pull request passes having checked none of the change.
if [ -z "${FILES//[[:space:]]/}" ]; then
  if [ -n "$BASE" ] && [ -n "$HEAD" ]; then
    FILES="$(git diff --name-only "$BASE" "$HEAD")"
  else
    log "::error::Neither FILES nor BASE and HEAD were given — refusing to select nothing."
    exit 1
  fi
fi

# An genuinely empty diff, on the other hand, really does need no pipelines.
if [ -z "${FILES//[[:space:]]/}" ]; then
  log "::warning::No changed files — selecting nothing."
  [ -n "${GITHUB_OUTPUT:-}" ] && echo "selected=[]" >> "$GITHUB_OUTPUT"
  echo '[]'
  exit 0
fi

log "Changed files:"
while IFS= read -r file; do
  [ -n "$file" ] && log "  $file"
done <<< "$FILES"

# Every pipeline named in RULES, in the order the rules list them, deduplicated.
pipelines=()
while IFS= read -r rule; do
  [ -z "${rule//[[:space:]]/}" ] && continue
  name="${rule%%:*}"
  name="${name//[[:space:]]/}"
  for seen in ${pipelines[@]+"${pipelines[@]}"}; do
    [ "$seen" = "$name" ] && continue 2
  done
  pipelines+=("$name")
done <<< "$RULES"

# A pipeline is selected when any changed file matches any of its rules.
selected=()
for pipeline in ${pipelines[@]+"${pipelines[@]}"}; do
  while IFS= read -r rule; do
    [ -z "${rule//[[:space:]]/}" ] && continue
    name="${rule%%:*}"
    name="${name//[[:space:]]/}"
    [ "$name" = "$pipeline" ] || continue
    pattern="${rule#*:}"

    if grep -qE "$pattern" <<< "$FILES"; then
      selected+=("$pipeline")
      break
    fi
  done <<< "$RULES"
done

# A file matching no rule at all is unclassified. One is enough to pull in the
# default, because the point is that nobody decided what it needs.
unmatched=""
while IFS= read -r file; do
  [ -z "${file//[[:space:]]/}" ] && continue
  matched=false
  while IFS= read -r rule; do
    [ -z "${rule//[[:space:]]/}" ] && continue
    pattern="${rule#*:}"
    if grep -qE "$pattern" <<< "$file"; then
      matched=true
      break
    fi
  done <<< "$RULES"
  [ "$matched" = false ] && unmatched+="${file}"$'\n'
done <<< "$FILES"

if [ -n "${unmatched//[[:space:]]/}" ]; then
  log "::warning::Files matching no rule — adding the default pipelines (${DEFAULT}):"
  while IFS= read -r file; do
    [ -n "$file" ] && log "  $file"
  done <<< "$unmatched"

  for pipeline in ${DEFAULT//,/ }; do
    already=false
    for seen in ${selected[@]+"${selected[@]}"}; do
      [ "$seen" = "$pipeline" ] && already=true && break
    done
    [ "$already" = false ] && selected+=("$pipeline")
  done
fi

if [ ${#selected[@]} -eq 0 ]; then
  json='[]'
else
  json=$(printf '%s\n' "${selected[@]}" | jq -Rsc 'split("\n") | map(select(length > 0))')
fi

log "::notice::Pipelines selected: ${json}"

if [ -n "${GITHUB_OUTPUT:-}" ]; then
  echo "selected=${json}" >> "$GITHUB_OUTPUT"
fi

echo "$json"
