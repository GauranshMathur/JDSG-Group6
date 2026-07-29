# Open questions

Decisions not yet taken. This is a **live list** — when work answers a question, it is deleted
from here and the answer moves into whichever document it belongs to. It is not a log of
things we once wondered about.

Each entry says what the question is, why it matters, and when it needs answering. A question
with no "when" tends to sit here forever; a question with one becomes a decision on time.

Answered decisions live in [`adr/`](adr/) when the trade-off is worth remembering, or in the
relevant document when it is not.

---

## Product

### Should an edit be visible as an edit?

Milestone 3 lets an author change a published post. It does not say whether that change is
*honest* — an "edited" marker, a timestamp, a history, or nothing at all.

**Why it matters:** a post that can change silently after people have read it is a different
object from one that shows it changed. Someone can agree with a post and then find they have
agreed with something else. It also interacts with caching, and with any future
fan-out-on-write timeline.

**When:** during milestone 3. Adding a marker later is easy; adding a history later means the
edits made in between are already gone.

### Is there a time limit on editing?

Can a post be rewritten a minute after posting, a year after, or not once someone has replied
to it?

**Why it matters:** it is the difference between fixing a typo and rewriting history.

**When:** milestone 3, alongside the question above. They are really one decision.

### Should duplicate posts be prevented?

For example by hashing the body and rejecting a repeat from the same author within a window.

**Why it matters:** double-submits happen, and a feed showing the same post three times is
bad. But "duplicate" needs defining — the exact same text, or normalised for whitespace and
case? Someone posting "good morning" every day is not spamming.

**When:** not urgent. Worth deciding before anything invites real usage.

### Should `username` be changeable after registration?

**Why it matters:** profile URLs are `/@username`. If usernames change, old links break unless
historical usernames are retained and redirected — which means a table of past usernames and a
rule about whether a released username can be claimed by someone else.

**When:** milestone 4, before profile URLs exist. Retrofitting stable URLs afterwards is
painful.

### What happens to someone's posts when they delete their account?

Cascade and remove them, or keep them attributed to a deleted user?

**Why it matters:** it shapes the schema — a nullable `user_id` and a tombstone versus a hard
foreign key — before the feature is built.

**When:** account deletion is out of scope, but answer this before milestone 3 fixes the
foreign key, because the answer decides whether it can be null.

### Should posts carry images?

Formats, size ceiling, whether they are re-encoded and compressed on upload, what
quality-to-size trade-off is acceptable, and whether thumbnails are generated separately from
the original.

**Why it matters:** this is the first requirement needing both object storage and background
jobs, so it pulls two deferred decisions forward at once.

**When:** before the media milestone. Not before that.

---

## Technical

### Ranked full-text search

Milestone 6 ships a `LIKE` search, because full-text search is adapter-specific and the app is
on SQLite — see [ADR 0004](adr/0004-hashtags-and-search.md).

**When:** once the app is actually on PostgreSQL. Not before, and not by bolting on a search
engine to avoid the move.

### Is the PostgreSQL switch actually verified?

[ADR 0003](adr/0003-sqlite-first.md) claims switching databases needs only an environment
variable. Nothing tests that claim — no CI job runs the suite against PostgreSQL.

**Why it matters:** an untested claim about portability is a guess, and adapter assumptions
get found at the worst possible moment.

**When:** worth a CI matrix run before anyone relies on it.

---

## Delivery

### Required status checks and up-to-date branches

`main` has neither. Auto-merge cannot arm without required checks, so every merge is manual;
and since CI no longer runs on `main`, nothing re-validates a merge commit.

**Why it matters:** two branches can each pass in isolation and still break once merged, and
the release will ship it.

**When:** now. This is configuration rather than work — see N-4.2 and N-4.2a in
[`REQUIREMENTS.md`](../REQUIREMENTS.md).

### Should the DAST scan fail the build?

The ZAP baseline scan runs and reports; `fail_action` is `false`.

**Why it matters:** a scan that cannot fail is a report nobody reads. Until its current
findings are triaged, though, turning it on would block every pull request on the same
pre-existing warnings.

**When:** after triaging what it currently reports.

### SonarCloud or self-hosted SonarQube?

The job is wired and skips itself without a `SONAR_TOKEN`.

**When:** whenever the quality gate is actually wanted. It blocks nothing today.

---

## Deferred by proof-of-concept scope

Not open questions so much as known gaps. Real answers are needed only if this is ever
deployed; they are recorded so the gap is known rather than forgotten. Tracked as N-5.x in
[`REQUIREMENTS.md`](../REQUIREMENTS.md).

- Password reset email has no delivery service — the flow and mailer exist, nothing sends.
- No email verification, so an account can be registered against an address its owner does not
  control.
- No rate limiting on sign-in attempts.
- `RAILS_FORCE_SSL` and `RAILS_ASSUME_SSL` default to off — see N-3.11.
- No backups, and no restore has ever been tested.
- Multi-environment strategy — staging and production, or production only.
