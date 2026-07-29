# Requirements

What the application must do, and the constraints it must do it under. Scope and sequencing
live in [`docs/roadmap.md`](docs/roadmap.md); this file is the checklist that says whether a
milestone is actually finished. Decisions and their costs are in
[`docs/adr/`](docs/adr/); questions not yet decided are in
[`docs/open-questions.md`](docs/open-questions.md).

Each requirement has an ID so specs, commits and issues can point at it.

Status: **Met** — implemented and covered by tests. **Partial** — implemented but
incomplete. **Planned** — agreed, not built. **Open** — not yet decided. **Deferred** —
knowingly not done, because this is a proof of concept and nothing is deployed.

A **Deferred** row is not a to-do. It is a gap recorded so that nobody mistakes the app for
production-ready, and so the work is visible if it ever is deployed.

---

## 1. Functional requirements

### 1.1 Feed (milestone 1)

| ID | Requirement | Status |
| --- | --- | --- |
| F-1.1 | A visitor can write a post from a composer on the feed page | Met |
| F-1.2 | A post has a body of 1–280 characters | Met |
| F-1.3 | A post carries an author name of at most 50 characters, defaulting to `anonymous` when left blank | Met — superseded by F-3.1 in milestone 3, which replaces the free-text name with a real account |
| F-1.4 | The feed lists posts newest first | Met |
| F-1.5 | Ordering is stable and total — posts sharing a timestamp never reorder between requests | Met |
| F-1.6 | A new post appears at the top of the timeline without a full page reload | Met |
| F-1.7 | The feed loads at most 20 posts per page | Met |
| F-1.8 | Older posts are reachable through a cursor, and no post is repeated or skipped as new posts arrive | Met |
| F-1.9 | An invalid post re-renders the composer with its errors and leaves the timeline intact | Met |
| F-1.10 | An empty timeline shows an empty state rather than a blank page | Met |

### 1.2 Authentication (milestone 2)

| ID | Requirement | Status |
| --- | --- | --- |
| F-2.1 | A visitor can register with an email address and password | Met |
| F-2.2 | Email addresses are unique, case-insensitively | Met — addresses are normalised to lower case on write, so the plain unique index enforces it without an adapter-specific functional index |
| F-2.3 | A registered user can sign in and sign out | Met |
| F-2.4 | Signing out revokes the session server-side, not only in the browser | Met — `terminate_session` destroys the `Session` row |
| F-2.5 | Reading the feed, profiles and tag pages never requires an account | Met for the feed; profiles and tag pages do not exist yet |
| F-2.6 | Creating, editing and deleting require a signed-in user | Met for create; edit and delete arrive with milestone 3 |
| F-2.7 | A user can reset a forgotten password | Met — against the development mailer only; see N-5.1 |

### 1.3 Post ownership and CRUD (milestone 3)

| ID | Requirement | Status |
| --- | --- | --- |
| F-3.1 | Every post belongs to a user account | Planned |
| F-3.2 | A user can edit their own post | Planned |
| F-3.3 | A user can delete their own post | Planned |
| F-3.4 | A user cannot edit or delete anyone else's post | Planned |
| F-3.5 | Authorisation is enforced by scoping through the association, not by a check after loading | Planned |
| F-3.6 | A signed-out visitor sees a prompt to sign in where the composer would be | Met — arrived with milestone 2, since guarding `create` without it would have shown a form that only bounced the visitor to sign in |

### 1.4 Navigation and profiles (milestone 4)

| ID | Requirement | Status |
| --- | --- | --- |
| F-4.1 | A sidebar provides navigation between the feed, the user's profile, and signing in or out | Planned |
| F-4.2 | Each user has a unique, case-insensitive, URL-safe username | Planned |
| F-4.3 | A public profile page lists that user's posts, newest first | Planned |
| F-4.4 | A user can edit their own display name and bio | Planned |
| F-4.5 | A user cannot edit anyone else's profile | Planned |

### 1.5 Hashtags (milestone 5)

| ID | Requirement | Status |
| --- | --- | --- |
| F-5.1 | Hashtags are parsed out of a post body when it is saved | Planned |
| F-5.2 | Tags are stored in their own table with a join, not matched with `LIKE` | Planned |
| F-5.3 | Tags are normalised to lower case, so `#Rails` and `#rails` are one tag | Planned |
| F-5.4 | Hashtags render as links in a post body | Planned |
| F-5.5 | A tag page lists every post carrying that tag, with the same ordering and pagination as the feed | Planned |

### 1.6 Search (milestone 6)

| ID | Requirement | Status |
| --- | --- | --- |
| F-6.1 | A search field in the sidebar finds posts by body text | Planned |
| F-6.2 | Search also finds users by username | Planned |
| F-6.3 | Search behaves identically on SQLite and PostgreSQL | Planned — a plain `LIKE` search; ranked full-text is a later decision |
| F-6.4 | Results reuse the timeline rendering and cursor pagination | Planned |

### 1.7 Later milestones

Recorded so the shape of the system is visible; none are being built yet.

| ID | Requirement | Status |
| --- | --- | --- |
| F-7.1 | A user can follow and unfollow another user | Later |
| F-7.2 | The feed can be filtered to accounts the user follows | Later |
| F-8.1 | A user can like, repost and reply to a post | Later |
| F-9.1 | A post can carry one or more images | Later |
| F-9.2 | A user can set an avatar | Later |
| F-10.1 | A user is notified of activity on their posts | Later |

---

## 1b. Design requirements

| ID | Requirement | Status |
| --- | --- | --- |
| D-1 | Reading is public; only writing requires an account (90-9-1: most visitors are lurkers) | Planned |
| D-2 | Posting is reachable from the feed itself, not behind a separate page | Met |
| D-3 | Power-user tooling — bulk management, drafts, scheduling — stays absent until the first two groups are served | Met — by omission |

---

## 2. Non-functional requirements

### 2.1 Data

| ID | Requirement | Status |
| --- | --- | --- |
| N-1.1 | The app runs on SQLite with no external services, so a checkout boots with one command | Met |
| N-1.2 | Switching to PostgreSQL requires no code change — only `DATABASE_URL` and installing the `pg` gem | Met |
| N-1.3 | Every schema change ships as a migration; `db/schema.rb` is never hand-edited | Met |
| N-1.4 | Columns used for timeline ordering are indexed | Met |
| N-1.5 | Production runs on managed PostgreSQL | Planned |

### 2.2 Quality

| ID | Requirement | Status |
| --- | --- | --- |
| N-2.1 | RuboCop passes with `rubocop-rails-omakase`, and CI fails on any offence | Met |
| N-2.2 | Model behaviour is covered by model specs, controller behaviour by request specs | Met |
| N-2.3 | A change that adds behaviour without a test is incomplete | Met |
| N-2.4 | No system/browser specs until the UI justifies the maintenance cost | Met |
| N-2.5 | SonarQube quality gate passes | Open — needs a server and `SONAR_TOKEN` |

### 2.3 Security

| ID | Requirement | Status |
| --- | --- | --- |
| N-3.1 | Brakeman runs on every pull request and fails on any warning | Met |
| N-3.2 | Gem CVEs are detected by bundler-audit on every pull request | Met |
| N-3.3 | Trivy scans the source tree; any fixable HIGH or CRITICAL fails the build | Met |
| N-3.4 | Trivy scans the built image; any fixable HIGH or CRITICAL fails the build | Met |
| N-3.5 | A DAST baseline scan runs against the running container | Partial — runs, but does not yet fail the build |
| N-3.6 | The container runs as a non-root user | Met |
| N-3.7 | The production image contains no development or test dependencies | Met |
| N-3.8 | User-supplied content is escaped on output | Met — ERB escapes by default |
| N-3.9 | Secrets are never committed; Trivy scans for them | Met |
| N-3.10 | The base image is kept current, since inherited CVEs fail the build like any other | Met |
| N-3.11 | SSL is enforced wherever the app is served over TLS — HSTS, https redirect, secure cookies | Deferred — `RAILS_FORCE_SSL` and `RAILS_ASSUME_SSL` default to off so the image runs over plain HTTP. Both must be set to `true` in any deployed environment |

### 2.4 Delivery

| ID | Requirement | Status |
| --- | --- | --- |
| N-4.1 | All work reaches the default branch through a pull request | Met |
| N-4.2 | A pull request merges only once every required check has passed | **Not met — `main` has no required status checks, so GitHub reports every pull request as mergeable immediately and refuses to arm auto-merge. Merges so far have been manual after checking CI by hand. Needs a branch ruleset requiring Lint, Test, SAST and Container.** |
| N-4.2a | A branch must be up to date with `main` before merging | **Not met — nothing re-validates the merge commit now that CI is pull-request-only, so two branches can each pass in isolation and still break once merged.** |
| N-4.3 | Commits follow Conventional Commits, since the version bump is derived from them | Met |
| N-4.4 | The version is derived automatically; no one edits a version by hand | Met |
| N-4.5 | The image builds reproducibly from `web/Dockerfile` | Met |
| N-4.6 | The image is proven to boot and serve traffic before release | Met — CI starts it and polls `/up` |
| N-4.7 | Images are tagged with the version, an immutable commit SHA, and `latest` | Met |
| N-4.8 | Images are published to a container registry on release | Met — GitHub Container Registry |
| N-4.9 | Published images run on both `linux/amd64` and `linux/arm64` | Met |
| N-4.10 | Images are published to Amazon ECR | Planned — written and commented out pending AWS setup |
| N-4.11 | The app is deployed to AWS | Planned |

---

## 2.5 Deferred by proof-of-concept scope

Real answers are needed only if this is ever deployed.

| ID | Requirement | Status |
| --- | --- | --- |
| N-5.1 | Password reset email reaches a real inbox | Deferred — the flow and mailer exist; no delivery service is configured, so reset sends nothing outside development |
| N-5.2 | An email address is verified before the account can post | Deferred — an account can be registered against an address its owner does not control |
| N-5.3 | Sign-in attempts are rate limited | Met — the generator applies `rate_limit to: 10, within: 3.minutes` to sign-in, password reset and registration. It counts through `Rails.cache`, so the limit is per-process and resets on restart; a shared store is needed before it means anything under more than one instance |
| N-5.4 | Sessions expire after a period of inactivity | Deferred |
| N-5.5 | The app is backed up, and restores are tested | Deferred — SQLite in a container volume, no backups |

---

## 2.6 Latency and degradation

How the app behaves when the network between it and its database is slow. Nothing here is
built; the reasoning and the proposed order are in [`docs/latency.md`](docs/latency.md).

None of this is testable on SQLite, which runs in-process with no wire to slow down, so all of
it depends on the PostgreSQL path — which is itself an untested claim today (N-1.2, ADR 0003).

| ID | Requirement | Status |
| --- | --- | --- |
| N-6.1 | Rendering the feed issues a constant number of queries, regardless of how many posts are on the page | Met — 1 signed out, 2 signed in, flat from 1 post to a full page |
| N-6.2 | Query count per request is asserted in specs, so a regression fails the build rather than being noticed as slowness | Met — `spec/requests/feed_query_budget_spec.rb`. Milestone 3's N+1 will fail it |
| N-6.3 | The connection pool is larger than the Puma thread count | Open — equal when `RAILS_MAX_THREADS` is set, since both read it |
| N-6.4 | Connection, checkout and statement timeouts are configured and adapter-neutral | Not met — the only timeout set is `timeout: 5000`, which is SQLite's `busy_timeout` and is ignored by PostgreSQL |
| N-6.5 | A readiness endpoint reports unhealthy when the database is unreachable | Not met — `/up` checks only that the app booted, so it returns 200 against a dead database. Deliberately separate from `/up`, which should not restart the app because a dependency is down |
| N-6.6 | Behaviour under injected latency is measured and written down — p50/p95, queries per request, errors | Open — proposed harness is Toxiproxy between the app and PostgreSQL containers |
| N-6.7 | The test suite passes against PostgreSQL, not only SQLite | Not met — no CI job has ever run it |

---

## 3. Out of scope

Explicitly not being built, to keep the current milestone honest:

- The follow graph and any personalised or ranked timeline. "Your feed" in milestones 2–6
  means the posts you wrote, not a timeline only you can see.
- Likes, reposts and replies.
- Media — images on posts, and avatars on profiles.
- Notifications.
- Account deletion.
- Ranked full-text search. Milestone 6 ships a plain `LIKE` search that works on both
  adapters; anything better is a decision to take once the app is on PostgreSQL.
- Background jobs. Sidekiq and Redis arrive when a milestone needs them.
- Any AWS resource, Terraform module or deployment target.
- Spam controls and moderation. Sign-in rate limiting is an open question, not a commitment.
