# Infrastructure

**Status: proposed design, not yet agreed.** Nothing here exists. No AWS resources will be
created and no Terraform written until this design is agreed — that rule survives this
document. What has changed is that the app side is complete, so the design can now be
concrete instead of a sketch.

The app this deploys: a single Rails 8 container (published to GHCR on every release,
`linux/amd64` and `linux/arm64`), SQLite today with PostgreSQL one environment variable away,
Active Storage on local disk, no background jobs, no Redis. The deployment is what forces the
PostgreSQL switch (N-1.5) and the disk-to-S3 move — both are flagged below where they bite.

## The shape

```
                        Route 53 (domain — open question)
                              │
                        ALB + ACM certificate (TLS terminates here)
                              │
        ┌─────────────────────┴─────────────────────┐
        │  ECS on Fargate — service "web", 1 task   │
        │  (the GHCR/ECR image, port 80, Thruster)  │
        └───────┬──────────────────────┬────────────┘
                │                      │
        RDS PostgreSQL          S3 bucket (Active Storage)
        (single-AZ, t4g.micro)
```

One environment, one region, one task. Everything that would make this production-grade —
Multi-AZ, autoscaling, staging, a CDN — is deliberately absent and listed at the end, so the
gap is recorded rather than discovered.

## Decisions and what they cost

### Compute — ECS on Fargate

**Why:** no instances to patch, one task definition, and a natural home for the Sidekiq
worker as a second service in the same cluster when jobs finally arrive. App Runner is
simpler and scales to zero, but it cannot run a worker service, so adopting it now means
migrating the moment Sidekiq lands. EC2 is cheapest at steady load but adds AMI, patching
and capacity management that a proof of concept has no one to do.

**Cost:** Fargate never scales to zero — a 0.25 vCPU / 0.5 GB task runs ~$9/month just for
existing. And one task means the in-process state the app already leans on stays honest:
`Rails.cache` (the ranked-feed cache) and the sign-in rate limiter are per-process, so a
second task would mean two divergent feed caches and a rate limit that counts half. Scaling
past one task is not a slider — it is the moment Solid Cache or Redis becomes mandatory.

### Database — RDS PostgreSQL, single-AZ

**Why:** managed PostgreSQL is the whole point of N-1.5, and `DATABASE_URL` is designed to be
the only change. `db.t4g.micro` with 20 GB gp3, automated backups on (7 days) — which quietly
retires half of N-5.5 (backups exist; a tested restore is still owed).

**Cost:** ~$12–15/month. Single-AZ means a maintenance window or AZ failure takes the app
down — accepted for a proof of concept, recorded so nobody mistakes it for resilience.
**Flag:** the `pg` gem ships behind an optional bundle group and the test suite has never run
against PostgreSQL (N-6.7). Verifying that — one CI job — is part of this milestone, not a
separate wish.

### Media — S3 for Active Storage

**Why:** Fargate task storage is ephemeral; every deploy would delete every avatar. This is
the "cloud storage is an infrastructure concern" note in the roadmap coming due.

**Cost:** pennies at this scale, but it is a *code* change as well as a bucket: an
`amazon` service in `storage.yml`, the `aws-sdk-s3` gem, and an IAM task role that can reach
only that bucket. The switch is small; pretending it is zero is how it gets forgotten.

### Networking — public subnets, no NAT

**Why:** the conventional layout puts tasks in private subnets behind a NAT gateway. A NAT
gateway is ~$32/month plus data — more than compute and database combined — to protect a
proof of concept holding no real data. Instead: tasks in public subnets, security groups as
the boundary (ALB → task port 80, task → RDS 5432, nothing else inbound).

**Cost:** this is the design's least conventional call, and it is pure cost-saving. If
anything real ever lives here, private subnets + NAT is the first thing to revisit.

### TLS — ALB + ACM, and two environment variables

ACM certificate on the ALB, HTTP redirected to HTTPS. **`RAILS_ASSUME_SSL=true` and
`RAILS_FORCE_SSL=true` must be set on the service** — they default to off so the image runs
locally, and a deployment that forgets them serves session cookies without `Secure` and no
HSTS. This is N-3.11; the deploy that leaves it off has shipped a security gap, not a config
nit. Needs a domain name — open question.

### Registry — ECR alongside GHCR

The release workflow already contains the ECR block, commented out (N-4.10). This milestone
creates the repository and a GitHub OIDC role — no long-lived AWS keys in GitHub secrets —
and uncomments it. GHCR stays; ECR is what ECS pulls from without cross-registry auth.

### Secrets — SSM Parameter Store

`SECRET_KEY_BASE` and `DATABASE_URL` as SecureString parameters, injected by the task
definition. **Why not Secrets Manager:** it charges per secret per month and its headline
feature, automatic rotation, needs a rotation Lambda nobody will write for a POC.
**Cost:** no rotation — a leaked secret is rotated by hand or not at all.

### Terraform — in `infra/terraform/`, state in S3

Remote state in an S3 bucket with native S3 locking (Terraform ≥ 1.10) — no DynamoDB table
to manage. The state bucket is the one resource created by hand, once, because Terraform
cannot create the bucket its own state lives in.

### Observability — CloudWatch logs, nothing else

`awslogs` driver on the task, 30-day retention. No APM, no error tracker, no dashboards —
the app logs to stdout and that is where looking happens. Recorded as a gap, not an oversight.

## Rough monthly cost

| Piece | ~USD/month |
| --- | --- |
| Fargate task (0.25 vCPU / 0.5 GB, always on) | 9 |
| RDS db.t4g.micro single-AZ + 20 GB | 14 |
| ALB | 17 |
| S3, ECR, Parameter Store, CloudWatch, data | < 5 |
| **Total** | **~45** |

The ALB is the most expensive line item. There is no cheaper managed TLS front door that can
sit in front of Fargate without changing the compute answer; accepting it is part of
accepting ECS.

## Deliberately not in this design

Recorded so absence reads as a decision, not a hole:

- **Staging.** One environment. The multi-environment question stays in the deferred table.
- **Multi-AZ, autoscaling, more than one task.** See the compute and database costs above —
  each is the trigger for work this design defers.
- **CDN.** Images are served by the app from S3 via redirects; CloudFront waits for a reason.
- **WAF, GuardDuty, budgets alarms** — worth an alarm on spend, nothing more, and that can be
  clicked once rather than managed.
- **Redis / ElastiCache.** Arrives with Sidekiq, which arrives with a milestone that needs a
  job. Nothing does yet.

## Sequencing (once agreed)

Each step is a pull request that leaves something working; the order means TLS and DNS — the
external dependency — is not the first blocker.

1. **I-1a — Terraform skeleton + ECR + OIDC.** State bucket by hand, then the ECR repository
   and the GitHub OIDC role; uncomment the release workflow's ECR block. Proves the pipeline
   end-to-end before any runtime exists. Closes N-4.10.
2. **I-1b — Network + RDS.** VPC, subnets, security groups, the database. Add the
   PostgreSQL CI job at the same time (N-6.7) so the switch is verified before anything
   depends on it.
3. **I-1c — ECS service + ALB + TLS.** The app on a URL, `RAILS_FORCE_SSL` on. Closes
   N-1.5, N-3.11, N-4.11.
4. **I-1d — S3 for Active Storage.** The bucket, the gem, the task role. After this a deploy
   no longer deletes the images.

## Open questions this design cannot answer for itself

Tracked in [`open-questions.md`](open-questions.md) with the rest:

- **Which AWS account and region**, and who pays the ~$45/month.
- **What domain name** the certificate is issued for.
