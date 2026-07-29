# Roadmap

Ordered. Each milestone is a shippable slice; we plan the details of a milestone when we
reach it, not before.

| # | Milestone | Status |
| --- | --- | --- |
| 0 | Repo scaffolding — Rails app in `web/`, Docker, CI | **Done** |
| 1 | **The feed** — post creation and timeline rendering | **Done** |
| 2 | **Authentication** — sign up, sign in, sign out, sessions | **Done** |
| 3 | **Post ownership and CRUD** — posts belong to users; edit and delete your own | Next |
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

**Built.** Per-requirement status lives in [`REQUIREMENTS.md`](../REQUIREMENTS.md) (F-1.x).

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

Requirement IDs referenced here are defined in [`REQUIREMENTS.md`](../REQUIREMENTS.md).

### Milestone 2 — Authentication (F-2.x) — **built**

Per-requirement status is in [`REQUIREMENTS.md`](../REQUIREMENTS.md) (F-2.x). What shipped:

- `User` with `has_secure_password`, and `Session` rows behind a signed cookie.
- Registration (ours), sign in, sign out and password reset (the generator's).
- `Current.user`, and `allow_unauthenticated_access only: :index` on the feed.
- A signed-out visitor reads the timeline and sees a sign-in prompt where the composer would
  be. This was written down as F-3.6 for milestone 3, but guarding `create` without it would
  have shown a form whose only effect was to bounce you to sign in.
- A plain masthead with sign in / sign up / sign out, replaced by the sidebar in milestone 4.
- 36 new specs, and one behaviour worth naming: sign-out is asserted to destroy the `Session`
  row, not just clear the cookie.

**Two things landed that the plan below did not expect.** The generator applies `rate_limit`
to sign-in and password reset, so N-5.3 moved from deferred to met without being asked for —
though it counts through `Rails.cache`, which is per-process here. And posts still carry a
free-text `author_name` while now requiring an account to write, which is an odd pairing:
you must sign in, then type whatever name you like. Milestone 3 removes the column.

The original plan, unchanged:

Rails 8 ships an authentication generator — `bin/rails generate authentication` — which
produces a `User` model, a `Session` model, sign-in, sign-out and password reset. No gem, no
Devise. That matches the "boring, conventional Rails" rule, and it is one fewer dependency to
inherit. See [ADR 0001](adr/0001-authentication.md).

- `User` — email address and `has_secure_password`, unique case-insensitive email.
- Registration, sign in, sign out. Sessions in a signed cookie backed by a `Session` record,
  so sign-out can revoke server-side rather than only clearing the browser.
- `Current.user` for the request-scoped current user.
- Reading stays public. `require_authentication` guards writes only.

Password reset ships with the generator, including a mailer. Nothing is wired to a delivery
service and nothing will be — this is a proof of concept, so reset works against the
development mailer and is not expected to send anything real. Likewise no email verification
and no sign-in rate limiting; both are listed under deferred scope below.

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
would then need defending forever. Safe here precisely because nothing real is deployed; a
backfill that invents ownership would not be acceptable against production data.

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
