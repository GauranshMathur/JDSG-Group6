# ADR 0007 — Usernames are changeable, and uniqueness is the only guarantee

**Status:** Accepted
**Date:** 2026-08-05
**Supersedes:** [ADR 0006](0006-immutable-usernames.md)

## Context

[ADR 0006](0006-immutable-usernames.md) fixed usernames at registration. Its reasoning
holds and is worth reading: an immutable username makes `/@username` a permanent URL for
free, and keeps uniqueness down to one indexed column, because a name that is never
released never has to be checked against names previously held.

It also named its own cost, and that cost is what overturned it: **a typo at registration
is permanent**, and the only remedy on offer was "register again". For a proof of concept
whose accounts are created by hand during demos, that is the failure encountered most
often — not the broken-link scenario the decision was protecting against, which requires
someone to have shared a profile link outside the app, which has never happened.

ADR 0006 said it should be revisited on "the first real rename request". This is it.

## Decision

**A username can be changed, from the profile edit page, as often as the owner likes.**
It stays unique and stays normalised to lower case on write.

The uniqueness mechanism does not change at all — the same `unique: true` index on
`users.username` that has existed since milestone 4 does the work. What changes is that
it is now consulted on update as well as on insert:

- `attr_readonly :username` is removed from `User`, so assignment on a persisted record
  no longer raises.
- `:username` joins the profile controller's permit list, alongside display name and bio.
- `validates :username, uniqueness: true` was already present and now actually matters —
  it turns a would-be `RecordNotUnique` from the database into a form error reading
  "Username has already been taken", rendered on the edit page with a 422.

The database index remains the backstop, so a race between two simultaneous renames to
the same name fails at the database rather than producing a duplicate.

One consequence of the username becoming editable was not obvious until the rejected
case was looked at in a browser. The controller used to apply the edit to `Current.user`
itself, and the layout renders the signed-in identity from that same object — so a
refused rename left the *rejected* username on it, and the sidebar showed the handle
belonging to whoever already held it, with the profile link pointing at their page. It
read as though the account had become someone else's. Edits are now applied to a
separately loaded instance, leaving `Current.user` clean for the shell. This was latent
before: display name is in the sidebar too, but a rejected display name is at worst the
user's own bad input, not another person's identity.

**No historical-usernames table, and no redirects.** This is the "changeable, old links
break" alternative that ADR 0006 explicitly rejected, and it is being accepted here with
that rejection in view — see the consequences below.

## Consequences

**Good**

- A registration typo is fixable in fifteen seconds instead of never.
- The lookup stays a single indexed exact match. Whatever else changes, "is this name
  taken?" remains one index probe, which is what the requirement asked for.
- The change is four lines of production code — remove one macro, permit one parameter,
  add one form field, reload before redirecting so the redirect targets the new handle.
  No new tables, no new endpoints, no migration.

**Bad, or at least accepted**

- **`/@oldname` 404s after a rename**, everywhere it was ever shared. ADR 0006 called
  this out and rejected it; the counter-argument is only that in this proof of concept
  nothing links to a profile from outside the app. That argument expires the moment
  anything does.
- **A released name is claimable by the next person to want it.** This is a genuine
  narrowing of ADR 0005's principle that an identity, once used, is never reused: posts
  still carry their author's row forever, but the *handle* on that row can now move to a
  stranger, so a bookmark or a screenshot can end up pointing at someone else. Email
  addresses remain unrecyclable; the username no longer is.
- **The deferred cost from ADR 0006 is now accruing rather than merely deferred.** Every
  rename between now and any future redirect table is a broken link that the redirect
  table cannot retroactively fix, because nothing records what the old name was.

## Alternatives

**Keep ADR 0006 as it stands.** Correct for a production system and cheaper than this in
every respect except the one that actually bites. Rejected on that one.

**Changeable, with historical redirects.** Still the right production answer: a `usernames`
table recording every name ever held, `/@oldname` redirecting to its current owner, and a
uniqueness check spanning both tables. Rejected again on weight — a second table, a
two-table check on registration and rename, and specs for all of it. Noted honestly:
rejecting it a second time costs more than the first time did, because renames are now
possible and each one adds to the debt.

**Rename limited to a grace window after registration** (fixing typos only). Attractive —
it addresses the actual failure without releasing any established name. Rejected as more
mechanism than a proof of concept needs: a timestamp comparison, a second error state, and
a rule to explain, in exchange for a narrower version of what four lines already buys.

## Revisiting

Before this project is exposed to anyone outside the team, or before any profile URL is
shared anywhere durable. At that point the historical-usernames table stops being
optional — and note it arrives with a gap, since renames made under this decision left no
record to backfill from.
