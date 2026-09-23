# Bootstrap — Remote Terraform State

Run this **once**, before creating any environment.

## What it creates
- `chessverse-terraform-state` S3 bucket (versioned, encrypted, lifecycle protected)

> **No DynamoDB table needed.** State locking uses S3's native conditional-write locking,
> available since **Terraform >= 1.10**. A `.tflock` object is written to the bucket
> automatically during `plan`/`apply` and removed on completion.

## Steps

```bash
cd infra/bootstrap/

# 1. Initialize with local state
terraform init

# 2. Review what will be created
terraform plan

# 3. Apply (creates the S3 bucket)
terraform apply

# 4. Note the outputs — they confirm the bucket name
terraform output
```

After this runs successfully, both environment backends (`staging/backend.tf` and
`production/backend.tf`) are already configured to use this bucket.

## ⚠️ Important
- Do NOT run `terraform destroy` on bootstrap — it would delete the state backend
- The S3 bucket has `prevent_destroy = true`
- If you need to delete everything, remove that lifecycle block first
- Requires **Terraform >= 1.10.0** for `use_lockfile = true` support
