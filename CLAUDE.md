# CLAUDE.md

Guidance for Claude Code when working in this repository.

## What this project is

A Twitter/X-style social application, built with Ruby on Rails, eventually deployed to AWS.
See `README.md` for the full plan, roadmap, and structure.

`REQUIREMENTS.md` is the checklist of what the app must do and whether it does it yet.
Update the status column there when a requirement's state actually changes.

**Current state: milestone 1 done.** The Rails app exists in `web/` and the feed works.
Nothing else is built — no auth, no follows, no jobs, no infra.

## How we work here

The project is built **incrementally, one vertical slice at a time**. This matters more than
any individual convention below:

- Do not scaffold ahead of the current milestone. If milestone 1 is the feed, do not add
  a follow graph, likes, or auth "while we're in there".
- Prefer finishing one feature end-to-end (migration → model → controller → view → specs)
  over starting several.
- When a decision is genuinely open, ask rather than guessing. Decisions are recorded in
  `README.md`; add new ones there or in `docs/` as ADRs.
- The "Open questions" list in `README.md` is a live list, not an append-only log. When work
  answers a question, delete it and move the answer into the section it belongs to.
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
- SQLite for now, PostgreSQL later. Nothing may depend on adapter-specific behaviour —
  the switch is meant to stay a single environment variable.
- Sidekiq with Redis for background jobs — decided but **not installed**. Do not add either
  until a milestone actually needs a job.
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

**Branches and pull requests**

- All work reaches the default branch through a **pull request**. Do not commit to it
  directly.
- Branch names: `feat/<short-description>`, `fix/<short-description>`, `docs/<...>`.
- Pull requests are set to auto-merge, so CI is the review gate. A green pipeline merges the
  branch — never open one expecting to fix it up afterwards.
- Run `bundle exec rspec` and `bundle exec rubocop` locally before pushing. CI failing on
  something a local run would have caught wastes a full pipeline.
- Prefer several small, self-contained commits over one large one.

## Commands

```bash
# From web/
bin/rails server             # Run the app on http://localhost:3000
bundle exec rspec            # Run all tests
bundle exec rspec spec/path  # Run one spec file
bundle exec rubocop          # Lint
bundle exec rubocop -a       # Lint and autocorrect
bundle exec brakeman         # Security static analysis
bin/rails db:migrate         # Apply migrations
bin/rails db:seed            # Sample posts for the feed
bin/rails console            # REPL

# From repo root
docker build -t twitter-clone-web web                     # Build the image
docker compose -f infra/docker/docker-compose.yml up -d   # Postgres, only when switching off SQLite
```

## Current milestone

**Milestone 1 (the feed) is done.** Milestone 2 — authentication — is next but not started.
Read the roadmap in `README.md` before starting work and keep changes inside the milestone
being worked on.

Anything outside it — follows, likes, replies, media, search, notifications — is a later
milestone. If a task seems to require one of them, say so and ask rather than expanding
scope.

## Things to leave alone

- Do not create AWS resources or write Terraform until the architecture is agreed.
- Releases publish to GHCR. Do not uncomment the ECR block in
  `.github/workflows/release.yml` until the ECR repository and the GitHub OIDC role
  actually exist.
- Do not add authentication as a side effect of another feature.
- Do not add Redis, Sidekiq, or a background job until a milestone needs one.
- Do not upgrade Ruby or Rails major versions without asking.
- Do not weaken a CI security gate to make a build pass. If a finding is genuinely not
  actionable, say so and ask.
