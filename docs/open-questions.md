# Open questions

Decisions not yet taken. This is a **live list** — when work answers a question, it is deleted
from here and the answer moves into whichever document it belongs to. It is not a log of
things we once wondered about.

Each entry says what the question is, why it matters, and when it needs answering. A question
with no "when" tends to sit here forever; a question with one becomes a decision on time.

Answered decisions live in [`adr/`](adr/) when the trade-off is worth remembering, or in the
relevant document when it is not.

---

## Product

### Should an edit history be kept?

**Partly answered.** Milestone 3 ships an "edited" marker — a post that has changed says so.
What it does *not* keep is the previous wording, so an edit is visible but not inspectable.

**Why it matters:** the marker was the cheap half. A history is the half that cannot be added
retroactively: every edit made from now until it exists is one whose earlier version is
already gone. The cost of leaving this open is accruing, which is not true of most of the
questions on this page.

**When:** before anything invites real usage. It is cheap while the table is small.

### Is there a time limit on editing?

Milestone 3 ships no limit — a post can be rewritten a minute or a year after publication.

**Why it matters:** it is the difference between fixing a typo and rewriting history, and it
matters more now that replies exist, because a reply can be made to agree with something that
is then changed underneath it.

**When:** overdue. The original deadline was "before replies ship", and replies shipped in
milestone 5 with no limit decided — every post remains editable forever. Needs answering
before anything invites real usage.

### Should duplicate posts be prevented?

For example by hashing the body and rejecting a repeat from the same author within a window.

**Why it matters:** double-submits happen, and a feed showing the same post three times is
bad. But "duplicate" needs defining — the exact same text, or normalised for whitespace and
case? Someone posting "good morning" every day is not spamming.

**When:** not urgent. Worth deciding before anything invites real usage.

---

## Technical

### Ranked full-text search

Milestone 6 ships a `LIKE` search, because full-text search is adapter-specific and the app is
on SQLite — see [ADR 0004](adr/0004-hashtags-and-search.md).

**When:** once the app is actually on PostgreSQL. Not before, and not by bolting on a search
engine to avoid the move.

### Is the PostgreSQL switch actually verified?

[ADR 0003](adr/0003-sqlite-first.md) claims switching databases needs only an environment
variable. Nothing tests that claim — no CI job runs the suite against PostgreSQL.

**Why it matters:** an untested claim about portability is a guess, and adapter assumptions
get found at the worst possible moment.

**When:** it now has a date. The latency work in [`latency.md`](latency.md) cannot start
without PostgreSQL, because SQLite runs in-process and there is no network to slow down. So
verifying the switch and measuring latency are one piece of work, not two. Tracked as N-6.7.

### How does the app degrade when the database is slow?

Not a single question so much as a set of them, written up in [`latency.md`](latency.md):
query counts, pool exhaustion, timeouts that only apply to SQLite, and a health check that
reports 200 against a dead database.

**Why it matters:** none of it is visible today, because SQLite is in-process. All of it
appears at once the first time PostgreSQL runs in its own container.

**When:** steps 1 to 3 of that document are small and worth doing regardless — in particular
the query-count guard, which should land before milestone 3 creates the N+1 it exists to
catch. The measurement harness is a separate, larger piece.

---

## Infrastructure

The design is in [`infrastructure.md`](infrastructure.md): the enterprise AWS architecture
as the reference, realized entirely locally. The earlier questions about an AWS account,
budget and domain name are answered by the premise — there will never be a real account, so
nothing bills and TLS terminates against a local hostname.

Whether floci's emulation is deep enough is no longer the load-bearing question it was.
[ADR 0008](adr/0008-terraform-verifies-runtime-deploys.md) splits the work in two: floci
verifies that the Terraform stands up, and a real local Kubernetes cluster runs the app. So
emulation depth now only has to be good enough to apply resources, not to serve traffic.
Also settled there: no Terraform modules, Terraform stops at AWS with Kubernetes objects as
manifests, and images come from GHCR rather than the emulated ECR.

### Which local Kubernetes distribution for the runtime track?

ADR 0008 names k3d as the likely choice — it is k3s in Docker, so it matches what floci's
EKS emulation would have launched anyway, and it ships Traefik and ServiceLB. kind and
minikube are the alternatives.

**Why it matters:** it decides what the manifests are exercised against, and how node
scaling and zone-loss rescheduling get demonstrated in I-1f.

**When:** at the start of track B (I-1d). Nothing before then depends on it.

### What provides S3-compatible storage on the runtime track?

MinIO is the obvious candidate. Active Storage needs an S3-compatible endpoint, and the
`aws-sdk-s3` gem plus a `storage.yml` service is the app-side change either way.

**Why it matters:** it is one of the three app changes deploying forces, and it is the one
with no local default the way PostgreSQL has.

**When:** I-1e, when the app first needs somewhere to put an avatar that survives a redeploy.

### Shared cache: Solid Cache or Redis?

The ranked-feed cache and rate limiter are per-process memory, which breaks at two replicas.
Solid Cache rides on Postgres and adds no service; Redis is the conventional answer and will
be wanted for Sidekiq eventually anyway.

**Why it matters:** picking Solid Cache now and Redis later means doing the work twice;
picking Redis now adds a service before anything needs it.

**When:** the moment the deployment scales past one replica — during I-1e or I-1f, on the
runtime track.

---

## Delivery

### Required status checks and up-to-date branches

`main` has neither. Auto-merge cannot arm without required checks, so every merge is manual;
and since CI no longer runs on `main`, nothing re-validates a merge commit.

**Why it matters:** two branches can each pass in isolation and still break once merged, and
the release will ship it.

**When:** now. This is configuration rather than work — see N-4.2 and N-4.2a in
[`REQUIREMENTS.md`](../REQUIREMENTS.md).

**One trap when enabling them.** The checks to require are the six job names — `Detect
changes`, `Lint`, `Test`, `SAST`, `Container build, image scan and DAST`, `SonarQube` — all of
which report `skipped` rather than nothing when gated off, which satisfies a requirement.
`Trivy` is *not* a job: it is a code-scanning check created by the SARIF upload. It now reports
on every pull request, but only because the filesystem scan uploads from the SAST job, which is
never skipped. If that upload is ever removed, requiring `Trivy` would leave every docs-only
pull request waiting forever.

### Should the DAST scan fail the build?

The ZAP baseline scan runs and reports; `fail_action` is `false`.

**Why it matters:** a scan that cannot fail is a report nobody reads. Until its current
findings are triaged, though, turning it on would block every pull request on the same
pre-existing warnings.

**When:** after triaging what it currently reports.

### SonarCloud or self-hosted SonarQube?

The job is wired and skips itself without a `SONAR_TOKEN`.

**When:** whenever the quality gate is actually wanted. It blocks nothing today.

---

## Deferred by proof-of-concept scope

Not open questions so much as known gaps. Real answers are needed only if this is ever
deployed; they are recorded so the gap is known rather than forgotten. Tracked as N-5.x in
[`REQUIREMENTS.md`](../REQUIREMENTS.md).

- Password reset email has no delivery service — the flow and mailer exist, nothing sends.
- No email verification, so an account can be registered against an address its owner does not
  control.
- `RAILS_FORCE_SSL` and `RAILS_ASSUME_SSL` default to off — see N-3.11.
- No backups, and no restore has ever been tested.
- Multi-environment strategy — staging and production, or production only.
