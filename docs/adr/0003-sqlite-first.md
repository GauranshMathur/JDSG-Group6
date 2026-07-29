# ADR 0003 — SQLite first, PostgreSQL later

**Status:** Accepted
**Date:** 2026-07-28
**Milestone:** 1

## Context

The application will run on PostgreSQL if it is ever deployed — RDS is in the infrastructure
sketch, and the workload eventually wants concurrent writes and real full-text search.

That is not an argument for starting there. Starting on PostgreSQL means every checkout needs a
running database before the app boots: a Compose file, a container, a health check, a
connection string, and one more thing to be broken on someone else's machine. The feed does not
need any capability PostgreSQL has and SQLite does not.

## Decision

Run on SQLite. Make the switch to PostgreSQL a single environment variable rather than a
migration project, by holding two rules:

- `config/database.yml` defaults to SQLite, and `DATABASE_URL` overrides everything including
  the adapter. Setting it is the whole switch.
- Nothing in the application may depend on adapter-specific behaviour. This is recorded as
  requirement N-1.2 so it is testable rather than aspirational.

The `pg` gem sits in an optional Bundler group, so a plain `bundle install` does not need
`libpq` on a machine that will never use it.

## Consequences

**Good**

- A checkout boots with `bin/rails server` and nothing else running.
- CI needs no service containers, so the pipeline is faster and has fewer moving parts.
- The constraint is useful in itself. "No adapter-specific behaviour" keeps the app on standard
  Active Record, which is where it should be at this size anyway.

**Bad, or at least accepted**

- **It rules out the good version of search.** PostgreSQL full-text search and SQLite FTS5 are
  different, adapter-specific mechanisms, so N-1.2 forbids both. Milestone 6 therefore ships a
  plain `LIKE` search — see [ADR 0004](0004-hashtags-and-search.md). This is the largest cost
  of this decision, and it is paid by a feature, not by infrastructure.
- SQLite's single-writer model would matter under concurrent load. It does not matter here, and
  would be the trigger to make the switch.
- The switch is cheap but not free. It is verified by nothing today — no CI job runs the suite
  against PostgreSQL, so "it still works on Postgres" is a claim, not a fact. Worth adding a
  matrix run before relying on it.

## Alternatives

**PostgreSQL from the start** — correct if the deployment were near. It is not; the AWS
milestone has not begun, and paying setup cost now for a benefit later is the wrong order.

**SQLite forever** — viable for a proof of concept, and tempting. Rejected because the stated
goal includes deploying to AWS, and discovering adapter assumptions at that point is worse than
holding the constraint from the start.
