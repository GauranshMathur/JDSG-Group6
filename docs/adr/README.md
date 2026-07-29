# Architecture decision records

A record per decision that had a real alternative and a cost worth remembering. The point is
not to document everything — it is so that "why is it like this?" has an answer six months
later, including the answer "we knew, and here is what we accepted".

A decision with no genuine alternative does not need a record. It is a line in whichever
document it affects.

## Format

Context, then the decision, then the consequences — good *and* bad. An ADR that lists only
benefits is marketing, not a record. If a choice cost nothing, it probably was not a decision.

Records are immutable once accepted. When one is overturned, the new record supersedes it and
the old one stays, marked. The reasoning that turned out to be wrong is usually the most
useful part.

## Records

| # | Decision | Status |
| --- | --- | --- |
| [0001](0001-authentication.md) | Authentication with the Rails 8 generator, not Devise | Accepted |
| [0002](0002-keyset-pagination.md) | Keyset pagination for the timeline, not offset | Accepted |
| [0003](0003-sqlite-first.md) | SQLite first, PostgreSQL later, switchable by env var | Accepted |
| [0004](0004-hashtags-and-search.md) | Hashtags via a join table; search via `LIKE` | Accepted |
| [0005](0005-posts-outlive-accounts.md) | Posts outlive their author's account; identities are never reused | Accepted |
| [0006](0006-immutable-usernames.md) | Usernames are chosen at registration and never change | Accepted |
