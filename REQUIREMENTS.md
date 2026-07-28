# Requirements

What the application must do, and the constraints it must do it under. Scope and
sequencing live in `README.md`; this file is the checklist that says whether a
milestone is actually finished.

Each requirement has an ID so specs, commits and issues can point at it.

Status: **Met** — implemented and covered by tests. **Partial** — implemented but
incomplete. **Planned** — agreed, not built. **Open** — not yet decided.

---

## 1. Functional requirements

### 1.1 Feed (milestone 1)

| ID | Requirement | Status |
| --- | --- | --- |
| F-1.1 | A visitor can write a post from a composer on the feed page | Met |
| F-1.2 | A post has a body of 1–280 characters | Met |
| F-1.3 | A post carries an author name of at most 50 characters, defaulting to `anonymous` when left blank | Met |
| F-1.4 | The feed lists posts newest first | Met |
| F-1.5 | Ordering is stable and total — posts sharing a timestamp never reorder between requests | Met |
| F-1.6 | A new post appears at the top of the timeline without a full page reload | Met |
| F-1.7 | The feed loads at most 20 posts per page | Met |
| F-1.8 | Older posts are reachable through a cursor, and no post is repeated or skipped as new posts arrive | Met |
| F-1.9 | An invalid post re-renders the composer with its errors and leaves the timeline intact | Met |
| F-1.10 | An empty timeline shows an empty state rather than a blank page | Met |

### 1.2 Later milestones

Recorded so the shape of the system is visible; none are being built yet.

| ID | Requirement | Status |
| --- | --- | --- |
| F-2.1 | A visitor can register, sign in and sign out | Planned |
| F-2.2 | Posts belong to a user account rather than a free-text name | Planned |
| F-3.1 | Each user has a profile page listing their posts | Planned |
| F-4.1 | A user can follow and unfollow another user | Planned |
| F-4.2 | The feed can be filtered to accounts the user follows | Planned |
| F-5.1 | A user can like, repost and reply to a post | Planned |
| F-6.1 | A post can carry one or more images | Planned |
| F-7.1 | Posts can be searched, and hashtags resolve to a filtered feed | Planned |
| F-8.1 | A user is notified of activity on their posts | Planned |

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

### 2.4 Delivery

| ID | Requirement | Status |
| --- | --- | --- |
| N-4.1 | All work reaches the default branch through a pull request | Met |
| N-4.2 | A pull request merges only once every required check has passed | Met — via auto-merge |
| N-4.3 | Commits follow Conventional Commits, since the version bump is derived from them | Met |
| N-4.4 | The version is derived automatically; no one edits a version by hand | Met |
| N-4.5 | The image builds reproducibly from `web/Dockerfile` | Met |
| N-4.6 | The image is proven to boot and serve traffic before release | Met — CI starts it and polls `/up` |
| N-4.7 | Images are tagged with the version, an immutable commit SHA, and `latest` | Met |
| N-4.8 | Images are published to a container registry on release | Met — GitHub Container Registry |
| N-4.9 | Images are published to Amazon ECR | Planned — written and commented out pending AWS setup |
| N-4.10 | The app is deployed to AWS | Planned |

---

## 3. Out of scope

Explicitly not being built, to keep the current milestone honest:

- Authentication, sessions and authorisation.
- The follow graph and any personalised or ranked timeline.
- Likes, reposts, replies, media, search, hashtags and notifications.
- Background jobs. Sidekiq and Redis arrive when a milestone needs them.
- Any AWS resource, Terraform module or deployment target.
- Rate limiting, spam controls and moderation.
