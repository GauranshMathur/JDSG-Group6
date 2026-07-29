# ADR 0002 — Keyset pagination for the timeline

**Status:** Accepted
**Date:** 2026-07-28
**Milestone:** 1

## Context

The feed is reverse-chronological and needs to page through more posts than fit on a screen.
The obvious approach is `LIMIT 20 OFFSET n`, which every tutorial uses and which Rails
pagination gems default to.

Offset pagination assumes the list is stable while you read it. A timeline is the opposite: new
rows arrive at exactly the position the offset counts from. Between fetching page 1 and page 2,
three new posts push everything down three places, so page 2 begins three rows earlier than the
reader expects. Posts they already read appear again, and if rows are deleted instead, posts
they never saw are skipped entirely. The bug is invisible in development, where nobody is
posting while you click, and constant in anything with traffic.

Offset also degrades: `OFFSET 10000` makes the database walk and discard ten thousand rows.

## Decision

Paginate by keyset. The cursor is the `(created_at, id)` of the last row on the page, and the
next page is everything strictly before it:

```sql
WHERE created_at < :created_at OR (created_at = :created_at AND id < :id)
ORDER BY created_at DESC, id DESC
LIMIT 20
```

The ordering carries `id` as a tie-break, which is not decoration. `created_at` alone is not a
total order — two posts saved in the same tick can come back in either order, so a cursor built
on timestamp alone can skip or repeat exactly the rows it was meant to fix. A composite index
on `(created_at DESC, id DESC)` matches the sort, so it serves both the ordering and the cursor
comparison.

## Consequences

**Good**

- Pages do not shift when rows are inserted or deleted. No repeats, no skips.
- Cost is constant per page rather than growing with depth.
- No dependency. It is one scope and one index.

**Bad, or at least accepted**

- No page numbers, and no jumping to "page 5". A cursor only moves forwards from where you
  are. For a timeline nobody wants page 5, but it rules out a numbered pager if one is ever
  asked for.
- No total count without a separate query.
- The cursor is exposed in the URL as `?after=<timestamp>,<id>`. It is opaque enough not to
  invite tampering, and a malformed value falls back to the first page rather than raising —
  but it is not a secret and does leak a row's `created_at` and `id`.
- Microsecond precision in the cursor is required. Truncating to seconds silently reintroduces
  the skipping this was meant to prevent, which is the kind of bug that reappears when someone
  "tidies up" the format.

## Alternatives

**Offset pagination** — rejected above.

**A pagination gem** (Kaminari, Pagy) — both are offset-first. Pagy supports keyset, but the
implementation here is a scope and an index, and CLAUDE.md says not to add a dependency without
asking. Not worth asking for this.
