# floci — the local AWS emulator

What [floci](https://floci.io/floci/) is, how it works, how far its emulation goes, and —
the part that matters here — what that means for realizing our
[reference architecture](infrastructure.md) locally. Researched from the project's
[README](https://github.com/floci-io/floci), its service docs (EKS, EC2, RDS), and the
[CLI repo](https://github.com/floci-io/floci-cli); anything the docs left unclear is listed
at the end as an I-1a verification item rather than assumed.

## What it is

A free, MIT-licensed family of local cloud emulators (AWS, Azure, GCP, OCI — one container
per cloud). The AWS emulator speaks the AWS APIs on a single endpoint, `localhost:4566`,
so the AWS SDK, CLI, Terraform (v1.10+), OpenTofu and CDK all work by pointing at that
endpoint — validated upstream by ~2,500 automated compatibility tests. No auth token, no
paid tier, no feature gates, no telemetry. It exists in part because LocalStack's community
edition was sunset in March 2026; floci is a drop-in replacement (same default port, its
LocalStack environment variables auto-translate).

Built as a Quarkus Native binary: ~90 MB image, ~24 ms startup, ~13 MiB idle — the
emulator itself costs effectively nothing next to the containers it manages.

## How it works

Services are implemented in one of three ways, and knowing which is which is most of
knowing what floci can and cannot do:

| Tier | How | Services (examples) |
| --- | --- | --- |
| Stateless, in-process | Java implementations answering the API directly | IAM, STS, SSM, Secrets Manager, KMS, SQS, SNS, Route 53, CloudWatch, CloudFormation |
| Stateful, in-process | Same, plus a pluggable storage backend | S3, DynamoDB |
| **Real Docker** | floci launches *actual containers* running real engines | EKS (k3s), RDS (real PostgreSQL/MySQL/MariaDB), ElastiCache (real Redis), EC2 (a container per instance), Lambda, ECS, OpenSearch, MSK |

The real-Docker tier is the honest kind of emulation — your app talks to a real PostgreSQL
16, a real Redis, a real Kubernetes API server — and it is why floci needs the Docker
socket mounted (`-v /var/run/docker.sock`). A few services are **stubs** that return
shaped dummy data: Textract, Transcribe, Bedrock Runtime.

State: four storage modes via `FLOCI_STORAGE_MODE` — `memory` (ephemeral, fastest),
`persistent` (write-through to disk), `hybrid` (memory with async 5-second flush), `wal`
(write-ahead log). Multi-account isolation works by using different 12-digit access key
IDs; the default account is `000000000000`.

Running it, via the CLI (`floci start`, `floci env`, `floci doctor`, snapshots,
`--persist`) or plain compose:

```yaml
services:
  floci:
    image: floci/floci:latest          # latest-compat adds AWS CLI + boto3 inside
    ports: ["4566:4566"]
    volumes: ["/var/run/docker.sock:/var/run/docker.sock"]
```

```bash
export AWS_ENDPOINT_URL=http://localhost:4566
export AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test AWS_DEFAULT_REGION=us-east-1
```

## EKS, specifically — since it is our core

- `CreateCluster` (default, "real mode") launches **one k3s container per cluster**
  (`rancher/k3s:latest`, overridable), its API server published on a host port from
  6500–6599. The cluster goes `ACTIVE` once k3s answers `/readyz`.
- `aws eks update-kubeconfig --name <cluster>` then `kubectl get nodes` **works
  end-to-end**: floci wires a TokenReview webhook into k3s that maps the AWS-style token to
  `system:masters`, so no `aws-iam-authenticator` is needed.
- **ECR integration is built in**: each k3s container gets a generated `registries.yaml`
  mirroring floci's ECR, so images pushed to the emulated ECR are pullable by pods without
  manual configuration.
- Node group and Fargate profile APIs exist (create/describe/list/delete, 23 operations
  total), **but node groups appear to be metadata** — the docs do not say they launch
  additional worker containers, and there is no `UpdateNodegroupConfig`. The cluster's
  capacity is the one k3s container.
- A `FLOCI_SERVICES_EKS_MOCK=true` mode stores metadata only — useful for cheap
  Terraform-plan-level tests.
- Not supported: cluster config/version updates, add-ons, identity provider configs,
  access entries, encryption config.

## How it differs from real AWS

The differences cluster into two kinds.

**Fundamental to being an emulator** — these hold for any local emulation and are the
accepted cost of never having a real account:

- **The network is not real.** VPCs, subnets, security groups, NAT and internet gateways
  are stored as metadata — Terraform creates and reads them happily, but nothing enforces
  them. There is no packet filtering; Docker bridge networking does the actual routing.
- **No region isolation** — every region name points at the same emulator; no cross-region
  replication.
- **No quotas, throttling, or realistic failure modes.** The emulator never rate-limits
  you, never runs out of capacity, and its IAM does not exercise the sharp edges real IAM
  has. Billing-shaped APIs return synthetic data.
- Proving *wiring* is therefore the ceiling: that the Terraform is coherent, the services
  connect, the app runs. AWS *behaviour* — what fails, when, and how — stays unproven.

**Specific gaps that touch our design** — found in the service docs, each with the move it
forces:

| Reference design piece | floci reality | Our move |
| --- | --- | --- |
| **ALB as the only ingress** | **ELB/ALB is not emulated at all** | Ingress runs at the Kubernetes layer instead: k3s ships Traefik + ServiceLB. The ALB stays in the reference diagram; locally, Traefik plays its part |
| EKS **managed node groups** ×2 AZs, cluster autoscaler | Node groups are API metadata; one k3s container is the cluster; no ASG integration | Multi-node and node-scaling demos happen at the k3s layer — joining/removing k3s agent containers — not through the EKS API. Zone labels are ours to fake |
| **RDS Multi-AZ** primary + standby | Real PostgreSQL 16 container behind an auth proxy (ports 7000–7099) — but no Multi-AZ, failover, or read replicas | Accept a single Postgres for the platform, and if we want the failover *demonstration*, run it in-cluster with an operator (CloudNativePG) as a separate exercise |
| ACM certificate on the ALB | No ALB to attach it to | TLS terminates at Traefik with a locally-issued cert, or is accepted as HTTP locally |
| CloudWatch dashboards/alarms | Logs/metrics APIs accept writes | Real observability, if we want it, is Prometheus + Grafana in-cluster (already the plan) |

## What can and can't be done — summary

**Can:** apply real Terraform (AWS provider, v1.10+) against it; stand up an EKS cluster
and get a live Kubernetes API you can `kubectl` and Helm into; run the app against a real
PostgreSQL via the emulated RDS; store media in emulated S3; push/pull images through
emulated ECR straight into the cluster; keep secrets in SSM; create the whole VPC skeleton
so the Terraform matches the reference design; snapshot and restore emulator state; run it
all in CI if wanted.

**Can't:** terminate TLS on an ALB (none exists); scale nodes through EKS node-group APIs;
fail over a Multi-AZ RDS; enforce a security group; exercise real IAM edge cases, quotas,
or throttling; prove anything about actual AWS behaviour under load or failure. Load and
latency results measured on this stack describe *our app on local hardware* — valid for
finding N+1s, cache problems and scaling cliffs in the app, not for capacity-planning real
AWS.

## To verify in I-1a — things the docs left unclear

1. Does the standard `terraform-aws-modules/eks` module `apply` cleanly, or does it touch
   unsupported APIs (add-ons, access entries) that force a slimmer hand-rolled config?
2. What does `kubectl get nodes` actually show, and can extra k3s agents be joined to
   floci's cluster container for multi-node demos?
3. Does Rails connect happily through the RDS auth proxy (`DATABASE_URL` at
   `localhost:70xx`), including under migration load?
4. Does Active Storage work against floci's S3 (presigned URLs, redirect mode)?
5. How permissive is the emulated IAM — does IRSA-style scoping do anything at all?
