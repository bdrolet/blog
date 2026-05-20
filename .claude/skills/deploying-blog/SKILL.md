---
name: deploying-blog
description: Use when the user wants to build and push the blog Docker image, release a new version of the blog, deploy the blog to Kubernetes, or update the blog container image in the cluster.
compatibility: Requires docker, git, kubectl, and gcloud auth configured for us-central1-docker.pkg.dev
---

# Deploying the Blog

Run `scripts/push.sh` from the repo root. It handles the full deploy end-to-end:

1. Abort if there are uncommitted changes (working tree must be clean)
2. Compute the short git SHA
3. Build the Docker image tagged as both `<SHA>` and `latest`
3. Push both tags to the registry
4. Push both tags to the registry
5. Run `kubectl set image` on the `blog` deployment in the `apps` namespace
6. Wait for the rollout to complete with `kubectl rollout status`

```bash
bash scripts/push.sh
```

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
