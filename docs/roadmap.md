# Roadmap

Ordered. Each milestone is a shippable slice; we plan the details of a milestone when we
reach it, not before.

| # | Milestone | Status |
| --- | --- | --- |
| 0 | Repo scaffolding — Rails app in `web/`, Docker, CI | **Done** |
| 1 | **The feed** — post creation and timeline rendering | **Done** |
| 2 | **Authentication** — sign up, sign in, sign out, sessions | **Done** |
| 3 | **Post ownership and CRUD** — posts belong to users; edit and delete your own | **Done** |
| 4 | **Navigation and profiles** — sidebar shell, profile pages, edit your profile | **Done** |
| 5 | **Engagement and hashtags** — likes, reposts, replies, `#tag` pages | Next |
| 6 | **Search** — find posts and people from the sidebar | Planned |
| 7 | Follows — follow/unfollow, following-only feed | Later |
| 8 | Media — image uploads on posts | Later |
| 9 | Notifications | Later |
| 10 | AWS deployment — Terraform, ECS/Fargate, RDS, ElastiCache | TODO |

Milestones 0 and 1 were built together, since a feed needs an app to live in.

Milestones 2–6 are the current block of work: authentication, full CRUD on posts, profiles,
engagement with hashtags, and search. They are listed separately rather than as one milestone
because each is independently shippable, and because a single change touching auth, ownership,
navigation, engagement, tagging and search at once is not reviewable.

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

### Milestone 3 — Post ownership and CRUD (F-3.x) — **built**

Per-requirement status is in [`REQUIREMENTS.md`](../REQUIREMENTS.md) (F-3.x). What shipped:
`posts.user_id` not null with a foreign key, the free-text `author_name` gone, edit and delete
restricted to the author by scoping, and an "edited" marker on changed posts.

**Two decisions were taken during the milestone** that the plan below did not contain:

- *Posts outlive their author's account, and identities are never reused* — [ADR 0005](adr/0005-posts-outlive-accounts.md).
  A user row is never destroyed, so a released address can never be claimed by someone who
  would then inherit the old account's posts.
- *Authors display as the local part of their email address.* The timeline is public, so
  publishing full addresses invites scraping. Temporary — milestone 4's username replaces it.

The original plan, unchanged:

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

### Milestone 4 — Navigation and profiles (F-4.x) — **built**

Per-requirement status is in [`REQUIREMENTS.md`](../REQUIREMENTS.md) (F-4.x). The plan below
shipped as written. Three things landed alongside it worth naming:

- **A bug the specs could not have named:** on a public (`allow_unauthenticated_access`)
  page, nothing resumed the session before the view read `Current.user` — the feed only
  escaped because its template happens to call `authenticated?` first, and the new profile
  page did not, so it showed every visitor a stranger's page, owner included. Session resume
  is now an unconditional `before_action`; only *requiring* a session stays skippable.
- Cursor pagination moved from `PostsController` into a shared `TimelinePagination` concern,
  since profiles page through posts the same way — and tag pages will next milestone.
- Profile pages got their own query budget spec: 2 queries signed out, 3 signed in, flat
  however many posts render. The extra query over the feed's budget is the username lookup.

The original plan, unchanged:

- A sidebar as the application shell: Feed, Profile, Sign in/out — Search joins it in
  milestone 6. Rendered from a layout partial, not duplicated per page. It replaces the
  milestone 2 masthead.
- `username` added to `User`: unique, case-insensitive, URL-safe — lower-case letters,
  digits and underscores, 3–20 characters. Uniqueness works the way email already does
  (F-2.2): normalised to lower case on write, enforced by a plain unique index, nothing
  adapter-specific.
- **Usernames are chosen at registration and never change** —
  [ADR 0006](adr/0006-immutable-usernames.md). This is what makes `/@username` a stable URL,
  and it keeps uniqueness down to one indexed column: were names releasable, a candidate
  would have to be checked against every name ever held, not just the current ones.
- Existing users are backfilled from the local part of their email address, deduplicated
  with a numeric suffix. Same licence as milestone 3's backfill: acceptable precisely
  because this is development data — inventing usernames for real accounts would not be.
- `/@username` public profile pages listing that user's posts — the same ordering, cursor
  pagination and post partial as the feed. Reading one never requires an account (F-2.5).
- Edit your own profile — display name (≤ 50 characters) and bio (≤ 160). A singular
  resource acting on the signed-in account: no id in the URL, so a route to anyone else's
  profile settings does not exist, rather than existing and needing a guard (F-4.5).
- The display name appears beside `@username` on posts and profiles, falling back to the
  username when unset. This retires milestone 3's stopgap of showing the email local part.
- Avatars need file storage, so they wait for the media milestone.

### Milestone 5 — Engagement and hashtags (F-5.x)

The milestone that makes the feed interactive. Four independently shippable slices, built in
order — each is a PR or a small series, and each ends with the app working.

#### Slice A — Likes (F-5.6, F-5.7)

The simplest engagement action: a like is a row in a join table, nothing more.

- `Like` model: `user_id` + `post_id`, compound unique index, foreign keys.
- Counter cache `posts.likes_count` so displaying the count never N+1s.
- Like/unlike toggle via Turbo Stream — the button swaps state without a page reload.
- A signed-in user can like any post, including their own. Disallowing self-likes is
  complexity that solves nothing in a proof of concept.
- Signed-out visitors see the count but no toggle.

#### Slice B — Reposts (F-5.8, F-5.9)

Structurally identical to likes — a join table, a counter cache, a toggle.

- `Repost` model: `user_id` + `post_id`, compound unique index, foreign keys.
- Counter cache `posts.reposts_count`.
- Repost/un-repost toggle via Turbo Stream.
- **No timeline fan-out.** On Twitter, a repost puts the original in your followers'
  timelines. There is no follow graph yet, so reposts are a count only — the original post
  stays where it is. Fan-out arrives with the follows milestone.
- No quote posts. Those are a different model (a post that embeds another) and are out of
  scope.

#### Slice C — Replies (F-5.10, F-5.11, F-5.12)

The first change to the `Post` model itself since milestone 3.

- Self-referential `parent_id` on `posts`, nullable foreign key, indexed. A reply is a post
  with a parent — not a separate model. This keeps the body validation, authorship and CRUD
  rules identical for replies and top-level posts.
- Counter cache `posts.replies_count`.
- A **post detail page** at `/posts/:id` showing the post and its direct replies in
  chronological order. The detail page is new — until now, posts only appear on feeds.
- A composer on the detail page for replying, scoped to the parent post.
- The main timeline and profile pages show **top-level posts only** (`WHERE parent_id IS
  NULL`). Replies are visible on the detail page, not scattered through the feed.
- "Replying to @username" context on the detail page above each reply.
- Replies are flat. A reply to a reply is allowed (it sets its own `parent_id`), but there
  is no thread unwinding or nested display — every reply page lists its direct children only.

#### Slice D — Hashtags (F-5.1 through F-5.5)

Unchanged from the original plan. [ADR 0004](adr/0004-hashtags-and-search.md) covers the
join-table decision.

- `#tag` parsed out of the post body on save.
- `Tag` and a `PostTag` join table, rather than `LIKE '%#tag%'` — a join gives an indexed
  lookup, exact matching, and a place to hang tag metadata later. A `LIKE` scan cannot
  distinguish `#rails` from `#railsconf` without more escaping than it is worth.
- Hashtags render as links in post bodies.
- `/tags/:name` lists posts carrying that tag, reusing the existing timeline and cursor
  pagination.
- Tags are normalised to lower case on write so `#Rails` and `#rails` are one tag.

#### Design notes for the milestone

- **Counter caches over live counts.** Each engagement type adds a `_count` column to
  `posts`, maintained by Rails's `counter_cache: true`. This keeps the timeline query flat —
  no subqueries, no N+1. The cost is a write on both the join table and the post row on
  every like/repost/reply, which is fine at this scale.
- **No new query in the timeline.** Likes, reposts and reply counts are columns on `posts`,
  so the timeline query stays the same. Whether the current user has liked or reposted a
  post is one query per page (batch lookup), not per post.
- **Turbo Streams for toggles.** Like and repost are instant toggles that do not navigate.
  Turbo Streams replace the button partial in place, the same pattern as the post composer.

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

Follows and a following-only timeline, media and avatars, notifications, moderation and rate
limiting. Each is a later milestone; none should be started "while we're in there".
