# ChessVerse Deployment Process

This document outlines the step-by-step process for deploying the ChessVerse application. It details which actions you need to perform manually, which actions are handled automatically by the CI/CD pipeline, and the underlying purpose of each step.

---

## 🧑‍💻 Manual Steps (What You Do)

These are the actions you take as a developer to initiate and approve the deployment process.

### 1. Write Code & Infrastructure Changes
*   **What:** Develop new features, fix bugs, or modify Terraform files (`infra/`).
*   **Why:** This is the core development work. Note: If you change infrastructure (Terraform), you must apply those changes manually using `terraform apply` before pushing application code that depends on the new infra.

### 2. Push to Remote Branches (`main` or `prod`)
*   **What:** Run `git push origin main` (for staging) or `git push origin prod` (for production).
*   **Why:** Pushing to these specific branches triggers the GitHub Actions workflow (`.github/workflows/deploy.yml`). This is the event that kicks off the automatic pipeline.

### 3. Review and Approve Production Deployments (Production Only)
*   **What:** If you pushed to `prod` and there are pending database migrations, you must go to the GitHub Actions tab and manually click "Review deployments" to approve the production environment deployment.
*   **Why:** This prevents destructive or irreversible database changes from applying to the live production database automatically without human oversight.

---

## 🤖 Automatic Steps (What the Pipeline Does)

Once you push to `main` or `prod`, the GitHub Actions workflow takes over. Here is exactly what happens step-by-step, entirely in the background.

### Step 1: Validate DB Migrations (diff)
*   **What:** The pipeline runs a "dry run" of Prisma database migrations (`prisma migrate diff`) against the target database (Staging or Production).
*   **Why:** To ensure that the database schema defined in your code matches the actual database. If changes are needed, it outputs the exact SQL that will run, allowing you to review it (crucial for production).

### Step 2: Apply DB Migrations
*   **What:** Runs `prisma migrate deploy`.
*   **Why:** This executes any pending SQL migrations on the actual AWS RDS database. We do this *before* deploying new code so that when the new backend starts up, the database tables and columns it expects are already there.

### Step 3: Build & Push Docker Images
*   **What:** Docker builds the `backend` and `ws` (WebSocket) applications. It tags them with the unique Git Commit SHA (e.g., `sha-a1b2c3d`) and pushes them to Amazon Elastic Container Registry (ECR).
*   **Why:** ECR acts as our image storage. By tagging them with the Git commit, we can easily trace which version of the code is running in AWS. The servers will pull these images in the next step.

### Step 4: Deploy Backend & WebSocket (Instance Refresh)
*   **What:** 
    1. Writes the new Docker Image tag (the Git SHA) into AWS Systems Manager (SSM) Parameter Store.
    2. Triggers an **Auto Scaling Group (ASG) Instance Refresh** for both the Backend and WS ASGs.
    3. Polls AWS continuously until the refresh reaches 100%.
*   **Why:** 
    *   **SSM Parameter:** The EC2 instances use a startup script (user-data) that reads this SSM parameter to know exactly which Docker image to pull and run.
    *   **Instance Refresh:** This ensures zero-downtime deployments. AWS spins up *new* EC2 instances with the new code, waits for them to be healthy, and then terminates the *old* instances on a rolling basis.

### Step 5: Deploy Frontend (S3 + CloudFront)
*   **What:** Builds the React frontend application using Vite. It then uploads the static files (HTML, JS, CSS) to an AWS S3 bucket and tells CloudFront (the CDN) to invalidate its cache.
*   **Why:** We host the frontend as a static site on S3 because it is extremely fast and cheap. CloudFront distributes these files globally. Invalidating the cache forces CloudFront to fetch your newly uploaded files so users instantly see the latest version of the website.

### Step 6: Verify Deployment Health
*   **What:** Waits for 30 seconds, then repeatedly pings the API's `/health` endpoint until it gets a `200 OK` response.
*   **Why:** This acts as a final sanity check. If the pipeline finishes and this step passes, you have absolute confirmation that the new code is live, running, and accessible to the public internet.

---

## 🎯 Summary Workflow

1. You write code and `git push origin main`.
2. Pipeline checks the Database.
3. Pipeline updates the Database.
4. Pipeline uploads new App code to ECR and S3.
5. Pipeline tells AWS to gracefully restart the servers to pull the new code.
6. Pipeline confirms the app is healthy.
7. Done! 🎉
