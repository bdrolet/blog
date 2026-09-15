---
name: deploying-blog
description: Use when the user wants to deploy, publish, or release the blog, push a new post live, check whether a blog deploy finished, or debug a failed blog build on Cloudflare Pages.
compatibility: Requires git, curl and python3. Reads the Cloudflare API token from ~/src/infra/cloudflare/terraform.tfvars for build status; the live-site check needs no credentials.
---

# Deploying the Blog

The blog is a **Cloudflare Pages** project. There is no image to build and
nothing to roll out: pushing to `main` on `github.com/bdrolet/blog` triggers a
Pages build, and the build publishes the site.

> This used to be a Docker image pushed to Artifact Registry and rolled out to a
> Kubernetes Deployment behind a GKE Ingress. That Ingress had its own GCP load
> balancer at ~$18/month to serve a static site, so the blog moved to Pages and
> the whole cluster path was deleted. Do not reach for `docker`, `kubectl` or
> `gcloud` here — none of them are involved any more.

| | |
|---|---|
| **Repo** | `bdrolet/blog`, production branch `main` |
| **Pages project** | `blog` |
| **Build** | `npm run build` → `dist`, `NODE_VERSION=22.12.0` |
| **Live** | https://blog.drolet.cloud |
| **Pages URL** | https://blog-jl5.pages.dev |

The project is defined in Terraform, not in this repo:
`~/src/infra/cloudflare/drolet-cloud.tf` (`cloudflare_pages_project.blog`).
Change the build command, output directory or Node version there, not in the
Cloudflare dashboard.

## Step 1 — Commit and push

```bash
git status --short          # confirm what is going out
git push origin main
```

Anything committed to `main` goes live. Drafts must stay uncommitted or out of
`src/content/blog/`.

## Step 2 — Watch the build

```bash
bash .claude/skills/deploying-blog/scripts/deploy-status.sh
```

It polls the latest deployment until it reaches a terminal stage and prints the
stage, the status and the deployment URL. A successful run ends at
`deploy/success`; anything else is a failure and the script prints the failing
stage.

Without a Cloudflare token it falls back to reporting that it cannot read build
status — in that case skip to step 3, which needs no credentials, or read the
build log in the Cloudflare dashboard under **Workers & Pages → blog**.

## Step 3 — Verify the live site

```bash
curl -sI https://blog.drolet.cloud/ | head -1
curl -s https://blog.drolet.cloud/ | grep -o '<title>[^<]*</title>'
```

Expect `HTTP/2 200`. To confirm a specific post is live, request its URL
directly and check for a `200` rather than trusting the index page, which may
still be cached at the edge.

## Troubleshooting

| Symptom | Cause |
|---|---|
| Build fails on an Astro or syntax error | Reproduce locally with `npm run build`; the Pages build runs the same command |
| Build fails with an unsupported Node version | `NODE_VERSION` is pinned in `cloudflare_pages_project.blog`; Astro 6 needs ≥ 22.12 |
| Build succeeds but the site is unchanged | Cloudflare edge cache — retry with a cache-busting query string, or purge the cache for the zone |
| `deploy-status.sh` reports no token | The token lives in `~/src/infra/cloudflare/terraform.tfvars`, which exists only on the machine that runs the infra Terraform |
| 522 from `blog.drolet.cloud` | The Pages custom domain is not `active`; check the domain's status in the infra Terraform state or the dashboard |
