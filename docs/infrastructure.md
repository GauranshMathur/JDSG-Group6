# Infrastructure

**Status: design direction agreed, details in discussion.** This replaces the earlier
Fargate proposal, which assumed a real AWS account. The premise changed:

**There will never be a real AWS account.** This project practices enterprise-grade system
design, built and exercised entirely locally. The AWS architecture below is the *reference
design* — drawn, documented and diagrammed as a real AWS account would be — and the local
stack is its faithful realization. Terraform is written against the AWS provider so that
pointing at real AWS would be a provider/endpoint change, not a rewrite. Nothing real is
ever billed; local clusters and emulators are free to create and destroy.

The architecture diagram lives at
[`diagrams/aws-reference-architecture.drawio`](diagrams/aws-reference-architecture.drawio)
(draw.io, official AWS icon set — open with [draw.io](https://app.diagrams.net) or the
desktop app). It shows the full enterprise deployment: ingress and egress paths, two
availability zones, and every service the design names.

## Toolchain

| Piece | Tool | Note |
| --- | --- | --- |
| Provisioning | Terraform, AWS provider | Applied against the local emulator via its Terraform wrapper, not real AWS |
| AWS emulation | LocalStack (referred to as "floci" in discussion — **open: confirm this is the intended tool**) | Emulates the AWS APIs locally; its EKS support runs real k3d/k3s clusters under the hood |
| Kubernetes | k3s (via k3d — k3s nodes as containers) | The EKS stand-in. Node add/remove is a container operation, which is what makes autoscaling demonstrable locally |
| GitOps | Flux | Agreed as the direction but explicitly **not on the critical path** — nice to add once the platform stands, not a blocker for anything |
| Images | GHCR (already published on every release) | The reference design says ECR; locally the cluster pulls the GHCR images that already exist |

**One recorded risk:** LocalStack's EKS emulation is a paid (Pro) feature; the community
edition covers core services (S3, SSM, IAM and friends) but not EKS. If a licence is not
available, the fallback is plain **k3d + the same Kubernetes manifests**, with the
Terraform EKS module proven by `plan` rather than `apply`. The Kubernetes-side work — the
part this project is actually exercising — is identical in both cases.

## The reference architecture

What the diagram shows, in words:

```
Internet ──▶ Route 53 ──▶ ALB (public subnets, 2 AZs, TLS via ACM)
                              │  ingress: 443 only
                              ▼
              EKS — managed node groups (private subnets, 2 AZs)
              web pods × N · HPA · cluster autoscaler · PDBs
                    │                │               │
                    ▼                ▼               ▼
              RDS PostgreSQL    S3 (Active      ECR (pull via
              (Multi-AZ,        Storage media)  VPC endpoint)
               primary+standby)
                    
              egress: NAT gateway per AZ · secrets from SSM via IRSA
              logs/metrics: CloudWatch (reference) / Prometheus+Grafana (local)
```

Ingress: the internet reaches exactly one thing — the ALB on 443. Everything else sits in
private subnets and is reachable only through security groups scoped to its consumer
(ALB → pods, pods → RDS 5432, pods → S3/ECR via gateway endpoints). Egress from the private
subnets flows through a NAT gateway per AZ.

Resiliency, and how each piece is demonstrated locally:

| Reference (AWS) | What it survives | Local demonstration |
| --- | --- | --- |
| Two AZs everywhere | Loss of a data centre | Two k3d node groups labelled as zones; delete one and watch rescheduling |
| EKS managed node group + cluster autoscaler | Node loss; load growth | `k3d node create/delete`; HPA scales pods, node count follows |
| ≥2 web replicas + PodDisruptionBudget | Deploys and drains without downtime | Rolling deploy under load; `kubectl drain` |
| RDS Multi-AZ (primary + standby) | Database instance loss | Postgres in-cluster with an operator (e.g. CloudNativePG) failing over, or accepted as single-instance with the gap recorded |
| ALB health checks → pod readiness | Routing to a dead pod | Ingress + readiness probes against the app's `/up` |

## What this forces in the app — read before deploying

The app was built single-process on purpose, and three of its choices break the moment a
second replica exists. **This is expected.** Finding these under load is part of the point;
they are recorded here so they read as a plan rather than a surprise:

1. **SQLite → PostgreSQL.** Replicas cannot share a SQLite file. The switch is
   `DATABASE_URL` by design but has never been proven — the PostgreSQL CI job (N-6.7) lands
   with this milestone.
2. **Per-process cache → shared cache.** The ranked-feed cache and the sign-in rate limiter
   live in `Rails.cache` memory. Two replicas means two divergent feeds and a rate limit
   that counts half. Fix is Solid Cache (on Postgres, no new service) or Redis — decided
   when replicas go past one, recorded in `open-questions.md`.
3. **Disk → S3 for Active Storage.** Pod filesystems are ephemeral; a redeploy deletes
   every avatar. Locally this targets the emulator's S3 (or MinIO); the code change is a
   `storage.yml` service plus the `aws-sdk-s3` gem.

Also owed to this milestone: a real readiness endpoint (N-6.5 — `/up` returns 200 against a
dead database, which is exactly wrong for a load balancer).

## Later phases (agreed, not yet designed)

- **Load testing and latency testing** — how the app behaves as users grow, what breaks
  first, and whether the fix is infra or app. Tooling deliberately undecided (k6 and
  Toxiproxy are the leading candidates; `latency.md` already sketches the questions).
  This phase starts once the app is serving on the local platform.
- **Flux GitOps** — manifests reconciled from the repo instead of applied by hand.
- **Observability** — Prometheus + Grafana in-cluster as the CloudWatch stand-in.

## Sequencing

| Step | What exists at the end |
| --- | --- |
| I-1a | This design agreed; the reference diagram; toolchain verified (can Terraform actually stand up the emulated EKS? — the floci/licence question answers itself here) |
| I-1b | The platform: cluster up via Terraform, ingress, Postgres, S3-compatible storage |
| I-1c | The app served on it: image pulled, migrations run, `/up` green behind ingress — with the three app changes above made as they block |
| I-1d | Resiliency demonstrated: HPA, node scaling, drains, zone-loss rescheduling |
| I-1e | Load and latency testing, and the improvement loop it feeds |

The standing rule adapts rather than dies: **no real cloud resources, ever** — and no
Terraform until I-1a's design is agreed and the toolchain question is answered.
