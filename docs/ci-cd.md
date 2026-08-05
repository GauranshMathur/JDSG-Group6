# CI/CD

GitHub Actions. `release.yml` ships after merge and `render-diagrams.yml` keeps the
architecture diagram's rendered image in step with its source. Pull requests go through a
**parent pipeline that calls child pipelines** — `ci.yml` decides what a change needs, and
`ci-app.yml`, `ci-infra.yml` and `ci-security.yml` do the work.

## The pipelines

GitHub has no parent/child pipelines as such. The equivalent is a **reusable workflow**:
`on: workflow_call` in the child, `uses: ./.github/workflows/child.yml` in the parent. It
behaves like GitLab's `trigger` with `strategy: depend` — the calling job waits for the child
and can read its outputs.

| Workflow | Runs | Contains |
| --- | --- | --- |
| `ci.yml` | Every pull request | Routing and the aggregate gate. No checks of its own |
| `ci-app.yml` | `[APP]` | Lint, Test, Container build + image scan + DAST, SonarQube |
| `ci-infra.yml` | `[INFRA]` | Compose validation, Trivy misconfiguration scan over `infra/`. Terraform `fmt`/`validate`/`apply` arrive with the Terraform in I-1b |
| `ci-security.yml` | Always | Brakeman, bundler-audit, Trivy filesystem scan |

**Routing is by a tag in the pull request title** — `[APP]`, `[INFRA]` or `[DOC]`.
`[APP][INFRA]` runs both, matching is case-insensitive, and a title with no recognised tag
runs everything with a warning. Failing open on coverage is the safe direction: a change
nobody routed should be over-checked rather than waved through.

The routing step is [`.github/actions/pipeline-router`](../.github/actions/pipeline-router),
written to be lifted into another project — its README has the pattern and the traps.
`uses:` cannot be an expression, so a parent workflow can never be shared across
repositories; the router is the part that ports, and the parent is the ~40 lines each
project writes for itself.

**The trade:** a title is a claim, a diff is evidence. A pull request titled `[DOC]` that
edits `web/` will skip the specs. That is the cost of declaring the pipeline rather than
deriving it from changed paths, and the reason an untagged title runs everything.

**The security pipeline is never routed around.** Its Ruby-specific analysis is gated on
`[APP]`, because Brakeman has nothing to say about a Terraform change, but the Trivy scan is
not: it looks for committed secrets, and a credential pasted into a markdown file is every
bit as leaked as one in a Ruby file. Running it unconditionally is also what makes the
`Trivy` code-scanning check appear on every pull request.

### One required check, not seven

`ci.yml` ends with a **`CI`** job that always runs, `needs` every child, and fails if any
came back `failure` or `cancelled`. **That is the check to require on `main`** — not the
children. A reusable workflow that is never called contributes *no check runs at all*, so
requiring `App / Lint` would leave every `[INFRA]` pull request waiting forever for a status
that is never coming. Same trap `paths-ignore` sets, one layer up.

### The routing tag and the release

With squash merging the pull request title becomes the commit subject, and
`next-version.sh` anchors every Conventional Commit pattern at `^`. So
`[INFRA] feat(terraform): …` matched nothing, `bump=none`, and the release was silently
skipped — no tag, no image, exit code 0.

The script now strips leading `[TAG]` markers before classifying, with regression tests
covering single tags, stacked tags, and tagged commits that must *not* release. As ever with
this script, the tests were checked against the unfixed version first: five of the seven
failed, which is the only evidence that they test anything.


All work reaches the default branch through a pull request, and a pull request merges only
once these pass. Jobs run in parallel:

| Job | What it does | Fails the build on |
| --- | --- | --- |
| **Lint** | RuboCop with `rubocop-rails-omakase` | any offence |
| **Test** | RSpec on SQLite | any failure |
| **SAST** | Brakeman, bundler-audit, Trivy filesystem scan | any Brakeman warning, any gem CVE, any fixable HIGH/CRITICAL |
| **Container** | Builds the image, Trivy image scan, boots it, OWASP ZAP baseline scan | any fixable HIGH/CRITICAL in the image, or the container failing to serve `/up` |
| **SonarQube** | Quality gate | quality gate failure — skipped while unconfigured |

On the security gates:

- **Trivy fails on HIGH and CRITICAL, in both the filesystem and the image scan.** MEDIUM
  and LOW are reported without blocking. A HIGH in the image is usually inherited from the
  base image rather than written here, but inherited is not the same as acceptable — the
  fix is to bump the base image or patch the package, and the build stays red until someone
  does.
- **Each Trivy scan runs twice: once to gate, once to report.** The gating pass filters to
  HIGH and CRITICAL and sets an exit code; the second pass produces SARIF at every severity
  and uploads it to code scanning. The reporting pass is `if: always()`, so a failing gate
  still publishes what it found — a scan that fails the build without saying why is the less
  useful half of the two.

**A note on the `Trivy` check, because it looks like a job and is not.** It is created by
GitHub code scanning, named after the tool inside the SARIF, and it exists only when something
uploads results. Until recently the only upload was in the container job, which a docs-only
pull request skips — so on those pull requests the check was never created at all, and GitHub
listed it as expected and waiting for a status that was never coming. It reads exactly like a
job that refuses to be scheduled.

The filesystem scan now uploads too, from the SAST job, which is never skipped. That closes
two things at once: the check reports on every pull request, and the filesystem findings —
including the secret scanning that runs on documentation changes — reach the Security tab
instead of only ever setting an exit code.

This matters for required status checks (N-4.2). Requiring `Trivy` before this change would
have deadlocked every documentation pull request permanently.
- **`ignore-unfixed` is on**, so only findings with an available fix count. A vulnerability
  with no upstream patch cannot be actioned by any change in this repository; failing on it
  would only teach everyone to ignore the gate.
- **DAST reports but does not fail.** A baseline scan of a fresh Rails app flags
  header-level warnings (CSP, permissions policy) that are real but out of scope for
  milestone 1. Once triaged, flip `fail_action` to `true` so regressions block.

The container job is also the proof that the image works: it starts the built image and
polls `/up` until the app answers, so a broken image fails CI rather than a deployment.

## `release.yml` — after merge to the default branch

This workflow **ships; it does not re-test.**

1. Derive the next semantic version from the Conventional Commits since the last tag.
2. Stop here if nothing warrants a release.
3. Build the image and push it to the **GitHub Container Registry** at
   `ghcr.io/gauranshmathur/twitter-clone-web`, tagged with the version, `sha-<commit>` and
   `latest`, for both `linux/amd64` and `linux/arm64`.
4. **Then** create the git tag and the GitHub release.

Nothing from `ci.yml` is repeated here. Every check ran on the pull request against this
same code, and running the suite twice spends the same minutes to reach the same answer.
The merged code is built exactly once, by this workflow.

The ordering in steps 3 and 4 is deliberate. These jobs used to run in parallel, so the tag
and release appeared while the build was still going — a pull of the just-announced version
returned `not found` for several minutes, and a failed build would have left a published
release pointing at an image that never existed.

Because there is no gate on `main`, the pull request has to be a real one. Turn on
**Require branches to be up to date before merging**: without it, two branches can each
pass in isolation and still break once merged, and nothing downstream will catch it.

**Registry: GHCR, for now.** It needs no provisioning — the built-in `GITHUB_TOKEN`
authenticates the push, so there is no registry to create and no secret to manage. Amazon
ECR is written into the workflow and commented out; it arrives with the AWS work, at which
point the image can be pushed to both. Enabling it before the repository and the OIDC role
exist only produces red builds.

**Architectures:** release images are published as a manifest list covering `linux/amd64`
and `linux/arm64`, so `docker pull` selects the right variant. Without the arm64 half, a
pull on an Apple Silicon machine fails outright with `no matching manifest for
linux/arm64`, and AWS Graviton instances want arm64 too. The arm64 build runs under QEMU on
GitHub's x86 runners and is noticeably slower; if that becomes a problem the answer is a
native arm64 runner, not dropping the platform.

Pull request builds stay single-architecture. That image is only scanned and booted on the
runner, and paying the emulation cost on every pull request buys no extra signal.

**Image tagging:** every image carries an immutable `sha-<commit>` tag alongside the
semantic version, so a deployment can always be pinned to an exact build.

## `render-diagrams.yml` — the architecture diagram, rendered

The architecture diagram is authored as draw.io XML
([`docs/diagrams/aws-reference-architecture.drawio`](diagrams/aws-reference-architecture.drawio))
and edited online in app.diagrams.net, which commits the `.drawio` straight back to `main`.
GitHub cannot render draw.io files, so the README embeds an SVG — and an SVG exported by
hand goes stale the first time someone edits the diagram and forgets to re-export.

So the export is a workflow instead: any push to `main` that touches a `.drawio` under
`docs/diagrams/` runs [`rlespinasse/drawio-export-action`](https://github.com/rlespinasse/drawio-export-action)
(headless draw.io in a container), and if the rendered SVG differs from what is committed,
the workflow commits it back as `github-actions[bot]`. The commit message carries
`[skip ci]` so the render never triggers another workflow run, and pushes from the built-in
`GITHUB_TOKEN` do not retrigger workflows anyway — no recursion by two independent
mechanisms. A `workflow_dispatch` trigger allows forcing a render by hand, which is also
how the first SVG gets created.

This is the one workflow that pushes to `main` directly rather than going through a pull
request. That is deliberate: the SVG is derived output, not authored work — reviewing it
would mean reviewing a rendering, and requiring a pull request would mean a human in the
loop for a file no human writes.

## Configuring SonarQube

The SonarQube job checks for a `SONAR_TOKEN` secret and skips the scan when it is absent, so
it does not block pull requests before the server exists. Add `SONAR_TOKEN` (and
`SONAR_HOST_URL` for a self-hosted server) to repository secrets to turn it on. Project
settings live in `sonar-project.properties`.

## Versioning and releases

The project follows [Semantic Versioning 2.0.0](https://semver.org/): `MAJOR.MINOR.PATCH`.

- **MAJOR** — incompatible changes to a public interface or a migration that cannot be
  rolled back cleanly.
- **MINOR** — new functionality, backwards compatible. Most feature milestones land here.
- **PATCH** — backwards-compatible bug fixes.

While the app is pre-release it stays on `0.x.y`, where `0.MINOR.PATCH` signals that the
public interface is not yet stable.

Conventions:

- Commits follow [Conventional Commits](https://www.conventionalcommits.org/)
  (`feat:`, `fix:`, `chore:`, `docs:`, `refactor:`, `test:`, `ci:`). This is what lets the
  version bump and changelog be derived automatically.
- Releases are git tags of the form `v0.3.1`, created by CI rather than by hand.
- Release notes are generated by GitHub from the commits and pull requests in the range.

Releases are automated in `.github/workflows/release.yml`: when a pull request lands on the
default branch, the commit messages since the last tag decide the bump — `feat` gives a
minor, `fix` and `perf` give a patch, `!` or a `BREAKING CHANGE` footer gives a major. A
merge carrying only `docs`, `chore`, `test` or `ci` commits produces no tag and no image.

**Below 1.0, a breaking change bumps the minor rather than declaring 1.0.0.** SemVer clause 9
says that while the major version is zero the public API is not stable and anything may change,
so `0.1.3` plus a breaking change is `0.2.0`, not `1.0.0`. Reaching 1.0 is a deliberate claim
that the app is stable, and should be an act rather than a side effect of a commit footer. The
rule lifts automatically once the project is genuinely at 1.x, where a breaking change gives a
major as normal.

The derivation lives in [`.github/scripts/next-version.sh`](../.github/scripts/next-version.sh)
with tests beside it, run as `.github/scripts/test-next-version.sh`. It is a script rather than
inline YAML because it has shipped a wrong tag twice, and inline it could not be exercised
without pushing:

- **v0.0.1 instead of v0.1.0.** Only the newest commit in the range was ever classified — every
  record after the first began with a newline, so `head -n1` returned an empty subject. Seven
  tests passed against the bug, because every one of them put the release-worthy commit newest.
- **v1.0.0 instead of v0.2.0.** A `BREAKING CHANGE` footer bumped the major with no 0.x case,
  which would have promoted this proof of concept to a stable release.

Both are now regression tests, and new cases are expected to be checked against the unfixed
script first — a test that passes either way proves nothing.

This is why the commit prefix is functional rather than decorative: mislabel a feature as a
chore and it silently never ships a version.

**With squash merging, the squash commit message is the one that counts.** The individual
commits on a branch collapse into a single commit on the default branch, so a branch full of
tidy `feat:` commits still produces no release if the squash title is left as something
generic. Keep the pull request title in Conventional Commit form — it is what GitHub offers
as the default squash subject.

The bump is derived by a short script in the workflow rather than an off-the-shelf action.
The usual candidate, `github-tag-action`, cannot cut a *first* release: with no existing tag
it has no range to diff against, reports "Analysis of 0 commits" and declines to release.
Treating "no tag yet" as "consider the whole history" is the only behavioural difference.
