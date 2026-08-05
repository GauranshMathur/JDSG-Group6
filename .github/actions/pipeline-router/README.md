# Pipeline router

Routes a pull request to child pipelines by the files it changes, so a Terraform
change does not run the application's test suite and a documentation change does
not build a container.

GitHub has no parent/child pipelines. The equivalent is a **reusable workflow**:
`on: workflow_call` in the child, `uses: ./.github/workflows/child.yml` in the
parent. That behaves like GitLab's `trigger` with `strategy: depend` — the
calling job waits for the child and can read its outputs.

This action is the routing step. It diffs `base..head`, matches each changed
path against your rules, and returns a JSON array of the pipelines to run.

## Use it

```yaml
name: CI
on: pull_request

jobs:
  route:
    runs-on: ubuntu-latest
    outputs:
      selected: ${{ steps.route.outputs.selected }}
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0          # both ends of the diff must be present
      - uses: ./.github/actions/pipeline-router
        id: route
        with:
          base: ${{ github.event.pull_request.base.sha }}
          head: ${{ github.event.pull_request.head.sha }}
          rules: |
            app:^web/
            app:^\.github/
            infra:^infra/
            infra:^\.github/
            docs:^docs/
            docs:\.md$
          default: app infra

  app:
    needs: route
    if: contains(fromJSON(needs.route.outputs.selected), 'app')
    uses: ./.github/workflows/ci-app.yml

  gate:
    name: CI
    needs: [route, app]
    if: always()
    runs-on: ubuntu-latest
    timeout-minutes: 5
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

## Why not `dorny/paths-filter`

It is the usual choice and it is good. The one thing it does not express is
**`default`** — what to do with a changed file that matches *no* filter. Without
that, an unanticipated path matches nothing, selects nothing, and the pull
request goes green having run no checks. Here an unclassified file pulls in the
default pipelines instead, so the failure mode is running too much rather than
too little.

If you do not need that property, use `dorny/paths-filter` and delete this.

## Two things to get right

**Require one aggregate check, not the children.** A reusable workflow that is
never called contributes *no check runs at all* — so requiring `app / Lint` on
your default branch leaves every infra-only pull request waiting forever for a
status that is never coming. It is the same trap `paths-ignore` sets. The `gate`
job above always runs, so it can be required without deadlocking anything.

**Rules are regexes, so anchor them.** `^web/` matches the `web` directory;
`web/` would also match `vendor/web/`. There are tests for exactly this.

## Tests

```bash
.github/actions/pipeline-router/test-route.sh
```

The logic lives in `route.sh` rather than inline in `action.yml`, so the tests
exercise the script the action actually runs instead of a copy free to drift.
Run it in CI — see this repository's `ci.yml`, where a `Pipeline self-test` job
runs unconditionally, outside the routing. You cannot use a routed pipeline to
test the router: if it is broken it may route away from its own test.

Worth the trouble because **a broken router fails green.** If it selects
nothing, every pipeline is skipped, the aggregate gate sees nothing that failed,
and the pull request passes having tested none of the change. So the cases weigh
towards under-selection — unclassified paths, an empty diff, misconfiguration —
and towards anchoring mistakes that match the wrong directory.

Writing them found two real bugs: a misconfigured call selected nothing instead
of failing, and a composite action's `env:` always *sets* every variable, so
"unset" could not be used to mean "derive from git".

## Behaviour

| Changed files | Selected |
| --- | --- |
| `web/app/models/user.rb` | `["app"]` |
| `infra/terraform/eks.tf` | `["infra"]` |
| `docs/roadmap.md` | `["docs"]` |
| `web/…` and `infra/…` | `["app","infra"]` |
| `.github/workflows/ci.yml` | `["app","infra"]` — a workflow can break either |
| `Makefile` (matches nothing) | the `default` |
| nothing at all | `[]` |

Given neither `files` nor `base`/`head`, the action **fails** rather than
selecting nothing. That direction is deliberate throughout: an empty selection
is the one result that looks exactly like a pass.
