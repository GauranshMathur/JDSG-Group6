# JDSG-Group6 — Twitter Clone

A Twitter/X-style social application built with Ruby on Rails, intended to be deployed on AWS.

> **Status: milestone 1 built.** The Rails app is scaffolded in `web/` and the feed works
> end-to-end. Authentication, follows and everything else remain unbuilt — see the
> [roadmap](#roadmap). Cloud infrastructure is still a TODO.

---

## Table of contents

- [Goals](#goals)
- [Tech stack](#tech-stack)
- [Design principles](#design-principles)
- [Repository layout](#repository-layout)
- [Database](#database)
- [Roadmap](#roadmap)
- [Milestone 1 — The Feed](#milestone-1--the-feed)
- [Milestones 2–6 — the plan](#milestones-26--the-plan)
- [Getting started](#getting-started)
- [Versioning and releases](#versioning-and-releases)
- [CI/CD](#cicd)
- [Infrastructure](#infrastructure)
- [Open questions](#open-questions)

---

## Goals

Build a working Twitter clone one vertical slice at a time. Each slice should be usable
end-to-end (model → controller → view → tests) before the next one starts.

The near-term goal is **the feed**: a user can post, and see posts, in a timeline. Auth,
follows, likes, replies and everything else are sequenced after that — see the
[roadmap](#roadmap).

Cloud architecture is deliberately deferred. `infra/` exists as a placeholder so that
infra and app code live in one repository from day one, but the AWS design is a **TODO**.

## Tech stack

| Layer | Choice | Notes |
| --- | --- | --- |
| Framework | Ruby on Rails 8 (full-stack) | Server-rendered, not API-only |
| Frontend | Hotwire (Turbo + Stimulus) | No separate SPA; Turbo Streams for live feed updates |
| Language | Ruby 3.3+ | |
| Database | SQLite now, PostgreSQL later | Switchable through `DATABASE_URL` — see [Database](#database) |
| Background jobs | Sidekiq + Redis (deferred) | Not installed; nothing needs jobs yet |
| Cache / sessions | Rails defaults | Redis arrives with Sidekiq |
| Asset pipeline | Propshaft + importmap | Rails 8 defaults |
| Testing | RSpec + FactoryBot | |
| Linting | RuboCop (`rubocop-rails-omakase`) | |
| Containerization | Docker | Multi-stage build, image published to GHCR by CI |
| IaC | Terraform (planned) | TODO — see [Infrastructure](#infrastructure) |
| CI/CD | GitHub Actions | Lint, test, SAST, DAST, image scan — see [CI/CD](#cicd) |

**Why Sidekiq over Solid Queue:** timeline fan-out is the workload that eventually dictates
job throughput. Sidekiq is the safer long-term bet even though it means running Redis
(ElastiCache on AWS). Neither is installed yet — the decision is recorded, not acted on.

**Why SQLite first:** the feed has no workload that Postgres serves better, and SQLite means
a checkout boots with no services running. The switch is a single environment variable, so
the cost of deferring it is close to zero.

## Design principles

### The 90-9-1 rule

Online communities tend to split roughly 90% lurkers, 9% occasional contributors, 1% heavy
creators. The app is built for that distribution rather than for the 1% who are easiest to
imagine:

- **Reading never requires an account.** The feed, profiles and hashtag pages are all public.
  Requiring sign-up to read would wall off the group that makes up most of the traffic.
- **Signing in is required only to write.** Authentication guards `create`, `update` and
  `destroy` — never `index` or `show`.
- **Posting stays cheap.** The composer is on the feed itself, not behind a separate page, so
  the occasional contributor is never more than one click from posting.
- **Power-user tooling comes last, not first.** Managing your own posts in bulk, drafts and
  scheduling serve the 1%; they are deliberately absent until the other two groups are served.

The practical consequence is a **public global feed plus a personal profile**, not a private
per-user feed. "Your feed" means the posts you wrote and can manage, not a separate timeline
only you can see. A personalised timeline needs the follow graph and arrives in milestone 7.

### Ownership over visibility

Everything is readable by everyone; only *writes* are restricted. A post can be edited or
deleted by its author and nobody else. This is enforced by scoping queries through the
association — `Current.user.posts.find(params[:id])` — rather than by fetching a record and
then checking who owns it, so a missing check cannot silently expose someone else's row.

## Repository layout

Two top-level folders, one for the application and one for infrastructure:

```
JDSG-Group6/
├── web/                  # The Rails application (all app code lives here)
│   ├── app/
│   ├── config/
│   ├── db/
│   ├── spec/
│   ├── Dockerfile
│   └── Gemfile
├── infra/                # Infrastructure as code and deployment config
│   ├── terraform/        # AWS resources (TODO)
│   ├── docker/           # Compose files for local dev
│   └── README.md
├── .github/
│   └── workflows/        # CI/CD pipelines
├── docs/                 # Design notes, ADRs, feature specs
├── CLAUDE.md             # Working agreements for AI-assisted development
├── REQUIREMENTS.md       # What the app must do, and whether it does it yet
└── README.md
```

Naming rules:

- Folder names are lowercase and hyphenated (`infra/terraform`, not `infra/Terraform`).
- The Rails app is `web/`, not `app/`, so that internal Rails paths read as
  `web/app/models/post.rb` rather than the confusing `app/app/models/post.rb`.
- Everything that is not application code (Terraform, Compose, deploy scripts, runbooks)
  belongs under `infra/`.

## Database

The app runs on **SQLite** by default, so a fresh checkout boots with no services. Nothing in
the application code knows which database it is talking to: migrations use standard Rails
column types and every query goes through Active Record.

**Switching to PostgreSQL:**

```bash
# 1. Install the pg gem (kept out of the default bundle so plain installs need no libpq)
cd web && bundle config set --local with postgres && bundle install

# 2. Start Postgres
docker compose -f infra/docker/docker-compose.yml up -d

# 3. Point the app at it
export DATABASE_URL=postgres://twitter_clone:twitter_clone@localhost:5432/twitter_clone_development

# 4. Create the schema
bin/rails db:prepare
```

`DATABASE_URL` overrides every setting in `config/database.yml`, adapter included, so no file
needs editing. Unset it to go back to SQLite.

Production is expected to run on PostgreSQL (RDS) configured entirely through `DATABASE_URL`.

## Roadmap

Ordered. Each milestone is a shippable slice; we plan the details of a milestone when we
reach it, not before.

| # | Milestone | Status |
| --- | --- | --- |
| 0 | Repo scaffolding — Rails app in `web/`, Docker, CI | **Done** |
| 1 | **The feed** — post creation and timeline rendering | **Done** |
| 2 | **Authentication** — sign up, sign in, sign out, sessions | Next |
| 3 | **Post ownership and CRUD** — posts belong to users; edit and delete your own | Planned |
| 4 | **Navigation and profiles** — sidebar shell, profile pages, edit your profile | Planned |
| 5 | **Hashtags** — parsed from post bodies, browsable tag pages | Planned |
| 6 | **Search** — find posts and people from the sidebar | Planned |
| 7 | Follows — follow/unfollow, following-only feed | Later |
| 8 | Engagement — likes, reposts, replies | Later |
| 9 | Media — image uploads on posts | Later |
| 10 | Notifications | Later |
| 11 | AWS deployment — Terraform, ECS/Fargate, RDS, ElastiCache | TODO |

Milestones 0 and 1 were built together, since a feed needs an app to live in.

Milestones 2–6 are the current block of work: authentication, full CRUD on posts, profiles,
hashtags and search. They are listed separately rather than as one milestone because each is
independently shippable, and because a single change touching auth, ownership, navigation,
tagging and search at once is not reviewable.

## Milestone 1 — The Feed

**Built.** Per-requirement status lives in `REQUIREMENTS.md` (F-1.x).

What shipped:

- `Post` — body (1–280 chars) and author name (≤50 chars, defaulting to `anonymous`).
- A composer form, with validation errors rendered inline.
- A reverse-chronological timeline, 20 posts per page.
- Turbo Stream response on create, so a new post is prepended without a page reload.
- Keyset (cursor) pagination with a "Load older posts" link.
- 27 model and request specs.

**Deliberately not built**

- Follow graph and personalised ranking — this is a global timeline.
- Likes, replies, reposts, media, mentions, hashtags.
- Authentication. Authorship is a free-text name on the post; milestone 2 replaces it with a
  `belongs_to :user` association.

**Design decisions made along the way**

- *Timeline read model* — query-on-read. Fan-out-on-write is deferred until a follow graph
  exists to fan out to (milestone 4).
- *Pagination* — keyset rather than offset. An offset page shifts as new posts arrive at the
  head of the timeline, which repeats and skips rows; a cursor of `(created_at, id)` does not.
- *Ordering tie-break* — `created_at DESC, id DESC`. Ordering on `created_at` alone is not a
  total order, so posts written in the same tick could swap places between requests and be
  paginated past. The index matches the sort, so it serves both.

## Milestones 2–6 — the plan

Written before any of it is built, so the shape is agreed rather than discovered. Each
milestone is a pull request or a small series of them, and each ends with the app working.

Requirement IDs referenced here are defined in `REQUIREMENTS.md`.

### Milestone 2 — Authentication (F-2.x)

Rails 8 ships an authentication generator — `bin/rails generate authentication` — which
produces a `User` model, a `Session` model, sign-in, sign-out and password reset. No gem, no
Devise. That matches the "boring, conventional Rails" rule, and it is one fewer dependency to
inherit. See `docs/adr/0001-authentication.md`.

- `User` — email address and `has_secure_password`, unique case-insensitive email.
- Registration, sign in, sign out. Sessions in a signed cookie backed by a `Session` record,
  so sign-out can revoke server-side rather than only clearing the browser.
- `Current.user` for the request-scoped current user.
- Reading stays public. `require_authentication` guards writes only.

Password reset ships with the generator and needs a mailer. Nothing sends real email yet, so
delivery stays in `letter_opener`-style development mode and production email is an open
question below.

### Milestone 3 — Post ownership and CRUD (F-3.x)

The slice that makes posts *belong* to someone.

- `posts.user_id`, indexed, not null, `belongs_to :user`.
- The existing `author_name` column is removed. Every post is attributed through the
  association instead.
- Full CRUD: create, read, update, destroy. Edit and delete are restricted to the author.
- Authorization by scoping, per the principle above.
- Composer requires sign-in; signed-out visitors see a prompt instead of the form.

**The existing posts have no user.** The seeded rows are development data, so the migration
backfills them to a single placeholder account rather than inventing a nullable column that
would then need defending forever. This is only safe because nothing real is deployed — see
the open question about it below.

### Milestone 4 — Navigation and profiles (F-4.x)

- A sidebar as the application shell: Feed, Profile, Sign in/out — Search joins it in
  milestone 6. Rendered from a layout partial, not duplicated per page.
- `/@username` style public profile pages listing that user's posts.
- `username` added to `User`: unique, case-insensitive, URL-safe.
- Edit your own profile — display name and bio. Avatars need file storage, so they wait for
  the media milestone.

### Milestone 5 — Hashtags (F-5.x)

- `#tag` parsed out of the post body on save.
- `Tag` and a `PostTag` join table, rather than `LIKE '%#tag%'` — a join gives an indexed
  lookup, exact matching, and a place to hang tag metadata later. A `LIKE` scan cannot
  distinguish `#rails` from `#railsconf` without more escaping than it is worth.
- Hashtags render as links in post bodies.
- `/tags/:name` lists posts carrying that tag, reusing the existing timeline and cursor
  pagination.
- Tags are normalised to lower case on write so `#Rails` and `#rails` are one tag.

### Milestone 6 — Search (F-6.x)

- A search field in the sidebar, covering post bodies and usernames.
- Results reuse the timeline partial and cursor pagination.

**Search is the first feature where the database actually shows through.** PostgreSQL
full-text search and SQLite FTS5 are different, adapter-specific mechanisms, and N-1.2 says
nothing may depend on adapter-specific behaviour. So this milestone ships a plain
`LIKE`-based search that works identically on both, documented as deliberately basic. Proper
ranked full-text search is a later, separate decision — taken once the app is actually on
PostgreSQL, not before.

### Explicitly not in this block

Follows and a following-only timeline, likes, reposts, replies, media and avatars,
notifications, moderation and rate limiting. Each is a later milestone; none should be
started "while we're in there".

## Getting started

```bash
cd web
bundle install
bin/rails db:prepare
bin/rails db:seed        # optional — a handful of sample posts
bin/rails server         # http://localhost:3000
```

Everyday commands, all from `web/`:

```bash
bundle exec rspec                  # Run all tests
bundle exec rspec spec/models      # Run one directory or file
bundle exec rubocop                # Lint
bundle exec rubocop -a             # Lint and autocorrect
bundle exec brakeman               # Security static analysis
bin/rails db:migrate               # Apply migrations
bin/rails console                  # REPL
```

Running the published image:

```bash
docker run --rm -p 3000:80 \
  -e SECRET_KEY_BASE=$(openssl rand -hex 64) \
  -v twitter-clone-data:/rails/storage \
  ghcr.io/gauranshmathur/twitter-clone-web:latest
```

Then open <http://localhost:3000>. The port mapping is `3000:80` because the container
listens on 80. `SECRET_KEY_BASE` is required — the image runs in production mode and will
not boot without one. The volume keeps the SQLite database between runs; drop it and posts
disappear when the container exits.

**SSL is off by default**, which is what makes the above work over plain HTTP. Set
`RAILS_ASSUME_SSL=true` and `RAILS_FORCE_SSL=true` when the app is deployed behind TLS —
see [Infrastructure](#infrastructure).

Or build it yourself, from the repository root:

```bash
docker build -t twitter-clone-web web
docker run --rm -p 3000:80 -e SECRET_KEY_BASE=$(openssl rand -hex 64) twitter-clone-web
```

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

## CI/CD

GitHub Actions, in two workflows.

### `ci.yml` — pull requests only

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
  does. Full results are also uploaded to GitHub code scanning.
- **`ignore-unfixed` is on**, so only findings with an available fix count. A vulnerability
  with no upstream patch cannot be actioned by any change in this repository; failing on it
  would only teach everyone to ignore the gate.
- **DAST reports but does not fail.** A baseline scan of a fresh Rails app flags
  header-level warnings (CSP, permissions policy) that are real but out of scope for
  milestone 1. Once triaged, flip `fail_action` to `true` so regressions block.

The container job is also the proof that the image works: it starts the built image and
polls `/up` until the app answers, so a broken image fails CI rather than a deployment.

### `release.yml` — after merge to the default branch

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

### Configuring SonarQube

The SonarQube job checks for a `SONAR_TOKEN` secret and skips the scan when it is absent, so
it does not block pull requests before the server exists. Add `SONAR_TOKEN` (and
`SONAR_HOST_URL` for a self-hosted server) to repository secrets to turn it on. Project
settings live in `sonar-project.properties`.

## Infrastructure

**Everything in this section is a TODO.** `infra/` is a placeholder so that infra lives
beside the app from the start.

Sketch of what will need to be decided:

- Compute — ECS on Fargate vs. EC2 vs. App Runner.
- Database — RDS for PostgreSQL, instance sizing, Multi-AZ.
- Cache and jobs — ElastiCache for Redis, Sidekiq worker service.
- Networking — VPC, subnets, security groups, ALB.
- Storage — S3 for user-uploaded media (milestone 6).
- Secrets — Secrets Manager or SSM Parameter Store.
- **TLS — set `RAILS_ASSUME_SSL=true` and `RAILS_FORCE_SSL=true` on the deployed service.**
  They default to off so the image runs over plain HTTP locally, which means a deployment
  that forgets them gets no HSTS, no https redirect and non-secure session cookies.
  Tracked as N-3.11 in `REQUIREMENTS.md`.
- Observability — CloudWatch logs and metrics; error tracking TBD.
- State — Terraform remote state in S3 with DynamoDB locking.

No AWS resources will be created until this is designed and agreed.

## Open questions

Live list. A question gets deleted once it is answered, and the answer moves into whichever
section it belongs to — this is not an append-only log.

**Product**

- Should an edit be visible as an edit — an "edited" marker, or a history? Milestone 3 allows
  editing; it does not yet say whether editing is *honest*. A post that can change silently
  after people have read it is a different thing from one that shows it changed.
- Is there a time limit on editing, or can a post be rewritten a year later?
- Should duplicate posts be prevented — for example by hashing the body and rejecting a
  repeat from the same author within some window? Worth deciding what "duplicate" means: the
  exact same text, or normalised for whitespace and case.
- Should posts carry images? If so: what formats and size ceiling, are they re-encoded and
  compressed on upload, what quality/size trade-off is acceptable, and are thumbnails
  generated separately from the full-size original? This is the first requirement that needs
  both S3 and background jobs, so it pulls two deferred decisions forward.
- What happens to someone's posts when they delete their account — cascade, or keep them
  attributed to a deleted user? Account deletion is deliberately out of scope for now, but
  the answer shapes the schema before it is needed.

**Authentication**

- How does password reset actually send email in production? The Rails generator ships the
  flow and a mailer, but nothing is wired to a delivery service. Until that is answered,
  password reset works in development and silently does nothing in production.
- Is email verification required before a new account can post? Without it, anyone can sign
  up as any address. Against that: it is friction on exactly the 9% we want to convert.
- Is there rate limiting on sign-in attempts? Rails 8 ships `rate_limit`, so this is cheap to
  add, but it is a decision rather than a default.

**Data**

- The milestone 3 migration backfills existing posts to a placeholder user, which is only
  acceptable because nothing real is deployed. Confirm that before it runs — once there is
  production data, a backfill that invents ownership is not reversible.
- Should `username` be changeable after registration? If yes, profile URLs are not stable and
  old links break unless historical usernames are retained.

**Delivery and infrastructure**

- Multi-environment strategy — `staging` and `production`, or production only at first?
- Does the SonarQube scan run against SonarCloud or a self-hosted server?
- Ranked full-text search, once the app is on PostgreSQL — see milestone 6.
