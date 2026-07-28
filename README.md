# JDSG-Group6 — Twitter Clone

A Twitter/X-style social application built with Ruby on Rails, intended to be deployed on AWS.

> **Status: milestone 1 built.** The Rails app is scaffolded in `web/` and the feed works
> end-to-end. Authentication, follows and everything else remain unbuilt — see the
> [roadmap](#roadmap). Cloud infrastructure is still a TODO.

---

## Table of contents

- [Goals](#goals)
- [Tech stack](#tech-stack)
- [Repository layout](#repository-layout)
- [Database](#database)
- [Roadmap](#roadmap)
- [Milestone 1 — The Feed](#milestone-1--the-feed)
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
| Containerization | Docker | Multi-stage build, image published by CI |
| IaC | Terraform (planned) | TODO — see [Infrastructure](#infrastructure) |
| CI/CD | GitHub Actions | Lint, test, SAST, DAST, image scan — see [CI/CD](#cicd) |

**Why Sidekiq over Solid Queue:** timeline fan-out is the workload that eventually dictates
job throughput. Sidekiq is the safer long-term bet even though it means running Redis
(ElastiCache on AWS). Neither is installed yet — the decision is recorded, not acted on.

**Why SQLite first:** the feed has no workload that Postgres serves better, and SQLite means
a checkout boots with no services running. The switch is a single environment variable, so
the cost of deferring it is close to zero.

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
| 2 | Authentication — sign up, sign in, sessions | Not started (next) |
| 3 | Profiles — user pages, bio, avatar | Not started |
| 4 | Follows — follow/unfollow, following-only feed | Not started |
| 5 | Engagement — likes, reposts, replies | Not started |
| 6 | Media — image uploads on posts | Not started |
| 7 | Search and hashtags | Not started |
| 8 | Notifications | Not started |
| 9 | AWS deployment — Terraform, ECS/Fargate, RDS, ElastiCache | TODO |

Milestones 0 and 1 were built together, since a feed needs an app to live in.

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

Building and running the container, from the repository root:

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

### `ci.yml` — every pull request

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

1. Derive the next semantic version from the Conventional Commits since the last tag.
2. Stop here if nothing warrants a release.
3. Create the git tag and a GitHub release with generated notes.
4. Build the image and tag it with the version, `sha-<commit>`, and `latest`.
5. **Push to Amazon ECR — commented out.** The AWS steps are written and inert. Uncomment
   them once the ECR repository and the GitHub OIDC role exist; enabling them before that
   only produces red builds.

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
- Observability — CloudWatch logs and metrics; error tracking TBD.
- State — Terraform remote state in S3 with DynamoDB locking.

No AWS resources will be created until this is designed and agreed.

## Open questions

Live list. A question gets deleted once it is answered, and the answer moves into whichever
section it belongs to — this is not an append-only log.

**Product — the feed**

- Should a post be editable after publishing? If so, for how long, and is an edit history
  shown? Editing interacts with caching and with any future fan-out-on-write timeline.
- Should duplicate posts be prevented — for example by hashing the body and rejecting a
  repeat from the same author within some window? Worth deciding what "duplicate" means: the
  exact same text, or normalised for whitespace and case.
- Should posts carry images? If so: what formats and size ceiling, are they re-encoded and
  compressed on upload, what quality/size trade-off is acceptable, and are thumbnails
  generated separately from the full-size original? This is the first requirement that needs
  both S3 and background jobs, so it pulls two deferred decisions forward.
- Should hashtags be parsed out of the body and become browsable, so a tag resolves to a
  filtered feed? That implies a tags table and a join, not just a `LIKE` search.

**Delivery and infrastructure**

- Container registry — ECR, or GitHub Container Registry for simplicity during development?
- Multi-environment strategy — `staging` and `production`, or production only at first?
- Does the SonarQube scan run against SonarCloud or a self-hosted server?
