# ChessVerse — Infrastructure (Terraform)

Production-grade, module-based Terraform for ChessVerse on AWS (ap-south-1 Mumbai).

## Architecture

```
name.com (lumenvault.live)
    └── NS delegation → Route53 hosted zone (chess.lumenvault.live)
                              │
            ┌─────────────────┼──────────────────┐
            ▼                 ▼                  ▼
   chess.lumenvault.live   api.chess...    staging.chess...
   (CloudFront → S3)       (ALB)          (separate stack)
                             │
              ┌──────────────┼──────────────┐
              ▼              ▼              ▼
         Backend ASG      WS ASG      ElastiCache Redis
         (EC2+Docker)   (EC2+Docker)   (pub/sub + sessions)
              │              │
              └──────────────┘
                     │
              Aurora PostgreSQL
              (Serverless v2)
```

## Directory Structure

```
infra/
├── bootstrap/              ← Run ONCE: creates S3 state bucket + DynamoDB lock
├── modules/
│   ├── networking/         ← VPC, subnets, IGW, NAT, security groups
│   ├── dns/                ← Route53 zone, ACM cert, health checks, DNS records
│   ├── ecr/                ← ECR repos (managed by production env)
│   ├── database/           ← Aurora PostgreSQL Serverless v2
│   ├── cache/              ← ElastiCache Redis 7.x
│   ├── iam/                ← EC2 instance role (ECR, SSM, Secrets, CloudWatch)
│   ├── secrets/            ← Secrets Manager (all app config as one JSON secret)
│   ├── storage/            ← S3 + CloudFront (React SPA)
│   ├── compute/            ← ALB, launch templates, ASGs with auto-rollback
│   └── monitoring/         ← CloudWatch logs, alarms, dashboard, SNS
├── environments/
│   ├── staging/            ← staging.chess.lumenvault.live
│   └── production/         ← chess.lumenvault.live
└── .github/workflows/
    ├── terraform-plan.yml  ← PR → posts plan as comment
    └── terraform-apply.yml ← Merge → manual approval → apply
```

## First-Time Setup

### 1. Run Bootstrap (once)
```bash
cd infra/bootstrap/
terraform init && terraform apply
```

### 2. Configure GitHub Secrets

**Repository-level secrets:**
| Secret | Value |
|--------|-------|
| `AWS_ACCESS_KEY_ID` | IAM user access key |
| `AWS_SECRET_ACCESS_KEY` | IAM user secret key |

**GitHub Environment `terraform-staging` secrets:**
| Secret | Value |
|--------|-------|
| `TF_VAR_JWT_SECRET` | Staging JWT secret |
| `TF_VAR_COOKIE_SECRET` | Staging cookie secret |
| `TF_VAR_GOOGLE_CLIENT_ID` | Staging Google OAuth client ID |
| `TF_VAR_GOOGLE_CLIENT_SECRET` | Staging Google OAuth secret |
| `TF_VAR_GITHUB_CLIENT_ID` | Staging GitHub OAuth client ID |
| `TF_VAR_GITHUB_CLIENT_SECRET` | Staging GitHub OAuth secret |

**GitHub Environment `terraform-production` secrets:** (same keys, different values)

### 3. Configure GitHub Environments
1. Go to **Settings → Environments → New environment**
2. Create `terraform-staging` with yourself as required reviewer
3. Create `terraform-production` with yourself as required reviewer

### 4. Deploy Production (first)

Production must be deployed first because it creates the ECR repositories that
staging will reference via data sources.

```bash
cd infra/environments/production/
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with real values
terraform init
terraform plan
terraform apply
```

**After apply — note these outputs:**
- `dns_name_servers` → Add these 4 NS records to name.com under `chess.lumenvault.live`
- `ecr_registry` → Set as `ECR_REGISTRY` in your app deployment GitHub secrets
- `frontend_s3_bucket` → Set as `FRONTEND_S3_BUCKET` in GitHub secrets
- `cloudfront_distribution_id` → Set as `CLOUDFRONT_DISTRIBUTION_ID` in GitHub secrets

### 5. DNS Delegation (name.com)

1. Log into name.com → Manage Domain → DNS Records
2. Add 4 NS records for subdomain `chess` pointing to the Route53 name servers from step 4
3. Wait ~5 minutes for propagation

### 6. Deploy Staging

```bash
cd infra/environments/staging/
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars
terraform init
terraform apply
```

### 7. After Deployment — App Secrets

Each environment's `DATABASE_URL` and `REDIS_URL` are automatically injected into
AWS Secrets Manager. EC2 instances fetch these at boot.

For the CI/CD application pipeline (deploy.yml), set:
- `ECR_REGISTRY` = from `terraform output ecr_registry` (production)
- `FRONTEND_S3_BUCKET` = from `terraform output frontend_s3_bucket`
- `CLOUDFRONT_DISTRIBUTION_ID` = from `terraform output cloudfront_distribution_id`
- `DATABASE_URL` = from `terraform output aurora_endpoint` (for prisma migrate step)

## PR-Driven Workflow

1. Create branch, make infra changes
2. Open PR → GitHub Actions runs `terraform plan` on changed environments
3. Plan appears as a comment on the PR
4. Get PR reviewed and merged
5. GitHub Actions detects merge → requires manual approval (GitHub Environment gate)
6. On approval → `terraform apply` runs

## Rollback

- **Application rollback:** ASG instance refresh auto-cancels if new instances fail health checks → old instances remain running
- **Infrastructure rollback:** Each apply is versioned in S3. To restore: `aws s3 cp s3://chessverse-terraform-state/<env>/terraform.tfstate.backup ./` then apply

## Environment Differences

| Setting | Staging | Production |
|---------|---------|-----------|
| Domain | `staging.chess.lumenvault.live` | `chess.lumenvault.live` |
| Aurora min/max ACU | 0.5 / 4 | 1 / 16 |
| Aurora backup retention | 3 days | 14 days |
| Deletion protection | OFF | ON |
| EC2 instance type | t3.small | t3.medium |
| ASG min/max per service | 1 / 3 | 2 / 6 |
| Log retention | 30 days | 90 days |
| Redis node type | cache.t3.micro | cache.t3.small |
