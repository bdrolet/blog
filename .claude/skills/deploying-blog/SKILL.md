---
name: deploying-blog
description: Use when the user wants to build and push the blog Docker image, release a new version of the blog, deploy the blog to Kubernetes, or update the blog container image in the cluster.
compatibility: Requires docker, git, kubectl, and gcloud auth configured for us-central1-docker.pkg.dev
---

# Deploying the Blog

Read each agent file from `agents/` before spawning.

## Step 1 — Build and push (sequential)

Spawn **build-and-push** (`agents/build-and-push.md`). Pass:
- `skill_path`: absolute path to this skill directory (the directory containing this SKILL.md)

If the agent reports dirty working tree, stop and tell the user which files need to be committed. Do not proceed to step 2.

If the agent reports failure for any other reason, surface the error and stop.

## Step 2 — Monitor rollout (sequential)

Spawn **monitor-rollout** (`agents/monitor-rollout.md`). Pass the `sha` and `image` from step 1's output.

Report the monitoring summary back to the user. If status is `degraded` or `failed`, include the rollback command.

## Registry

`us-central1-docker.pkg.dev/bens-project-462804/blog/blog`

Kubectl context: `gke_bens-project-462804_us-central1_bens-k8s`

## Auth errors

If `docker push` fails:
```bash
gcloud auth configure-docker us-central1-docker.pkg.dev
```

If `kubectl` fails:
```bash
gcloud container clusters get-credentials bens-k8s --region us-central1
```
