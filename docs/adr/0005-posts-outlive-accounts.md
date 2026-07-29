# ADR 0005 — Posts outlive the accounts that wrote them, and identities are never reused

**Status:** Accepted
**Date:** 2026-07-29
**Milestone:** 3

## Context

Milestone 3 attaches every post to a user, which forces a question the feed never had to
answer before: what happens to someone's posts when their account goes away?

The answer shapes the schema, and it has to be decided *before* the foreign key is written
rather than after, because it decides whether `posts.user_id` may be null.

Two requirements were given:

1. **A deleted account's posts stay up.** Removing an account does not remove what it wrote.
2. **Every new user is always distinct from every previous one.** A new account can never be
   mistaken for an old one.

The second is the sharper constraint, and it is easy to miss. If an account is deleted and its
identity released, someone else can register the same address, and every post the first account
wrote now appears — to any reader — to have been written by the new one. Attribution silently
transfers to a stranger. Nothing in the schema notices.

## Decision

**A user row is never destroyed.** Deleting an account marks it deleted; the row, and the
unique index entry that holds its address, stay forever.

Consequently:

- `posts.user_id` is `NOT NULL`, with a foreign key.
- `User has_many :posts, dependent: :restrict_with_error` — destroying a user with posts is
  refused, in the model and by the foreign key underneath it.
- Account deletion, when it is built, is a soft delete. It is not in this milestone; only the
  schema shape it requires is.

## Consequences

**Good**

- Requirement 2 is enforced by the database, not by remembering. The unique index still holds
  the deleted account's address, so it cannot be claimed again — there is no window, and no
  code path that forgets.
- `user_id` stays `NOT NULL`, so no query, view or serialiser ever has to handle a post with no
  author. A nullable column would have to be defended everywhere, forever, to describe a state
  that only exists because deletion is possible.
- `dependent: :restrict_with_error` makes requirement 1 an error rather than a convention.
  Someone calling `user.destroy` gets a refusal, not a silently emptied timeline.

**Bad, or at least accepted**

- **Deletion is not deletion.** The row survives, holding the email address that identified the
  person. That is a real cost, and in a deployed system with real users it is the part that
  needs the most care: "delete my account" that retains an address is not what most people mean
  by it, and in some jurisdictions not what they are entitled to. Recorded as N-5.6.
- Retaining an address forever is in tension with erasing personal data on request. Squaring
  the two means storing a hash of the address rather than the address, so uniqueness survives
  while the address itself does not. That is a real design, and it is deliberately not being
  built for a proof of concept — but the cheap version chosen here is the one that would have
  to be revisited first.
- Rows accumulate. Irrelevant at this size, and worth knowing.

## Alternatives

**Cascade delete — posts go with the account.** Simplest, and directly contradicts requirement
1. Rejected.

**Nullable `user_id`, with a tombstone rendered for null.** Keeps posts, and satisfies
requirement 1. Rejected for two reasons: it makes every reader of `post.user` handle nil
forever, and — decisively — it does not satisfy requirement 2 on its own. Releasing the address
still lets a new account claim an old identity. Blocking that needs a retained record of taken
addresses, which is the row we would have just deleted.

**A single shared "deleted user" account that orphaned posts are reassigned to.** Keeps
`NOT NULL` and keeps the posts, but merges every deleted account into one, so two different
people's posts become indistinguishable. It also frees the original address for reuse, failing
requirement 2 for the same reason as above.

## Revisiting

The point to revisit is the first time someone asks to be erased. At that point the address
must stop being stored while uniqueness still has to hold, which means storing a fingerprint of
it instead. That is a migration and a decision, not a tweak — better to make it deliberately
than to discover it under a deadline.
