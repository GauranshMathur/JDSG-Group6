# JDSG-Group6 — Twitter Clone

A Twitter/X-style social application built with Ruby on Rails, intended to be deployed on AWS.

> **Status: planning / pre-scaffold.** Nothing is built yet. This repository currently
> contains documentation only. The structure and decisions below are the agreed plan; each
> piece gets built incrementally, starting with the feed.

---

## Table of contents

- [Goals](#goals)
- [Tech stack](#tech-stack)
- [Repository layout](#repository-layout)
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
| Database | PostgreSQL | RDS on AWS (TODO) |
| Background jobs | Sidekiq + Redis | Chosen over Solid Queue for high-volume fan-out later |
| Cache / sessions | Redis | Shared with Sidekiq initially |
| Asset pipeline | Propshaft + importmap | Rails 8 defaults |
| Testing | RSpec + FactoryBot | |
| Linting | RuboCop (`rubocop-rails-omakase`) | |
| Containerization | Docker | Multi-stage build, image published by CI |
| IaC | Terraform (planned) | TODO — see [Infrastructure](#infrastructure) |
| CI/CD | GitHub Actions | TODO — see [CI/CD](#cicd) |

**Why Sidekiq over Solid Queue:** timeline fan-out is the workload that eventually dictates
job throughput. Sidekiq is the safer long-term bet even though it means running Redis
(ElastiCache on AWS) from the start.

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
└── README.md
```

Naming rules:

- Folder names are lowercase and hyphenated (`infra/terraform`, not `infra/Terraform`).
- The Rails app is `web/`, not `app/`, so that internal Rails paths read as
  `web/app/models/post.rb` rather than the confusing `app/app/models/post.rb`.
- Everything that is not application code (Terraform, Compose, deploy scripts, runbooks)
  belongs under `infra/`.

## Roadmap

Ordered. Each milestone is a shippable slice; we plan the details of a milestone when we
reach it, not before.

| # | Milestone | Status |
| --- | --- | --- |
| 0 | Repo scaffolding — Rails app in `web/`, Docker, CI skeleton | Not started |
| 1 | **The feed** — post creation and timeline rendering | Not started (next) |
| 2 | Authentication — sign up, sign in, sessions | Not started |
| 3 | Profiles — user pages, bio, avatar | Not started |
| 4 | Follows — follow/unfollow, following-only feed | Not started |
| 5 | Engagement — likes, reposts, replies | Not started |
| 6 | Media — image uploads on posts | Not started |
| 7 | Search and hashtags | Not started |
| 8 | Notifications | Not started |
| 9 | AWS deployment — Terraform, ECS/Fargate, RDS, ElastiCache | TODO |

Milestone 0 and 1 will likely be built together, since a feed needs an app to live in.

## Milestone 1 — The Feed

The current focus. Scope is intentionally small; anything not listed is out of scope and
gets picked up by a later milestone.

**In scope**

- A `Post` model (body text, author, timestamps) with validation on length and presence.
- A composer form to create a post.
- A reverse-chronological timeline of all posts.
- Turbo Stream updates so a new post appears without a full page reload.
- Pagination or infinite scroll on the timeline.
- Request and model specs covering the above.

**Out of scope for now**

- Follow graph and personalized ranking — milestone 1 shows a global timeline.
- Likes, replies, reposts, media, mentions, hashtags.
- Real authentication. Posts are attributed to a placeholder/seeded user until milestone 2.

**Open design points to settle before coding**

- Timeline read model: query-on-read now, fan-out-on-write later (write path deferred until
  the follow graph exists in milestone 4).
- Pagination strategy: cursor-based (keyset) is preferred over offset for a timeline.

## Getting started

> Not yet applicable — the Rails app has not been scaffolded. This section will be filled in
> during milestone 0 with the real commands.

The intended local workflow:

```bash
# Bring up Postgres and Redis
docker compose -f infra/docker/docker-compose.yml up -d

# Install dependencies and prepare the database
cd web
bundle install
bin/rails db:prepare

# Run the app
bin/dev
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
- Releases are git tags of the form `v0.3.1`.
- `CHANGELOG.md` is generated from commit history, not hand-edited.

**TODO:** pick the release tooling — GitHub Actions with
[`release-please`](https://github.com/googleapis/release-please) is the leading candidate.

## CI/CD

GitHub Actions. Planned pipelines, none implemented yet:

**On every pull request**

1. Lint — RuboCop.
2. Security — `bundle audit` and Brakeman.
3. Test — RSpec against Postgres and Redis service containers.
4. Build — Docker image build (validation only, not published).

**On merge to `main`**

1. All of the above.
2. Determine the next semantic version from the commit history.
3. Build the Docker image and tag it with `<version>`, the commit SHA, and `latest`.
4. Push to the registry.
5. Create the git tag and GitHub release with generated changelog notes.

**Registry:** Amazon ECR (assumed, to be confirmed alongside the AWS design).

**Image tagging:** every image carries an immutable `sha-<commit>` tag in addition to the
semantic version, so a deployment can always be pinned to an exact build.

**TODO:** deployment stage — nothing deploys anywhere until the AWS architecture is decided.

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

- Which release automation tool for semantic versioning (`release-please` vs. alternatives)?
- Container registry — ECR, or GitHub Container Registry for simplicity during development?
- Multi-environment strategy — `staging` and `production`, or production only at first?
- Ruby version pin and Rails version pin — set during milestone 0.
