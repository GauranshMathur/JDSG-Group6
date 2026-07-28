# CLAUDE.md

Guidance for Claude Code when working in this repository.

## What this project is

A Twitter/X-style social application, built with Ruby on Rails, eventually deployed to AWS.
See `README.md` for the full plan, roadmap, and structure.

**Current state: documentation only.** The Rails app has not been scaffolded. Do not assume
any file exists outside of `README.md` and this file — check before referencing.

## How we work here

The project is built **incrementally, one vertical slice at a time**. This matters more than
any individual convention below:

- Do not scaffold ahead of the current milestone. If milestone 1 is the feed, do not add
  a follow graph, likes, or auth "while we're in there".
- Prefer finishing one feature end-to-end (migration → model → controller → view → specs)
  over starting several.
- When a decision is genuinely open, ask rather than guessing. Decisions are recorded in
  `README.md`; add new ones there or in `docs/` as ADRs.
- Anything infrastructure-related is a **TODO** until the AWS design is agreed. Do not write
  Terraform or create cloud resources without an explicit ask.

## Repository layout

```
web/       Rails application — all app code
infra/     Terraform, Docker Compose, deploy config
docs/      Design notes, ADRs, feature specs
.github/   CI/CD workflows
```

Rules:

- Application code goes in `web/`. Never at the repository root.
- The Rails app lives at `web/`, so internal paths are `web/app/models/`, `web/config/`,
  `web/spec/`. Watch for this — a path like `app/models/post.rb` is wrong here.
- Infra and deployment code goes in `infra/`. Never inside `web/`, with the exception of
  `web/Dockerfile`, which stays next to the app it builds.
- Folder names: lowercase, hyphenated.

## Stack (decided)

- Ruby on Rails 8, full-stack, **not** API-only.
- Hotwire — Turbo and Stimulus. No React/Vue/SPA. Reach for a Turbo Frame or Stream before
  reaching for JavaScript.
- PostgreSQL.
- Sidekiq with Redis for background jobs.
- RSpec + FactoryBot for tests. Not Minitest.
- RuboCop with `rubocop-rails-omakase`.
- Propshaft + importmap. No Node build step, no bundler/webpack.

Do not introduce a new framework, database, job runner, or test library without asking.

## Conventions

**Ruby / Rails**

- Follow Rails conventions and idioms; prefer boring, conventional Rails over cleverness.
- Fat models are fine to a point — extract to a plain-old-Ruby service object in
  `web/app/services/` when a model method grows past its responsibility.
- Every schema change is a migration. Never edit `db/schema.rb` by hand.
- Add database indexes for foreign keys and any column used for timeline ordering.
- Use strong parameters, and scope queries through associations rather than
  `Model.find(params[:id])` on user-owned records.

**Views**

- ERB, not Haml or Slim.
- Extract repeated markup to partials early — the feed will render the same post markup in
  several places.
- Use Turbo Streams for anything that updates in place.

**Testing**

- Model specs for validations and scopes; request specs for controller behaviour.
- Every feature slice ships with specs. A PR that adds behaviour with no test is incomplete.
- No system/browser specs until there is enough UI to justify the maintenance cost.

**Commits**

- [Conventional Commits](https://www.conventionalcommits.org/) — the semantic version bump
  is derived from these, so the prefix is functional, not decorative.
- Format: `type(scope): subject`, e.g. `feat(feed): add cursor pagination to timeline`.
- Types: `feat`, `fix`, `docs`, `refactor`, `test`, `chore`, `ci`, `perf`.
- Breaking changes: `feat!:` or a `BREAKING CHANGE:` footer.
- Subject in the imperative mood, lowercase, no trailing period.

**Branches**

- `main` is the default branch and should always be deployable.
- Feature branches: `feat/<short-description>`, fixes: `fix/<short-description>`.
- Never commit directly to `main`.

## Commands

> Placeholders — fill these in during milestone 0, once the app exists.

```bash
# From web/
bin/dev                      # Run the app
bundle exec rspec            # Run all tests
bundle exec rspec spec/path  # Run one spec file
bundle exec rubocop -a       # Lint and autocorrect
bin/rails db:migrate         # Apply migrations
bin/rails console            # REPL

# From repo root
docker compose -f infra/docker/docker-compose.yml up -d   # Postgres + Redis
```

## Current milestone

**Milestone 1 — the feed.** Scope is defined in `README.md`; read it before starting work
and keep changes inside that scope.

Anything not in that scope — auth, follows, likes, replies, media, search, notifications —
is a later milestone. If a task seems to require one of them, say so and ask rather than
expanding scope.

## Things to leave alone

- Do not create AWS resources or write Terraform until the architecture is agreed.
- Do not add CI/CD workflow files until the pipeline design in `README.md` is confirmed.
- Do not add authentication as a side effect of another feature.
- Do not upgrade Ruby or Rails major versions without asking.
