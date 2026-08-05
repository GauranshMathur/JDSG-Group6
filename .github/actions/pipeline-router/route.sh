#!/usr/bin/env bash
#
# Selects which child pipelines a pull request needs, from tags in its title.
#
# Reads three environment variables:
#
#   TITLE     the pull request title, e.g. "[APP] feat(feed): rank posts"
#   TAGS      the tags this repository routes on, space- or comma-separated,
#             without brackets, e.g. "app infra doc"
#   FALLBACK  what to select when the title carries none of them
#
# Prints a JSON array to stdout — ["app","infra"] — and appends
# selected=<json> to $GITHUB_OUTPUT when running under Actions.
#
# Diagnostics go to stderr so stdout stays machine-readable, the same split
# next-version.sh uses.
#
# A separate file rather than inline in action.yml so that test-route.sh
# exercises the script CI actually runs, instead of a copy of it that is free
# to drift.
set -euo pipefail

log() { echo "$@" >&2; }

# TITLE may legitimately be empty — ${TITLE:?} would abort on that rather than
# falling back, and an aborted router fails the whole pull request over a title
# nobody typed. Only TAGS is genuinely required: without it there is nothing to
# route on and falling back silently would hide the misconfiguration.
TITLE="${TITLE-}"
FALLBACK="${FALLBACK:-}"
: "${TAGS:?TAGS is required}"

selected=()
for tag in ${TAGS//,/ }; do
  # -F so a tag is a literal string rather than a pattern — brackets included,
  # which is also what stops "[apple]" matching a tag of "app". -i so [infra]
  # and [INFRA] both match.
  if grep -qiF "[$tag]" <<< "$TITLE"; then
    selected+=("$tag")
  fi
done

if [ ${#selected[@]} -eq 0 ] && [ -n "${FALLBACK// /}" ]; then
  log "::warning::No pipeline tag in the title — falling back to: ${FALLBACK}. Tag the title to route it."
  for tag in ${FALLBACK//,/ }; do
    selected+=("$tag")
  done
fi

if [ ${#selected[@]} -eq 0 ]; then
  json='[]'
else
  json=$(printf '%s\n' "${selected[@]}" | jq -Rsc 'split("\n") | map(select(length > 0))')
fi

log "::notice::Title: ${TITLE}"
log "::notice::Pipelines selected: ${json}"

if [ -n "${GITHUB_OUTPUT:-}" ]; then
  echo "selected=${json}" >> "$GITHUB_OUTPUT"
fi

echo "$json"
