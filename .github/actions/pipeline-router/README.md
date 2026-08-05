# Pipeline router

Routes a pull request to child pipelines by a tag in its title — `[APP]`,
`[INFRA]`, `[DOC]` — so a Terraform change does not run the application's test
suite and a documentation change does not build a container.

GitHub has no parent/child pipelines. The equivalent is a **reusable workflow**:
`on: workflow_call` in the child, `uses: ./.github/workflows/child.yml` in the
parent. That behaves like GitLab's `trigger` with `strategy: depend` — the
calling job waits for the child and can read its outputs.

This action is the routing step. It reads the title, matches it against the tags
you route on, and returns a JSON array.

## Use it

```yaml
name: CI
on:
  pull_request:
    # `edited` matters: without it, a pull request opened as [DOC] and retitled
    # to [APP] keeps the checks it got the first time.
    types: [opened, synchronize, reopened, edited]

jobs:
  route:
    runs-on: ubuntu-latest
    outputs:
      selected: ${{ steps.route.outputs.selected }}
    steps:
      - uses: actions/checkout@v4
      - uses: ./.github/actions/pipeline-router
        id: route
        with:
          title: ${{ github.event.pull_request.title }}
          tags: app infra doc
          fallback: app infra

  app:
    needs: route
    if: contains(fromJSON(needs.route.outputs.selected), 'app')
    uses: ./.github/workflows/ci-app.yml

  gate:
    name: CI
    needs: [route, app]
    if: always()
    runs-on: ubuntu-latest
    steps:
      - env:
          RESULTS: ${{ toJSON(needs) }}
        run: |
          grep -qE '"result"[[:space:]]*:[[:space:]]*"(failure|cancelled)"' <<< "$RESULTS" && exit 1
          echo "Every pipeline that ran passed."
```

`uses:` cannot be an expression, so a parent workflow can never be shared across
repositories — it has to name its children literally. This action is the part
that ports; the parent above is the ~40 lines each project writes for itself.

## Two things to get right

**Require one aggregate check, not the children.** A reusable workflow that is
never called contributes *no check runs at all* — so requiring `app / Lint` on
your default branch leaves every `[INFRA]` pull request waiting forever for a
status that is never coming. It is the same trap `paths-ignore` sets. The `gate`
job above always runs, so it can be required without deadlocking anything.

**Check what your release tooling does with the title.** Under squash merging
the title becomes the commit subject. Anything deriving a version from
Conventional Commits anchors its patterns at `^`, so `[INFRA] feat(x): y`
matches nothing and the release is silently skipped. Strip the tag first — this
repository does it in `.github/scripts/next-version.sh`, with tests.

## Tests

```bash
.github/actions/pipeline-router/test-route.sh
```

The logic lives in `route.sh` rather than inline in `action.yml`, so the tests
exercise the script the action actually runs instead of a copy free to drift.
Run it in CI — see this repository's `ci.yml`, where a `Pipeline self-test` job
runs unconditionally, before any routing decision is acted on.

Worth the trouble because **a broken router fails green.** If it selects
nothing, every pipeline is skipped, the aggregate gate sees nothing that failed,
and the pull request passes having tested none of the change. So the cases weigh
towards under-selection — unknown tags, near-misses, an empty title, an empty
fallback — and towards the substring traps that would make it over-select
(`[apple]` must not match a tag of `app`).

Writing them found one real bug: an empty title aborted the script rather than
falling back, which would have failed a pull request over a title nobody typed.

## Behaviour

| Title | Selected |
| --- | --- |
| `[APP] feat(feed): rank posts` | `["app"]` |
| `[APP][INFRA] feat: both halves` | `["app","infra"]` |
| `[infra] fix: lowercase works` | `["infra"]` |
| `feat: no tag at all` | the `fallback` |

Matching is case-insensitive and on the literal tag, so `[DOCS]` does **not**
match a `doc` tag — it falls through to the fallback. That direction is
deliberate: an unrecognised tag runs more than it needs to, never less.

**The trade this accepts:** a title is a claim, while a diff is evidence. A pull
request titled `[DOC]` that edits application code will skip that code's tests.
If you would rather not accept that, route on changed paths instead — the parent
and gate stay exactly as they are, and only the `route` job changes.
