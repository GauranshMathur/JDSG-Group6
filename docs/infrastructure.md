# Infrastructure

**Everything in this section is a TODO.** `infra/` is a placeholder so that infra lives
beside the app from the start.

Sketch of what will need to be decided:

- Compute — ECS on Fargate vs. EC2 vs. App Runner.
- Database — RDS for PostgreSQL, instance sizing, Multi-AZ.
- Cache and jobs — ElastiCache for Redis, Sidekiq worker service.
- Networking — VPC, subnets, security groups, ALB.
- Storage — S3 for user-uploaded media (milestone 6).
- Secrets — Secrets Manager or SSM Parameter Store.
- **TLS — set `RAILS_ASSUME_SSL=true` and `RAILS_FORCE_SSL=true` on the deployed service.**
  They default to off so the image runs over plain HTTP locally, which means a deployment
  that forgets them gets no HSTS, no https redirect and non-secure session cookies.
  Tracked as N-3.11 in `REQUIREMENTS.md`.
- Observability — CloudWatch logs and metrics; error tracking TBD.
- State — Terraform remote state in S3 with DynamoDB locking.

No AWS resources will be created until this is designed and agreed.
