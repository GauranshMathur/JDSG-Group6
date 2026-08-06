# JDSG-Group6 — Twitter Clone

A Twitter/X-style social application built with Ruby on Rails.

**This is a proof of concept**, built to exercise the stack and the delivery pipeline end to
end. It is not a product and is not deployed anywhere. Where a decision trades production
robustness for getting something working and understandable, it takes the second — those
trades are called out where they are made rather than left implicit.

> **Status: all app milestones shipped (1–7, including 5.5 and 6.5).** The feed is ranked
> and cached, accounts exist with profiles and avatars, posts carry images, and engagement —
> likes, reposts, replies, hashtags — and search all work. The app is released as a container
> image. Reading needs no account; writing does. What remains is infrastructure (I-1) and
> anything the scope grows to next. See the [roadmap](docs/roadmap.md).

---

## Documentation

This README covers what the project is and how to run it. Everything else lives in `docs/`,
so that each document can be read on its own and changed without rewriting the rest.

| Document | What is in it |
| --- | --- |
| [Requirements](REQUIREMENTS.md) | Numbered, testable requirements and whether each is met |
| [Roadmap](docs/roadmap.md) | Milestones and what shipped in each — all app milestones are done |
| [Design principles](docs/design-principles.md) | The 90-9-1 rule, and ownership over visibility |
| [Database](docs/database.md) | SQLite today, and the switch to PostgreSQL |
| [Latency](docs/latency.md) | How the app should degrade when the database is slow — planned, not built |
| [CI/CD](docs/ci-cd.md) | The pipeline, versioning, and how releases are cut |
| [Open questions](docs/open-questions.md) | Decisions not yet taken — a live list, pruned as they are answered |
| [Decision records](docs/adr/) | Why a choice was made, and what it cost |

Contributor conventions live in [`CLAUDE.md`](CLAUDE.md) — layout rules, commit format,
testing expectations and the things not to touch.

## Infrastructure

How this application is deployed lives in its own repository:
**[JDSG-Group6-infra](https://github.com/GauranshMathur/JDSG-Group6-infra)** — the enterprise AWS reference design, realized entirely
locally, with the Terraform and Kubernetes manifests that stand it up.

This repository does not describe its own deployment. The one thing that crosses the
boundary is the container image: released here to GHCR, pulled there by the cluster.

## Tech stack

| Layer | Choice | Notes |
| --- | --- | --- |
| Framework | Ruby on Rails 8 (full-stack) | Server-rendered, not API-only |
| Frontend | Hotwire (Turbo + Stimulus) | No separate SPA; Turbo Streams for live feed updates |
| Language | Ruby 3.3+ | |
| Database | SQLite now, PostgreSQL later | Switchable through `DATABASE_URL` — see [database notes](docs/database.md) |
| Background jobs | Sidekiq + Redis (deferred) | Not installed; nothing needs jobs yet |
| Cache / sessions | Rails defaults | Redis arrives with Sidekiq |
| Asset pipeline | Propshaft + importmap | Rails 8 defaults |
| Testing | RSpec + FactoryBot | |
| Linting | RuboCop (`rubocop-rails-omakase`) | |
| Containerization | Docker | Multi-stage build, image published to GHCR by CI |
| CI/CD | GitHub Actions | Lint, test, SAST, DAST, image scan — see [CI/CD](docs/ci-cd.md) |

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
├── .github/
│   └── workflows/        # CI/CD pipelines
├── docs/                 # Everything that is not code
│   ├── roadmap.md
│   ├── design-principles.md
│   ├── database.md
│   ├── ci-cd.md
│   ├── open-questions.md
│   └── adr/              # Decision records — why, and what it cost
├── CLAUDE.md             # Working agreements for AI-assisted development
├── REQUIREMENTS.md       # What the app must do, and whether it does it yet
└── README.md             # What this is, and how to run it
```

Naming rules:

- Folder names are lowercase and hyphenated.
- The Rails app is `web/`, not `app/`, so that internal Rails paths read as
  `web/app/models/post.rb` rather than the confusing `app/app/models/post.rb`.
- Everything that is not application code — Terraform, Compose, deploy scripts, runbooks —
  belongs in [JDSG-Group6-infra](https://github.com/GauranshMathur/JDSG-Group6-infra), not here.
- Prose belongs in `docs/`, not in the README. The README says what the project is and how to
  run it; anything longer earns its own file so it can be read and changed on its own.
- A decision with a trade-off worth remembering gets an ADR in `docs/adr/`. A decision with
  no real alternative is just a line in the document it affects.

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
see the [infrastructure repository](https://github.com/GauranshMathur/JDSG-Group6-infra).

Or build it yourself, from the repository root:

```bash
docker build -t twitter-clone-web web
docker run --rm -p 3000:80 -e SECRET_KEY_BASE=$(openssl rand -hex 64) twitter-clone-web
```
