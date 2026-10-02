# ChessVerse — Deployment Guide
### After the Audit Fixes

This document walks you through every action needed to safely bring the audit-fixed infrastructure live.
Each step tells you **what to do**, **whether it's manual or automatic**, and **why it's needed**.

---

## Overview: What Happens End-to-End

```
You (manual)                      GitHub Actions (automatic)
─────────────────                 ──────────────────────────
1. Bootstrap SSM params
2. Set up GitHub Environments
3. Commit & push to main    ──►  (no PR check on direct push)
4. terraform apply staging  ──►  Infrastructure updated
5. Verify staging infra
6. PR: main → prod          ──►  Terraform Plan (production) runs
7. Merge PR → prod          ──►  Terraform Apply (production) starts
                                  └─ Pauses: needs your approval
8. Verify production infra
9. Push code change to main  ──►  Full deploy pipeline runs automatically
10. Verify first deploy
11. PR: main → prod (code)   ──►  Full production deploy pipeline
```

---

## Phase 1 — Pre-Deploy Preparation (Manual)

### Step 1 · Bootstrap SSM Parameters

**What to do:**
```bash
# Run from your terminal with AWS credentials configured

# Staging
aws ssm put-parameter \
  --name "/chessverse/staging/image-tag" \
  --value "latest" \
  --type String \
  --region ap-south-1

# Production
aws ssm put-parameter \
  --name "/chessverse/production/image-tag" \
  --value "latest" \
  --type String \
  --region ap-south-1
```

**Why:**
The new EC2 boot script no longer has a hardcoded image tag. Instead it reads the tag from
AWS SSM Parameter Store at the moment the instance boots. This ensures every auto-scaled
instance always pulls the **exact same image** that was last deployed — not a stale `latest`.

The SSM parameter must **exist before any EC2 instance boots**. If it doesn't, the boot script
fails, the instance never becomes healthy, and the ASG keeps launching broken instances in a loop.
We seed it with `"latest"` as a placeholder — the first real deploy overwrites it with the git SHA.

---

### Step 2 · Set Up GitHub Environments

**What to do:**
Go to your GitHub repo → **Settings → Environments** → create/configure these four:

| Environment Name | Required Reviewers | What it protects |
|---|---|---|
| `staging` | None (auto) | Staging app deploys |
| `production` | ✅ Add yourself | Production app deploys + migrations |
| `terraform-staging` | None (auto) | Terraform apply to staging infra |
| `terraform-production` | ✅ Add yourself | Terraform apply to production infra |

**For environments with Required Reviewers:**
1. Click the environment name
2. Enable **"Required reviewers"** → add your GitHub username
3. Click **Save protection rules**

**Why:**
GitHub Environments are the approval gate. When a workflow job is assigned to an `environment:`
that has required reviewers, GitHub **pauses the pipeline** and emails you before continuing.

This is how the **production migration safety gate (H2)** works in practice:
- On a `prod` push, `validate-migrations` runs `prisma migrate diff` and posts the pending SQL
- The `migrate` job is gated on `environment: production`
- GitHub pauses, you **review the SQL and click Approve**
- Only then does `prisma migrate deploy` touch the production database

Without this, a breaking migration could silently destroy production data.

---

## Phase 2 — Terraform: Staging

### Step 3 · Commit and Push All Changes

**What to do:**
```bash
cd /home/suraj/Documents/Personal_Work/Projects/ChessVerse

git add -A
git commit -m "infra: apply all audit fixes (H1-H4, M1-M7, L1-L3, L6-L7)"
git push origin main
```

**Why:**
Pushes all Terraform + workflow changes to `main`. This doesn't trigger a plan check (that only
fires on PRs), but gets your changes into version control before you apply them.

---

### Step 4 · Terraform Apply — Staging

**What to do:**
```bash
cd infra/environments/staging
terraform init    # only needed if switching backends for the first time
terraform plan    # READ THE OUTPUT before applying
terraform apply   # type "yes" to confirm
```

> Pass your secret vars. Easiest way — export as env vars first:
> ```bash
> export TF_VAR_jwt_secret="..."
> export TF_VAR_cookie_secret="..."
> # etc. — then just run: terraform apply
> ```

**What Terraform changes in staging:**

| Resource | Action | Reason |
|---|---|---|
| `aws_elasticache_replication_group` | **Create** | Replaces old single-node cluster (M6) |
| `aws_elasticache_cluster` (old) | **Destroy** | No longer used |
| `aws_iam_role_policy.secrets_read` | Update | Removed `"*"` wildcard; added SSM permission (H3) |
| `aws_s3_bucket_lifecycle_configuration.alb_logs` | Update | Now reads from variable: 30 days (M3) |
| `aws_cloudwatch_metric_alarm.*_cpu` | Update | Added `treat_missing_data = "breaching"` (M2) |
| `aws_cloudwatch_metric_alarm.alb_latency` | Update | Fixed `extended_statistic = "p99"` (L1) |
| `aws_launch_template.*` | Update | SSM param path replaces hardcoded `"latest"` (H1) |

> [!CAUTION]
> **Redis will be briefly unavailable.** Terraform destroys the old `aws_elasticache_cluster`
> and creates the new `aws_elasticache_replication_group`. Active WebSocket sessions will drop.
> This is acceptable for staging — plan it for a quiet moment.

---

### Step 5 · Verify Staging Infrastructure

**What to do — run these checks:**
```bash
# 1. SSM parameter exists
aws ssm get-parameter \
  --name "/chessverse/staging/image-tag" \
  --region ap-south-1

# 2. Redis replication group is active
aws elasticache describe-replication-groups \
  --replication-group-id chessverse-staging-redis \
  --region ap-south-1 \
  --query "ReplicationGroups[0].Status"
# Expected: "available"

# 3. IAM policy no longer has wildcard
aws iam get-role-policy \
  --role-name chessverse-staging-ec2-role \
  --policy-name chessverse-staging-secrets-read
# Confirm "Resource" does NOT contain "*"
```

**Why:**
Verify before touching production. If anything is wrong, you fix it here with zero user impact.
The exact same Terraform code runs production — so a clean staging means a clean production apply.

---

## Phase 3 — Terraform: Production

### Step 6 · Create a PR: `main` → `prod`

**What to do:**
```bash
git checkout prod
git merge main
git push origin prod
# Then open a Pull Request on GitHub: main → prod
```

**What happens automatically:**
`terraform-plan.yml` fires. The `plan-production` job runs (the `plan-staging` job is skipped
because `paths-filter` detects no staging-specific changes). GitHub posts a comment on the PR
showing the exact production infrastructure diff.

**Why:**
You never apply to production without reviewing the plan first. The PR comment is your last
checkpoint — read it carefully before merging.

---

### Step 7 · Merge PR → `prod` (Terraform Apply)

**What to do:** Merge the PR on GitHub.

**What happens automatically:**
1. `terraform-apply.yml` fires on push to `prod`
2. `apply-production` job hits the `terraform-production` environment gate
3. **GitHub sends you a notification: "Waiting for your review"**
4. You go to the Actions tab → click **Review deployments → Approve and deploy**
5. Terraform applies

**What Terraform changes in production:**

| Resource | Action | Reason |
|---|---|---|
| `aws_rds_cluster_instance.reader[0]` | **Create** | Aurora reader for near-instant failover (M5) |
| `aws_elasticache_replication_group` | **Create** | Multi-AZ Redis: primary + replica (M6) |
| `aws_elasticache_cluster` (old) | **Destroy** | Replaced |
| `aws_autoscaling_group.*` | Update | `min_healthy_percentage = 90` (M7) |
| `aws_s3_bucket.alb_logs` | Update | `force_destroy = false` protects prod logs (L7) |
| `aws_s3_bucket_lifecycle_configuration.alb_logs` | Update | 90-day retention (M3) |
| `aws_iam_role_policy.secrets_read` | Update | No wildcard; scoped SSM permission (H3) |
| `aws_launch_template.*` | Update | SSM param path for image tag (H1) |

> [!CAUTION]
> **Redis downtime applies here too.** Schedule this during off-peak hours.
> The Aurora reader creation (~5–10 min) does **not** cause database downtime.

---

### Step 8 · Verify Production Infrastructure

**What to do:**
```bash
# 1. Aurora reader instance exists
aws rds describe-db-instances \
  --region ap-south-1 \
  --query "DBInstances[?contains(DBInstanceIdentifier,'reader')].{ID:DBInstanceIdentifier,Status:DBInstanceStatus}"
# Expected: "available"

# 2. Redis Multi-AZ is enabled
aws elasticache describe-replication-groups \
  --replication-group-id chessverse-production-redis \
  --region ap-south-1 \
  --query "ReplicationGroups[0].{Status:Status,MultiAZ:MultiAZ}"
# Expected: "available", "enabled"

# 3. ALB logs bucket has 90-day lifecycle (not 30)
aws s3api get-bucket-lifecycle-configuration \
  --bucket chessverse-production-alb-logs \
  --region ap-south-1
```

---

## Phase 4 — First Application Deploy (Fully Automatic)

### Step 9 · Trigger the First Code Deploy to Staging

**What to do:** Push any small change to `main`:
```bash
git checkout main
# make any minor change (e.g. update a README or add a comment)
git commit -m "chore: trigger first deploy with new pipeline"
git push origin main
```

**What happens automatically — in this exact order:**

```
[1] validate-migrations  (staging auto-proceeds, no approval needed)
      └─ Fetches DATABASE_URL from Secrets Manager
      └─ Runs: prisma migrate diff → shows pending SQL in job summary
      └─ Posts "No pending migrations" or "⚠️ Pending DB Migration" summary

[2] migrate  (runs only after validate-migrations passes)
      └─ Runs: prisma migrate deploy → safely applies any pending migrations

[3a] build-and-push          [3b] deploy-frontend  (both run in parallel)
      └─ Builds Docker images        └─ yarn build
      └─ Tags with git SHA           └─ aws s3 sync (hashed assets + index.html)
      └─ Pushes to ECR               └─ CloudFront invalidation
      └─ (no "latest" tag on staging)

[4a] deploy-backend          [4b] deploy-ws  (both run in parallel after build)
      └─ Writes SHA to SSM:           └─ Same, but for WS ASG
         /chessverse/staging/image-tag
      └─ Triggers ASG instance refresh
      └─ Polls every 30s:
           InProgress (0%)
           InProgress (25%)
           InProgress (75%)
           Successful (100%) ✅
         (AWS auto-rolls back if new instances fail health checks)

[5] verify-deployment  (runs after both backend + ws + frontend done)
      └─ Waits 30s for instance warmup
      └─ Polls https://{API_DOMAIN}/health up to 10 times
      └─ Reports ✅ or ❌
```

**Why this pipeline is better than before:**

| Old pipeline | New pipeline |
|---|---|
| `sleep 30` — blind wait | Polls real ASG status every 30s |
| No rollback if container crashes at startup | AWS auto-rolls back on failed ALB health checks |
| Auto-scaled instances boot with `latest` (could be stale) | Auto-scaled instances read exact SHA from SSM |
| Staging deploys overwrote `latest` tag in production ECR | `latest` tag only pushed on `prod` branch |
| No migration review — ran blindly against production | `prisma migrate diff` posted + approval gate |

---

### Step 10 · Verify the First Deploy

**What to do — in GitHub Actions:**
1. Go to **Actions** tab → "Deploy" workflow → latest run
2. All 6 jobs should be green ✅
3. Click `deploy-backend` → expand **"Poll backend refresh"** — expect output like:
   ```
   Attempt 1/40 -- Status: InProgress (0% complete)
   Attempt 3/40 -- Status: InProgress (50% complete)
   Attempt 5/40 -- Status: Successful (100% complete)
   ✅ Backend instance refresh completed successfully.
   ```

**What to do — in terminal:**
```bash
# Confirm SSM param now holds a real SHA (not "latest")
aws ssm get-parameter \
  --name "/chessverse/staging/image-tag" \
  --region ap-south-1 \
  --query Parameter.Value --output text
# Expected: a40f3b2c9d... (your git SHA)

# Confirm staging API is healthy
curl https://api.staging.chess.lumenvault.live/health
# Expected: HTTP 200
```

---

## Phase 5 — Production Code Deploy

### Step 11 · Deploy to Production

When staging is working and you're ready:

**What to do:**
1. Create a PR on GitHub: `main` → `prod`
2. Wait for the Terraform plan comment to appear on the PR (only infra changes show up here — for code-only changes the plan will show "No changes")
3. Merge the PR

**What happens automatically:**
Same pipeline as Step 9 but targeting production. GitHub pauses **twice** for your approval:

1. **Before `validate-migrations`** — the `production` environment gate fires
   - You see the migration SQL diff in the job summary
   - Click **Approve** only if the SQL looks safe
2. **Before `migrate`** — second pause (same environment gate)
   - Final confirmation before the migration runs on the live database
   - Click **Approve** to proceed

Then the rest of the pipeline runs identically to staging: build → refresh backend ASG → refresh ws ASG → verify.

---

## Quick Reference

### Branch → Environment

| Push to | Terraform Plan | Terraform Apply | App Deploy Target |
|---|---|---|---|
| `main` (via PR) | Runs staging plan | — | — |
| `main` (merge/push) | — | Applies staging | Staging |
| `prod` (via PR) | Runs production plan | — | — |
| `prod` (merge/push) | — | Applies production | Production |

### Manual vs Automatic

| Action | Who |
|---|---|
| Bootstrap SSM params | **You — once** |
| Create GitHub Environments + reviewers | **You — once** |
| `terraform apply` (staging) | **You** |
| `terraform apply` (production) | **You approve → Automatic runs** |
| Production migration approval | **You** |
| Docker build + ECR push | **Automatic** |
| SSM parameter write (image tag) | **Automatic** |
| ASG instance refresh | **Automatic** |
| Rollback on failed health check | **Automatic (AWS)** |
| S3 + CloudFront frontend deploy | **Automatic** |
| Health check verification | **Automatic** |

---

## Phase 6 — Infrastructure Teardown (Destroy)

> [!CAUTION]
> **Destruction is permanent.** Once Terraform destroys resources, the data is gone.
> Production has `deletion_protection = true` on Aurora and `force_destroy = false` on the
> ALB log bucket — Terraform will refuse to destroy those until you explicitly override them.
> This is intentional. Read every warning below before running `terraform destroy`.

---

### Why you might destroy

- Shutting down the project entirely
- Cleaning up a staging environment to save costs
- Rebuilding from scratch after a major infrastructure change

---

### Step D1 · Destroy Staging (Safer, No Data Risk)

**What to do:**

```bash
cd infra/environments/staging
terraform destroy
# type "yes" when prompted
```

**What gets destroyed (in dependency order — Terraform handles this automatically):**

| Resource | Notes |
|---|---|
| EC2 instances (via ASG) | Terminated immediately |
| Application Load Balancer | DNS stops resolving |
| ALB S3 log bucket | `force_destroy = true` on staging → bucket deleted even if it has logs |
| Launch templates | Deleted |
| Aurora cluster + writer instance | Deleted. Staging has `skip_final_snapshot = true` — **no backup is taken** |
| ElastiCache Redis replication group | All session data lost |
| CloudWatch alarms + dashboard | Deleted |
| CloudWatch log groups | Deleted (log data gone) |
| IAM roles + policies | Deleted |
| SSM Parameter (`/chessverse/staging/image-tag`) | **Not managed by Terraform** — delete manually (see Step D4) |
| S3 frontend bucket | Deleted |
| CloudFront distribution | Takes ~15 min to fully disable |
| VPC, subnets, security groups | Deleted last |

**Why staging is straightforward:**
`deletion_protection = false` and `skip_final_snapshot = true` — Terraform destroys Aurora
without complaint and without taking a backup. This is fine for staging.

---

### Step D2 · Prepare Production for Destroy

Production has two safety locks that must be removed before `terraform destroy` will work.

#### 2a — Disable Aurora deletion protection

**Why it's locked:** Aurora has `deletion_protection = true` so no one can accidentally
destroy the production database. Terraform will refuse to delete it until you turn this off.

**Option A — via Terraform (recommended):**

In [`environments/production/main.tf`](file:///home/suraj/Documents/Personal_Work/Projects/ChessVerse/infra/environments/production/main.tf),
change the database module call:

```hcl
module "database" {
  # ...
  deletion_protection = false   # was: true
  skip_final_snapshot = true    # was: false — skip snapshot if you don't need it
}
```

Then apply that change first:
```bash
cd infra/environments/production
terraform apply   # only changes the deletion_protection flag — no downtime
```

**Option B — via AWS Console (faster):**
1. Go to RDS → Clusters → `chessverse-production`
2. Click **Modify** → uncheck **Deletion protection** → **Continue** → **Apply immediately**

#### 2b — Empty the ALB log S3 bucket

**Why:** Production ALB log bucket has `force_destroy = false`. AWS refuses to delete an
S3 bucket that still has objects. You must empty it first.

```bash
# Delete all objects in the bucket (including old log files)
aws s3 rm s3://chessverse-production-alb-logs --recursive --region ap-south-1

# Optional: if versioning is enabled, also delete all versions
aws s3api delete-objects \
  --bucket chessverse-production-alb-logs \
  --delete "$(aws s3api list-object-versions \
    --bucket chessverse-production-alb-logs \
    --query '{Objects: Versions[].{Key:Key,VersionId:VersionId}}' \
    --output json)" \
  --region ap-south-1
```

> [!NOTE]
> If you want to keep these logs for billing/audit, download them first:
> `aws s3 sync s3://chessverse-production-alb-logs ./alb-logs-backup --region ap-south-1`

#### 2c — Take a final database snapshot (optional but strongly recommended)

**Why:** Once Aurora is destroyed, the data is gone. If you might need it later, snapshot it now.

```bash
aws rds create-db-cluster-snapshot \
  --db-cluster-identifier chessverse-production \
  --db-cluster-snapshot-identifier chessverse-production-final-$(date +%Y%m%d) \
  --region ap-south-1
```

Wait for the snapshot status to become `available` before continuing:
```bash
aws rds describe-db-cluster-snapshots \
  --db-cluster-snapshot-identifier chessverse-production-final-$(date +%Y%m%d) \
  --query "DBClusterSnapshots[0].Status" \
  --region ap-south-1
```

---

### Step D3 · Destroy Production

Only run this after completing all of Step D2.

```bash
cd infra/environments/production
terraform destroy
# type "yes" when prompted
```

**What gets destroyed:**

| Resource | Notes |
|---|---|
| EC2 instances (via ASG) | Terminated |
| Application Load Balancer | DNS stops resolving |
| ALB S3 log bucket | Now empty — can be deleted |
| Aurora cluster + writer + reader | Deleted. Snapshot exists if you did Step D2c |
| ElastiCache Redis (Multi-AZ) | Both nodes deleted |
| CloudWatch resources | Deleted |
| IAM roles + policies | Deleted |
| S3 frontend bucket | Deleted |
| CloudFront distribution | Disabled + deleted (~15 min) |
| VPC, subnets, SGs, route tables | Deleted last |

> [!WARNING]
> `terraform destroy` on production takes **15–25 minutes** because CloudFront distributions
> take time to fully disable before they can be deleted. Do not interrupt it.

---

### Step D4 · Clean Up Resources Not Managed by Terraform (Manual)

Some resources were created outside Terraform and must be deleted manually.

```bash
# 1. Delete SSM Parameters (created in Step 1 of this guide, not in Terraform)
aws ssm delete-parameter --name "/chessverse/staging/image-tag"    --region ap-south-1
aws ssm delete-parameter --name "/chessverse/production/image-tag" --region ap-south-1

# 2. Delete ECR images (ECR repos are managed by Terraform and deleted with destroy,
#    but images are not — Terraform only creates the repo + lifecycle policy)
#    The lifecycle policy auto-expires old images, but the latest ones remain.
#    If you want clean deletion:
aws ecr delete-repository \
  --repository-name chessverse-backend \
  --force \
  --region ap-south-1

aws ecr delete-repository \
  --repository-name chessverse-ws \
  --force \
  --region ap-south-1

# 3. Delete the Terraform state backend (ONLY if you're shutting down entirely)
#    WARNING: Deleting this removes all record of what Terraform managed.
#    Do this LAST, after all environments are destroyed.
aws s3 rm s3://chessverse-terraform-state --recursive --region ap-south-1
aws s3api delete-bucket --bucket chessverse-terraform-state --region ap-south-1
```

---

### Step D5 · Verify Everything Is Gone

```bash
# Check no EC2 instances remain
aws ec2 describe-instances \
  --filters "Name=tag:Project,Values=ChessVerse" "Name=instance-state-name,Values=running,stopped" \
  --query "Reservations[].Instances[].InstanceId" \
  --region ap-south-1
# Expected: [] (empty)

# Check no RDS clusters remain
aws rds describe-db-clusters \
  --query "DBClusters[?contains(DBClusterIdentifier,'chessverse')].DBClusterIdentifier" \
  --region ap-south-1
# Expected: [] (empty)

# Check no ElastiCache remains
aws elasticache describe-replication-groups \
  --query "ReplicationGroups[?contains(ReplicationGroupId,'chessverse')].ReplicationGroupId" \
  --region ap-south-1
# Expected: [] (empty)

# Check no load balancers remain
aws elbv2 describe-load-balancers \
  --query "LoadBalancers[?contains(LoadBalancerName,'chessverse')].LoadBalancerName" \
  --region ap-south-1
# Expected: [] (empty)
```

---

### Destroy Order Summary

```
Staging (safe to run any time)
└── terraform destroy  →  done

Production (do in this order)
├── 1. Snapshot Aurora (if you need the data)
├── 2. Disable deletion_protection on Aurora
├── 3. Empty the ALB log S3 bucket
├── 4. terraform destroy  (15–25 min)
└── 5. Manual cleanup: SSM params, ECR repos, state bucket
```

### Quick Teardown Reference

| Action | Manual / Auto | Risk |
|---|---|---|
| `terraform destroy` staging | **You** | Low — no production data |
| Snapshot production Aurora | **You** | None — creates a backup |
| Disable Aurora deletion_protection | **You** | Low — just removes lock |
| Empty ALB log bucket | **You** | Logs deleted permanently |
| `terraform destroy` production | **You** | 🔴 High — all data destroyed |
| Delete SSM parameters | **You** | Low |
| Delete ECR repositories | **You** | Images deleted permanently |
| Delete Terraform state bucket | **You — last** | 🔴 Cannot undo |
