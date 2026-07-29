# ADR 0001 — Authentication with the Rails 8 generator

**Status:** Accepted
**Date:** 2026-07-29
**Milestone:** 2

## Context

Milestone 2 adds accounts. Posts currently carry a free-text `author_name`, which anyone can
type, so there is no ownership to enforce and nothing to attach a profile to.

Three options were on the table.

**Devise** is the default answer in most Rails projects. It ships confirmations, lockouts,
`omniauth` hooks and a decade of hardening. It is also a large dependency with its own
controller and routing conventions, and it takes over enough of the request cycle that
working against its assumptions later is real effort.

**Hand-rolled `has_secure_password`** gives complete control. It also means writing session
fixation defence, token expiry and password reset by hand — the parts where a mistake is a
vulnerability rather than a bug.

**The Rails 8 generator** — `bin/rails generate authentication` — was added to the framework
precisely to fill this gap. It generates a `User` model, a `Session` model, sign-in, sign-out
and password reset, as ordinary application code in the repository.

## Decision

Use the Rails 8 built-in generator.

## Consequences

**Good**

- No new dependency. `CLAUDE.md` says not to introduce a framework or library without asking,
  and this needs neither.
- The generated code lives in `web/app` and is ours to read and modify. There is no gem
  internals to work around when the requirements grow.
- Sessions are backed by a `Session` record, so signing out revokes server-side rather than
  merely clearing a cookie — which is what F-2.4 requires.
- It matches "boring, conventional Rails" — the framework's own answer, not a third party's.

**Bad, or at least accepted**

- Less comes for free than with Devise. Email confirmation, account lockout and OAuth are not
  generated; each is a deliberate later decision. Two of them are already open questions.
- The generator produces a password-reset mailer but nothing delivers email. Reset works in
  development and does nothing in production until a delivery service is configured. This is
  tracked as an open question and must be resolved before anything real is deployed.
- Being ordinary application code, security fixes do not arrive by bumping a gem. If a
  weakness is found in the generated pattern, we apply it ourselves.

## Revisiting

If the project later needs OAuth sign-in, email confirmation and account lockout together,
that is the point to reconsider Devise — porting to it is easier than reimplementing all
three by hand.
