# ADR 0006 — Usernames are chosen at registration and never change

**Status:** Superseded by [ADR 0007](0007-changeable-usernames.md)
**Date:** 2026-07-29
**Milestone:** 4

## Context

Milestone 4 gives every user a username and makes it a public URL: `/@username` is the
profile page. That forces the question `docs/open-questions.md` had been holding: can a
username change after registration?

The answer decides more than a form. If usernames can change, then either every shared
profile link is only as durable as its owner's whim, or old links must keep working — which
means a table of historical usernames, a redirect from each, and a rule that a released name
can never be claimed by someone else. That last rule is not optional: ADR 0005 already
established that an identity, once used, is never reused, because attribution silently
transferring to a stranger is the failure mode this project decided to make impossible.

Uniqueness is central to how much machinery each answer needs. With immutable usernames, the
whole mechanism is one plain unique index on one column — the same shape email already uses
(F-2.2): normalise to lower case on write, let the index refuse duplicates. The database's
own index makes the "is this name taken?" check an indexed exact-match lookup; no bespoke
search structure is needed. But the moment names can be released, that stops being enough:
a candidate name must be checked not only against every *current* username but against every
name *ever held*, so uniqueness now spans a second, growing, indexed table consulted on every
registration and every rename.

## Decision

**A username is fixed at registration.** There is no rename form, no rename endpoint, and no
code path that writes to `users.username` after the row is created.

Consequently:

- `/@username` is a permanent URL. A profile link shared anywhere keeps working for as long
  as the account exists — and per ADR 0005, the account row exists forever.
- Uniqueness is one unique index over stored-lowercase values. No historical-usernames
  table, no redirect table, no reclamation policy, no second lookup on write.
- The mutable parts of identity — display name and bio — are separate columns, freely
  editable. What people actually want to change day to day changes; the URL does not.

## Consequences

**Good**

- The URL story is trivially correct. Every alternative needs extra machinery to reach the
  same guarantee; this one gets it from a single `NOT NULL` column with a unique index.
- Consistent with ADR 0005: the username joins the email address as identity that is claimed
  once and never recycled, enforced by the database rather than by remembering.
- Nothing to get wrong later. A redirect table is only correct if every rename writes to it
  atomically, forever; a column nobody updates cannot drift.

**Bad, or at least accepted**

- **A typo at registration is permanent.** In this proof of concept the answer is "register
  again"; in a real product that answer is a support burden and this decision would need
  revisiting.
- People legitimately outgrow names — rebrands, safety, marriage. A real product eventually
  needs renames, and adding them later requires exactly the historical-usernames machinery
  this decision avoids paying for now. The cost is deferred, not deleted.
- Names can be squatted at registration and there is no recovery mechanism.

## Alternatives

**Changeable, old links break.** Cheap, and fails on both counts: `/@oldname` 404s
everywhere it was ever shared, and the released name is claimable — a new account inherits
an old identity in every bookmark and search result, which is the attribution transfer
ADR 0005 exists to prevent. Rejected.

**Changeable, with historical redirects.** The correct production answer: a rename keeps
`/@oldname` redirecting and the old name unclaimable forever. Rejected here for weight, not
correctness — it is a second table, a two-table uniqueness check on every registration and
rename, and specs for all of it, bought for a proof of concept in which nobody has ever
renamed anything.

## Revisiting

The first real rename request. Note that the deferral is only cheap while it holds: the day
renames are added *without* the redirect machinery, every previously shared link becomes
retroactively breakable. If this decision is overturned, the redirect table must arrive in
the same change, not after it.
